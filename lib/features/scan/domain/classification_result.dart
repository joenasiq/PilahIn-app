import '../../../core/waste/waste_types.dart';
import 'waste_category.dart';

class ClassificationResult {
  final WasteType wasteType;
  final double confidence; // 0.0 - 1.0 (keyakinan untuk wasteType)
  final String imagePath;
  final bool isUncertain;
  final DateTime timestamp;

  /// Kategori SELALU diturunkan dari jenis sampah
  WasteCategory get category => wasteType.category;

  /// Status bahaya diturunkan dari jenis sampah
  bool get isHazardous => wasteType.isHazardous;

  ClassificationResult({
    required this.wasteType,
    required this.confidence,
    required this.imagePath,
    required this.isUncertain,
    required this.timestamp,
  });
}

