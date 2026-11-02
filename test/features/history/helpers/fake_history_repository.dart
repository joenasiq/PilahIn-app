import 'package:pilahin_app/features/history/domain/history_entry.dart';
import 'package:pilahin_app/features/history/domain/history_repository.dart';
import 'package:pilahin_app/features/scan/domain/waste_category.dart';

class FakeHistoryRepository implements HistoryRepository {
  final List<HistoryEntry> _entries = [];
  int _nextId = 1;

  @override
  Future<void> add(HistoryEntry entry) async {
    // Idempotent
    if (_entries.any((e) => e.scanKey == entry.scanKey)) {
      return;
    }
    final newEntry = entry.copyWith(id: _nextId++);
    _entries.add(newEntry);
  }

  @override
  Future<int> count({String? userId}) async {
    if (userId == null) return _entries.length;
    return _entries.where((e) => e.userId == userId).length;
  }

  @override
  Future<void> delete(int id) async {
    _entries.removeWhere((e) => e.id == id);
  }

  @override
  Future<List<HistoryEntry>> getAll({WasteCategory? category, String? userId}) async {
    var list = _entries;
    if (userId != null) {
      list = list.where((e) => e.userId == userId).toList();
    }
    if (category != null) {
      list = list.where((e) => e.category == category).toList();
    }
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  Future<void> restore(HistoryEntry entry) async {
    _entries.removeWhere((e) => e.id == entry.id);
    _entries.add(entry);
  }

  @override
  Future<Map<WasteCategory, int>> countByCategory({String? userId}) async {
    final list = userId == null
        ? _entries
        : _entries.where((e) => e.userId == userId).toList();
    int organik = list.where((e) => e.category == WasteCategory.organik).length;
    int anorganik = list.where((e) => e.category == WasteCategory.anorganik).length;
    return {
      WasteCategory.organik: organik,
      WasteCategory.anorganik: anorganik,
    };
  }
}
