import 'package:sqflite/sqflite.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/db/app_database.dart';
import '../../../core/waste/waste_types.dart';
import '../domain/history_entry.dart';
import '../domain/history_repository.dart';
import '../../scan/domain/waste_category.dart';

/// Repository riwayat berbasis SQLite.
///
/// Koneksi diambil dari [AppDatabase] (satu-satunya titik akses DB),
/// jadi skema tabel `scan_history` dikelola terpusat di sana.
class SqfliteHistoryRepository implements HistoryRepository {
  final AppDatabase _appDb;

  SqfliteHistoryRepository([AppDatabase? appDb]) : _appDb = appDb ?? AppDatabase();

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
  Future<List<HistoryEntry>> getAll({
    String? userId,
    WasteCategory? category,
  }) async {
    final db = await database;

    final conditions = <String>[];
    final whereArgs = <Object?>[];

    if (userId != null) {
      conditions.add('user_id = ?');
      whereArgs.add(userId);
    }
    if (category != null) {
      conditions.add('category = ?');
      whereArgs.add(category == WasteCategory.organik ? 'organik' : 'anorganik');
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
  Future<List<HistoryEntry>> getBetween({
    String? userId,
    required DateTime start,
    required DateTime end,
  }) async {
    final db = await database;
    final where = StringBuffer('created_at >= ? AND created_at < ?');
    final whereArgs = <Object?>[
      start.millisecondsSinceEpoch,
      end.millisecondsSinceEpoch,
    ];
    if (userId != null) {
      where.write(' AND user_id = ?');
      whereArgs.add(userId);
    }
    final List<Map<String, dynamic>> maps = await db.query(
      'scan_history',
      where: where.toString(),
      whereArgs: whereArgs,
      orderBy: 'created_at ASC',
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
        'SELECT COUNT(*) FROM scan_history WHERE user_id = ?',
        [userId],
      );
    } else {
      result = await db.rawQuery('SELECT COUNT(*) FROM scan_history');
    }
    return Sqflite.firstIntValue(result) ?? 0;
  }

  @override
  Future<Map<WasteCategory, int>> countByCategory({String? userId}) async {
    final db = await database;

    final String sql;
    final List<Object?> args;
    if (userId != null) {
      sql = 'SELECT category, COUNT(*) as count FROM scan_history '
          'WHERE user_id = ? AND is_uncertain = 0 GROUP BY category';
      args = [userId];
    } else {
      sql = 'SELECT category, COUNT(*) as count FROM scan_history '
          'WHERE is_uncertain = 0 GROUP BY category';
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

  @override
  Future<Map<WasteType, int>> countByWasteType({String? userId}) async {
    final db = await database;
    final String sql;
    final List<Object?> args;
    if (userId != null) {
      sql = 'SELECT waste_type, COUNT(*) as count FROM scan_history '
          'WHERE user_id = ? AND is_uncertain = 0 AND waste_type IS NOT NULL '
          'GROUP BY waste_type';
      args = [userId];
    } else {
      sql = 'SELECT waste_type, COUNT(*) as count FROM scan_history '
          'WHERE is_uncertain = 0 AND waste_type IS NOT NULL '
          'GROUP BY waste_type';
      args = const [];
    }
    final results = await db.rawQuery(sql, args);

    final counts = <WasteType, int>{};
    for (final row in results) {
      final wasteType = WasteType.fromLabelKey(row['waste_type'] as String);
      if (wasteType != null) {
        counts[wasteType] = row['count'] as int;
      }
    }
    return counts;
  }

  @override
  Future<int> sumPointsEarned({String? userId}) async {
    final db = await database;
    final List<Map<String, dynamic>> result;
    if (userId != null) {
      result = await db.rawQuery(
        'SELECT SUM(points_earned) as total FROM scan_history WHERE user_id = ?',
        [userId],
      );
    } else {
      result = await db.rawQuery(
        'SELECT SUM(points_earned) as total FROM scan_history',
      );
    }
    return Sqflite.firstIntValue(result) ?? 0;
  }

  @override
  Future<bool> hasScannedWasteTypeOn({
    String? userId,
    required WasteType wasteType,
    required DateTime day,
  }) async {
    final db = await database;
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final String sql;
    final List<Object?> args;
    if (userId != null) {
      sql = 'SELECT COUNT(*) FROM scan_history '
          'WHERE user_id = ? AND waste_type = ? AND is_uncertain = 0 '
          'AND created_at >= ? AND created_at < ?';
      args = [
        userId,
        wasteType.labelKey,
        start.millisecondsSinceEpoch,
        end.millisecondsSinceEpoch,
      ];
    } else {
      sql = 'SELECT COUNT(*) FROM scan_history '
          'WHERE waste_type = ? AND is_uncertain = 0 '
          'AND created_at >= ? AND created_at < ?';
      args = [
        wasteType.labelKey,
        start.millisecondsSinceEpoch,
        end.millisecondsSinceEpoch,
      ];
    }
    final result = await db.rawQuery(sql, args);
    return (Sqflite.firstIntValue(result) ?? 0) > 0;
  }
}
