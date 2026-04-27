import 'package:flutter/material.dart';
import '../db/delivery_dao.dart';
import '../db/sale_dao.dart';
import '../utils/formatters.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _saleDao = SaleDao();
  final _deliveryDao = DeliveryDao();

  Map<String, double> _today = {};
  Map<String, double> _month = {};
  List<Map<String, dynamic>> _daily = [];
  List<Map<String, dynamic>> _perf = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final now = DateTime.now();
    final dayStart = DateTime(now.year, now.month, now.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 1);

    final today = await _saleDao.totals(from: dayStart, to: dayEnd);
    final month = await _saleDao.totals(from: monthStart, to: monthEnd);
    final daily = await _saleDao.dailyTotals(days: 30);
    final perf = await _deliveryDao.performance(from: monthStart);

    if (!mounted) return;
    setState(() {
      _today = today;
      _month = month;
      _daily = daily;
      _perf = perf;
    });
  }

  Widget _stat(String label, String value, {Color? color}) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 6),
              Text(value,
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: color)),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rapports')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            const Text("Aujourd'hui",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(child: _stat("CA", fmtMoney(_today['total'] ?? 0))),
              Expanded(
                  child: _stat("Bénéfice",
                      fmtMoney(_today['profit'] ?? 0),
                      color: Colors.green)),
            ]),
            const SizedBox(height: 12),
            const Text("Ce mois",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(child: _stat("CA", fmtMoney(_month['total'] ?? 0))),
              Expanded(
                  child: _stat("Bénéfice",
                      fmtMoney(_month['profit'] ?? 0),
                      color: Colors.green)),
              Expanded(
                  child: _stat(
                      "Ventes", '${(_month['count'] ?? 0).toInt()}')),
            ]),
            const SizedBox(height: 16),
            const Text("Performance livreurs (mois)",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            ..._perf.map((r) {
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(r['name'] as String),
                  subtitle: Text(
                      '${(r['sessions'] as num).toInt()} tournée(s) • Bénéfice: ${fmtMoney((r['total_profit'] as num).toDouble())}'),
                  trailing: Text(
                      fmtMoney((r['total_sales'] as num).toDouble()),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              );
            }),
            const SizedBox(height: 16),
            const Text("Ventes / jour (30j)",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            ..._daily.map((r) => ListTile(
                  dense: true,
                  title: Text(r['day'] as String),
                  trailing: Text(fmtMoney((r['total'] as num).toDouble())),
                )),
          ],
        ),
      ),
    );
  }
}
