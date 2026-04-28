import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../db/database_helper.dart';
import 'auth_service.dart';

/// Bidirectional sync between local SQLite and Supabase.
///
/// Strategy:
/// - PUSH: rows where dirty=1 → upsert to Supabase (server generates uuid for
///   new rows; we store it in `remote_id`). Then mark dirty=0.
/// - PULL: fetch rows updated_at > last_pulled_at → upsert into local
///   (matching by remote_id), without re-marking them dirty.
///
/// Conflict resolution: last-writer-wins (server `updated_at`).
class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  SupabaseClient get _sb => Supabase.instance.client;
  Future<Database> get _db => DatabaseHelper.instance.database;

  bool _running = false;
  bool get isRunning => _running;

  Future<bool> get _online async {
    final r = await Connectivity().checkConnectivity();
    return !r.contains(ConnectivityResult.none);
  }

  /// Run a full sync. Returns a short status string.
  Future<String> syncNow() async {
    if (_running) return 'Sync déjà en cours';
    final shopId = AuthService.instance.shopId;
    if (shopId == null) {
      throw Exception('Aucune épicerie sélectionnée');
    }
    if (!await _online) {
      throw Exception('Hors ligne');
    }
    _running = true;
    try {
      // Order matters: parents before children (FK on remote)
      await _push('products', shopId, _productLocalToRemote);
      await _push('delivery_men', shopId, _manLocalToRemote);
      await _push('delivery_sessions', shopId, _sessionLocalToRemote,
          enrich: _enrichSession);
      await _push('sales', shopId, _saleLocalToRemote, enrich: _enrichSale);
      // New modules (v2)
      await _push('customers', shopId, _customerLocalToRemote);
      await _push('suppliers', shopId, _supplierLocalToRemote);
      await _push('expenses', shopId, _expenseLocalToRemote,
          enrich: _enrichExpense);
      await _push('stock_movements', shopId, _movementLocalToRemote,
          enrich: _enrichMovement);
      await _push('customer_credits', shopId, _creditLocalToRemote,
          enrich: _enrichCredit);

      await _pull('products', shopId, _productRemoteToLocal);
      await _pull('delivery_men', shopId, _manRemoteToLocal);
      await _pull('delivery_sessions', shopId, _sessionRemoteToLocal);
      await _pull('sales', shopId, _saleRemoteToLocal);
      await _pull('customers', shopId, _customerRemoteToLocal);
      await _pull('suppliers', shopId, _supplierRemoteToLocal);
      await _pull('expenses', shopId, _expenseRemoteToLocal);
      await _pull('stock_movements', shopId, _movementRemoteToLocal);
      await _pull('customer_credits', shopId, _creditRemoteToLocal);

      return 'Synchronisé';
    } finally {
      _running = false;
    }
  }

  // ---------------- PUSH ----------------

  Future<void> _push(
    String table,
    String shopId,
    Map<String, dynamic> Function(Map<String, dynamic> row, String shopId)
        toRemote, {
    Future<Map<String, dynamic>?> Function(Database db, Map<String, dynamic> row)?
        enrich,
  }) async {
    final db = await _db;
    final rows = await db.query(table, where: 'dirty = 1');
    if (rows.isEmpty) return;

    for (final row in rows) {
      Map<String, dynamic> mutable = Map.of(row);
      if (enrich != null) {
        final enriched = await enrich(db, mutable);
        if (enriched == null) {
          // Parent not yet synced: skip; will retry next sync.
          continue;
        }
        mutable = enriched;
      }
      final remote = toRemote(mutable, shopId);
      final hasRemoteId = (row['remote_id'] as String?)?.isNotEmpty ?? false;

      Map<String, dynamic> result;
      if (hasRemoteId) {
        // Update by remote id
        result = (await _sb
                .from(table)
                .update(remote)
                .eq('id', row['remote_id'] as String)
                .select()
                .single()) as Map<String, dynamic>;
      } else {
        result = (await _sb.from(table).insert(remote).select().single())
            as Map<String, dynamic>;
      }

      await db.rawUpdate(
        'UPDATE $table SET remote_id = ?, dirty = 0 WHERE id = ?',
        [result['id'], row['id']],
      );
    }
  }

  // ---------------- PULL ----------------

  Future<void> _pull(
    String table,
    String shopId,
    Future<void> Function(Database db, Map<String, dynamic> remote) apply,
  ) async {
    final db = await _db;
    final st = await db.query('sync_state',
        where: 'table_name = ?', whereArgs: [table], limit: 1);
    final since = st.isEmpty
        ? '1970-01-01T00:00:00Z'
        : (st.first['last_pulled_at'] as String? ??
            '1970-01-01T00:00:00Z');

    final remoteRows = await _sb
        .from(table)
        .select()
        .eq('shop_id', shopId)
        .gt('updated_at', since)
        .order('updated_at');

    final list = List<Map<String, dynamic>>.from(remoteRows);
    if (list.isEmpty) return;

    String maxUpdated = since;
    for (final r in list) {
      await apply(db, r);
      final u = r['updated_at'] as String;
      if (u.compareTo(maxUpdated) > 0) maxUpdated = u;
    }

    await db.insert(
      'sync_state',
      {'table_name': table, 'last_pulled_at': maxUpdated},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ---------------- MAPPERS ----------------

  Map<String, dynamic> _productLocalToRemote(
      Map<String, dynamic> r, String shopId) {
    return {
      if ((r['remote_id'] as String?) != null) 'id': r['remote_id'],
      'shop_id': shopId,
      'barcode': r['barcode'],
      'name': r['name'],
      'category': r['category'],
      'purchase_price': r['purchase_price'],
      'sale_price': r['sale_price'],
      'stock_qty': r['stock_qty'],
      'alert_threshold': r['alert_threshold'],
      'expiry_date': r['expiry_date'],
      'deleted_at': r['deleted_at'],
    };
  }

  Future<void> _productRemoteToLocal(
      Database db, Map<String, dynamic> r) async {
    final existing = await db.query('products',
        where: 'remote_id = ?', whereArgs: [r['id']], limit: 1);
    final values = {
      'barcode': r['barcode'],
      'name': r['name'],
      'category': r['category'],
      'purchase_price': r['purchase_price'],
      'sale_price': r['sale_price'],
      'stock_qty': r['stock_qty'],
      'alert_threshold': r['alert_threshold'],
      'expiry_date': r['expiry_date'],
      'deleted_at': r['deleted_at'],
      'remote_id': r['id'],
      'updated_at': r['updated_at'],
      'dirty': 0,
    };
    if (existing.isEmpty) {
      // Avoid duplicate by barcode if local row was created offline
      final byCode = await db.query('products',
          where: 'barcode = ? AND remote_id IS NULL',
          whereArgs: [r['barcode']],
          limit: 1);
      if (byCode.isNotEmpty) {
        await db.update('products', values,
            where: 'id = ?', whereArgs: [byCode.first['id']]);
      } else {
        await db.insert('products', values);
      }
    } else {
      await db.update('products', values,
          where: 'id = ?', whereArgs: [existing.first['id']]);
    }
  }

  Map<String, dynamic> _manLocalToRemote(
      Map<String, dynamic> r, String shopId) {
    return {
      if ((r['remote_id'] as String?) != null) 'id': r['remote_id'],
      'shop_id': shopId,
      'name': r['name'],
      'phone': r['phone'],
      'deleted_at': r['deleted_at'],
    };
  }

  Future<void> _manRemoteToLocal(
      Database db, Map<String, dynamic> r) async {
    final existing = await db.query('delivery_men',
        where: 'remote_id = ?', whereArgs: [r['id']], limit: 1);
    final values = {
      'name': r['name'],
      'phone': r['phone'],
      'deleted_at': r['deleted_at'],
      'remote_id': r['id'],
      'updated_at': r['updated_at'],
      'dirty': 0,
    };
    if (existing.isEmpty) {
      await db.insert('delivery_men', values);
    } else {
      await db.update('delivery_men', values,
          where: 'id = ?', whereArgs: [existing.first['id']]);
    }
  }

  Future<Map<String, dynamic>?> _enrichSession(
      Database db, Map<String, dynamic> row) async {
    final man = await db.query('delivery_men',
        columns: ['remote_id'],
        where: 'id = ?',
        whereArgs: [row['delivery_man_id']],
        limit: 1);
    if (man.isEmpty) return null;
    final remoteId = man.first['remote_id'] as String?;
    if (remoteId == null) return null;
    return {...row, '_remote_delivery_man_id': remoteId};
  }

  Future<Map<String, dynamic>?> _enrichSale(
      Database db, Map<String, dynamic> row) async {
    String? sessionRemote;
    if (row['session_id'] != null) {
      final s = await db.query('delivery_sessions',
          columns: ['remote_id'],
          where: 'id = ?',
          whereArgs: [row['session_id']],
          limit: 1);
      if (s.isEmpty || (s.first['remote_id'] as String?) == null) {
        return null;
      }
      sessionRemote = s.first['remote_id'] as String?;
    }
    return {...row, '_remote_session_id': sessionRemote};
  }

  Map<String, dynamic> _sessionLocalToRemote(
      Map<String, dynamic> r, String shopId) {
    // We need delivery_man's remote_id
    return {
      if ((r['remote_id'] as String?) != null) 'id': r['remote_id'],
      'shop_id': shopId,
      // resolved at push time (see below)
      'delivery_man_id': r['_remote_delivery_man_id'],
      'status': r['status'],
      'start_date': r['start_date'],
      'end_date': r['end_date'],
    };
  }

  // Same for sales — we'll resolve session remote_id if needed.
  Map<String, dynamic> _saleLocalToRemote(
      Map<String, dynamic> r, String shopId) {
    return {
      if ((r['remote_id'] as String?) != null) 'id': r['remote_id'],
      'shop_id': shopId,
      'date': r['date'],
      'total': r['total'],
      'profit': r['profit'],
      'source': r['source'],
      'session_id': r['_remote_session_id'],
    };
  }

  Future<void> _sessionRemoteToLocal(
      Database db, Map<String, dynamic> r) async {
    final man = await db.query('delivery_men',
        columns: ['id'],
        where: 'remote_id = ?',
        whereArgs: [r['delivery_man_id']],
        limit: 1);
    if (man.isEmpty) return; // parent not yet synced; will retry next time
    final existing = await db.query('delivery_sessions',
        where: 'remote_id = ?', whereArgs: [r['id']], limit: 1);
    final values = {
      'delivery_man_id': man.first['id'],
      'status': r['status'],
      'start_date': r['start_date'],
      'end_date': r['end_date'],
      'remote_id': r['id'],
      'updated_at': r['updated_at'],
      'dirty': 0,
    };
    if (existing.isEmpty) {
      await db.insert('delivery_sessions', values);
    } else {
      await db.update('delivery_sessions', values,
          where: 'id = ?', whereArgs: [existing.first['id']]);
    }
  }

  Future<void> _saleRemoteToLocal(
      Database db, Map<String, dynamic> r) async {
    final existing = await db.query('sales',
        where: 'remote_id = ?', whereArgs: [r['id']], limit: 1);
    final values = {
      'date': r['date'],
      'total': r['total'],
      'profit': r['profit'],
      'source': r['source'],
      'session_id': null,
      'remote_id': r['id'],
      'updated_at': r['updated_at'],
      'dirty': 0,
    };
    if (existing.isEmpty) {
      await db.insert('sales', values);
    } else {
      await db.update('sales', values,
          where: 'id = ?', whereArgs: [existing.first['id']]);
    }
  }

  // ============ V2 MAPPERS: customers / suppliers / expenses /
  //               stock_movements / customer_credits ============

  // ---- customers ----
  Map<String, dynamic> _customerLocalToRemote(
      Map<String, dynamic> r, String shopId) {
    return {
      if ((r['remote_id'] as String?) != null) 'id': r['remote_id'],
      'shop_id': shopId,
      'name': r['name'],
      'phone': r['phone'],
      'note': r['note'],
      'balance': r['balance'],
      'deleted_at': r['deleted_at'],
    };
  }

  Future<void> _customerRemoteToLocal(
      Database db, Map<String, dynamic> r) async {
    final existing = await db.query('customers',
        where: 'remote_id = ?', whereArgs: [r['id']], limit: 1);
    final values = {
      'name': r['name'],
      'phone': r['phone'],
      'note': r['note'],
      'balance': r['balance'],
      'deleted_at': r['deleted_at'],
      'remote_id': r['id'],
      'updated_at': r['updated_at'],
      'dirty': 0,
    };
    if (existing.isEmpty) {
      await db.insert('customers', values);
    } else {
      await db.update('customers', values,
          where: 'id = ?', whereArgs: [existing.first['id']]);
    }
  }

  // ---- suppliers ----
  Map<String, dynamic> _supplierLocalToRemote(
      Map<String, dynamic> r, String shopId) {
    return {
      if ((r['remote_id'] as String?) != null) 'id': r['remote_id'],
      'shop_id': shopId,
      'name': r['name'],
      'phone': r['phone'],
      'note': r['note'],
      'deleted_at': r['deleted_at'],
    };
  }

  Future<void> _supplierRemoteToLocal(
      Database db, Map<String, dynamic> r) async {
    final existing = await db.query('suppliers',
        where: 'remote_id = ?', whereArgs: [r['id']], limit: 1);
    final values = {
      'name': r['name'],
      'phone': r['phone'],
      'note': r['note'],
      'deleted_at': r['deleted_at'],
      'remote_id': r['id'],
      'updated_at': r['updated_at'],
      'dirty': 0,
    };
    if (existing.isEmpty) {
      await db.insert('suppliers', values);
    } else {
      await db.update('suppliers', values,
          where: 'id = ?', whereArgs: [existing.first['id']]);
    }
  }

  // ---- expenses (FK: supplier_id) ----
  Future<Map<String, dynamic>?> _enrichExpense(
      Database db, Map<String, dynamic> row) async {
    String? supplierRemote;
    if (row['supplier_id'] != null) {
      final s = await db.query('suppliers',
          columns: ['remote_id'],
          where: 'id = ?',
          whereArgs: [row['supplier_id']],
          limit: 1);
      // If supplier exists locally but isn't synced yet, defer this expense.
      if (s.isNotEmpty && (s.first['remote_id'] as String?) == null) {
        return null;
      }
      supplierRemote = s.isEmpty ? null : s.first['remote_id'] as String?;
    }
    return {...row, '_remote_supplier_id': supplierRemote};
  }

  Map<String, dynamic> _expenseLocalToRemote(
      Map<String, dynamic> r, String shopId) {
    return {
      if ((r['remote_id'] as String?) != null) 'id': r['remote_id'],
      'shop_id': shopId,
      'date': r['date'],
      'amount': r['amount'],
      'category': r['category'],
      'supplier_id': r['_remote_supplier_id'],
      'note': r['note'],
    };
  }

  Future<void> _expenseRemoteToLocal(
      Database db, Map<String, dynamic> r) async {
    int? localSupplierId;
    if (r['supplier_id'] != null) {
      final s = await db.query('suppliers',
          columns: ['id'],
          where: 'remote_id = ?',
          whereArgs: [r['supplier_id']],
          limit: 1);
      if (s.isNotEmpty) localSupplierId = s.first['id'] as int?;
    }
    final existing = await db.query('expenses',
        where: 'remote_id = ?', whereArgs: [r['id']], limit: 1);
    final values = {
      'date': r['date'],
      'amount': r['amount'],
      'category': r['category'],
      'supplier_id': localSupplierId,
      'note': r['note'],
      'remote_id': r['id'],
      'updated_at': r['updated_at'],
      'dirty': 0,
    };
    if (existing.isEmpty) {
      await db.insert('expenses', values);
    } else {
      await db.update('expenses', values,
          where: 'id = ?', whereArgs: [existing.first['id']]);
    }
  }

  // ---- stock_movements (FK: product_id) ----
  Future<Map<String, dynamic>?> _enrichMovement(
      Database db, Map<String, dynamic> row) async {
    final p = await db.query('products',
        columns: ['remote_id'],
        where: 'id = ?',
        whereArgs: [row['product_id']],
        limit: 1);
    if (p.isEmpty) return null;
    final remoteId = p.first['remote_id'] as String?;
    if (remoteId == null) return null; // wait for product to be pushed first
    return {...row, '_remote_product_id': remoteId};
  }

  Map<String, dynamic> _movementLocalToRemote(
      Map<String, dynamic> r, String shopId) {
    return {
      if ((r['remote_id'] as String?) != null) 'id': r['remote_id'],
      'shop_id': shopId,
      'product_id': r['_remote_product_id'],
      'qty': r['qty'],
      'kind': r['kind'],
      'source_type': r['source_type'],
      // source_id is local-only; skipped on push (would not match remote uuids)
      'note': r['note'],
      'date': r['date'],
    };
  }

  Future<void> _movementRemoteToLocal(
      Database db, Map<String, dynamic> r) async {
    final p = await db.query('products',
        columns: ['id'],
        where: 'remote_id = ?',
        whereArgs: [r['product_id']],
        limit: 1);
    if (p.isEmpty) return; // product not synced locally yet; will retry
    final existing = await db.query('stock_movements',
        where: 'remote_id = ?', whereArgs: [r['id']], limit: 1);
    final values = {
      'product_id': p.first['id'],
      'qty': r['qty'],
      'kind': r['kind'],
      'source_type': r['source_type'],
      'source_id': null,
      'note': r['note'],
      'date': r['date'],
      'remote_id': r['id'],
      'updated_at': r['updated_at'],
      'dirty': 0,
    };
    if (existing.isEmpty) {
      await db.insert('stock_movements', values);
    } else {
      await db.update('stock_movements', values,
          where: 'id = ?', whereArgs: [existing.first['id']]);
    }
  }

  // ---- customer_credits (FK: customer_id, optional sale_id) ----
  Future<Map<String, dynamic>?> _enrichCredit(
      Database db, Map<String, dynamic> row) async {
    final c = await db.query('customers',
        columns: ['remote_id'],
        where: 'id = ?',
        whereArgs: [row['customer_id']],
        limit: 1);
    if (c.isEmpty) return null;
    final customerRemote = c.first['remote_id'] as String?;
    if (customerRemote == null) return null;
    String? saleRemote;
    if (row['sale_id'] != null) {
      final s = await db.query('sales',
          columns: ['remote_id'],
          where: 'id = ?',
          whereArgs: [row['sale_id']],
          limit: 1);
      if (s.isNotEmpty && (s.first['remote_id'] as String?) == null) {
        return null; // wait for the sale to be synced first
      }
      saleRemote = s.isEmpty ? null : s.first['remote_id'] as String?;
    }
    return {
      ...row,
      '_remote_customer_id': customerRemote,
      '_remote_sale_id': saleRemote,
    };
  }

  Map<String, dynamic> _creditLocalToRemote(
      Map<String, dynamic> r, String shopId) {
    return {
      if ((r['remote_id'] as String?) != null) 'id': r['remote_id'],
      'shop_id': shopId,
      'customer_id': r['_remote_customer_id'],
      'sale_id': r['_remote_sale_id'],
      'amount': r['amount'],
      'kind': r['kind'],
      'note': r['note'],
      'date': r['date'],
    };
  }

  Future<void> _creditRemoteToLocal(
      Database db, Map<String, dynamic> r) async {
    final c = await db.query('customers',
        columns: ['id'],
        where: 'remote_id = ?',
        whereArgs: [r['customer_id']],
        limit: 1);
    if (c.isEmpty) return; // customer not synced locally yet
    int? localSaleId;
    if (r['sale_id'] != null) {
      final s = await db.query('sales',
          columns: ['id'],
          where: 'remote_id = ?',
          whereArgs: [r['sale_id']],
          limit: 1);
      if (s.isNotEmpty) localSaleId = s.first['id'] as int?;
    }
    final existing = await db.query('customer_credits',
        where: 'remote_id = ?', whereArgs: [r['id']], limit: 1);
    final values = {
      'customer_id': c.first['id'],
      'sale_id': localSaleId,
      'amount': r['amount'],
      'kind': r['kind'],
      'note': r['note'],
      'date': r['date'],
      'remote_id': r['id'],
      'updated_at': r['updated_at'],
      'dirty': 0,
    };
    if (existing.isEmpty) {
      await db.insert('customer_credits', values);
    } else {
      await db.update('customer_credits', values,
          where: 'id = ?', whereArgs: [existing.first['id']]);
    }
  }
}
