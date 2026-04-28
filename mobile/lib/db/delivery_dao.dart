import 'package:sqflite/sqflite.dart';
import '../models/delivery_man.dart';
import '../models/delivery_session.dart';
import 'database_helper.dart';

class DeliveryDao {
  Future<Database> get _db async => DatabaseHelper.instance.database;

  // Delivery men
  Future<int> insertMan(DeliveryMan m) async {
    final db = await _db;
    return db.insert('delivery_men', m.toMap()..remove('id'));
  }

  Future<int> updateMan(DeliveryMan m) async {
    final db = await _db;
    return db
        .update('delivery_men', m.toMap(), where: 'id = ?', whereArgs: [m.id]);
  }

  Future<int> deleteMan(int id) async {
    final db = await _db;
    return db.delete('delivery_men', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<DeliveryMan>> allMen() async {
    final db = await _db;
    final rows = await db.query('delivery_men', orderBy: 'name ASC');
    return rows.map(DeliveryMan.fromMap).toList();
  }

  Future<DeliveryMan?> findMan(int id) async {
    final db = await _db;
    final rows = await db
        .query('delivery_men', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return DeliveryMan.fromMap(rows.first);
  }

  // Sessions
  Future<int> createSession(int deliveryManId) async {
    final db = await _db;
    return db.insert('delivery_sessions', {
      'delivery_man_id': deliveryManId,
      'status': 'IN_PROGRESS',
      'start_date': DateTime.now().toIso8601String(),
    });
  }

  Future<List<DeliverySession>> openSessions() async {
    final db = await _db;
    final rows = await db.query('delivery_sessions',
        where: 'status = ?',
        whereArgs: ['IN_PROGRESS'],
        orderBy: 'start_date DESC');
    return rows.map(DeliverySession.fromMap).toList();
  }

  Future<List<DeliverySession>> allSessions() async {
    final db = await _db;
    final rows = await db.query('delivery_sessions',
        orderBy: 'start_date DESC');
    return rows.map(DeliverySession.fromMap).toList();
  }

  Future<DeliverySession?> findSession(int id) async {
    final db = await _db;
    final rows = await db.query('delivery_sessions',
        where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return DeliverySession.fromMap(rows.first);
  }

  /// Add a product to a session as "pris par le livreur".
  /// Decrements shop stock and increments qty_out.
  Future<void> addItemOut({
    required int sessionId,
    required int productId,
    required double qty,
    required double salePrice,
    required double purchasePrice,
  }) async {
    final db = await _db;
    await db.transaction((txn) async {
      // Stock check
      final stockRow = await txn.query('products',
          columns: ['stock_qty'],
          where: 'id = ?',
          whereArgs: [productId],
          limit: 1);
      if (stockRow.isEmpty) {
        throw Exception('Produit introuvable');
      }
      final currentStock = (stockRow.first['stock_qty'] as num).toDouble();
      if (currentStock < qty) {
        throw Exception('Stock insuffisant');
      }

      final existing = await txn.query('session_items',
          where: 'session_id = ? AND product_id = ?',
          whereArgs: [sessionId, productId],
          limit: 1);

      if (existing.isEmpty) {
        await txn.insert('session_items', {
          'session_id': sessionId,
          'product_id': productId,
          'qty_out': qty,
          'qty_returned': 0,
          'unit_sale_price': salePrice,
          'unit_purchase_price': purchasePrice,
        });
      } else {
        await txn.rawUpdate(
            'UPDATE session_items SET qty_out = qty_out + ? WHERE session_id = ? AND product_id = ?',
            [qty, sessionId, productId]);
      }

      await txn.rawUpdate(
          'UPDATE products SET stock_qty = stock_qty - ? WHERE id = ?',
          [qty, productId]);
    });
  }

  Future<void> setItemReturned({
    required int sessionId,
    required int productId,
    required double qtyReturned,
  }) async {
    final db = await _db;
    await db.update(
      'session_items',
      {'qty_returned': qtyReturned},
      where: 'session_id = ? AND product_id = ?',
      whereArgs: [sessionId, productId],
    );
  }

  Future<List<SessionItem>> sessionItems(int sessionId) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT si.*, p.name, p.barcode
      FROM session_items si
      JOIN products p ON p.id = si.product_id
      WHERE si.session_id = ?
      ORDER BY p.name
    ''', [sessionId]);
    return rows.map(SessionItem.fromMap).toList();
  }

  /// Closes the session: returns unsold qty back to shop stock,
  /// records a "sale" for sold qty (qty_out - qty_returned).
  Future<int> closeSession(int sessionId) async {
    final db = await _db;
    return db.transaction<int>((txn) async {
      final items = await txn.rawQuery('''
        SELECT si.*, p.name, p.barcode
        FROM session_items si
        JOIN products p ON p.id = si.product_id
        WHERE si.session_id = ?
      ''', [sessionId]);

      double total = 0;
      double profit = 0;

      // 1) Return unsold to shop stock
      for (final r in items) {
        final productId = r['product_id'] as int;
        final qtyOut = (r['qty_out'] as num).toDouble();
        final qtyReturned = (r['qty_returned'] as num).toDouble();
        final sold = qtyOut - qtyReturned;
        final salePrice = (r['unit_sale_price'] as num).toDouble();
        final purchasePrice = (r['unit_purchase_price'] as num).toDouble();

        if (qtyReturned > 0) {
          await txn.rawUpdate(
              'UPDATE products SET stock_qty = stock_qty + ? WHERE id = ?',
              [qtyReturned, productId]);
        }

        if (sold > 0) {
          total += sold * salePrice;
          profit += sold * (salePrice - purchasePrice);
        }
      }

      // 2) Create sale entry
      final saleId = await txn.insert('sales', {
        'date': DateTime.now().toIso8601String(),
        'total': total,
        'profit': profit,
        'source': 'DELIVERY',
        'session_id': sessionId,
      });

      for (final r in items) {
        final productId = r['product_id'] as int;
        final qtyOut = (r['qty_out'] as num).toDouble();
        final qtyReturned = (r['qty_returned'] as num).toDouble();
        final sold = qtyOut - qtyReturned;
        if (sold <= 0) continue;
        await txn.insert('sale_items', {
          'sale_id': saleId,
          'product_id': productId,
          'qty': sold,
          'unit_sale_price': r['unit_sale_price'],
          'unit_purchase_price': r['unit_purchase_price'],
        });
      }

      // 3) Mark session completed
      await txn.update(
        'delivery_sessions',
        {
          'status': 'COMPLETED',
          'end_date': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [sessionId],
      );

      return saleId;
    });
  }

  /// Per-deliveryman performance over a date range.
  Future<List<Map<String, dynamic>>> performance(
      {DateTime? from, DateTime? to}) async {
    final db = await _db;
    final args = <dynamic>[];
    var where = "ds.status = 'COMPLETED'";
    if (from != null) {
      where += ' AND ds.end_date >= ?';
      args.add(from.toIso8601String());
    }
    if (to != null) {
      where += ' AND ds.end_date <= ?';
      args.add(to.toIso8601String());
    }
    return db.rawQuery('''
      SELECT dm.id, dm.name,
        COUNT(DISTINCT ds.id) AS sessions,
        COALESCE(SUM((si.qty_out - si.qty_returned) * si.unit_sale_price), 0) AS total_sales,
        COALESCE(SUM((si.qty_out - si.qty_returned) * (si.unit_sale_price - si.unit_purchase_price)), 0) AS total_profit
      FROM delivery_men dm
      LEFT JOIN delivery_sessions ds ON ds.delivery_man_id = dm.id AND $where
      LEFT JOIN session_items si ON si.session_id = ds.id
      GROUP BY dm.id, dm.name
      ORDER BY total_sales DESC
    ''', args);
  }
}
