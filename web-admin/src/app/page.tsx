import { redirect } from 'next/navigation';
import { serverClient } from '@/lib/supabase-server';

const fmt = (n: number) =>
  new Intl.NumberFormat('fr-FR', {
    style: 'currency',
    currency: 'XOF',
    maximumFractionDigits: 0,
  }).format(n);

export default async function DashboardPage() {
  const sb = serverClient();
  const {
    data: { user },
  } = await sb.auth.getUser();
  if (!user) redirect('/login');

  // Shops
  const { data: shopsRes } = await sb
    .from('shop_members')
    .select('role, shops(id, name, currency)');
  const shops = (shopsRes ?? []).map((r: any) => r.shops);

  if (shops.length === 0) {
    return (
      <div className="bg-white p-8 rounded shadow">
        <p>Aucune épicerie associée à ce compte. Crée-en une depuis l'app mobile.</p>
      </div>
    );
  }

  // Stats par shop (mois courant)
  const start = new Date();
  start.setDate(1);
  start.setHours(0, 0, 0, 0);

  const stats = await Promise.all(
    shops.map(async (s: any) => {
      const { data: sales } = await sb
        .from('sales')
        .select('total, profit, source, date')
        .eq('shop_id', s.id)
        .gte('date', start.toISOString());
      const total = (sales ?? []).reduce((a, b) => a + Number(b.total), 0);
      const profit = (sales ?? []).reduce((a, b) => a + Number(b.profit), 0);
      const counter = (sales ?? []).filter((x) => x.source === 'COUNTER').length;
      const delivery = (sales ?? []).filter((x) => x.source === 'DELIVERY').length;
      return { shop: s, total, profit, counter, delivery };
    })
  );

  // Stock bas
  const { data: lowStock } = await sb
    .from('products')
    .select('shop_id, name, stock_qty, alert_threshold')
    .gt('alert_threshold', 0)
    .order('stock_qty', { ascending: true })
    .limit(20);

  return (
    <div className="space-y-8">
      <h2 className="text-2xl font-bold">Tableau de bord</h2>
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        {stats.map(({ shop, total, profit, counter, delivery }) => (
          <div key={shop.id} className="bg-white rounded-xl p-6 shadow">
            <h3 className="text-lg font-semibold mb-2">{shop.name}</h3>
            <div className="text-3xl font-bold text-emerald-700">{fmt(total)}</div>
            <div className="text-sm text-slate-500">
              Bénéfice: <span className="font-semibold">{fmt(profit)}</span>
            </div>
            <div className="mt-3 text-sm flex gap-4">
              <span>🛒 Comptoir: {counter}</span>
              <span>🚲 Livraison: {delivery}</span>
            </div>
          </div>
        ))}
      </div>

      <section>
        <h3 className="text-xl font-bold mb-3">Stock bas</h3>
        {(!lowStock || lowStock.length === 0) ? (
          <p className="text-slate-500">Aucun produit en stock bas</p>
        ) : (
          <div className="bg-white rounded-xl shadow overflow-hidden">
            <table className="w-full">
              <thead className="bg-slate-100 text-left text-sm">
                <tr>
                  <th className="p-3">Produit</th>
                  <th className="p-3">Stock</th>
                  <th className="p-3">Seuil</th>
                </tr>
              </thead>
              <tbody>
                {lowStock.map((p, i) => (
                  <tr key={i} className="border-t">
                    <td className="p-3">{p.name}</td>
                    <td className="p-3 font-semibold text-red-600">
                      {p.stock_qty}
                    </td>
                    <td className="p-3">{p.alert_threshold}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>
    </div>
  );
}
