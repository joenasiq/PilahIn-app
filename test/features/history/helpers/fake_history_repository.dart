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
  Future<int> count() async {
    return _entries.length;
  }

  @override
  Future<void> delete(int id) async {
    _entries.removeWhere((e) => e.id == id);
  }

  @override
  Future<List<HistoryEntry>> getAll({WasteCategory? category}) async {
    var list = _entries;
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
  Future<Map<WasteCategory, int>> countByCategory() async {
    int organik = _entries.where((e) => e.category == WasteCategory.organik).length;
    int anorganik = _entries.where((e) => e.category == WasteCategory.anorganik).length;
    return {
      WasteCategory.organik: organik,
      WasteCategory.anorganik: anorganik,
    };
  }
}
