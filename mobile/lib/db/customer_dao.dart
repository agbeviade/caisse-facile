import 'package:sqflite/sqflite.dart';
import '../models/customer.dart';
import 'database_helper.dart';

class CustomerDao {
  Future<Database> get _db async => DatabaseHelper.instance.database;

  Future<int> insert(Customer c) async {
    final db = await _db;
    return db.insert('customers', c.toMap()..remove('id'));
  }

  Future<int> update(Customer c) async {
    final db = await _db;
    return db.update('customers', c.toMap(), where: 'id = ?', whereArgs: [c.id]);
  }

  Future<int> delete(int id) async {
    final db = await _db;
    return db.delete('customers', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Customer>> all({String? search}) async {
    final db = await _db;
    final rows = await db.query('customers',
        where: search == null || search.isEmpty
            ? 'deleted_at IS NULL'
            : 'deleted_at IS NULL AND (name LIKE ? OR phone LIKE ?)',
        whereArgs: search == null || search.isEmpty
            ? null
            : ['%$search%', '%$search%'],
        orderBy: 'name COLLATE NOCASE ASC');
    return rows.map(Customer.fromMap).toList();
  }

  Future<Customer?> findById(int id) async {
    final db = await _db;
    final r = await db
        .query('customers', where: 'id = ?', whereArgs: [id], limit: 1);
    return r.isEmpty ? null : Customer.fromMap(r.first);
  }

  /// Insert a credit ledger entry and update customer balance.
  Future<int> addLedger(CustomerCredit entry) async {
    final db = await _db;
    return db.transaction((tx) async {
      final id =
          await tx.insert('customer_credits', entry.toMap()..remove('id'));
      await tx.rawUpdate(
          'UPDATE customers SET balance = balance + ? WHERE id = ?',
          [entry.balanceDelta, entry.customerId]);
      return id;
    });
  }

  Future<List<CustomerCredit>> ledger(int customerId) async {
    final db = await _db;
    final rows = await db.query('customer_credits',
        where: 'customer_id = ?',
        whereArgs: [customerId],
        orderBy: 'date DESC');
    return rows.map(CustomerCredit.fromMap).toList();
  }

  /// Total outstanding debt across all customers.
  Future<double> totalDebt() async {
    final db = await _db;
    final r = await db.rawQuery(
        'SELECT COALESCE(SUM(balance),0) AS t FROM customers WHERE deleted_at IS NULL');
    return (r.first['t'] as num).toDouble();
  }
}
