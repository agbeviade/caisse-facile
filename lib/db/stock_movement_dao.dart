import 'package:sqflite/sqflite.dart';
import '../models/stock_movement.dart';
import 'database_helper.dart';

class StockMovementDao {
  Future<Database> get _db async => DatabaseHelper.instance.database;

  Future<int> insert(StockMovement m) async {
    final db = await _db;
    return db.insert('stock_movements', m.toMap()..remove('id'));
  }

  /// Convenience: log a movement and update product stock atomically.
  Future<void> logAndAdjust({
    required int productId,
    required double qty, // signed
    required String kind,
    String? sourceType,
    int? sourceId,
    String? note,
  }) async {
    final db = await _db;
    await db.transaction((tx) async {
      await tx.insert('stock_movements', {
        'product_id': productId,
        'qty': qty,
        'kind': kind,
        'source_type': sourceType,
        'source_id': sourceId,
        'note': note,
        'date': DateTime.now().toIso8601String(),
      });
      await tx.rawUpdate(
          'UPDATE products SET stock_qty = stock_qty + ? WHERE id = ?',
          [qty, productId]);
    });
  }

  Future<List<StockMovement>> all({
    DateTime? from,
    DateTime? to,
    int? productId,
    String? kind,
    int limit = 200,
  }) async {
    final db = await _db;
    final wheres = <String>[];
    final args = <Object?>[];
    if (from != null) {
      wheres.add('m.date >= ?');
      args.add(from.toIso8601String());
    }
    if (to != null) {
      wheres.add('m.date < ?');
      args.add(to.toIso8601String());
    }
    if (productId != null) {
      wheres.add('m.product_id = ?');
      args.add(productId);
    }
    if (kind != null) {
      wheres.add('m.kind = ?');
      args.add(kind);
    }
    final whereClause = wheres.isEmpty ? '' : 'WHERE ${wheres.join(' AND ')}';
    final rows = await db.rawQuery('''
      SELECT m.*, p.name AS product_name
      FROM stock_movements m
      LEFT JOIN products p ON p.id = m.product_id
      $whereClause
      ORDER BY m.date DESC
      LIMIT ?
    ''', [...args, limit]);
    return rows.map(StockMovement.fromMap).toList();
  }
}
