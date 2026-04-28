import 'package:flutter/material.dart';
import '../db/customer_dao.dart';
import '../models/customer.dart';
import '../utils/formatters.dart';

class CustomerDetailScreen extends StatefulWidget {
  final Customer customer;
  const CustomerDetailScreen({super.key, required this.customer});

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  final _dao = CustomerDao();
  late Customer _c;
  List<CustomerCredit> _ledger = [];

  @override
  void initState() {
    super.initState();
    _c = widget.customer;
    _load();
  }

  Future<void> _load() async {
    final l = await _dao.ledger(_c.id!);
    final fresh = await _dao.findById(_c.id!);
    if (!mounted) return;
    setState(() {
      _ledger = l;
      if (fresh != null) _c = fresh;
    });
  }

  Future<void> _addPayment() async {
    final amount = await _amountDialog(
        title: 'Encaisser un remboursement',
        hint: 'Montant remboursé');
    if (amount == null || amount <= 0) return;
    await _dao.addLedger(CustomerCredit(
      customerId: _c.id!,
      amount: amount,
      kind: 'PAYMENT',
      date: DateTime.now(),
      note: 'Remboursement',
    ));
    _load();
  }

  Future<void> _addManualCredit() async {
    final amount = await _amountDialog(
        title: 'Ajouter une dette manuelle',
        hint: 'Montant');
    if (amount == null || amount <= 0) return;
    await _dao.addLedger(CustomerCredit(
      customerId: _c.id!,
      amount: amount,
      kind: 'CREDIT',
      date: DateTime.now(),
      note: 'Crédit manuel',
    ));
    _load();
  }

  Future<double?> _amountDialog(
      {required String title, required String hint}) async {
    final ctrl = TextEditingController();
    return showDialog<double>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(hintText: hint)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () =>
                  Navigator.pop(context, double.tryParse(ctrl.text)),
              child: const Text('Valider')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_c.name)),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            color: _c.balance > 0
                ? Colors.orange.shade100
                : Colors.green.shade100,
            child: Column(
              children: [
                const Text('Solde dû'),
                const SizedBox(height: 4),
                Text(fmtMoney(_c.balance),
                    style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: _c.balance > 0
                            ? Colors.red.shade800
                            : Colors.green.shade800)),
                if (_c.phone != null) ...[
                  const SizedBox(height: 6),
                  Text(_c.phone!, style: const TextStyle(fontSize: 14)),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _addPayment,
                    icon: const Icon(Icons.payments),
                    label: const Text('Remboursement'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _addManualCredit,
                    icon: const Icon(Icons.add),
                    label: const Text('Crédit'),
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Historique',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          Expanded(
            child: _ledger.isEmpty
                ? const Center(child: Text('Aucune opération'))
                : ListView.separated(
                    itemCount: _ledger.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final e = _ledger[i];
                      final isCredit = e.kind == 'CREDIT';
                      return ListTile(
                        leading: Icon(
                          isCredit ? Icons.shopping_cart : Icons.payments,
                          color: isCredit ? Colors.red : Colors.green,
                        ),
                        title: Text(isCredit
                            ? 'Vente à crédit'
                            : 'Remboursement'),
                        subtitle: Text(
                            '${fmtDateTime(e.date)}${e.note != null && e.note!.isNotEmpty ? ' • ${e.note}' : ''}'),
                        trailing: Text(
                          (isCredit ? '+' : '-') + fmtMoney(e.amount.abs()),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isCredit ? Colors.red : Colors.green,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
