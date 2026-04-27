-- Caisse Facile — Schéma Supabase (Postgres)
-- À exécuter dans Supabase Studio → SQL Editor.
-- Multi-tenant: chaque ligne appartient à un `shop_id`. RLS = isolation par épicerie.

create extension if not exists "pgcrypto";

-- ============ SHOPS / MEMBERSHIP ============

create table if not exists shops (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  currency text not null default 'F',
  created_at timestamptz not null default now()
);

-- Lien utilisateur Supabase ↔ épicerie. Un user peut gérer plusieurs shops.
create table if not exists shop_members (
  shop_id uuid not null references shops(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'owner' check (role in ('owner','cashier')),
  pin_hash text,                         -- PIN local optionnel (haché côté client)
  created_at timestamptz not null default now(),
  primary key (shop_id, user_id)
);

-- ============ DOMAIN TABLES ============

create table if not exists products (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references shops(id) on delete cascade,
  barcode text not null,
  name text not null,
  category text,
  purchase_price numeric not null default 0,
  sale_price numeric not null default 0,
  stock_qty numeric not null default 0,
  alert_threshold numeric not null default 0,
  expiry_date date,
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (shop_id, barcode)
);
create index if not exists idx_products_shop on products(shop_id);
create index if not exists idx_products_updated on products(updated_at);

create table if not exists delivery_men (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references shops(id) on delete cascade,
  name text not null,
  phone text,
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index if not exists idx_delivery_men_shop on delivery_men(shop_id);

create table if not exists delivery_sessions (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references shops(id) on delete cascade,
  delivery_man_id uuid not null references delivery_men(id),
  status text not null check (status in ('IN_PROGRESS','COMPLETED')),
  start_date timestamptz not null default now(),
  end_date timestamptz,
  updated_at timestamptz not null default now()
);
create index if not exists idx_sessions_shop on delivery_sessions(shop_id);

create table if not exists session_items (
  session_id uuid not null references delivery_sessions(id) on delete cascade,
  product_id uuid not null references products(id),
  qty_out numeric not null default 0,
  qty_returned numeric not null default 0,
  unit_sale_price numeric not null default 0,
  unit_purchase_price numeric not null default 0,
  updated_at timestamptz not null default now(),
  primary key (session_id, product_id)
);

create table if not exists sales (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references shops(id) on delete cascade,
  date timestamptz not null default now(),
  total numeric not null default 0,
  profit numeric not null default 0,
  source text not null default 'COUNTER' check (source in ('COUNTER','DELIVERY')),
  session_id uuid references delivery_sessions(id),
  updated_at timestamptz not null default now()
);
create index if not exists idx_sales_shop_date on sales(shop_id, date);

create table if not exists sale_items (
  id uuid primary key default gen_random_uuid(),
  sale_id uuid not null references sales(id) on delete cascade,
  product_id uuid not null references products(id),
  qty numeric not null,
  unit_sale_price numeric not null,
  unit_purchase_price numeric not null
);
create index if not exists idx_sale_items_sale on sale_items(sale_id);

-- ============ updated_at TRIGGERS ============

create or replace function set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;

do $$ declare t text; begin
  for t in
    select unnest(array['products','delivery_men','delivery_sessions','session_items','sales'])
  loop
    execute format('drop trigger if exists trg_%I_updated on %I', t, t);
    execute format('create trigger trg_%I_updated before update on %I for each row execute function set_updated_at()', t, t);
  end loop;
end $$;

-- ============ ROW LEVEL SECURITY ============

alter table shops enable row level security;
alter table shop_members enable row level security;
alter table products enable row level security;
alter table delivery_men enable row level security;
alter table delivery_sessions enable row level security;
alter table session_items enable row level security;
alter table sales enable row level security;
alter table sale_items enable row level security;

-- Helper: shops the current user is member of
create or replace function user_shop_ids() returns setof uuid
language sql stable as $$
  select shop_id from shop_members where user_id = auth.uid()
$$;

-- shops
drop policy if exists shops_select on shops;
create policy shops_select on shops for select
  using (id in (select user_shop_ids()));
drop policy if exists shops_insert on shops;
create policy shops_insert on shops for insert
  with check (true);  -- created by RPC; tightened below
drop policy if exists shops_update on shops;
create policy shops_update on shops for update
  using (id in (select user_shop_ids()));

-- shop_members
drop policy if exists members_select on shop_members;
create policy members_select on shop_members for select
  using (user_id = auth.uid() or shop_id in (select user_shop_ids()));
drop policy if exists members_insert on shop_members;
create policy members_insert on shop_members for insert
  with check (user_id = auth.uid()); -- self-enroll via RPC

-- Generic policies for shop-scoped tables
do $$ declare t text; begin
  for t in
    select unnest(array['products','delivery_men','delivery_sessions','sales'])
  loop
    execute format('drop policy if exists %I_select on %I', t||'_select', t);
    execute format('create policy %I on %I for select using (shop_id in (select user_shop_ids()))',
                   t||'_select', t);
    execute format('drop policy if exists %I_modify on %I', t||'_modify', t);
    execute format('create policy %I on %I for all using (shop_id in (select user_shop_ids())) with check (shop_id in (select user_shop_ids()))',
                   t||'_modify', t);
  end loop;
end $$;

-- session_items / sale_items: via parent
drop policy if exists session_items_all on session_items;
create policy session_items_all on session_items for all
  using (session_id in (select id from delivery_sessions where shop_id in (select user_shop_ids())))
  with check (session_id in (select id from delivery_sessions where shop_id in (select user_shop_ids())));

drop policy if exists sale_items_all on sale_items;
create policy sale_items_all on sale_items for all
  using (sale_id in (select id from sales where shop_id in (select user_shop_ids())))
  with check (sale_id in (select id from sales where shop_id in (select user_shop_ids())));

-- ============ RPC: create_shop ============
create or replace function create_shop(p_name text, p_currency text default 'F')
returns uuid language plpgsql security definer as $$
declare new_id uuid;
begin
  insert into shops(name, currency) values (p_name, p_currency) returning id into new_id;
  insert into shop_members(shop_id, user_id, role) values (new_id, auth.uid(), 'owner');
  return new_id;
end $$;
revoke all on function create_shop(text, text) from public;
grant execute on function create_shop(text, text) to authenticated;
