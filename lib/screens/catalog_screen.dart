import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../db/product_dao.dart';
import '../models/product.dart';
import '../utils/formatters.dart';
import '../widgets/app_drawer.dart';
import '../widgets/barcode_scanner_screen.dart';
import '../widgets/product_thumb.dart';
import 'product_form_screen.dart';
import 'labels_screen.dart';

enum _ViewMode { list, grid }

/// Persists view preference across screen pushes (in-memory).
_ViewMode _activeViewMode = _ViewMode.list;

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final _dao = ProductDao();
  final _searchCtrl = TextEditingController();
  List<Product> _products = [];
  _ViewMode _mode = _activeViewMode;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await _dao.all(search: _searchCtrl.text.trim());
    if (!mounted) return;
    setState(() => _products = p);
  }

  Future<void> _addNew() async {
    final code = await scanOrEnterBarcode(context, title: 'Code du produit');
    final barcode = (code != null && code.isNotEmpty)
        ? code
        : const Uuid().v4().substring(0, 12);
    if (!mounted) return;
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => ProductFormScreen(initialBarcode: barcode)));
    _load();
  }

  Future<void> _scanFind() async {
    final code = await scanOrEnterBarcode(context, title: 'Rechercher produit');
    if (code == null) return;
    final p = await _dao.findByBarcode(code);
    if (!mounted) return;
    if (p == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Produit introuvable')));
      return;
    }
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => ProductFormScreen(product: p)));
    _load();
  }

  Future<void> _adjust(Product p, double delta) async {
    if (p.id == null) return;
    final newQty = p.stockQty + delta;
    if (newQty < 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Stock ne peut pas être négatif')));
      return;
    }
    await _dao.adjustStock(p.id!, delta);
    _load();
  }

  void _switchMode(_ViewMode m) {
    setState(() {
      _mode = m;
      _activeViewMode = m;
    });
  }

  Future<void> _openProduct(Product p) async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => ProductFormScreen(product: p)));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Produits'),
        actions: [
          IconButton(
            icon: Icon(_mode == _ViewMode.list ? Icons.grid_view : Icons.view_list),
            tooltip: _mode == _ViewMode.list ? 'Vue grille' : 'Vue liste',
            onPressed: () => _switchMode(
                _mode == _ViewMode.list ? _ViewMode.grid : _ViewMode.list),
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_2),
            tooltip: 'Étiquettes',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(
                  builder: (_) => LabelsScreen(products: _products)));
            },
          ),
          IconButton(
              icon: const Icon(Icons.qr_code_scanner),
              tooltip: 'Scanner',
              onPressed: _scanFind),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Rechercher (nom ou code)…',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (_) => _load(),
            ),
          ),
          Expanded(
            child: _products.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inventory_2,
                              size: 80, color: Colors.grey),
                          SizedBox(height: 12),
                          Text('Aucun produit',
                              style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  )
                : (_mode == _ViewMode.list ? _buildList() : _buildGrid()),
          )
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addNew,
        icon: const Icon(Icons.add),
        label: const Text('Nouveau produit'),
      ),
    );
  }

  Widget _buildList() {
    return ListView.separated(
      itemCount: _products.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final p = _products[i];
        final low = p.alertThreshold > 0 && p.stockQty <= p.alertThreshold;
        return InkWell(
          onTap: () => _openProduct(p),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                ProductThumb(imagePath: p.imagePath, name: p.name, size: 52),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(p.barcode,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 2),
                      Text(
                          '${fmtMoney(p.purchasePrice)} / ${fmtMoney(p.salePrice)}',
                          style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(fmtQty(p.stockQty),
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: low ? Colors.red : null)),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _qtyBtn(Icons.remove, () => _adjust(p, -1)),
                        const SizedBox(width: 6),
                        _qtyBtn(Icons.add, () => _adjust(p, 1)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.78,
      ),
      itemCount: _products.length,
      itemBuilder: (_, i) {
        final p = _products[i];
        final low = p.alertThreshold > 0 && p.stockQty <= p.alertThreshold;
        return InkWell(
          onTap: () => _openProduct(p),
          borderRadius: BorderRadius.circular(14),
          child: Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AspectRatio(
                    aspectRatio: 1,
                    child: ProductThumb(
                        imagePath: p.imagePath,
                        name: p.name,
                        size: double.infinity,
                        radius: 10),
                  ),
                  const SizedBox(height: 8),
                  Text(p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(fmtMoney(p.salePrice),
                      style: const TextStyle(
                          color: Colors.green, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Row(
                    children: [
                      Text('Stk ${fmtQty(p.stockQty)}',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: low ? Colors.red : null)),
                      const Spacer(),
                      _qtyBtn(Icons.remove, () => _adjust(p, -1), small: true),
                      const SizedBox(width: 4),
                      _qtyBtn(Icons.add, () => _adjust(p, 1), small: true),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap, {bool small = false}) {
    final s = small ? 28.0 : 32.0;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(s / 2),
      child: Container(
        width: s,
        height: s,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: small ? 16 : 18),
      ),
    );
  }
}
