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

      await _pull('products', shopId, _productRemoteToLocal);
      await _pull('delivery_men', shopId, _manRemoteToLocal);
      await _pull('delivery_sessions', shopId, _sessionRemoteToLocal);
      await _pull('sales', shopId, _saleRemoteToLocal);

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
}
