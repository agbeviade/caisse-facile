import 'package:flutter/material.dart';

import '../config/env.dart';
import '../screens/alerts_screen.dart';
import '../screens/auth_screen.dart';
import '../screens/catalog_screen.dart';
import '../screens/counter_sale_screen.dart';
import '../screens/customers_screen.dart';
import '../screens/delivery_men_screen.dart';
import '../screens/delivery_sessions_screen.dart';
import '../screens/expenses_screen.dart';
import '../screens/home_screen.dart';
import '../screens/reports_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/stock_movements_screen.dart';
import '../screens/suppliers_screen.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';

/// Main lateral menu of the app. Used on every primary screen.
class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  bool _shopsExpanded = false;
  bool _switching = false;

  Future<void> _switchShop(String id, String name) async {
    setState(() => _switching = true);
    AuthService.instance.setShop(id, name: name);
    if (!mounted) return;
    setState(() => _switching = false);
    Navigator.of(context).pop(); // close drawer
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  Future<void> _logout() async {
    await AuthService.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (route) => false,
    );
  }

  void _go(Widget screen) {
    Navigator.of(context).pop(); // close drawer
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  void _comingSoon(String title) {
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text("$title — bientôt disponible"),
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shopName = AuthService.instance.shopName ?? 'Boutique';
    final email = AuthService.instance.currentUser?.email ?? '';

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // ===== Header =====
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              decoration: BoxDecoration(color: scheme.primary),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: scheme.onPrimary.withOpacity(.15),
                        child: Icon(Icons.storefront,
                            color: scheme.onPrimary, size: 26),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Caisse Facile',
                                style: TextStyle(
                                    color: scheme.onPrimary,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold)),
                            if (email.isNotEmpty)
                              Text(email,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color:
                                          scheme.onPrimary.withOpacity(.85),
                                      fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // ===== Shop switcher =====
                  if (Env.hasSupabase)
                    InkWell(
                      onTap: () =>
                          setState(() => _shopsExpanded = !_shopsExpanded),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: scheme.onPrimary.withOpacity(.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(shopName,
                                  style: TextStyle(
                                      color: scheme.onPrimary,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600)),
                            ),
                            Icon(
                              _shopsExpanded
                                  ? Icons.keyboard_arrow_up
                                  : Icons.keyboard_arrow_down,
                              color: scheme.onPrimary,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: scheme.onPrimary.withOpacity(.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text("Mode hors-ligne",
                          style: TextStyle(
                              color: scheme.onPrimary,
                              fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
            ),

            // ===== Shop list (expanded) =====
            if (_shopsExpanded && Env.hasSupabase) _ShopList(onPick: _switchShop),

            // ===== Menu items =====
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _section('Vendre'),
                  _item(Icons.point_of_sale, 'Vente comptoir',
                      onTap: () => _go(const CounterSaleScreen())),
                  _item(Icons.delivery_dining, 'Tournées livraison',
                      onTap: () => _go(const DeliverySessionsScreen())),
                  const Divider(),
                  _section('Gestion'),
                  _item(Icons.inventory_2, 'Produits',
                      onTap: () => _go(const CatalogScreen())),
                  _item(Icons.swap_vert, 'Mouvements de stock',
                      onTap: () => _go(const StockMovementsScreen())),
                  _item(Icons.payments, 'Charges',
                      onTap: () => _go(const ExpensesScreen())),
                  _item(Icons.handshake, 'Fournisseurs',
                      onTap: () => _go(const SuppliersScreen())),
                  _item(Icons.group, 'Acheteurs (crédits)',
                      onTap: () => _go(const CustomersScreen())),
                  _item(Icons.directions_bike, 'Équipe livreurs',
                      onTap: () => _go(const DeliveryMenScreen())),
                  const Divider(),
                  _section('Suivi'),
                  _item(Icons.bar_chart, 'Tableau de bord',
                      onTap: () => _go(const ReportsScreen())),
                  _item(Icons.notifications_active, 'Alertes',
                      onTap: () => _go(const AlertsScreen())),
                  const Divider(),
                  _item(Icons.settings_outlined, 'Paramètres',
                      onTap: () => _go(const SettingsScreen())),
                  if (Env.hasSupabase) ...[
                    const Divider(),
                    _section('Cloud'),
                    _item(Icons.cloud_sync, 'Synchroniser',
                        onTap: () async {
                      Navigator.of(context).pop();
                      final messenger = ScaffoldMessenger.of(context);
                      messenger.showSnackBar(const SnackBar(
                          content: Text('Synchronisation…'),
                          duration: Duration(seconds: 2)));
                      try {
                        final r = await SyncService.instance.syncNow();
                        messenger.showSnackBar(SnackBar(
                            backgroundColor: Colors.green,
                            content: Text(r)));
                      } catch (e) {
                        messenger.showSnackBar(SnackBar(
                            backgroundColor: Colors.red,
                            content: Text('Sync échouée: $e')));
                      }
                    }),
                  ],
                ],
              ),
            ),

            // ===== Footer =====
            const Divider(height: 1),
            if (Env.hasSupabase)
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Déconnexion'),
                onTap: _logout,
              ),
          ],
        ),
      ),
    );
  }

  Widget _section(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: Text(label.toUpperCase(),
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
              letterSpacing: 0.8)),
    );
  }

  Widget _item(IconData icon, String label, {required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, size: 22),
      title: Text(label, style: const TextStyle(fontSize: 15)),
      dense: true,
      onTap: _switching ? null : onTap,
    );
  }
}

/// Inline list of the user's other shops, shown when header is expanded.
class _ShopList extends StatefulWidget {
  final Future<void> Function(String id, String name) onPick;
  const _ShopList({required this.onPick});

  @override
  State<_ShopList> createState() => _ShopListState();
}

class _ShopListState extends State<_ShopList> {
  bool _loading = true;
  List<Map<String, dynamic>> _shops = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await AuthService.instance.myShops();
      if (!mounted) return;
      setState(() {
        _shops = s;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Center(child: SizedBox(
            width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }
    final currentId = AuthService.instance.shopId;
    return Container(
      color: Colors.grey[100],
      child: Column(
        children: [
          ..._shops.map((row) {
            final shop = row['shops'] as Map<String, dynamic>;
            final isCurrent = shop['id'] == currentId;
            return ListTile(
              dense: true,
              leading: Icon(
                  isCurrent ? Icons.check_circle : Icons.store_outlined,
                  color: isCurrent ? Colors.green : null),
              title: Text(shop['name'] as String,
                  style: TextStyle(
                      fontWeight:
                          isCurrent ? FontWeight.bold : FontWeight.normal)),
              subtitle: Text('Rôle : ${row['role']}',
                  style: const TextStyle(fontSize: 11)),
              onTap: isCurrent
                  ? null
                  : () => widget
                      .onPick(shop['id'] as String, shop['name'] as String),
            );
          }),
        ],
      ),
    );
  }
}
