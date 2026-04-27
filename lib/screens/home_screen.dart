import 'package:flutter/material.dart';
import '../config/env.dart';
import '../db/product_dao.dart';
import '../db/sale_dao.dart';
import '../services/sync_service.dart';
import '../utils/formatters.dart';
import 'catalog_screen.dart';
import 'counter_sale_screen.dart';
import 'delivery_men_screen.dart';
import 'delivery_sessions_screen.dart';
import 'reports_screen.dart';
import 'alerts_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _saleDao = SaleDao();
  final _productDao = ProductDao();

  double _todayTotal = 0;
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
      _alerts = low.length + exp.length;
    });
  }

  Widget _tile(IconData icon, String label, VoidCallback onTap,
      {Color? color, String? badge}) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          await onTap();
          _refresh();
        },
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Stack(
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 56, color: color ?? Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 12),
                  Text(label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Caisse Facile'),
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
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const Icon(Icons.today, size: 40),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Chiffre d'affaires aujourd'hui",
                              style: TextStyle(fontSize: 14)),
                          Text(fmtMoney(_todayTotal),
                              style: const TextStyle(
                                  fontSize: 28, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1,
              children: [
                _tile(Icons.point_of_sale, 'Vente comptoir', () =>
                    Navigator.push(context, MaterialPageRoute(builder: (_) =>
                        const CounterSaleScreen()))),
                _tile(Icons.local_shipping, 'Livreurs', () =>
                    Navigator.push(context, MaterialPageRoute(builder: (_) =>
                        const DeliverySessionsScreen()))),
                _tile(Icons.inventory_2, 'Catalogue', () =>
                    Navigator.push(context, MaterialPageRoute(builder: (_) =>
                        const CatalogScreen()))),
                _tile(Icons.people, 'Équipe livreurs', () =>
                    Navigator.push(context, MaterialPageRoute(builder: (_) =>
                        const DeliveryMenScreen()))),
                _tile(Icons.bar_chart, 'Rapports', () =>
                    Navigator.push(context, MaterialPageRoute(builder: (_) =>
                        const ReportsScreen()))),
                _tile(Icons.warning_amber, 'Alertes', () =>
                    Navigator.push(context, MaterialPageRoute(builder: (_) =>
                        const AlertsScreen())),
                  color: _alerts > 0 ? Colors.orange : null,
                  badge: _alerts > 0 ? '$_alerts' : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
