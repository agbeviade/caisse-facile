import 'package:flutter/material.dart';
import '../db/customer_dao.dart';
import '../models/customer.dart';
import '../utils/formatters.dart';
import '../widgets/app_drawer.dart';
import '../widgets/skeletons.dart';
import 'customer_detail_screen.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final _dao = CustomerDao();
  final _searchCtrl = TextEditingController();
  List<Customer> _list = [];
  double _totalDebt = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final c = await _dao.all(search: _searchCtrl.text.trim());
    final t = await _dao.totalDebt();
    if (!mounted) return;
    setState(() {
      _list = c;
      _totalDebt = t;
      _loading = false;
    });
  }

  Future<void> _addCustomer() async {
    final res = await showDialog<Customer>(
      context: context,
      builder: (_) => const _CustomerEditDialog(),
    );
    if (res == null) return;
    await _dao.insert(res);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(title: const Text('Acheteurs')),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: _totalDebt > 0
                ? Colors.orange.shade100
                : Colors.green.shade100,
            child: Column(
              children: [
                const Text('Total dû par les acheteurs',
                    style: TextStyle(fontSize: 13)),
                const SizedBox(height: 4),
                Text(fmtMoney(_totalDebt),
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Rechercher (nom, téléphone)…',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (_) => _load(),
            ),
          ),
          Expanded(
            child: _loading
                ? const SkeletonProductList()
                : _list.isEmpty
                ? EmptyState(
                    icon: Icons.group_outlined,
                    title: 'Aucun acheteur',
                    subtitle: 'Ajoute tes habitués pour suivre les crédits.',
                    actionLabel: 'Nouvel acheteur',
                    onAction: _addCustomer)
                : ListView.separated(
                    itemCount: _list.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final c = _list[i];
                      return ListTile(
                        leading: CircleAvatar(
                            child: Text(c.name.isEmpty
                                ? '?'
                                : c.name[0].toUpperCase())),
                        title: Text(c.name,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: c.phone == null
                            ? null
                            : Text(c.phone!,
                                style: const TextStyle(fontSize: 12)),
                        trailing: Text(
                          fmtMoney(c.balance),
                          style: TextStyle(
                            color: c.balance > 0 ? Colors.red : Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onTap: () async {
                          await Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      CustomerDetailScreen(customer: c)));
                          _load();
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addCustomer,
        icon: const Icon(Icons.person_add),
        label: const Text('Nouvel acheteur'),
      ),
    );
  }
}

class _CustomerEditDialog extends StatefulWidget {
  final Customer? initial;
  const _CustomerEditDialog({this.initial});

  @override
  State<_CustomerEditDialog> createState() => _CustomerEditDialogState();
}

class _CustomerEditDialogState extends State<_CustomerEditDialog> {
  late TextEditingController _name;
  late TextEditingController _phone;
  late TextEditingController _note;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initial?.name ?? '');
    _phone = TextEditingController(text: widget.initial?.phone ?? '');
    _note = TextEditingController(text: widget.initial?.note ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'Nouvel acheteur' : 'Modifier'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Nom *')),
            const SizedBox(height: 8),
            TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Téléphone')),
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
            final n = _name.text.trim();
            if (n.isEmpty) return;
            Navigator.pop(
                context,
                Customer(
                  id: widget.initial?.id,
                  name: n,
                  phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
                  note: _note.text.trim().isEmpty ? null : _note.text.trim(),
                  balance: widget.initial?.balance ?? 0,
                ));
          },
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}
