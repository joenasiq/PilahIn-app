import '../../../core/guest/guest_progress_store.dart';
import '../../../core/waste/waste_types.dart';
import '../../scan/domain/waste_category.dart';
import '../domain/history_entry.dart';
import '../domain/history_repository.dart';

/// Repository riwayat untuk pengguna tamu, berbasis [GuestProgressStore]
/// (JSON di SharedPreferences).
///
/// Repository ini hanya menyimpan data tamu; parameter [userId] pada
/// interface dipakai untuk guard (hanya melayani `guest_id`).
class GuestHistoryRepository implements HistoryRepository {
  GuestHistoryRepository(this._store);

  final GuestProgressStore _store;

  /// Salinan kerja di memori; dimuat sekali lalu dipersist per perubahan.
  List<HistoryEntry>? _entries;

  List<HistoryEntry> get _all {
    final current = _entries;
    if (current != null) return current;
    final loaded = _store.loadScans();
    _entries = loaded;
    return loaded;
  }

  Future<void> _persist() async {
    await _store.saveScans(_all);
  }

  @override
  Future<void> add(HistoryEntry entry) async {
    final list = _all;
    // Idempotent based on scanKey
    if (list.any((e) => e.scanKey == entry.scanKey)) return;
    final nextId = list.isEmpty
        ? 1
        : (list.map((e) => e.id ?? 0).reduce((a, b) => a > b ? a : b) + 1);
    list.add(entry.copyWith(id: nextId));
    await _persist();
  }

  @override
  Future<List<HistoryEntry>> getAll(
      {WasteCategory? category, String? userId}) async {
    if (userId != null && userId != 'guest_id') return const [];
    var list = _all;
    if (category != null) {
      list = list.where((e) => e.category == category).toList();
    }
    final sorted = [...list]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted;
  }

  @override
  Future<void> delete(int id) async {
    final list = _all;
    list.removeWhere((e) => e.id == id);
    await _persist();
  }

  @override
  Future<void> restore(HistoryEntry entry) async {
    final list = _all;
    list.removeWhere((e) => e.scanKey == entry.scanKey);
    list.add(entry);
    await _persist();
  }

  @override
  Future<int> count({String? userId}) async {
    if (userId != null && userId != 'guest_id') return 0;
    return _all.length;
  }

  @override
  Future<Map<WasteCategory, int>> countByCategory({String? userId}) async {
    final list = (userId != null && userId != 'guest_id')
        ? const <HistoryEntry>[]
        : _all;
    return {
      WasteCategory.organik:
          list.where((e) => e.category == WasteCategory.organik).length,
      WasteCategory.anorganik:
          list.where((e) => e.category == WasteCategory.anorganik).length,
    };
  }

  @override
  Future<List<HistoryEntry>> getBetween({
    String? userId,
    required DateTime start,
    required DateTime end,
  }) async {
    if (userId != null && userId != 'guest_id') return const [];
    // [start] inklusif, [end] eksklusif; terlama dulu (konsisten SQLite).
    return _all
        .where((e) =>
            !e.createdAt.isBefore(start) && e.createdAt.isBefore(end))
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  @override
  Future<Map<WasteType, int>> countByWasteType({String? userId}) async {
    final list = (userId != null && userId != 'guest_id')
        ? const <HistoryEntry>[]
        : _all;
    final counts = <WasteType, int>{};
    for (final e in list) {
      // Hanya hasil valid (is_uncertain=0) & jenis dikenal.
      if (e.isUncertain) continue;
      final type = e.wasteType;
      if (type == null) continue;
      counts[type] = (counts[type] ?? 0) + 1;
    }
    return counts;
  }

  @override
  Future<int> sumPointsEarned({String? userId}) async {
    final list = (userId != null && userId != 'guest_id')
        ? const <HistoryEntry>[]
        : _all;
    var total = 0;
    for (final e in list) {
      total += e.pointsEarned;
    }
    return total;
  }

  @override
  Future<bool> hasScannedWasteTypeOn({
    String? userId,
    required WasteType wasteType,
    required DateTime day,
  }) async {
    if (userId != null && userId != 'guest_id') return false;
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    return _all.any((e) =>
        !e.isUncertain &&
        e.wasteType == wasteType &&
        !e.createdAt.isBefore(start) &&
        e.createdAt.isBefore(end));
  }
}
