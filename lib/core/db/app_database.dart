import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'seeds.dart';

/// Satu-satunya titik akses database PilahIn (file `pilahin.db`).
///
/// Semua repository (auth, history, gamifikasi, dll.) WAJIB mengambil
/// koneksi dari class ini agar skema & versi dikelola di satu tempat.
/// Jangan panggil `openDatabase` langsung di repository lain.
class AppDatabase {
  /// Buat instance dengan [path] kustom (dipakai unit test, mis. ':memory:').
  /// Tanpa argumen, memakai direktori dokumen aplikasi (perilaku default).
  AppDatabase({String? path}) : _customPath = path;

  final String? _customPath;
  Database? _db;

  static const int version = 3;
  static const String fileName = 'pilahin.db';

  Future<Database> get database async {
    final existing = _db;
    if (existing != null) return existing;

    final String path;
    if (_customPath != null) {
      path = _customPath;
    } else {
      final dir = await getApplicationDocumentsDirectory();
      path = '${dir.path}/$fileName';
    }

    final db = await openDatabase(
      path,
      version: version,
      onCreate: (db, _) async {
        // Install baru: buat seluruh skema v3, lalu seed.
        await db.transaction((txn) async {
          await _createAllTables(txn);
          await _createIndexes(txn);
          await insertSeedData(txn);
        });
      },
      onUpgrade: (db, oldVersion, _) async {
        if (oldVersion < 2) {
          // v1 -> v2 (migrasi lama, dipertahankan untuk install era v1).
          await db.execute('ALTER TABLE scan_history ADD COLUMN waste_type TEXT');
        }
        if (oldVersion < 3) {
          await _upgradeToV3(db);
        }
      },
    );

    // Wajib per koneksi: sqflite tidak mengaktifkan FK secara default.
    await db.execute('PRAGMA foreign_keys = ON');
    _db = db;
    return db;
  }

  /// Tutup koneksi (berguna untuk unit test).
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  static String _ifNotExists(String ddl) =>
      ddl.replaceFirst('CREATE TABLE ', 'CREATE TABLE IF NOT EXISTS ');

  // ---------------------------------------------------------------------------
  // DDL
  // ---------------------------------------------------------------------------

  static const String _ddlUsers = '''
    CREATE TABLE users (
      id               TEXT PRIMARY KEY,
      email            TEXT UNIQUE,
      password_hash    TEXT,
      display_name     TEXT NOT NULL,
      is_guest         INTEGER NOT NULL DEFAULT 0,
      total_points     INTEGER NOT NULL DEFAULT 0,
      current_streak   INTEGER NOT NULL DEFAULT 0,
      best_streak      INTEGER NOT NULL DEFAULT 0,
      last_active_date TEXT,
      created_at       INTEGER NOT NULL,
      updated_at       INTEGER NOT NULL
    )
  ''';

  static const String _ddlWasteTypes = '''
    CREATE TABLE waste_types (
      id            INTEGER PRIMARY KEY AUTOINCREMENT,
      label_key     TEXT NOT NULL UNIQUE,
      display_name  TEXT NOT NULL,
      category      TEXT NOT NULL CHECK (category IN ('organik','anorganik')),
      is_hazardous  INTEGER NOT NULL DEFAULT 0,
      icon_key      TEXT,
      is_active     INTEGER NOT NULL DEFAULT 1
    )
  ''';

  static const String _ddlEcoImpact = '''
    CREATE TABLE eco_impact (
      waste_type_id             INTEGER PRIMARY KEY REFERENCES waste_types(id) ON DELETE CASCADE,
      co2_saved_kg              REAL NOT NULL,
      primary_metric_label      TEXT,
      primary_metric_value      TEXT,
      primary_metric_icon       TEXT,
      decomposition_time        TEXT,
      environmental_equivalence TEXT,
      action_tip                TEXT,
      highlight_fact            TEXT
    )
  ''';

  static const String _ddlLevels = '''
    CREATE TABLE levels (
      level      INTEGER PRIMARY KEY,
      name       TEXT NOT NULL,
      min_points INTEGER NOT NULL,
      icon_key   TEXT
    )
  ''';

  static const String _ddlBadges = '''
    CREATE TABLE badges (
      id             INTEGER PRIMARY KEY AUTOINCREMENT,
      code           TEXT NOT NULL UNIQUE,
      name           TEXT NOT NULL,
      description    TEXT NOT NULL,
      category       TEXT NOT NULL CHECK (category IN ('organik','anorganik','streak','umum')),
      icon_key       TEXT NOT NULL,
      target         INTEGER NOT NULL,
      unit           TEXT NOT NULL,
      reward_points  INTEGER NOT NULL DEFAULT 0,
      metric         TEXT NOT NULL DEFAULT 'total'
                     CHECK (metric IN ('total','kategori_organik','kategori_anorganik','jenis','streak')),
      waste_type_ids TEXT,
      is_active      INTEGER NOT NULL DEFAULT 1
    )
  ''';

  static const String _ddlMissions = '''
    CREATE TABLE missions (
      id            INTEGER PRIMARY KEY AUTOINCREMENT,
      code          TEXT NOT NULL UNIQUE,
      title         TEXT NOT NULL,
      unit          TEXT NOT NULL,
      target        INTEGER NOT NULL,
      reward_points INTEGER NOT NULL DEFAULT 0,
      period        TEXT NOT NULL CHECK (period IN ('harian','mingguan')),
      metric        TEXT NOT NULL CHECK (metric IN ('total','kategori_organik','kategori_anorganik','jenis')),
      waste_type_id INTEGER REFERENCES waste_types(id),
      is_active     INTEGER NOT NULL DEFAULT 1
    )
  ''';

  /// Skema `scan_history` versi 3: skema v2 + `user_id` + `waste_type_id`.
  /// Kolom `waste_type` (TEXT) dipertahankan agar skema identik di
  /// install-fresh maupun install yang di-migrasi.
  static const String _ddlScanHistory = '''
    CREATE TABLE scan_history (
      id            INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id       TEXT NOT NULL DEFAULT 'guest_id' REFERENCES users(id),
      scan_key      TEXT NOT NULL UNIQUE,
      waste_type    TEXT,
      waste_type_id INTEGER REFERENCES waste_types(id),
      category      TEXT NOT NULL,
      confidence    REAL NOT NULL,
      is_uncertain  INTEGER NOT NULL,
      item_name     TEXT,
      points_earned INTEGER NOT NULL,
      image_path    TEXT,
      created_at    INTEGER NOT NULL
    )
  ''';

  static const String _ddlUserBadges = '''
    CREATE TABLE user_badges (
      user_id     TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      badge_id    INTEGER NOT NULL REFERENCES badges(id) ON DELETE CASCADE,
      progress    INTEGER NOT NULL DEFAULT 0,
      unlocked_at INTEGER,
      PRIMARY KEY (user_id, badge_id)
    )
  ''';

  static const String _ddlUserMissions = '''
    CREATE TABLE user_missions (
      id           INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id      TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      mission_id   INTEGER NOT NULL REFERENCES missions(id) ON DELETE CASCADE,
      period_start TEXT NOT NULL,
      progress     INTEGER NOT NULL DEFAULT 0,
      status       TEXT NOT NULL DEFAULT 'berjalan' CHECK (status IN ('berjalan','selesai','diklaim')),
      claimed_at   INTEGER,
      UNIQUE (user_id, mission_id, period_start)
    )
  ''';

  static const String _ddlPointTransactions = '''
    CREATE TABLE point_transactions (
      id         INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id    TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      delta      INTEGER NOT NULL,
      reason     TEXT NOT NULL CHECK (reason IN ('scan','misi','lencana','penyesuaian')),
      ref_type   TEXT,
      ref_id     INTEGER,
      created_at INTEGER NOT NULL
    )
  ''';

  Future<void> _createAllTables(DatabaseExecutor db) async {
    await db.execute(_ddlUsers);
    await db.execute(_ddlWasteTypes);
    await db.execute(_ddlEcoImpact);
    await db.execute(_ddlLevels);
    await db.execute(_ddlBadges);
    await db.execute(_ddlMissions);
    await db.execute(_ddlScanHistory);
    await db.execute(_ddlUserBadges);
    await db.execute(_ddlUserMissions);
    await db.execute(_ddlPointTransactions);
  }

  Future<void> _createIndexes(DatabaseExecutor db) async {
    await db.execute('CREATE INDEX idx_scan_user_created ON scan_history(user_id, created_at)');
    await db.execute('CREATE INDEX idx_scan_type ON scan_history(waste_type_id)');
    await db.execute('CREATE INDEX idx_scan_created ON scan_history(created_at)');
    await db.execute('CREATE INDEX idx_points_user ON point_transactions(user_id, created_at)');
  }

  /// Migrasi v2 -> v3: tabel baru + seed + ekstensi `scan_history` + backfill.
  /// Urutan penting: seed `waste_types` dulu agar backfill `waste_type_id`
  /// menemukan id-nya.
  Future<void> _upgradeToV3(Database db) async {
    await db.transaction((txn) async {
      // Tabel baru (reuse DDL dari onCreate, dengan IF NOT EXISTS).
      await txn.execute(_ifNotExists(_ddlUsers));
      await txn.execute(_ifNotExists(_ddlWasteTypes));
      await txn.execute(_ifNotExists(_ddlEcoImpact));
      await txn.execute(_ifNotExists(_ddlLevels));
      await txn.execute(_ifNotExists(_ddlBadges));
      await txn.execute(_ifNotExists(_ddlMissions));
      await txn.execute(_ifNotExists(_ddlUserBadges));
      await txn.execute(_ifNotExists(_ddlUserMissions));
      await txn.execute(_ifNotExists(_ddlPointTransactions));

      // Ekstensi scan_history (kolom lama dipertahankan).
      await txn.execute("ALTER TABLE scan_history ADD COLUMN user_id TEXT NOT NULL DEFAULT 'guest_id'");
      await txn.execute('ALTER TABLE scan_history ADD COLUMN waste_type_id INTEGER');
      await txn.execute('CREATE INDEX IF NOT EXISTS idx_scan_user_created ON scan_history(user_id, created_at)');
      await txn.execute('CREATE INDEX IF NOT EXISTS idx_scan_type ON scan_history(waste_type_id)');
      await txn.execute('CREATE INDEX IF NOT EXISTS idx_scan_created ON scan_history(created_at)');
      await txn.execute('CREATE INDEX IF NOT EXISTS idx_points_user ON point_transactions(user_id, created_at)');

      // Seed reference data + user default (idempoten).
      await insertSeedData(txn);

      // Backfill waste_type_id dari kolom TEXT lama.
      await txn.execute('''
        UPDATE scan_history
        SET waste_type_id = (SELECT id FROM waste_types WHERE label_key = scan_history.waste_type)
        WHERE waste_type IS NOT NULL
      ''');
    });
  }
}

/// Provider singleton [AppDatabase] untuk seluruh aplikasi.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});
