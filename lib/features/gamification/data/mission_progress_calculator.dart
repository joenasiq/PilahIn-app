import '../../../core/waste/waste_types.dart';
import '../../history/domain/history_entry.dart';
import '../../scan/domain/waste_category.dart';
import '../domain/mission_template.dart';

/// Perhitungan nilai metrik misi berdasarkan riwayat pemindaian.
class MissionProgressCalculator {
  const MissionProgressCalculator();

  /// Menghitung nilai metrik dari daftar riwayat.
  /// Hasil "tidak yakin" diabaikan agar tidak bisa dipakai mengejar misi.
  int metricValue(MissionMetric metric, List<HistoryEntry> entries) {
    final valid = entries.where((entry) => !entry.isUncertain).toList();

    switch (metric) {
      case MissionMetric.totalScans:
        return valid.length;
      case MissionMetric.organicScans:
        return valid
            .where((entry) => entry.category == WasteCategory.organik)
            .length;
      case MissionMetric.plasticScans:
        return valid
            .where((entry) => entry.wasteType == WasteType.plastic)
            .length;
      case MissionMetric.biologicalScans:
        return valid
            .where((entry) => entry.wasteType == WasteType.biological)
            .length;
      case MissionMetric.distinctWasteTypes:
        return valid
            .map((entry) => entry.wasteType)
            .whereType<WasteType>()
            .toSet()
            .length;
    }
  }
}
