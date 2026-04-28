import 'package:flutter/material.dart';
import '../db/expense_dao.dart';
import '../db/supplier_dao.dart';
import '../models/expense.dart';
import '../models/supplier.dart';
import '../utils/formatters.dart';
import '../widgets/app_drawer.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final _dao = ExpenseDao();
  final _supplierDao = SupplierDao();
  List<Expense> _list = [];
  List<Supplier> _suppliers = [];
  double _totalMonth = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 1);
    final l = await _dao.all();
    final s = await _supplierDao.all();
    final t = await _dao.totalBetween(start, end);
    if (!mounted) return;
    setState(() {
      _list = l;
      _suppliers = s;
      _totalMonth = t;
    });
  }

  Future<void> _add() async {
    final res = await showDialog<Expense>(
      context: context,
      builder: (_) => _ExpenseDialog(suppliers: _suppliers),
    );
    if (res == null) return;
    await _dao.insert(res);
    _load();
  }

  String? _supplierName(int? id) {
    if (id == null) return null;
    return _suppliers.firstWhere((s) => s.id == id,
            orElse: () => Supplier(name: '?'))
        .name;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(title: const Text('Charges')),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.red.shade50,
            child: Column(
              children: [
                const Text('Charges du mois',
                    style: TextStyle(fontSize: 13)),
                const SizedBox(height: 4),
                Text(fmtMoney(_totalMonth),
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.red)),
              ],
            ),
          ),
          Expanded(
            child: _list.isEmpty
                ? const Center(
                    child: Text('Aucune charge enregistrée',
                        style: TextStyle(color: Colors.grey)))
                : ListView.separated(
                    itemCount: _list.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final e = _list[i];
                      final sup = _supplierName(e.supplierId);
                      return ListTile(
                        leading: const CircleAvatar(
                            backgroundColor: Color(0xFFFFEBEE),
                            child: Icon(Icons.payments, color: Colors.red)),
                        title: Text(
                          [
                            if (e.category != null && e.category!.isNotEmpty)
                              e.category!,
                            if (sup != null) sup,
                            if (e.note != null && e.note!.isNotEmpty) e.note!,
                          ].join(' • '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(fmtDateTime(e.date)),
                        trailing: Text(fmtMoney(e.amount),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red)),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle charge'),
      ),
    );
  }
}

class _ExpenseDialog extends StatefulWidget {
  final List<Supplier> suppliers;
  const _ExpenseDialog({required this.suppliers});

  @override
  State<_ExpenseDialog> createState() => _ExpenseDialogState();
}

class _ExpenseDialogState extends State<_ExpenseDialog> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String? _category;
  int? _supplierId;
  DateTime _date = DateTime.now();

  static const _categories = [
    'Achat marchandise',
    'Transport',
    'Électricité',
    'Eau',
    'Loyer',
    'Salaire',
    'Internet / Téléphone',
    'Autres',
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nouvelle charge'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: _amount,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration:
                    const InputDecoration(labelText: 'Montant *')),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(labelText: 'Catégorie'),
              items: _categories
                  .map((c) =>
                      DropdownMenuItem<String>(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _category = v),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int?>(
              value: _supplierId,
              decoration: const InputDecoration(labelText: 'Fournisseur'),
              items: [
                const DropdownMenuItem<int?>(
                    value: null, child: Text('— Aucun —')),
                ...widget.suppliers.map((s) =>
                    DropdownMenuItem<int?>(value: s.id, child: Text(s.name))),
              ],
              onChanged: (v) => setState(() => _supplierId = v),
            ),
            const SizedBox(height: 8),
            TextField(
                controller: _note,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Note')),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler')),
        FilledButton(
          onPressed: () {
            final amt = double.tryParse(_amount.text);
            if (amt == null || amt <= 0) return;
            Navigator.pop(
                context,
                Expense(
                  date: _date,
                  amount: amt,
                  category: _category,
                  supplierId: _supplierId,
                  note: _note.text.trim().isEmpty ? null : _note.text.trim(),
                ));
          },
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}
