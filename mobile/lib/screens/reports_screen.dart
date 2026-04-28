import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../db/customer_dao.dart';
import '../db/delivery_dao.dart';
import '../db/expense_dao.dart';
import '../db/sale_dao.dart';
import '../utils/formatters.dart';
import '../widgets/app_drawer.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _saleDao = SaleDao();
  final _deliveryDao = DeliveryDao();
  final _expenseDao = ExpenseDao();
  final _customerDao = CustomerDao();

  Map<String, double> _today = {};
  Map<String, double> _month = {};
  List<Map<String, dynamic>> _daily = [];
  List<Map<String, dynamic>> _perf = [];
  List<Map<String, dynamic>> _topSellers = [];
  double _monthExpenses = 0;
  double _totalDebt = 0;

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
    final exp = await _expenseDao.totalBetween(monthStart, monthEnd);
    final debt = await _customerDao.totalDebt();
    final tops =
        await _saleDao.topSellers(from: monthStart, to: monthEnd, limit: 5);

    if (!mounted) return;
    setState(() {
      _today = today;
      _month = month;
      _daily = daily;
      _perf = perf;
      _monthExpenses = exp;
      _totalDebt = debt;
      _topSellers = tops;
    });
  }

  /// Builds the data series for the last 14 days from `_daily` (already sorted DESC).
  List<({String day, double total})> _last14() {
    final now = DateTime.now();
    final byDay = <String, double>{};
    for (final r in _daily) {
      byDay[r['day'] as String] = (r['total'] as num).toDouble();
    }
    final out = <({String day, double total})>[];
    for (int i = 13; i >= 0; i--) {
      final d = now.subtract(Duration(days: i));
      final key =
          '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      out.add((day: key, total: byDay[key] ?? 0));
    }
    return out;
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
    final monthCa = _month['total'] ?? 0;
    final monthProfit = _month['profit'] ?? 0;
    final netBenefit = monthProfit - _monthExpenses;
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(title: const Text('Tableau de bord')),
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
                  child: _stat("Bénéfice brut",
                      fmtMoney(_today['profit'] ?? 0),
                      color: Colors.green)),
            ]),
            const SizedBox(height: 12),
            const Text("Ce mois",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(child: _stat("CA", fmtMoney(monthCa))),
              Expanded(
                  child: _stat("Bénéfice brut",
                      fmtMoney(monthProfit),
                      color: Colors.green)),
            ]),
            Row(children: [
              Expanded(
                  child: _stat('Charges', fmtMoney(_monthExpenses),
                      color: Colors.red)),
              Expanded(
                  child: _stat('Bénéfice net', fmtMoney(netBenefit),
                      color: netBenefit >= 0 ? Colors.green : Colors.red)),
            ]),
            Row(children: [
              Expanded(
                  child: _stat('Ventes',
                      '${(_month['count'] ?? 0).toInt()}')),
              Expanded(
                  child: _stat('Dû par acheteurs',
                      fmtMoney(_totalDebt),
                      color: _totalDebt > 0 ? Colors.orange : null)),
            ]),
            const SizedBox(height: 16),
            _SalesChart(data: _last14()),
            const SizedBox(height: 16),
            if (_topSellers.isNotEmpty) ...[
              _TopSellersCard(rows: _topSellers),
              const SizedBox(height: 16),
            ],
            if (_perf.isNotEmpty) ...[
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
            ],
          ],
        ),
      ),
    );
  }
}

class _TopSellersCard extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  const _TopSellersCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final maxRevenue = rows
        .map((r) => (r['revenue'] as num).toDouble())
        .fold<double>(0, (a, b) => b > a ? b : a);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Meilleures ventes — ce mois",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            ...rows.asMap().entries.map((e) {
              final i = e.key;
              final r = e.value;
              final name = r['name'] as String? ?? '—';
              final qty = (r['qty'] as num).toDouble();
              final revenue = (r['revenue'] as num).toDouble();
              final ratio = maxRevenue > 0 ? revenue / maxRevenue : 0.0;
              final medalColors = [
                const Color(0xFFFFC107),
                const Color(0xFFB0BEC5),
                const Color(0xFFCD7F32),
              ];
              final badgeColor = i < 3 ? medalColors[i] : scheme.primary;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: badgeColor,
                      child: Text('${i + 1}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: ratio,
                              minHeight: 6,
                              backgroundColor: scheme.surfaceContainerHighest,
                              valueColor:
                                  AlwaysStoppedAnimation(scheme.primary),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(fmtMoney(revenue),
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold)),
                        Text('${qty.toInt()} u.',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _SalesChart extends StatelessWidget {
  final List<({String day, double total})> data;
  const _SalesChart({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();
    final maxY = data
        .map((e) => e.total)
        .fold<double>(0, (a, b) => b > a ? b : a);
    final yMax = maxY <= 0 ? 1.0 : maxY * 1.15;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 8),
              child: Text("Chiffre d'affaires — 14 derniers jours",
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
            ),
            SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: yMax,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        getTitlesWidget: (v, _) {
                          final i = v.toInt();
                          if (i < 0 || i >= data.length) {
                            return const SizedBox.shrink();
                          }
                          // Show every 2nd label to avoid crowding
                          if (i % 2 != 0) return const SizedBox.shrink();
                          final dayPart =
                              data[i].day.split('-').last;
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(dayPart,
                                style: const TextStyle(fontSize: 10)),
                          );
                        },
                      ),
                    ),
                  ),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, _, rod, __) {
                        final entry = data[group.x];
                        return BarTooltipItem(
                          '${entry.day}\n${fmtMoney(rod.toY)}',
                          const TextStyle(
                              color: Colors.white, fontSize: 12),
                        );
                      },
                    ),
                  ),
                  barGroups: List.generate(data.length, (i) {
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: data[i].total,
                          width: 12,
                          borderRadius: BorderRadius.circular(4),
                          color: scheme.primary,
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
