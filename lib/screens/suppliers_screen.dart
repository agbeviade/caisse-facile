import 'package:flutter/material.dart';
import '../db/supplier_dao.dart';
import '../models/supplier.dart';
import '../widgets/app_drawer.dart';

class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  final _dao = SupplierDao();
  final _searchCtrl = TextEditingController();
  List<Supplier> _list = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await _dao.all(search: _searchCtrl.text.trim());
    if (!mounted) return;
    setState(() => _list = s);
  }

  Future<void> _edit([Supplier? initial]) async {
    final res = await showDialog<Supplier>(
      context: context,
      builder: (_) => _SupplierEditDialog(initial: initial),
    );
    if (res == null) return;
    if (res.id == null) {
      await _dao.insert(res);
    } else {
      await _dao.update(res);
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(title: const Text('Fournisseurs')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Rechercher…',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (_) => _load(),
            ),
          ),
          Expanded(
            child: _list.isEmpty
                ? const Center(
                    child: Text('Aucun fournisseur',
                        style: TextStyle(color: Colors.grey)))
                : ListView.separated(
                    itemCount: _list.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final s = _list[i];
                      return ListTile(
                        leading: const CircleAvatar(
                            child: Icon(Icons.handshake)),
                        title: Text(s.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600)),
                        subtitle: s.phone == null && s.note == null
                            ? null
                            : Text([s.phone, s.note]
                                .where((e) => e != null && e!.isNotEmpty)
                                .join(' • ')),
                        onTap: () => _edit(s),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text('Nouveau'),
      ),
    );
  }
}

class _SupplierEditDialog extends StatefulWidget {
  final Supplier? initial;
  const _SupplierEditDialog({this.initial});

  @override
  State<_SupplierEditDialog> createState() => _SupplierEditDialogState();
}

class _SupplierEditDialogState extends State<_SupplierEditDialog> {
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
      title:
          Text(widget.initial == null ? 'Nouveau fournisseur' : 'Modifier'),
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
                Supplier(
                  id: widget.initial?.id,
                  name: n,
                  phone: _phone.text.trim().isEmpty
                      ? null
                      : _phone.text.trim(),
                  note: _note.text.trim().isEmpty ? null : _note.text.trim(),
                ));
          },
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}
