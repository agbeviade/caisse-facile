import 'package:flutter/material.dart';
import '../db/delivery_dao.dart';
import '../models/delivery_man.dart';
import '../models/delivery_session.dart';
import '../services/receipt_service.dart';
import '../utils/formatters.dart';
import '../widgets/barcode_scanner_screen.dart';

/// Le "Point" — scan des invendus rapportés. Calcul auto montant dû.
class DeliveryReturnScreen extends StatefulWidget {
  final int sessionId;
  const DeliveryReturnScreen({super.key, required this.sessionId});

  @override
  State<DeliveryReturnScreen> createState() => _DeliveryReturnScreenState();
}

class _DeliveryReturnScreenState extends State<DeliveryReturnScreen> {
  final _dao = DeliveryDao();
  List<SessionItem> _items = [];
  // local override of returned qty before saving
  final Map<int, double> _returned = {};
  DeliveryMan? _man;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await _dao.sessionItems(widget.sessionId);
    final session = await _dao.findSession(widget.sessionId);
    final man = session != null
        ? await _dao.findMan(session.deliveryManId)
        : null;
    if (!mounted) return;
    setState(() {
      _items = items;
      _man = man;
      for (final it in items) {
        _returned[it.productId] ??= it.qtyReturned;
      }
    });
  }

  Future<void> _scanReturn() async {
    final code = await scanOrEnterBarcode(context, title: 'Scanner invendu');
    if (code == null || code.isEmpty) return;
    final idx = _items.indexWhere((e) => e.productBarcode == code);
    if (!mounted) return;
    if (idx < 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Ce produit n'a pas été confié au livreur")));
      return;
    }
    final it = _items[idx];
    final current = _returned[it.productId] ?? 0;
    if (current + 1 > it.qtyOut) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              "Quantité rapportée > confiée pour ${it.productName}")));
      return;
    }
    setState(() {
      _returned[it.productId] = current + 1;
    });
  }

  double _qtyReturned(SessionItem it) => _returned[it.productId] ?? 0;
  double _qtySold(SessionItem it) => it.qtyOut - _qtyReturned(it);
  double _amountDue(SessionItem it) => _qtySold(it) * it.unitSalePrice;
  double get _totalDue => _items.fold(0, (s, e) => s + _amountDue(e));

  Future<void> _validate() async {
    // Persist returned quantities
    for (final it in _items) {
      await _dao.setItemReturned(
        sessionId: widget.sessionId,
        productId: it.productId,
        qtyReturned: _qtyReturned(it),
      );
    }
    final saleId = await _dao.closeSession(widget.sessionId);
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tournée clôturée'),
        content: Text(
            'Montant dû par ${_man?.name ?? 'le livreur'}: ${fmtMoney(_totalDue)}\n\n'
            'Voulez-vous partager le reçu sur WhatsApp ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Fermer')),
          FilledButton.icon(
            icon: const Icon(Icons.share),
            label: const Text('Partager PDF'),
            onPressed: () async {
              Navigator.pop(ctx);
              final updatedItems =
                  await _dao.sessionItems(widget.sessionId);
              await ReceiptService.shareDeliveryReceipt(
                deliveryManName: _man?.name ?? 'Livreur',
                deliveryManPhone: _man?.phone,
                items: updatedItems,
                date: DateTime.now(),
                saleId: saleId,
              );
            },
          ),
        ],
      ),
    );
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Point — ${_man?.name ?? "Livreur"}'),
      ),
      body: Column(
        children: [
          Expanded(
            child: _items.isEmpty
                ? const Center(
                    child: Text('Aucun produit dans cette tournée'))
                : ListView.separated(
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final it = _items[i];
                      final qReturned = _qtyReturned(it);
                      final qSold = _qtySold(it);
                      return ListTile(
                        title: Text(it.productName ?? '#${it.productId}'),
                        subtitle: Text(
                            'Confié: ${fmtQty(it.qtyOut)} • Vendu: ${fmtQty(qSold)} • Rapporté: ${fmtQty(qReturned)}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: qReturned <= 0
                                    ? null
                                    : () => setState(() {
                                          _returned[it.productId] =
                                              qReturned - 1;
                                        })),
                            SizedBox(
                              width: 36,
                              child: Text(fmtQty(qReturned),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                            ),
                            IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: qReturned >= it.qtyOut
                                    ? null
                                    : () => setState(() {
                                          _returned[it.productId] =
                                              qReturned + 1;
                                        })),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('MONTANT DÛ',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600)),
                    Text(fmtMoney(_totalDue),
                        style: const TextStyle(
                            fontSize: 28, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _scanReturn,
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('Scanner invendu'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: _items.isEmpty ? null : _validate,
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Valider'),
                    ),
                  ),
                ]),
              ],
            ),
          )
        ],
      ),
    );
  }
}
