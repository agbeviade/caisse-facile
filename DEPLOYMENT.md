# Caisse Facile — Guide de déploiement

Pas-à-pas pour brancher **GitHub + Codemagic + Supabase + Vercel**.

---

## 1. GitHub — push initial

```powershell
cd "d:\Caisse facile"
git init
git add .
git commit -m "feat: initial scaffold caisse facile"
git branch -M main
# Crée le repo vide sur github.com → Settings : Private recommandé
git remote add origin https://github.com/<TON-USER>/caisse-facile.git
git push -u origin main
```

---

## 2. Supabase — créer le projet

1. https://supabase.com/dashboard → **New Project** → région la plus proche (Paris/Frankfurt).
2. Note ton **mot de passe DB** (sert si tu veux te connecter en SQL externe).
3. Une fois prêt : `Project Settings → API` → copie :
   - **Project URL** → `SUPABASE_URL`
   - **anon public** → `SUPABASE_ANON_KEY`
4. **SQL Editor** → New query → colle le contenu de `supabase/schema.sql` → **Run**. Vérifie que toutes les tables sont créées.
5. **Authentication → Providers** : laisse **Email** activé. Désactive "Confirm email" en dev pour aller plus vite (Authentication → Settings → Email Auth).

### Tester la connexion en local

Crée `d:\Caisse facile\.env` (non commité) :
```
SUPABASE_URL=https://xxx.supabase.co
SUPABASE_ANON_KEY=eyJh...
```

Puis :
```powershell
flutter run --dart-define=SUPABASE_URL=https://xxx.supabase.co --dart-define=SUPABASE_ANON_KEY=eyJh...
```

À l'ouverture, l'app affiche l'écran de **connexion** → crée un compte → l'écran "Choisir l'épicerie" → "Créer une épicerie". Le bouton **☁** dans la barre d'app déclenche la sync.

---

## 3. Codemagic — APK auto à chaque push

1. https://codemagic.io → Sign in with GitHub → **Add application** → choisis le repo `caisse-facile`.
2. Codemagic détecte `codemagic.yaml` à la racine.
3. **Environment variables** (group `default` ou via UI) — ajoute :
   - `SUPABASE_URL` (secret = oui)
   - `SUPABASE_ANON_KEY` (secret = oui)
   - `CM_NOTIFY_EMAIL` = ton email
4. Lance **Start new build → workflow `android-debug`**. ~10 min plus tard tu reçois l'APK par email.

### APK release signé (workflow `android-release`)

1. Génère un keystore en local :
   ```powershell
   keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
2. Encode-le en base64 :
   ```powershell
   [Convert]::ToBase64String([IO.File]::ReadAllBytes("upload-keystore.jks")) | Set-Clipboard
   ```
3. Codemagic UI → **Environment variables** group `keystore_credentials` :
   - `CM_KEYSTORE` = (paste base64)
   - `CM_KEYSTORE_PASSWORD`
   - `CM_KEY_PASSWORD`
   - `CM_KEY_ALIAS` (ex: `upload`)
4. Le build release se déclenche sur tag : `git tag v1.0.0 && git push --tags`.

---

## 4. Vercel — back-office web

1. https://vercel.com → **Add new → Project** → importe `caisse-facile`.
2. **Configure project** :
   - **Root Directory** : `web-admin`
   - **Framework preset** : Next.js (auto)
3. **Environment variables** :
   - `NEXT_PUBLIC_SUPABASE_URL`
   - `NEXT_PUBLIC_SUPABASE_ANON_KEY`
4. **Deploy**. Tu obtiens `https://caisse-facile-admin.vercel.app`.
5. Connecte-toi avec le **même compte** que sur l'app mobile → tu vois ton/tes épicerie(s) et leurs stats du mois.

---

## 5. Architecture finale

```
┌──────────────────┐                    ┌──────────────────┐
│  Téléphone       │                    │  Navigateur      │
│  (Flutter app)   │                    │  (Vercel)        │
│  - SQLite local  │ ◄── sync (REST) ──►│  - Lecture       │
│  - Scan, vente,  │                    │    rapports      │
│    livreurs      │                    │  - Multi-shops   │
└────────┬─────────┘                    └────────┬─────────┘
         │                                        │
         └────────────────┬───────────────────────┘
                          ▼
                  ┌──────────────┐
                  │   Supabase   │
                  │  Postgres +  │
                  │  Auth + RLS  │
                  └──────────────┘

  GitHub ──► Codemagic (APK) ──► Email/Téléphone
         └─► Vercel (preview à chaque PR)
```

## 6. Sécurité — rappel important

- **Ne commit jamais** `.env`, `key.properties`, `*.jks`. Le `.gitignore` les bloque déjà.
- La clé `anon` de Supabase **est publique** (visible dans l'app et le navigateur), c'est normal — la sécurité vient des **policies RLS** dans `schema.sql`.
- Active la confirmation email Supabase en production.
- Passe le repo GitHub en **Private** si tes données business sont sensibles.

## 7. Évolutions suggérées

- **Rotation hebdo** automatique : push tag `vX.Y.Z` chaque vendredi → APK release distribué via Firebase App Distribution (Codemagic supporte le `publishing.firebase`).
- **Realtime** : remplacer le bouton "Sync" par les `Supabase Realtime channels` pour une mise à jour instantanée multi-postes.
- **Vercel preview** par PR : une URL unique par branche pour valider les changements du back-office avant merge.
