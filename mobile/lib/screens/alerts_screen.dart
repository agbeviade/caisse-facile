import 'package:flutter/material.dart';
import '../db/product_dao.dart';
import '../models/product.dart';
import '../utils/formatters.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final _dao = ProductDao();
  List<Product> _low = [];
  List<Product> _expiring = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final low = await _dao.lowStock();
    final exp = await _dao.expiringSoon(days: 14);
    if (!mounted) return;
    setState(() {
      _low = low;
      _expiring = exp;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Alertes')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          const Text('Stock bas',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          if (_low.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Aucun produit en stock bas'),
            ),
          ..._low.map((p) => Card(
                color: Colors.red.shade50,
                child: ListTile(
                  leading: const Icon(Icons.warning, color: Colors.red),
                  title: Text(p.name),
                  subtitle: Text(
                      'Stock: ${fmtQty(p.stockQty)} (seuil ${fmtQty(p.alertThreshold)})'),
                ),
              )),
          const SizedBox(height: 16),
          const Text('Péremption proche',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          if (_expiring.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Aucun produit proche de la péremption'),
            ),
          ..._expiring.map((p) => Card(
                color: Colors.orange.shade50,
                child: ListTile(
                  leading: const Icon(Icons.event_busy, color: Colors.orange),
                  title: Text(p.name),
                  subtitle: Text('Péremption: ${fmtDate(p.expiryDate!)}'),
                ),
              )),
        ],
      ),
    );
  }
}
