import 'waste_category.dart';

class ClassificationResult {
  final WasteCategory category;
  final double confidence; // 0.0 - 1.0
  final String imagePath;
  final bool isUncertain;
  final DateTime timestamp;

  ClassificationResult({
    required this.category,
    required this.confidence,
    required this.imagePath,
    required this.isUncertain,
    required this.timestamp,
  });
}
