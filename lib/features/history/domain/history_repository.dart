import '../../../core/waste/waste_types.dart';
import 'history_entry.dart';
import '../../scan/domain/waste_category.dart';

abstract class HistoryRepository {
  Future<void> add(HistoryEntry entry);
  Future<List<HistoryEntry>> getAll({WasteCategory? category});
  Future<void> delete(int id);
  Future<void> restore(HistoryEntry entry);
  Future<int> count();
  Future<Map<WasteCategory, int>> countByCategory();

  /// Jumlah pemindaian per jenis sampah spesifik (dataset).
  Future<Map<WasteType, int>> countByWasteType();

  /// Total poin gamifikasi yang didapat dari seluruh pemindaian.
  Future<int> sumPointsEarned();
}
