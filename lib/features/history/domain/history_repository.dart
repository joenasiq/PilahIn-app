import '../../../core/waste/waste_types.dart';
import 'history_entry.dart';
import '../../scan/domain/waste_category.dart';

abstract class HistoryRepository {
  Future<void> add(HistoryEntry entry);
  Future<List<HistoryEntry>> getAll({
    required String userId,
    WasteCategory? category,
  });
  Future<void> delete(int id);
  Future<void> restore(HistoryEntry entry);

  /// Riwayat akun pada rentang waktu [start] (inklusif) hingga [end] (eksklusif).
  Future<List<HistoryEntry>> getBetween({
    required String userId,
    required DateTime start,
    required DateTime end,
  });
  Future<int> count({required String userId});
  Future<Map<WasteCategory, int>> countByCategory({required String userId});
  Future<Map<WasteType, int>> countByWasteType({required String userId});

  /// Total poin yang didapat dari seluruh pemindaian akun ini.
  Future<int> sumPointsEarned({required String userId});

  /// Apakah jenis sampah ini sudah pernah dipindai (hasil valid) pada [day].
  Future<bool> hasScannedWasteTypeOn({
    required String userId,
    required WasteType wasteType,
    required DateTime day,
  });
}
