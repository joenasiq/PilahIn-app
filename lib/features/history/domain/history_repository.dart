import 'history_entry.dart';
import '../../scan/domain/waste_category.dart';

abstract class HistoryRepository {
  Future<void> add(HistoryEntry entry);

  /// Ambil semua riwayat. Bila [userId] diberikan, hanya riwayat user tsb.
  Future<List<HistoryEntry>> getAll({WasteCategory? category, String? userId});

  Future<void> delete(int id);

  Future<void> restore(HistoryEntry entry);

  /// Total jumlah riwayat (opsional difilter [userId]).
  Future<int> count({String? userId});

  /// Jumlah riwayat per kategori (opsional difilter [userId]).
  Future<Map<WasteCategory, int>> countByCategory({String? userId});
}
