import 'package:sqflite/sqflite.dart';

import '../../../core/db/app_database.dart';
import '../domain/history_entry.dart';
import '../domain/history_repository.dart';
import '../../scan/domain/waste_category.dart';

/// Repository riwayat berbasis SQLite.
///
/// Koneksi diambil dari [AppDatabase] (satu-satunya titik akses DB),
/// jadi skema tabel `scan_history` dikelola terpusat di sana.
class SqfliteHistoryRepository implements HistoryRepository {
  final AppDatabase _appDb;

  SqfliteHistoryRepository(this._appDb);

  Future<Database> get database => _appDb.database;

  /// Cache label_key -> id untuk kolom waste_type_id.
  Map<String, int>? _wasteTypeIds;

  Future<Map<String, int>> _wasteTypeLookup() async {
    final cached = _wasteTypeIds;
    if (cached != null) return cached;

    final db = await database;
    final rows = await db.query('waste_types', columns: ['id', 'label_key']);
    final map = {
      for (final row in rows) (row['label_key'] as String): row['id'] as int,
    };
    _wasteTypeIds = map;
    return map;
  }

  /// Isi kolom `waste_type_id` (FK) dari `wasteType` entry bila tersedia.
  Future<Map<String, dynamic>> _withWasteTypeId(HistoryEntry entry) async {
    final map = entry.toMap();
    final type = entry.wasteType;
    if (type != null) {
      final lookup = await _wasteTypeLookup();
      map['waste_type_id'] = lookup[type.labelKey];
    }
    return map;
  }

  @override
  Future<void> add(HistoryEntry entry) async {
    final db = await database;
    final map = await _withWasteTypeId(entry);
    await db.insert(
      'scan_history',
      map,
      conflictAlgorithm: ConflictAlgorithm.ignore, // Idempotent based on scanKey
    );
  }

  @override
  Future<List<HistoryEntry>> getAll({WasteCategory? category, String? userId}) async {
    final db = await database;

    final conditions = <String>[];
    final whereArgs = <Object?>[];

    if (category != null) {
      conditions.add('category = ?');
      whereArgs.add(category == WasteCategory.organik ? 'organik' : 'anorganik');
    }
    if (userId != null) {
      conditions.add('user_id = ?');
      whereArgs.add(userId);
    }

    final List<Map<String, dynamic>> maps = await db.query(
      'scan_history',
      where: conditions.isEmpty ? null : conditions.join(' AND '),
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'created_at DESC',
    );

    return maps.map((e) => HistoryEntry.fromMap(e)).toList();
  }

  @override
  Future<void> delete(int id) async {
    final db = await database;
    await db.delete(
      'scan_history',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> restore(HistoryEntry entry) async {
    final db = await database;
    final map = await _withWasteTypeId(entry);
    await db.insert(
      'scan_history',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<int> count({String? userId}) async {
    final db = await database;
    final List<Map<String, dynamic>> result;
    if (userId != null) {
      result = await db.rawQuery(
        'SELECT COUNT(*) AS c FROM scan_history WHERE user_id = ?',
        [userId],
      );
    } else {
      result = await db.rawQuery('SELECT COUNT(*) AS c FROM scan_history');
    }
    return (result.first['c'] as int?) ?? 0;
  }

  @override
  Future<Map<WasteCategory, int>> countByCategory({String? userId}) async {
    final db = await database;

    String sql;
    List<Object?> args;
    if (userId != null) {
      sql = "SELECT category, COUNT(*) AS count FROM scan_history WHERE user_id = ? GROUP BY category";
      args = [userId];
    } else {
      sql = 'SELECT category, COUNT(*) AS count FROM scan_history GROUP BY category';
      args = const [];
    }

    final results = await db.rawQuery(sql, args);

    int organik = 0;
    int anorganik = 0;

    for (var row in results) {
      if (row['category'] == 'organik') {
        organik = row['count'] as int;
      } else if (row['category'] == 'anorganik') {
        anorganik = row['count'] as int;
      }
    }

    return {
      WasteCategory.organik: organik,
      WasteCategory.anorganik: anorganik,
    };
  }
}
