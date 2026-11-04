import 'package:pilahin_app/core/waste/waste_types.dart';
import 'package:pilahin_app/features/history/domain/history_entry.dart';
import 'package:pilahin_app/features/history/domain/history_repository.dart';
import 'package:pilahin_app/features/scan/domain/waste_category.dart';

class FakeHistoryRepository implements HistoryRepository {
  final List<HistoryEntry> _entries = [];

  List<HistoryEntry> get entries => List.unmodifiable(_entries);

  @override
  Future<void> add(HistoryEntry entry) async {
    _entries.add(entry);
  }

  @override
  Future<int> count({String? userId}) async {
    if (userId == null) return _entries.length;
    return _entries.where((e) => e.userId == userId).length;
  }

  @override
  Future<List<HistoryEntry>> getBetween({
    String? userId,
    required DateTime start,
    required DateTime end,
  }) async {
    final list = _entries
        .where(
          (e) =>
              (userId == null || e.userId == userId) &&
              !e.createdAt.isBefore(start) &&
              e.createdAt.isBefore(end),
        )
        .toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  Future<void> delete(int id) async {
    _entries.removeWhere((e) => e.id == id);
  }

  @override
  Future<List<HistoryEntry>> getAll({
    String? userId,
    WasteCategory? category,
  }) async {
    var list = userId == null
        ? _entries
        : _entries.where((e) => e.userId == userId).toList();
    if (category != null) {
      list = list.where((e) => e.category == category).toList();
    }
    return List.from(list);
  }

  @override
  Future<void> restore(HistoryEntry entry) async {
    _entries.add(entry);
  }

  @override
  Future<Map<WasteCategory, int>> countByCategory({
    String? userId,
  }) async {
    final valid = _entries.where((e) => (userId == null || e.userId == userId) && !e.isUncertain);
    int organik = valid
        .where((e) => e.category == WasteCategory.organik)
        .length;
    int anorganik = valid
        .where((e) => e.category == WasteCategory.anorganik)
        .length;
    return {WasteCategory.organik: organik, WasteCategory.anorganik: anorganik};
  }

  @override
  Future<Map<WasteType, int>> countByWasteType({String? userId}) async {
    final counts = <WasteType, int>{};
    for (final entry in _entries) {
      if ((userId != null && entry.userId != userId) || entry.isUncertain) continue;
      final wasteType = entry.wasteType;
      if (wasteType != null) {
        counts[wasteType] = (counts[wasteType] ?? 0) + 1;
      }
    }
    return counts;
  }

  @override
  Future<int> sumPointsEarned({String? userId}) async {
    return _entries
        .where((e) => userId == null || e.userId == userId)
        .fold<int>(0, (sum, entry) => sum + entry.pointsEarned);
  }

  @override
  Future<bool> hasScannedWasteTypeOn({
    String? userId,
    required WasteType wasteType,
    required DateTime day,
  }) async {
    return _entries.any(
      (e) =>
          (userId == null || e.userId == userId) &&
          !e.isUncertain &&
          e.wasteType == wasteType &&
          e.createdAt.year == day.year &&
          e.createdAt.month == day.month &&
          e.createdAt.day == day.day,
    );
  }
}
