import 'package:flutter/material.dart';
import '../config/env.dart';
import '../db/product_dao.dart';
import '../db/sale_dao.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import '../utils/formatters.dart';
import '../widgets/app_drawer.dart';
import 'alerts_screen.dart';
import 'catalog_screen.dart';
import 'counter_sale_screen.dart';
import 'customers_screen.dart';
import 'delivery_men_screen.dart';
import 'delivery_sessions_screen.dart';
import 'expenses_screen.dart';
import 'reports_screen.dart';
import 'stock_movements_screen.dart';
import '../widgets/fluent.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _saleDao = SaleDao();
  final _productDao = ProductDao();

  double _todayTotal = 0;
  int _todayCount = 0;
  int _alerts = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    final t = await _saleDao.totals(from: start, to: end);
    final low = await _productDao.lowStock();
    final exp = await _productDao.expiringSoon(days: 7);
    if (!mounted) return;
    setState(() {
      _todayTotal = t['total'] ?? 0;
      _todayCount = (t['count'] ?? 0).toInt();
      _alerts = low.length + exp.length;
    });
  }

  void _push(Widget screen) async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => screen));
    _refresh();
  }

  Widget _tile(IconData icon, String label, String subtitle, VoidCallback onTap,
      {Color? color, String? badge}) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Stack(
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconBadge(icon: icon, color: color, size: 38, iconSize: 20),
                  const Spacer(),
                  Text(label,
                      style: const TextStyle(
                          fontSize: 14.5, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11.5,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant)),
                ],
              ),
              if (badge != null && badge.isNotEmpty)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(badge,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ),
                )
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shopName = AuthService.instance.shopName;
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Caisse Facile',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            if (shopName != null && shopName.isNotEmpty)
              Text(shopName,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.normal)),
          ],
        ),
        actions: [
          if (Env.hasSupabase)
            IconButton(
              icon: const Icon(Icons.cloud_sync),
              tooltip: 'Synchroniser',
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                messenger.showSnackBar(const SnackBar(
                    content: Text('Synchronisation…'),
                    duration: Duration(seconds: 2)));
                try {
                  final r = await SyncService.instance.syncNow();
                  messenger.showSnackBar(SnackBar(
                      backgroundColor: Colors.green,
                      content: Text(r)));
                  _refresh();
                } catch (e) {
                  messenger.showSnackBar(SnackBar(
                      backgroundColor: Colors.red,
                      content: Text('Sync échouée: $e')));
                }
              },
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _TodayHeroCard(
                total: _todayTotal,
                count: _todayCount,
                alerts: _alerts,
                onTapAlerts: () => _push(const AlertsScreen())),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 8),
              child: Text('Actions rapides',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                      color: Colors.grey)),
            ),
            _QuickActionsRow(actions: [
              _QA(Icons.point_of_sale, 'Vendre',
                  () => _push(const CounterSaleScreen())),
              _QA(Icons.add_shopping_cart, 'Produit',
                  () => _push(const CatalogScreen())),
              _QA(Icons.swap_vert, 'Stock',
                  () => _push(const StockMovementsScreen())),
              _QA(Icons.receipt_long, 'Charge',
                  () => _push(const ExpensesScreen())),
              _QA(Icons.group_outlined, 'Acheteur',
                  () => _push(const CustomersScreen())),
            ]),
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 8),
              child: Text('Sections',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                      color: Colors.grey)),
            ),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.15,
              children: [
                _tile(Icons.point_of_sale, 'Vente comptoir',
                    'Encaisser sur place',
                    () => _push(const CounterSaleScreen())),
                _tile(Icons.local_shipping, 'Tournées',
                    'Sortie / retour livreurs',
                    () => _push(const DeliverySessionsScreen())),
                _tile(Icons.inventory_2, 'Catalogue',
                    'Produits & stock',
                    () => _push(const CatalogScreen())),
                _tile(Icons.directions_bike, 'Équipe',
                    'Livreurs',
                    () => _push(const DeliveryMenScreen())),
                _tile(Icons.bar_chart, 'Tableau de bord',
                    'CA, bénéfices, top ventes',
                    () => _push(const ReportsScreen())),
                _tile(Icons.warning_amber, 'Alertes',
                    'Stock bas, périmés',
                    () => _push(const AlertsScreen()),
                    color: _alerts > 0 ? Colors.orange : null,
                    badge: _alerts > 0 ? '$_alerts' : null),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

/// Big hero card on top of the home: today CA + ventes count + alertes pill.
class _TodayHeroCard extends StatelessWidget {
  final double total;
  final int count;
  final int alerts;
  final VoidCallback onTapAlerts;
  const _TodayHeroCard({
    required this.total,
    required this.count,
    required this.alerts,
    required this.onTapAlerts,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary,
            Color.lerp(scheme.primary, Colors.black, 0.25)!,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.today, size: 18, color: Colors.white70),
              const SizedBox(width: 6),
              const Text("Aujourd'hui",
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              const Spacer(),
              if (alerts > 0)
                InkWell(
                  onTap: onTapAlerts,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.warning_amber,
                            size: 14, color: Colors.white),
                        const SizedBox(width: 4),
                        Text('$alerts alerte${alerts > 1 ? 's' : ''}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(fmtMoney(total),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5)),
          const SizedBox(height: 2),
          Text(
              count == 0
                  ? 'Aucune vente'
                  : '$count vente${count > 1 ? 's' : ''} encaissée${count > 1 ? 's' : ''}',
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ],
      ),
    );
  }
}

class _QA {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  _QA(this.icon, this.label, this.onTap);
}

/// Horizontal scroll row of small circular quick action buttons.
class _QuickActionsRow extends StatelessWidget {
  final List<_QA> actions;
  const _QuickActionsRow({required this.actions});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 86,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: actions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (_, i) {
          final a = actions[i];
          return SizedBox(
            width: 72,
            child: Column(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(28),
                  onTap: a.onTap,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer.withOpacity(0.55),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(a.icon, color: scheme.primary, size: 26),
                  ),
                ),
                const SizedBox(height: 6),
                Text(a.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11.5, fontWeight: FontWeight.w500)),
              ],
            ),
          );
        },
      ),
    );
  }
}
