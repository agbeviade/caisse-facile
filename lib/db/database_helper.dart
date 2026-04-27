import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'caisse_facile.db');
    return openDatabase(
      path,
      version: 3,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        barcode TEXT UNIQUE NOT NULL,
        name TEXT NOT NULL,
        category TEXT,
        purchase_price REAL NOT NULL DEFAULT 0,
        sale_price REAL NOT NULL DEFAULT 0,
        stock_qty REAL NOT NULL DEFAULT 0,
        alert_threshold REAL NOT NULL DEFAULT 0,
        expiry_date TEXT,
        image_path TEXT,
        remote_id TEXT,
        updated_at TEXT NOT NULL DEFAULT (datetime('now')),
        dirty INTEGER NOT NULL DEFAULT 1,
        deleted_at TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE delivery_men (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT,
        remote_id TEXT,
        updated_at TEXT NOT NULL DEFAULT (datetime('now')),
        dirty INTEGER NOT NULL DEFAULT 1,
        deleted_at TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE delivery_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        delivery_man_id INTEGER NOT NULL,
        status TEXT NOT NULL,
        start_date TEXT NOT NULL,
        end_date TEXT,
        remote_id TEXT,
        updated_at TEXT NOT NULL DEFAULT (datetime('now')),
        dirty INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (delivery_man_id) REFERENCES delivery_men(id)
      );
    ''');

    await db.execute('''
      CREATE TABLE session_items (
        session_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        qty_out REAL NOT NULL DEFAULT 0,
        qty_returned REAL NOT NULL DEFAULT 0,
        unit_sale_price REAL NOT NULL DEFAULT 0,
        unit_purchase_price REAL NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL DEFAULT (datetime('now')),
        dirty INTEGER NOT NULL DEFAULT 1,
        PRIMARY KEY (session_id, product_id),
        FOREIGN KEY (session_id) REFERENCES delivery_sessions(id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES products(id)
      );
    ''');

    await db.execute('''
      CREATE TABLE sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        total REAL NOT NULL DEFAULT 0,
        profit REAL NOT NULL DEFAULT 0,
        source TEXT NOT NULL DEFAULT 'COUNTER',
        session_id INTEGER,
        remote_id TEXT,
        updated_at TEXT NOT NULL DEFAULT (datetime('now')),
        dirty INTEGER NOT NULL DEFAULT 1
      );
    ''');

    await db.execute('''
      CREATE TABLE sale_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        qty REAL NOT NULL,
        unit_sale_price REAL NOT NULL,
        unit_purchase_price REAL NOT NULL,
        FOREIGN KEY (sale_id) REFERENCES sales(id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES products(id)
      );
    ''');

    await db.execute('''
      CREATE TABLE sync_state (
        table_name TEXT PRIMARY KEY,
        last_pulled_at TEXT
      );
    ''');

    await db.execute('CREATE INDEX idx_sales_date ON sales(date);');
    await db.execute('CREATE INDEX idx_sessions_status ON delivery_sessions(status);');
    await db.execute('CREATE INDEX idx_products_dirty ON products(dirty);');
    await db.execute('CREATE INDEX idx_delivery_men_dirty ON delivery_men(dirty);');
    await db.execute('CREATE INDEX idx_sessions_dirty ON delivery_sessions(dirty);');
    await db.execute('CREATE INDEX idx_sales_dirty ON sales(dirty);');

    await _createDirtyTriggers(db);
  }

  Future<void> _createDirtyTriggers(Database db) async {
    // On UPDATE: bump updated_at and mark dirty (unless already updated by sync code).
    // We skip trigger when the update is itself setting dirty=0 (sync clearing).
    for (final t in [
      'products',
      'delivery_men',
      'delivery_sessions',
      'session_items',
      'sales'
    ]) {
      await db.execute('''
        CREATE TRIGGER IF NOT EXISTS trg_${t}_dirty
        AFTER UPDATE ON $t
        FOR EACH ROW
        WHEN NEW.dirty = OLD.dirty
        BEGIN
          UPDATE $t SET dirty = 1, updated_at = datetime('now')
          WHERE ${t == 'session_items' ? 'session_id = NEW.session_id AND product_id = NEW.product_id' : 'rowid = NEW.rowid'};
        END;
      ''');
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add sync columns to existing tables
      const syncCols = [
        ['products', 'deleted_at TEXT'],
        ['delivery_men', 'deleted_at TEXT'],
      ];
      for (final t in [
        'products',
        'delivery_men',
        'delivery_sessions',
        'sales'
      ]) {
        await db.execute("ALTER TABLE $t ADD COLUMN remote_id TEXT");
        await db.execute(
            "ALTER TABLE $t ADD COLUMN updated_at TEXT NOT NULL DEFAULT (datetime('now'))");
        await db.execute(
            "ALTER TABLE $t ADD COLUMN dirty INTEGER NOT NULL DEFAULT 1");
      }
      for (final t in ['session_items']) {
        await db.execute(
            "ALTER TABLE $t ADD COLUMN updated_at TEXT NOT NULL DEFAULT (datetime('now'))");
        await db.execute(
            "ALTER TABLE $t ADD COLUMN dirty INTEGER NOT NULL DEFAULT 1");
      }
      for (final c in syncCols) {
        await db.execute("ALTER TABLE ${c[0]} ADD COLUMN ${c[1]}");
      }
      await db.execute('''
        CREATE TABLE IF NOT EXISTS sync_state (
          table_name TEXT PRIMARY KEY,
          last_pulled_at TEXT
        );
      ''');
      await _createDirtyTriggers(db);
    }
    if (oldVersion < 3) {
      await db.execute("ALTER TABLE products ADD COLUMN image_path TEXT");
    }
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
