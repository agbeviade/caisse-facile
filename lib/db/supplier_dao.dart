import 'package:sqflite/sqflite.dart';
import '../models/supplier.dart';
import 'database_helper.dart';

class SupplierDao {
  Future<Database> get _db async => DatabaseHelper.instance.database;

  Future<int> insert(Supplier s) async {
    final db = await _db;
    return db.insert('suppliers', s.toMap()..remove('id'));
  }

  Future<int> update(Supplier s) async {
    final db = await _db;
    return db.update('suppliers', s.toMap(),
        where: 'id = ?', whereArgs: [s.id]);
  }

  Future<int> delete(int id) async {
    final db = await _db;
    return db.delete('suppliers', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Supplier>> all({String? search}) async {
    final db = await _db;
    final rows = await db.query('suppliers',
        where: search == null || search.isEmpty
            ? 'deleted_at IS NULL'
            : 'deleted_at IS NULL AND (name LIKE ? OR phone LIKE ?)',
        whereArgs: search == null || search.isEmpty
            ? null
            : ['%$search%', '%$search%'],
        orderBy: 'name COLLATE NOCASE ASC');
    return rows.map(Supplier.fromMap).toList();
  }

  Future<Supplier?> findById(int id) async {
    final db = await _db;
    final r = await db
        .query('suppliers', where: 'id = ?', whereArgs: [id], limit: 1);
    return r.isEmpty ? null : Supplier.fromMap(r.first);
  }
}
