import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../db/product_dao.dart';
import '../models/product.dart';
import '../utils/formatters.dart';
import '../widgets/barcode_scanner_screen.dart';
import 'product_form_screen.dart';
import 'labels_screen.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final _dao = ProductDao();
  final _searchCtrl = TextEditingController();
  List<Product> _products = [];

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catalogue'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_2),
            tooltip: 'Étiquettes',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(
                  builder: (_) => LabelsScreen(products: _products)));
            },
          ),
          IconButton(
              icon: const Icon(Icons.qr_code_scanner), onPressed: _scanFind),
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
                ? const Center(child: Text('Aucun produit'))
                : ListView.separated(
                    itemCount: _products.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final p = _products[i];
                      final low = p.alertThreshold > 0 &&
                          p.stockQty <= p.alertThreshold;
                      return ListTile(
                        title: Text(p.name,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                            '${p.barcode} • Achat ${fmtMoney(p.purchasePrice)} • Vente ${fmtMoney(p.salePrice)}'),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Stock: ${fmtQty(p.stockQty)}',
                                style: TextStyle(
                                    color: low ? Colors.red : null,
                                    fontWeight: FontWeight.bold)),
                            if (p.expiryDate != null)
                              Text('Exp: ${fmtDate(p.expiryDate!)}',
                                  style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                        onTap: () async {
                          await Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      ProductFormScreen(product: p)));
                          _load();
                        },
                      );
                    },
                  ),
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
}
