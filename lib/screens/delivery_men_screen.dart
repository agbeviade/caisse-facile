import 'package:flutter/material.dart';
import '../db/delivery_dao.dart';
import '../models/delivery_man.dart';

class DeliveryMenScreen extends StatefulWidget {
  const DeliveryMenScreen({super.key});

  @override
  State<DeliveryMenScreen> createState() => _DeliveryMenScreenState();
}

class _DeliveryMenScreenState extends State<DeliveryMenScreen> {
  final _dao = DeliveryDao();
  List<DeliveryMan> _men = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final m = await _dao.allMen();
    if (!mounted) return;
    setState(() => _men = m);
  }

  Future<void> _edit({DeliveryMan? m}) async {
    final nameCtrl = TextEditingController(text: m?.name ?? '');
    final phoneCtrl = TextEditingController(text: m?.phone ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(m == null ? 'Nouveau livreur' : 'Modifier livreur'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Nom')),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Téléphone'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Enregistrer')),
        ],
      ),
    );
    if (ok != true) return;
    final dm = DeliveryMan(
      id: m?.id,
      name: nameCtrl.text.trim(),
      phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
    );
    if (dm.name.isEmpty) return;
    if (dm.id == null) {
      await _dao.insertMan(dm);
    } else {
      await _dao.updateMan(dm);
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Équipe livreurs')),
      body: _men.isEmpty
          ? const Center(child: Text('Aucun livreur enregistré'))
          : ListView.separated(
              itemCount: _men.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final m = _men[i];
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(m.name),
                  subtitle: Text(m.phone ?? '—'),
                  trailing: IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _edit(m: m)),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.person_add),
        label: const Text('Ajouter'),
      ),
    );
  }
}
