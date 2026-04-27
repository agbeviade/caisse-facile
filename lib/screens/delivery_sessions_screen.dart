import 'package:flutter/material.dart';
import '../db/delivery_dao.dart';
import '../models/delivery_man.dart';
import '../models/delivery_session.dart';
import '../utils/formatters.dart';
import 'delivery_loadout_screen.dart';
import 'delivery_return_screen.dart';

class DeliverySessionsScreen extends StatefulWidget {
  const DeliverySessionsScreen({super.key});

  @override
  State<DeliverySessionsScreen> createState() => _DeliverySessionsScreenState();
}

class _DeliverySessionsScreenState extends State<DeliverySessionsScreen> {
  final _dao = DeliveryDao();
  List<DeliverySession> _sessions = [];
  Map<int, DeliveryMan> _men = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await _dao.openSessions();
    final men = await _dao.allMen();
    if (!mounted) return;
    setState(() {
      _sessions = s;
      _men = {for (final m in men) m.id!: m};
    });
  }

  Future<void> _newSession() async {
    final men = await _dao.allMen();
    if (!mounted) return;
    if (men.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Créez d'abord un livreur (Équipe livreurs)")));
      return;
    }
    final selected = await showDialog<DeliveryMan>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Choisir un livreur'),
        children: men
            .map((m) => SimpleDialogOption(
                  child: Text(m.name),
                  onPressed: () => Navigator.pop(context, m),
                ))
            .toList(),
      ),
    );
    if (selected == null) return;
    final id = await _dao.createSession(selected.id!);
    if (!mounted) return;
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => DeliveryLoadoutScreen(sessionId: id)));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tournées livreurs')),
      body: _sessions.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.local_shipping, size: 80, color: Colors.grey),
                    SizedBox(height: 16),
                    Text("Aucune tournée en cours",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16)),
                  ],
                ),
              ),
            )
          : ListView.separated(
              itemCount: _sessions.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final s = _sessions[i];
                final m = _men[s.deliveryManId];
                return ListTile(
                  leading: const CircleAvatar(
                      child: Icon(Icons.local_shipping)),
                  title: Text(m?.name ?? 'Livreur #${s.deliveryManId}'),
                  subtitle: Text('Démarrée: ${fmtDateTime(s.startDate)}'),
                  trailing: Wrap(
                    spacing: 4,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.add_box),
                        tooltip: 'Ajouter produits',
                        onPressed: () async {
                          await Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => DeliveryLoadoutScreen(
                                      sessionId: s.id!)));
                          _load();
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.assignment_turned_in,
                            color: Colors.green),
                        tooltip: 'Faire le point',
                        onPressed: () async {
                          await Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => DeliveryReturnScreen(
                                      sessionId: s.id!)));
                          _load();
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newSession,
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle tournée'),
      ),
    );
  }
}
