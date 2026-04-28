import 'package:sqflite/sqflite.dart';
import '../models/expense.dart';
import 'database_helper.dart';

class ExpenseDao {
  Future<Database> get _db async => DatabaseHelper.instance.database;

  Future<int> insert(Expense e) async {
    final db = await _db;
    return db.insert('expenses', e.toMap()..remove('id'));
  }

  Future<int> update(Expense e) async {
    final db = await _db;
    return db.update('expenses', e.toMap(), where: 'id = ?', whereArgs: [e.id]);
  }

  Future<int> delete(int id) async {
    final db = await _db;
    return db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Expense>> all({DateTime? from, DateTime? to}) async {
    final db = await _db;
    final wheres = <String>[];
    final args = <Object?>[];
    if (from != null) {
      wheres.add('date >= ?');
      args.add(from.toIso8601String());
    }
    if (to != null) {
      wheres.add('date < ?');
      args.add(to.toIso8601String());
    }
    final rows = await db.query('expenses',
        where: wheres.isEmpty ? null : wheres.join(' AND '),
        whereArgs: wheres.isEmpty ? null : args,
        orderBy: 'date DESC');
    return rows.map(Expense.fromMap).toList();
  }

  Future<double> totalBetween(DateTime from, DateTime to) async {
    final db = await _db;
    final r = await db.rawQuery(
        'SELECT COALESCE(SUM(amount), 0) AS t FROM expenses WHERE date >= ? AND date < ?',
        [from.toIso8601String(), to.toIso8601String()]);
    return (r.first['t'] as num).toDouble();
  }
}
