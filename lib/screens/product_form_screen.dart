import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../db/product_dao.dart';
import '../models/product.dart';
import '../utils/formatters.dart';

class ProductFormScreen extends StatefulWidget {
  final Product? product;
  final String? initialBarcode;
  const ProductFormScreen({super.key, this.product, this.initialBarcode});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dao = ProductDao();

  late TextEditingController _barcode;
  late TextEditingController _name;
  late TextEditingController _category;
  late TextEditingController _purchase;
  late TextEditingController _sale;
  late TextEditingController _stock;
  late TextEditingController _alert;
  DateTime? _expiry;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _barcode = TextEditingController(text: p?.barcode ?? widget.initialBarcode ?? '');
    _name = TextEditingController(text: p?.name ?? '');
    _category = TextEditingController(text: p?.category ?? '');
    _purchase = TextEditingController(text: p?.purchasePrice.toString() ?? '');
    _sale = TextEditingController(text: p?.salePrice.toString() ?? '');
    _stock = TextEditingController(text: p?.stockQty.toString() ?? '0');
    _alert = TextEditingController(text: p?.alertThreshold.toString() ?? '0');
    _expiry = p?.expiryDate;
  }

  @override
  void dispose() {
    _barcode.dispose();
    _name.dispose();
    _category.dispose();
    _purchase.dispose();
    _sale.dispose();
    _stock.dispose();
    _alert.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final product = Product(
      id: widget.product?.id,
      barcode: _barcode.text.trim(),
      name: _name.text.trim(),
      category: _category.text.trim().isEmpty ? null : _category.text.trim(),
      purchasePrice: double.tryParse(_purchase.text) ?? 0,
      salePrice: double.tryParse(_sale.text) ?? 0,
      stockQty: double.tryParse(_stock.text) ?? 0,
      alertThreshold: double.tryParse(_alert.text) ?? 0,
      expiryDate: _expiry,
    );
    try {
      if (product.id == null) {
        await _dao.insert(product);
      } else {
        await _dao.update(product);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  Future<void> _delete() async {
    if (widget.product?.id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer ce produit ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok == true) {
      await _dao.delete(widget.product!.id!);
      if (!mounted) return;
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product == null ? 'Nouveau produit' : 'Modifier'),
        actions: [
          if (widget.product != null)
            IconButton(
                icon: const Icon(Icons.delete_outline), onPressed: _delete),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _barcode,
              decoration: const InputDecoration(
                  labelText: 'Code-barres / QR',
                  border: OutlineInputBorder()),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Requis' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                  labelText: 'Nom du produit', border: OutlineInputBorder()),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Requis' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _category,
              decoration: const InputDecoration(
                  labelText: 'Catégorie', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _purchase,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                  ],
                  decoration: const InputDecoration(
                      labelText: "Prix d'achat", border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _sale,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                  ],
                  decoration: const InputDecoration(
                      labelText: 'Prix de vente',
                      border: OutlineInputBorder()),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _stock,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                  ],
                  decoration: const InputDecoration(
                      labelText: 'Stock', border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _alert,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                  ],
                  decoration: const InputDecoration(
                      labelText: 'Seuil alerte',
                      border: OutlineInputBorder()),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            ListTile(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: Colors.grey.shade400)),
              title: Text(_expiry == null
                  ? 'Date de péremption (optionnel)'
                  : 'Péremption: ${fmtDate(_expiry!)}'),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final d = await showDatePicker(
                    context: context,
                    initialDate: _expiry ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100));
                if (d != null) setState(() => _expiry = d);
              },
            ),
            if (_expiry != null)
              TextButton(
                  onPressed: () => setState(() => _expiry = null),
                  child: const Text('Effacer la date')),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }
}
