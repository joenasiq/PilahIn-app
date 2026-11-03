import '../../../core/waste/waste_types.dart';
import '../../scan/domain/waste_category.dart';

/// Ringkasan statistik pemindaian untuk halaman profil.
///
/// Berisi klasifikasi dua tingkat:
/// - [byCategory]: kategori utama (Organik / Anorganik)
/// - [byWasteType]: jenis sampah spesifik dari dataset (12 jenis)
class HistoryStats {
  final Map<WasteCategory, int> byCategory;
  final Map<WasteType, int> byWasteType;
  final int totalPoints;

  HistoryStats({
    required this.byCategory,
    required this.byWasteType,
    required this.totalPoints,
  });

  int get organicCount => byCategory[WasteCategory.organik] ?? 0;
  int get anorganicCount => byCategory[WasteCategory.anorganik] ?? 0;
  int get totalScans => organicCount + anorganicCount;
  int get typedTotal =>
      byWasteType.values.fold<int>(0, (sum, count) => sum + count);

  /// Jenis sampah yang pernah dipindai, diurutkan dari yang paling sering.
  List<MapEntry<WasteType, int>> get sortedWasteTypes {
    final entries = byWasteType.entries
        .where((entry) => entry.value > 0)
        .toList();
    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }
}
