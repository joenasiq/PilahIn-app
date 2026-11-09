import '../../../core/waste/waste_types.dart';
import '../domain/history_entry.dart';
import '../../scan/domain/waste_category.dart';

abstract class HistoryRepository {
  Future<void> add(HistoryEntry entry);

  Future<List<HistoryEntry>> getAll({
    String? userId,
    WasteCategory? category,
  });

  Future<void> delete(int id);

  Future<void> restore(HistoryEntry entry);

  /// Riwayat akun pada rentang waktu [start] (inklusif) hingga [end] (eksklusif).
  Future<List<HistoryEntry>> getBetween({
    String? userId,
    required DateTime start,
    required DateTime end,
  });

  Future<int> count({String? userId});

  Future<Map<WasteCategory, int>> countByCategory({String? userId});

  Future<Map<WasteType, int>> countByWasteType({String? userId});

  /// Total poin yang didapat dari seluruh pemindaian akun ini.
  Future<int> sumPointsEarned({String? userId});

  /// Apakah jenis sampah ini sudah pernah dipindai (hasil valid) pada [day].
  Future<bool> hasScannedWasteTypeOn({
    String? userId,
    required WasteType wasteType,
    required DateTime day,
  });
}
