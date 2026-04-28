import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/export_service.dart';
import '../services/theme_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _runExport(
      BuildContext context, Future<void> Function() task, String label) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(SnackBar(content: Text('Export $label…')));
    try {
      await task();
    } catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(SnackBar(
          backgroundColor: Colors.red, content: Text('Échec : $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = AuthService.instance.currentUser?.email ?? '—';
    final shopName = AuthService.instance.shopName ?? '—';
    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _section('Compte'),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Email'),
            subtitle: Text(email),
          ),
          ListTile(
            leading: const Icon(Icons.storefront),
            title: const Text('Boutique active'),
            subtitle: Text(shopName),
          ),
          const Divider(),
          _section('Apparence'),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: ThemeService.instance.mode,
            builder: (_, mode, __) {
              return Column(
                children: [
                  RadioListTile<ThemeMode>(
                    title: const Text('Système'),
                    subtitle: const Text('Suit le réglage du téléphone'),
                    value: ThemeMode.system,
                    groupValue: mode,
                    onChanged: (v) =>
                        v == null ? null : ThemeService.instance.set(v),
                  ),
                  RadioListTile<ThemeMode>(
                    title: const Text('Clair'),
                    value: ThemeMode.light,
                    groupValue: mode,
                    onChanged: (v) =>
                        v == null ? null : ThemeService.instance.set(v),
                  ),
                  RadioListTile<ThemeMode>(
                    title: const Text('Sombre'),
                    value: ThemeMode.dark,
                    groupValue: mode,
                    onChanged: (v) =>
                        v == null ? null : ThemeService.instance.set(v),
                  ),
                ],
              );
            },
          ),
          const Divider(),
          _section('Export des données'),
          ListTile(
            leading: const Icon(Icons.inventory_2_outlined),
            title: const Text('Exporter les produits (CSV)'),
            subtitle: const Text('Catalogue complet pour Excel / Sheets'),
            trailing: const Icon(Icons.share_outlined),
            onTap: () => _runExport(context,
                ExportService.instance.exportProductsCsv, 'produits'),
          ),
          ListTile(
            leading: const Icon(Icons.point_of_sale_outlined),
            title: const Text('Exporter les ventes (CSV)'),
            subtitle: const Text('Toutes les ventes avec total et bénéfice'),
            trailing: const Icon(Icons.share_outlined),
            onTap: () => _runExport(
                context, ExportService.instance.exportSalesCsv, 'ventes'),
          ),
          ListTile(
            leading: const Icon(Icons.list_alt_outlined),
            title: const Text('Exporter les lignes de vente (CSV)'),
            subtitle:
                const Text('Détail produit par produit pour analyse fine'),
            trailing: const Icon(Icons.share_outlined),
            onTap: () => _runExport(context,
                ExportService.instance.exportSaleItemsCsv, 'lignes'),
          ),
          const Divider(),
          _section('À propos'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Caisse Facile'),
            subtitle: Text('Version 1.0.0'),
          ),
        ],
      ),
    );
  }

  Widget _section(String label) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
        child: Text(label.toUpperCase(),
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                color: Colors.grey)),
      );
}
