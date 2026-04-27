# Caisse Facile

Application mobile Flutter de **gestion d'épicerie de détail** : caisse comptoir avec scan, gestion du **stock confié aux livreurs** (sortie/retour/point) avec calcul automatique du montant dû, alertes péremption/stock bas, rapports CA & bénéfice, étiquettes PDF (codes-barres) et **partage WhatsApp** des reçus de tournée.

---

## Fonctionnalités

- **Catalogue** : nom, catégorie, prix achat/vente, stock, seuil d'alerte, péremption, code-barres unique (généré si absent).
- **Vente comptoir** : scan rapide → panier → encaissement (déduit le stock, enregistre la vente).
- **Module Livreurs** :
  - Création/édition de livreurs (nom + téléphone).
  - **Sortie** : scan des produits confiés → stock magasin baisse, "stock livreur" augmente.
  - **Le Point (retour)** : scan **uniquement des invendus** → calcul automatique
    `Quantité vendue = Confiée − Rapportée` et `Montant dû = Vendue × Prix vente`.
  - Validation : invendus retournent en stock, vente créditée au CA, **PDF + partage WhatsApp** du reçu.
- **Alertes** : stock bas, péremption proche (14j).
- **Rapports** : CA & bénéfice (jour, mois), performance par livreur, ventes journalières (30j).
- **Étiquettes PDF** : planche A4 (3×7) avec nom, prix, code-barres Code128 — impression / partage.

## Stack

- **Flutter 3.19+ / Dart 3.3+**
- **SQLite** via `sqflite` (offline-first)
- **Scan** via `mobile_scanner` (Google ML Kit Barcode sur Android)
- **PDF** via `pdf` + `printing` ; **partage** via `share_plus`
- UI Material 3, "zéro friction" (gros boutons, scan rapide).

## Schéma SQL (résumé)

Tables : `products`, `delivery_men`, `delivery_sessions`, `session_items`, `sales`, `sale_items`.
Voir `lib/db/database_helper.dart` pour le DDL exact (avec snapshots de prix par tournée).

## Mise en route

> Le scaffold contient `lib/`, `pubspec.yaml`, `android/app/src/main/AndroidManifest.xml`. Les autres fichiers de plateforme (Gradle, MainActivity, iOS) doivent être générés par Flutter.

```powershell
# 1) Génère les dossiers de plateforme (sans écraser lib/ ni pubspec.yaml)
flutter create --platforms=android,ios --org com.caissefacile .

# 2) Réapplique notre AndroidManifest si flutter create l'a remplacé :
#    (vérifie que la permission CAMERA est bien présente)

# 3) Installe les dépendances
flutter pub get

# 4) Lance l'application
flutter run
```

### Permissions

- **Android** : `android.permission.CAMERA` (déjà dans `AndroidManifest.xml`).
- **iOS** : ajoute dans `ios/Runner/Info.plist` :
  ```xml
  <key>NSCameraUsageDescription</key>
  <string>Scanner les codes-barres des produits</string>
  ```

### Configuration Android (minSdk)

`mobile_scanner` requiert **minSdkVersion 21**. Édite `android/app/build.gradle` :

```gradle
defaultConfig {
    minSdkVersion 21
    ...
}
```

## Architecture

```
lib/
├── main.dart                 # MaterialApp, thème
├── db/
│   ├── database_helper.dart  # Ouverture & schéma SQLite
│   ├── product_dao.dart
│   ├── delivery_dao.dart     # Sessions, sortie, retour, clôture
│   └── sale_dao.dart         # Encaissement comptoir, totaux
├── models/                   # Product, DeliveryMan, DeliverySession, SessionItem, Sale
├── services/
│   └── receipt_service.dart  # PDF + partage (WhatsApp via share_plus)
├── screens/
│   ├── home_screen.dart
│   ├── catalog_screen.dart
│   ├── product_form_screen.dart
│   ├── counter_sale_screen.dart
│   ├── delivery_men_screen.dart
│   ├── delivery_sessions_screen.dart
│   ├── delivery_loadout_screen.dart   # Sortie livreur (scan)
│   ├── delivery_return_screen.dart    # Le Point (scan invendus)
│   ├── reports_screen.dart
│   ├── alerts_screen.dart
│   └── labels_screen.dart             # Planche d'étiquettes PDF
├── utils/formatters.dart
└── widgets/barcode_scanner_screen.dart
```

## Flux "Le Point" (retour livreur)

1. Sélectionne la tournée en cours, action **Faire le point**.
2. L'écran liste tous les produits confiés.
3. Pour chaque invendu rapporté : **scan** ou bouton `+/−`.
4. **Montant dû** se met à jour en temps réel.
5. **Valider** :
   - Met à jour les `qty_returned` en base.
   - Réinjecte les invendus en stock magasin.
   - Crée une `sale` (source = `DELIVERY`) avec ses `sale_items`.
   - Marque la session `COMPLETED`.
6. Dialogue final → **Partager le reçu PDF** (WhatsApp, email, etc.).

## Notes

- Toutes les opérations critiques sont en **transaction SQLite** (cohérence stock + ventes + sessions).
- Les prix unitaires sont **figés** au moment de la sortie livreur (champs `unit_sale_price`, `unit_purchase_price` dans `session_items`) → évite les écarts si le tarif change pendant la tournée.
- Format monétaire par défaut : `F` (FCFA) — modifie `lib/utils/formatters.dart` pour ajuster.

## Roadmap suggérée

- Synchronisation cloud (Firebase / Supabase) pour multi-postes.
- Multi-utilisateurs (épicier vs caissier) avec PIN.
- Code-barres EAN-13 généré + clé de contrôle pour étiquetage produits frais.
- Export Excel/CSV des rapports.
- Mode "thermique" (planche d'étiquettes 58mm) pour imprimante POS Bluetooth.
