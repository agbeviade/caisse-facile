import 'package:flutter/material.dart';
import '../db/product_dao.dart';
import '../db/sale_dao.dart';
import '../utils/formatters.dart';
import '../widgets/barcode_scanner_screen.dart';

class CounterSaleScreen extends StatefulWidget {
  const CounterSaleScreen({super.key});

  @override
  State<CounterSaleScreen> createState() => _CounterSaleScreenState();
}

class _CounterSaleScreenState extends State<CounterSaleScreen> {
  final _productDao = ProductDao();
  final _saleDao = SaleDao();
  final List<CartItem> _cart = [];

  double get _total => _cart.fold(0, (s, e) => s + e.total);

  Future<void> _scan() async {
    final code = await scanOrEnterBarcode(context, title: 'Scanner article');
    if (code == null || code.isEmpty) return;
    final p = await _productDao.findByBarcode(code);
    if (!mounted) return;
    if (p == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Produit inconnu — créez-le d\'abord')));
      return;
    }
    setState(() {
      final idx = _cart.indexWhere((c) => c.productId == p.id);
      if (idx >= 0) {
        _cart[idx].qty += 1;
      } else {
        _cart.add(CartItem(
          productId: p.id!,
          name: p.name,
          barcode: p.barcode,
          qty: 1,
          salePrice: p.salePrice,
          purchasePrice: p.purchasePrice,
        ));
      }
    });
  }

  Future<void> _searchAdd() async {
    final products = await _productDao.all();
    if (!mounted) return;
    final selected = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        final ctrl = TextEditingController();
        var filtered = products;
        return StatefulBuilder(builder: (ctx, setS) {
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: SizedBox(
                height: MediaQuery.of(ctx).size.height * 0.7,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: TextField(
                        controller: ctrl,
                        autofocus: true,
                        decoration: const InputDecoration(
                            hintText: 'Rechercher…', prefixIcon: Icon(Icons.search)),
                        onChanged: (v) => setS(() {
                          final q = v.toLowerCase();
                          filtered = products
                              .where((p) =>
                                  p.name.toLowerCase().contains(q) ||
                                  p.barcode.toLowerCase().contains(q))
                              .toList();
                        }),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final p = filtered[i];
                          return ListTile(
                            title: Text(p.name),
                            subtitle: Text(
                                '${p.barcode} • Stock ${fmtQty(p.stockQty)}'),
                            trailing: Text(fmtMoney(p.salePrice)),
                            onTap: () => Navigator.pop(ctx, p.id),
                          );
                        },
                      ),
                    )
                  ],
                ),
              ),
            ),
          );
        });
      },
    );
    if (selected == null) return;
    final p = await _productDao.findById(selected);
    if (p == null || !mounted) return;
    setState(() {
      final idx = _cart.indexWhere((c) => c.productId == p.id);
      if (idx >= 0) {
        _cart[idx].qty += 1;
      } else {
        _cart.add(CartItem(
          productId: p.id!,
          name: p.name,
          barcode: p.barcode,
          qty: 1,
          salePrice: p.salePrice,
          purchasePrice: p.purchasePrice,
        ));
      }
    });
  }

  Future<void> _checkout() async {
    if (_cart.isEmpty) return;
    try {
      await _saleDao.checkout(_cart);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: Colors.green,
          content: Text('Vente enregistrée: ${fmtMoney(_total)}')));
      setState(() => _cart.clear());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vente comptoir'),
        actions: [
          IconButton(
              icon: const Icon(Icons.search), onPressed: _searchAdd),
          if (_cart.isNotEmpty)
            IconButton(
                icon: const Icon(Icons.delete_sweep),
                onPressed: () => setState(() => _cart.clear())),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _cart.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.shopping_cart, size: 80, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            "Scannez un article pour commencer",
                            style: TextStyle(fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: _cart.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final c = _cart[i];
                      return ListTile(
                        title: Text(c.name),
                        subtitle: Text(
                            '${fmtQty(c.qty)} × ${fmtMoney(c.salePrice)}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: () => setState(() {
                                      c.qty = (c.qty - 1).clamp(0, 99999);
                                      if (c.qty <= 0) _cart.removeAt(i);
                                    })),
                            Text(fmtMoney(c.total),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16)),
                            IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: () =>
                                    setState(() => c.qty += 1)),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              boxShadow: const [
                BoxShadow(blurRadius: 6, color: Colors.black12)
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('TOTAL',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    Text(fmtMoney(_total),
                        style: const TextStyle(
                            fontSize: 26, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _scan,
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text('Scanner'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: _cart.isEmpty ? null : _checkout,
                        icon: const Icon(Icons.payments),
                        label: const Text('Encaisser'),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
