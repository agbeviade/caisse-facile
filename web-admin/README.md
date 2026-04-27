# Caisse Facile — Back-office Web (Vercel)

Mini dashboard Next.js connecté à **Supabase** (mêmes tables/RLS que l'app mobile). Lecture seule pour l'instant.

## Dev

```bash
cd web-admin
cp .env.example .env.local   # remplis SUPABASE_URL et ANON_KEY
npm install
npm run dev
```

## Déploiement Vercel

1. Push le repo sur GitHub.
2. `vercel.com` → New Project → importe le repo.
3. **Root Directory** : `web-admin`
4. Variables d'env :
   - `NEXT_PUBLIC_SUPABASE_URL`
   - `NEXT_PUBLIC_SUPABASE_ANON_KEY`
5. Deploy.

L'utilisateur se connecte avec le **même compte** que sur l'app mobile (Supabase Auth). RLS isole automatiquement les données par épicerie.
