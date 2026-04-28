import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../db/database_helper.dart';

/// Exports SQLite tables to CSV files and shares them via the OS share sheet.
class ExportService {
  ExportService._();
  static final ExportService instance = ExportService._();

  /// Export all products to CSV and trigger share.
  Future<void> exportProductsCsv() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('products', orderBy: 'name COLLATE NOCASE');
    const headers = [
      'id',
      'barcode',
      'name',
      'category',
      'purchase_price',
      'sale_price',
      'stock_qty',
      'unit',
      'alert_threshold',
      'expiry_date',
    ];
    final lines = <String>[headers.join(',')];
    for (final r in rows) {
      lines.add(headers.map((h) => _csvCell(r[h])).join(','));
    }
    await _writeAndShare(
        'caisse_facile_produits_${_stamp()}.csv', lines.join('\n'));
  }

  /// Export sales (with totals) to CSV.
  Future<void> exportSalesCsv({DateTime? from, DateTime? to}) async {
    final db = await DatabaseHelper.instance.database;
    final clauses = <String>[];
    final args = <Object?>[];
    if (from != null) {
      clauses.add('date >= ?');
      args.add(from.toIso8601String());
    }
    if (to != null) {
      clauses.add('date < ?');
      args.add(to.toIso8601String());
    }
    final rows = await db.query(
      'sales',
      where: clauses.isEmpty ? null : clauses.join(' AND '),
      whereArgs: clauses.isEmpty ? null : args,
      orderBy: 'date DESC',
    );
    const headers = [
      'id',
      'date',
      'total',
      'profit',
      'payment_method',
      'customer_id',
      'on_credit',
      'channel',
    ];
    final lines = <String>[headers.join(',')];
    for (final r in rows) {
      lines.add(headers.map((h) => _csvCell(r[h])).join(','));
    }
    await _writeAndShare(
        'caisse_facile_ventes_${_stamp()}.csv', lines.join('\n'));
  }

  /// Export sale items (one row per line item) for deep analysis in Excel.
  Future<void> exportSaleItemsCsv({DateTime? from, DateTime? to}) async {
    final db = await DatabaseHelper.instance.database;
    final clauses = <String>['1=1'];
    final args = <Object?>[];
    if (from != null) {
      clauses.add('s.date >= ?');
      args.add(from.toIso8601String());
    }
    if (to != null) {
      clauses.add('s.date < ?');
      args.add(to.toIso8601String());
    }
    final rows = await db.rawQuery('''
      SELECT s.id AS sale_id, s.date AS date,
             p.name AS product_name, p.barcode AS barcode,
             si.quantity AS quantity,
             si.sale_price AS sale_price,
             si.purchase_price AS purchase_price,
             (si.quantity * si.sale_price) AS line_total,
             (si.quantity * (si.sale_price - si.purchase_price)) AS line_profit
      FROM sale_items si
      JOIN sales s ON s.id = si.sale_id
      JOIN products p ON p.id = si.product_id
      WHERE ${clauses.join(' AND ')}
      ORDER BY s.date DESC
    ''', args);
    const headers = [
      'sale_id',
      'date',
      'product_name',
      'barcode',
      'quantity',
      'sale_price',
      'purchase_price',
      'line_total',
      'line_profit',
    ];
    final lines = <String>[headers.join(',')];
    for (final r in rows) {
      lines.add(headers.map((h) => _csvCell(r[h])).join(','));
    }
    await _writeAndShare(
        'caisse_facile_lignes_ventes_${_stamp()}.csv', lines.join('\n'));
  }

  /// Quote and escape a single CSV cell. Wraps in quotes only if needed.
  String _csvCell(Object? v) {
    if (v == null) return '';
    final s = v.toString();
    if (s.contains(',') || s.contains('"') || s.contains('\n')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  String _stamp() {
    final n = DateTime.now();
    return '${n.year}${_pad(n.month)}${_pad(n.day)}_'
        '${_pad(n.hour)}${_pad(n.minute)}';
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  Future<void> _writeAndShare(String filename, String content) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsString(content);
    await Share.shareXFiles([XFile(file.path, mimeType: 'text/csv')],
        subject: filename);
  }
}
