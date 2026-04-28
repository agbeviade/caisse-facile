import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:barcode/barcode.dart' as bc;

import '../models/product.dart';
import '../utils/formatters.dart';

class LabelsScreen extends StatefulWidget {
  final List<Product> products;
  const LabelsScreen({super.key, required this.products});

  @override
  State<LabelsScreen> createState() => _LabelsScreenState();
}

class _LabelsScreenState extends State<LabelsScreen> {
  final Set<int> _selected = {};

  @override
  void initState() {
    super.initState();
    for (final p in widget.products) {
      if (p.id != null) _selected.add(p.id!);
    }
  }

  Future<Uint8List> _generatePdf() async {
    final doc = pw.Document();
    final selected =
        widget.products.where((p) => _selected.contains(p.id)).toList();
    // 3 columns x 7 rows = 21 labels per page
    const cols = 3;
    const rows = 7;
    const perPage = cols * rows;

    for (var i = 0; i < selected.length; i += perPage) {
      final page = selected.skip(i).take(perPage).toList();
      doc.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (ctx) => pw.GridView(
          crossAxisCount: cols,
          childAspectRatio: 1.6,
          children: page.map((p) {
            final barcode = bc.Barcode.code128();
            return pw.Container(
              padding: const pw.EdgeInsets.all(6),
              decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400, width: 0.5)),
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(p.name,
                      style: pw.TextStyle(
                          fontSize: 10, fontWeight: pw.FontWeight.bold),
                      maxLines: 2,
                      overflow: pw.TextOverflow.clip,
                      textAlign: pw.TextAlign.center),
                  pw.SizedBox(height: 4),
                  pw.Text(fmtMoney(p.salePrice),
                      style: pw.TextStyle(
                          fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 4),
                  pw.SizedBox(
                    height: 30,
                    child: pw.BarcodeWidget(
                      barcode: barcode,
                      data: p.barcode,
                      drawText: false,
                    ),
                  ),
                  pw.Text(p.barcode,
                      style: const pw.TextStyle(fontSize: 7)),
                ],
              ),
            );
          }).toList(),
        ),
      ));
    }
    return doc.save();
  }

  Future<void> _print() async {
    if (_selected.isEmpty) return;
    await Printing.layoutPdf(onLayout: (_) async => await _generatePdf());
  }

  Future<void> _share() async {
    if (_selected.isEmpty) return;
    final bytes = await _generatePdf();
    await Printing.sharePdf(bytes: bytes, filename: 'etiquettes.pdf');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Étiquettes (${_selected.length})'),
        actions: [
          IconButton(icon: const Icon(Icons.share), onPressed: _share),
          IconButton(icon: const Icon(Icons.print), onPressed: _print),
        ],
      ),
      body: ListView(
        children: widget.products.map((p) {
          return CheckboxListTile(
            value: _selected.contains(p.id),
            onChanged: (v) => setState(() {
              if (v == true) {
                _selected.add(p.id!);
              } else {
                _selected.remove(p.id);
              }
            }),
            title: Text(p.name),
            subtitle: Text('${p.barcode} • ${fmtMoney(p.salePrice)}'),
          );
        }).toList(),
      ),
    );
  }
}
