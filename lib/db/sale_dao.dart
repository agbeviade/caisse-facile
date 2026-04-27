import 'package:sqflite/sqflite.dart';
import '../models/sale.dart';
import 'database_helper.dart';

class CartItem {
  final int productId;
  final String name;
  final String barcode;
  double qty;
  final double salePrice;
  final double purchasePrice;

  CartItem({
    required this.productId,
    required this.name,
    required this.barcode,
    required this.qty,
    required this.salePrice,
    required this.purchasePrice,
  });

  double get total => qty * salePrice;
  double get profit => qty * (salePrice - purchasePrice);
}

class SaleDao {
  Future<Database> get _db async => DatabaseHelper.instance.database;

  Future<int> checkout(List<CartItem> items) async {
    if (items.isEmpty) {
      throw Exception('Panier vide');
    }
    final db = await _db;
    return db.transaction<int>((txn) async {
      // Stock check
      for (final it in items) {
        final row = await txn.query('products',
            columns: ['stock_qty'],
            where: 'id = ?',
            whereArgs: [it.productId],
            limit: 1);
        if (row.isEmpty) {
          throw Exception('Produit ${it.name} introuvable');
        }
        final stock = (row.first['stock_qty'] as num).toDouble();
        if (stock < it.qty) {
          throw Exception('Stock insuffisant pour ${it.name}');
        }
      }

      double total = 0;
      double profit = 0;
      for (final it in items) {
        total += it.total;
        profit += it.profit;
      }

      final saleId = await txn.insert('sales', {
        'date': DateTime.now().toIso8601String(),
        'total': total,
        'profit': profit,
        'source': 'COUNTER',
        'session_id': null,
      });

      for (final it in items) {
        await txn.insert('sale_items', {
          'sale_id': saleId,
          'product_id': it.productId,
          'qty': it.qty,
          'unit_sale_price': it.salePrice,
          'unit_purchase_price': it.purchasePrice,
        });
        await txn.rawUpdate(
            'UPDATE products SET stock_qty = stock_qty - ? WHERE id = ?',
            [it.qty, it.productId]);
      }

      return saleId;
    });
  }

  Future<Map<String, double>> totals(
      {required DateTime from, required DateTime to}) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT COALESCE(SUM(total),0) AS total,
             COALESCE(SUM(profit),0) AS profit,
             COUNT(*) AS n
      FROM sales WHERE date >= ? AND date <= ?
    ''', [from.toIso8601String(), to.toIso8601String()]);
    final r = rows.first;
    return {
      'total': (r['total'] as num).toDouble(),
      'profit': (r['profit'] as num).toDouble(),
      'count': (r['n'] as num).toDouble(),
    };
  }

  Future<List<Map<String, dynamic>>> dailyTotals({int days = 30}) async {
    final db = await _db;
    final from = DateTime.now().subtract(Duration(days: days));
    return db.rawQuery('''
      SELECT substr(date, 1, 10) AS day,
             SUM(total) AS total,
             SUM(profit) AS profit
      FROM sales
      WHERE date >= ?
      GROUP BY day
      ORDER BY day DESC
    ''', [from.toIso8601String()]);
  }

  Future<List<Sale>> recentSales({int limit = 50}) async {
    final db = await _db;
    final rows = await db.query('sales',
        orderBy: 'date DESC', limit: limit);
    return rows.map(Sale.fromMap).toList();
  }

  Future<List<Map<String, dynamic>>> saleItemsDetailed(int saleId) async {
    final db = await _db;
    return db.rawQuery('''
      SELECT si.*, p.name, p.barcode
      FROM sale_items si JOIN products p ON p.id = si.product_id
      WHERE si.sale_id = ?
    ''', [saleId]);
  }
}
