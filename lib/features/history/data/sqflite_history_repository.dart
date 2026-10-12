import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

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
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE scan_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            scan_key TEXT UNIQUE NOT NULL,
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
          'CREATE INDEX idx_created_at ON scan_history(created_at)'
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE scan_history ADD COLUMN waste_type TEXT');
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
      conflictAlgorithm: ConflictAlgorithm.ignore, // Idempotent based on scanKey
    );
  }

  @override
  Future<List<HistoryEntry>> getAll({WasteCategory? category}) async {
    final db = await database;
    String? where;
    List<Object?>? whereArgs;

    if (category != null) {
      where = 'category = ?';
      whereArgs = [category == WasteCategory.organik ? 'organik' : 'anorganik'];
    }

    final List<Map<String, dynamic>> maps = await db.query(
      'scan_history',
      where: where,
      whereArgs: whereArgs,
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
    await db.insert(
      'scan_history',
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<int> count() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) FROM scan_history');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  @override
  Future<Map<WasteCategory, int>> countByCategory() async {
    final db = await database;
    final results = await db.rawQuery(
        'SELECT category, COUNT(*) as count FROM scan_history GROUP BY category');
    
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
