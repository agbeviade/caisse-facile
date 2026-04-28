import 'package:flutter/material.dart';
import '../db/product_dao.dart';
import '../db/stock_movement_dao.dart';
import '../models/product.dart';
import '../models/stock_movement.dart';
import '../utils/formatters.dart';
import '../widgets/app_drawer.dart';

class StockMovementsScreen extends StatefulWidget {
  const StockMovementsScreen({super.key});

  @override
  State<StockMovementsScreen> createState() => _StockMovementsScreenState();
}

class _StockMovementsScreenState extends State<StockMovementsScreen> {
  final _dao = StockMovementDao();
  final _productDao = ProductDao();
  List<StockMovement> _list = [];
  List<Product> _products = [];
  String? _kindFilter; // null | 'IN' | 'OUT'
  int? _productFilter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final l = await _dao.all(kind: _kindFilter, productId: _productFilter);
    final p = await _productDao.all();
    if (!mounted) return;
    setState(() {
      _list = l;
      _products = p;
    });
  }

  Future<void> _addManual() async {
    if (_products.isEmpty) return;
    final res = await showDialog<_ManualMovement>(
      context: context,
      builder: (_) => _ManualMovementDialog(products: _products),
    );
    if (res == null) return;
    await _dao.logAndAdjust(
      productId: res.productId,
      qty: res.kind == 'IN' ? res.qty : -res.qty,
      kind: res.kind,
      sourceType: 'MANUAL',
      note: res.note,
    );
    _load();
  }

  String _sourceLabel(StockMovement m) {
    switch (m.sourceType) {
      case 'SALE':
        return 'Vente comptoir';
      case 'DELIVERY':
        return 'Livraison';
      case 'EXPENSE':
        return 'Achat';
      case 'MANUAL':
        return 'Ajustement';
      default:
        return '—';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(title: const Text('Mouvements de stock')),
      body: Column(
        children: [
          // Filters
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: SegmentedButton<String?>(
                    segments: const [
                      ButtonSegment(value: null, label: Text('Tous')),
                      ButtonSegment(
                          value: 'IN',
                          label: Text('Entrées'),
                          icon: Icon(Icons.arrow_downward)),
                      ButtonSegment(
                          value: 'OUT',
                          label: Text('Sorties'),
                          icon: Icon(Icons.arrow_upward)),
                    ],
                    selected: {_kindFilter},
                    onSelectionChanged: (s) {
                      setState(() => _kindFilter = s.first);
                      _load();
                    },
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: DropdownButtonFormField<int?>(
              value: _productFilter,
              decoration: const InputDecoration(
                  labelText: 'Filtrer par produit', isDense: true),
              items: [
                const DropdownMenuItem<int?>(
                    value: null, child: Text('Tous les produits')),
                ..._products.map((p) =>
                    DropdownMenuItem<int?>(value: p.id, child: Text(p.name))),
              ],
              onChanged: (v) {
                setState(() => _productFilter = v);
                _load();
              },
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: _list.isEmpty
                ? const Center(
                    child: Text('Aucun mouvement',
                        style: TextStyle(color: Colors.grey)))
                : ListView.separated(
                    itemCount: _list.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final m = _list[i];
                      final isIn = m.kind == 'IN';
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              isIn ? Colors.green.shade100 : Colors.red.shade100,
                          child: Icon(
                              isIn
                                  ? Icons.arrow_downward
                                  : Icons.arrow_upward,
                              color: isIn ? Colors.green : Colors.red),
                        ),
                        title: Text(m.productName ?? 'Produit #${m.productId}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600)),
                        subtitle: Text(
                            '${fmtDateTime(m.date)} • ${_sourceLabel(m)}${m.note != null ? ' — ${m.note}' : ''}'),
                        trailing: Text(
                          '${m.qty > 0 ? '+' : ''}${fmtQty(m.qty)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isIn ? Colors.green : Colors.red,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addManual,
        icon: const Icon(Icons.add),
        label: const Text('Ajustement'),
      ),
    );
  }
}

class _ManualMovement {
  final int productId;
  final double qty;
  final String kind;
  final String? note;
  _ManualMovement(this.productId, this.qty, this.kind, this.note);
}

class _ManualMovementDialog extends StatefulWidget {
  final List<Product> products;
  const _ManualMovementDialog({required this.products});

  @override
  State<_ManualMovementDialog> createState() => _ManualMovementDialogState();
}

class _ManualMovementDialogState extends State<_ManualMovementDialog> {
  int? _productId;
  String _kind = 'IN';
  final _qty = TextEditingController();
  final _note = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ajustement de stock'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<int>(
              value: _productId,
              decoration: const InputDecoration(labelText: 'Produit *'),
              items: widget.products
                  .map((p) =>
                      DropdownMenuItem<int>(value: p.id, child: Text(p.name)))
                  .toList(),
              onChanged: (v) => setState(() => _productId = v),
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'IN', label: Text('Entrée')),
                ButtonSegment(value: 'OUT', label: Text('Sortie')),
              ],
              selected: {_kind},
              onSelectionChanged: (s) => setState(() => _kind = s.first),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _qty,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Quantité *'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _note,
              maxLines: 2,
              decoration: const InputDecoration(
                  labelText: 'Raison (perte, retour, etc.)'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler')),
        FilledButton(
          onPressed: () {
            final q = double.tryParse(_qty.text);
            if (_productId == null || q == null || q <= 0) return;
            Navigator.pop(
                context,
                _ManualMovement(_productId!, q, _kind,
                    _note.text.trim().isEmpty ? null : _note.text.trim()));
          },
          child: const Text('Valider'),
        ),
      ],
    );
  }
}
