import 'package:flutter/material.dart';
import '../db/delivery_dao.dart';
import '../db/product_dao.dart';
import '../models/delivery_session.dart';
import '../utils/formatters.dart';
import '../widgets/barcode_scanner_screen.dart';

/// Sortie livreur: scan des produits confiés au livreur.
class DeliveryLoadoutScreen extends StatefulWidget {
  final int sessionId;
  const DeliveryLoadoutScreen({super.key, required this.sessionId});

  @override
  State<DeliveryLoadoutScreen> createState() => _DeliveryLoadoutScreenState();
}

class _DeliveryLoadoutScreenState extends State<DeliveryLoadoutScreen> {
  final _dao = DeliveryDao();
  final _productDao = ProductDao();

  List<SessionItem> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await _dao.sessionItems(widget.sessionId);
    if (!mounted) return;
    setState(() => _items = items);
  }

  Future<void> _addByScan() async {
    final code = await scanOrEnterBarcode(context, title: 'Confier au livreur');
    if (code == null || code.isEmpty) return;
    final p = await _productDao.findByBarcode(code);
    if (!mounted) return;
    if (p == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Produit inconnu')));
      return;
    }
    if (p.stockQty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Stock épuisé pour ${p.name}')));
      return;
    }
    try {
      await _dao.addItemOut(
        sessionId: widget.sessionId,
        productId: p.id!,
        qty: 1,
        salePrice: p.salePrice,
        purchasePrice: p.purchasePrice,
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  double get _totalValue =>
      _items.fold(0, (s, e) => s + e.qtyOut * e.unitSalePrice);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sortie livreur')),
      body: Column(
        children: [
          Expanded(
            child: _items.isEmpty
                ? const Center(
                    child: Text('Scannez les produits à confier'))
                : ListView.separated(
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final it = _items[i];
                      return ListTile(
                        title: Text(it.productName ?? '#${it.productId}'),
                        subtitle: Text(
                            '${fmtQty(it.qtyOut)} × ${fmtMoney(it.unitSalePrice)}'),
                        trailing: Text(fmtMoney(it.qtyOut * it.unitSalePrice),
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
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
                    const Text('Valeur emportée',
                        style: TextStyle(fontSize: 16)),
                    Text(fmtMoney(_totalValue),
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _addByScan,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scanner produit'),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
