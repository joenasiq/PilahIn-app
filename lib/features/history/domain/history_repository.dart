import 'history_entry.dart';
import '../../scan/domain/waste_category.dart';

abstract class HistoryRepository {
  Future<void> add(HistoryEntry entry);
  Future<List<HistoryEntry>> getAll({WasteCategory? category});
  Future<void> delete(int id);
  Future<void> restore(HistoryEntry entry);
  Future<int> count();
  Future<Map<WasteCategory, int>> countByCategory();
}
