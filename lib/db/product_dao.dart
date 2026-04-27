import 'package:sqflite/sqflite.dart';
import '../models/product.dart';
import 'database_helper.dart';

class ProductDao {
  Future<Database> get _db async => DatabaseHelper.instance.database;

  Future<int> insert(Product p) async {
    final db = await _db;
    return db.insert('products', p.toMap()..remove('id'));
  }

  Future<int> update(Product p) async {
    final db = await _db;
    return db.update('products', p.toMap(), where: 'id = ?', whereArgs: [p.id]);
  }

  Future<int> delete(int id) async {
    final db = await _db;
    return db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Product>> all({String? search}) async {
    final db = await _db;
    final rows = await db.query(
      'products',
      where: search == null || search.isEmpty
          ? null
          : 'name LIKE ? OR barcode LIKE ?',
      whereArgs: search == null || search.isEmpty
          ? null
          : ['%$search%', '%$search%'],
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows.map(Product.fromMap).toList();
  }

  Future<Product?> findByBarcode(String barcode) async {
    final db = await _db;
    final rows = await db.query('products',
        where: 'barcode = ?', whereArgs: [barcode], limit: 1);
    if (rows.isEmpty) return null;
    return Product.fromMap(rows.first);
  }

  Future<Product?> findById(int id) async {
    final db = await _db;
    final rows =
        await db.query('products', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Product.fromMap(rows.first);
  }

  Future<void> adjustStock(int productId, double delta) async {
    final db = await _db;
    await db.rawUpdate(
        'UPDATE products SET stock_qty = stock_qty + ? WHERE id = ?',
        [delta, productId]);
  }

  Future<List<Product>> lowStock() async {
    final db = await _db;
    final rows = await db.rawQuery(
        'SELECT * FROM products WHERE alert_threshold > 0 AND stock_qty <= alert_threshold ORDER BY name');
    return rows.map(Product.fromMap).toList();
  }

  Future<List<Product>> expiringSoon({int days = 7}) async {
    final db = await _db;
    final now = DateTime.now();
    final limit = now.add(Duration(days: days));
    final rows = await db.query('products',
        where: 'expiry_date IS NOT NULL AND expiry_date <= ?',
        whereArgs: [limit.toIso8601String()],
        orderBy: 'expiry_date ASC');
    return rows.map(Product.fromMap).toList();
  }
}
