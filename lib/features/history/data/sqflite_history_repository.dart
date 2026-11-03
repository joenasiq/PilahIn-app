import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/waste/waste_types.dart';
import '../domain/history_entry.dart';
import '../domain/history_repository.dart';
import '../../scan/domain/waste_category.dart';

class SqfliteHistoryRepository implements HistoryRepository {
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = '${documentsDirectory.path}/pilahin.db';

    return await openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE scan_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            scan_key TEXT UNIQUE NOT NULL,
            user_id TEXT NOT NULL DEFAULT '${AppConstants.demoUserId}',
            category TEXT NOT NULL,
            waste_type TEXT,
            confidence REAL NOT NULL,
            is_uncertain INTEGER NOT NULL,
            item_name TEXT,
            points_earned INTEGER NOT NULL,
            image_path TEXT,
            created_at INTEGER NOT NULL
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_created_at ON scan_history(created_at)',
        );
        await db.execute(
          'CREATE INDEX idx_user_created ON scan_history(user_id, created_at)',
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE scan_history ADD COLUMN waste_type TEXT',
          );
        }
        if (oldVersion < 3) {
          await db.execute(
            "ALTER TABLE scan_history ADD COLUMN user_id TEXT NOT NULL "
            "DEFAULT '${AppConstants.demoUserId}'",
          );
          await db.execute(
            'CREATE INDEX idx_user_created ON scan_history(user_id, created_at)',
          );
        }
      },
    );
  }

  @override
  Future<void> add(HistoryEntry entry) async {
    final db = await database;
    await db.insert(
      'scan_history',
      entry.toMap(),
      conflictAlgorithm:
          ConflictAlgorithm.ignore, // Idempotent based on scanKey
    );
  }

  @override
  Future<List<HistoryEntry>> getAll({
    required String userId,
    WasteCategory? category,
  }) async {
    final db = await database;
    final where = StringBuffer('user_id = ?');
    final whereArgs = <Object?>[userId];

    if (category != null) {
      where.write(' AND category = ?');
      whereArgs.add(
        category == WasteCategory.organik ? 'organik' : 'anorganik',
      );
    }

    final List<Map<String, dynamic>> maps = await db.query(
      'scan_history',
      where: where.toString(),
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
    );

    return maps.map((e) => HistoryEntry.fromMap(e)).toList();
  }

  @override
  Future<List<HistoryEntry>> getBetween({
    required String userId,
    required DateTime start,
    required DateTime end,
  }) async {
    final db = await database;
    final maps = await db.query(
      'scan_history',
      where: 'user_id = ? AND created_at >= ? AND created_at < ?',
      whereArgs: [
        userId,
        start.millisecondsSinceEpoch,
        end.millisecondsSinceEpoch,
      ],
      orderBy: 'created_at DESC',
    );
    return maps.map((e) => HistoryEntry.fromMap(e)).toList();
  }

  @override
  Future<void> delete(int id) async {
    final db = await database;
    await db.delete('scan_history', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> restore(HistoryEntry entry) async {
    final db = await database;
    await db.insert(
      'scan_history',
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<int> count({required String userId}) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) FROM scan_history WHERE user_id = ?',
      [userId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  @override
  Future<Map<WasteCategory, int>> countByCategory({
    required String userId,
  }) async {
    final db = await database;
    // Hanya hasil yang valid (bukan "tidak yakin") yang masuk statistik.
    final results = await db.rawQuery(
      'SELECT category, COUNT(*) as count FROM scan_history '
      'WHERE user_id = ? AND is_uncertain = 0 GROUP BY category',
      [userId],
    );

    int organik = 0;
    int anorganik = 0;

    for (var row in results) {
      if (row['category'] == 'organik') {
        organik = row['count'] as int;
      } else if (row['category'] == 'anorganik') {
        anorganik = row['count'] as int;
      }
    }

    return {WasteCategory.organik: organik, WasteCategory.anorganik: anorganik};
  }

  @override
  Future<Map<WasteType, int>> countByWasteType({required String userId}) async {
    final db = await database;
    final results = await db.rawQuery(
      'SELECT waste_type, COUNT(*) as count FROM scan_history '
      'WHERE user_id = ? AND is_uncertain = 0 AND waste_type IS NOT NULL '
      'GROUP BY waste_type',
      [userId],
    );

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
  Future<int> sumPointsEarned({required String userId}) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT SUM(points_earned) as total FROM scan_history WHERE user_id = ?',
      [userId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  @override
  Future<bool> hasScannedWasteTypeOn({
    required String userId,
    required WasteType wasteType,
    required DateTime day,
  }) async {
    final db = await database;
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final result = await db.rawQuery(
      'SELECT COUNT(*) FROM scan_history '
      'WHERE user_id = ? AND waste_type = ? AND is_uncertain = 0 '
      'AND created_at >= ? AND created_at < ?',
      [
        userId,
        wasteType.labelKey,
        start.millisecondsSinceEpoch,
        end.millisecondsSinceEpoch,
      ],
    );
    return (Sqflite.firstIntValue(result) ?? 0) > 0;
  }
}
