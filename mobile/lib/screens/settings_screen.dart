import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/export_service.dart';
import '../services/theme_service.dart';
import '../widgets/fluent.dart';

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
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          const SectionHeader('Compte'),
          FeatureCard(
            icon: Icons.person_outline,
            title: 'Email',
            subtitle: email,
          ),
          const SizedBox(height: 12),
          FeatureCard(
            icon: Icons.storefront_outlined,
            title: 'Boutique active',
            subtitle: shopName,
          ),
          const SizedBox(height: 24),
          const SectionHeader('Apparence'),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: ThemeService.instance.mode,
            builder: (_, mode, __) {
              return FeatureCard(
                icon: Icons.palette_outlined,
                title: 'Thème',
                subtitle:
                    "Choisis le mode d'affichage utilisé dans toute l'app.",
                content: Column(
                  children: [
                    RadioCard<ThemeMode>(
                      value: ThemeMode.system,
                      groupValue: mode,
                      onChanged: ThemeService.instance.set,
                      title: 'Système',
                      subtitle: 'Suit le réglage du téléphone',
                    ),
                    const SizedBox(height: 8),
                    RadioCard<ThemeMode>(
                      value: ThemeMode.light,
                      groupValue: mode,
                      onChanged: ThemeService.instance.set,
                      title: 'Clair',
                      subtitle: 'Fond blanc cassé pour la journée',
                    ),
                    const SizedBox(height: 8),
                    RadioCard<ThemeMode>(
                      value: ThemeMode.dark,
                      groupValue: mode,
                      onChanged: ThemeService.instance.set,
                      title: 'Sombre',
                      subtitle: 'Fond noir profond, plus reposant',
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          const SectionHeader('Export des données'),
          FeatureCard(
            icon: Icons.inventory_2_outlined,
            title: 'Exporter les produits',
            subtitle: 'Catalogue complet en CSV pour Excel / Sheets',
            trailing: const Icon(Icons.share_outlined, size: 20),
            onTap: () => _runExport(context,
                ExportService.instance.exportProductsCsv, 'produits'),
          ),
          const SizedBox(height: 12),
          FeatureCard(
            icon: Icons.point_of_sale_outlined,
            title: 'Exporter les ventes',
            subtitle: 'Toutes les ventes avec total et bénéfice',
            trailing: const Icon(Icons.share_outlined, size: 20),
            onTap: () => _runExport(
                context, ExportService.instance.exportSalesCsv, 'ventes'),
          ),
          const SizedBox(height: 12),
          FeatureCard(
            icon: Icons.list_alt_outlined,
            title: 'Exporter les lignes de vente',
            subtitle: 'Détail produit par produit pour analyse fine',
            trailing: const Icon(Icons.share_outlined, size: 20),
            onTap: () => _runExport(context,
                ExportService.instance.exportSaleItemsCsv, 'lignes'),
          ),
          const SizedBox(height: 24),
          const SectionHeader('À propos'),
          const FeatureCard(
            icon: Icons.info_outline,
            title: 'Caisse Facile',
            subtitle: 'Version 1.0.0',
          ),
        ],
      ),
    );
  }
}
