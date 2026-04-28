import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/delivery_session.dart';
import '../utils/formatters.dart';

class ReceiptService {
  /// Generates a PDF receipt for a delivery session and shares it
  /// via the system share sheet (WhatsApp, etc.).
  static Future<void> shareDeliveryReceipt({
    required String deliveryManName,
    String? deliveryManPhone,
    required List<SessionItem> items,
    required DateTime date,
    int? saleId,
  }) async {
    double totalDue = 0;
    double totalProfit = 0;
    final lines = <List<String>>[];
    for (final it in items) {
      final sold = it.qtyOut - it.qtyReturned;
      if (sold <= 0) continue;
      totalDue += sold * it.unitSalePrice;
      totalProfit += sold * (it.unitSalePrice - it.unitPurchasePrice);
      lines.add([
        it.productName ?? '#${it.productId}',
        fmtQty(it.qtyOut),
        fmtQty(it.qtyReturned),
        fmtQty(sold),
        fmtMoney(it.unitSalePrice),
        fmtMoney(sold * it.unitSalePrice),
      ]);
    }

    final doc = pw.Document();
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Reçu de tournée',
              style: pw.TextStyle(
                  fontSize: 22, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Text('Date: ${fmtDateTime(date)}'),
          pw.Text('Livreur: $deliveryManName'),
          if (deliveryManPhone != null) pw.Text('Téléphone: $deliveryManPhone'),
          if (saleId != null) pw.Text('N° vente: $saleId'),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: const [
              'Produit',
              'Confié',
              'Rapporté',
              'Vendu',
              'PU',
              'Total'
            ],
            data: lines,
            cellAlignment: pw.Alignment.centerLeft,
            headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration:
                const pw.BoxDecoration(color: PdfColors.green700),
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
          ),
          pw.SizedBox(height: 16),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                  color: PdfColors.green50,
                  borderRadius: pw.BorderRadius.circular(8)),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Bénéfice: ${fmtMoney(totalProfit)}'),
                  pw.SizedBox(height: 4),
                  pw.Text('MONTANT DÛ: ${fmtMoney(totalDue)}',
                      style: pw.TextStyle(
                          fontSize: 18, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ),
          ),
          pw.Spacer(),
          pw.Center(
              child: pw.Text('Caisse Facile',
                  style: const pw.TextStyle(
                      color: PdfColors.grey600, fontSize: 10))),
        ],
      ),
    ));

    final bytes = await doc.save();
    final tmp = await getTemporaryDirectory();
    final file = File(p.join(tmp.path,
        'recu_${deliveryManName.replaceAll(RegExp(r'\s+'), '_')}_${date.millisecondsSinceEpoch}.pdf'));
    await file.writeAsBytes(bytes);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      text:
          'Reçu de tournée - $deliveryManName\nMontant dû: ${fmtMoney(totalDue)}',
      subject: 'Reçu Caisse Facile',
    );
  }
}
