import '../../../core/constants/ml_config.dart';
import '../../../core/waste/waste_types.dart';
import '../domain/classification_result.dart';
import '../domain/waste_classifier.dart';

// SEMENTARA - model asli kelak cukup mengisi wasteType dan confidence.
class MockWasteClassifier implements WasteClassifier {
  int _callCount = 0;

  // Daftar 13 hasil pengujian bergilir:
  // 12 kelas dataset (confidence 85% - 97%) + 1 hasil tidak yakin (plastic 48%)
  static const List<_MockResultSpec> _cycleSpecs = [
    _MockResultSpec(WasteType.cardboard, 0.942),
    _MockResultSpec(WasteType.biological, 0.927),
    _MockResultSpec(WasteType.plastic, 0.912),
    _MockResultSpec(WasteType.battery, 0.885),
    _MockResultSpec(WasteType.paper, 0.954),
    _MockResultSpec(WasteType.metal, 0.896),
    _MockResultSpec(WasteType.brownGlass, 0.873),
    _MockResultSpec(WasteType.greenGlass, 0.931),
    _MockResultSpec(WasteType.whiteGlass, 0.965),
    _MockResultSpec(WasteType.clothes, 0.864),
    _MockResultSpec(WasteType.shoes, 0.908),
    _MockResultSpec(WasteType.trash, 0.852),
    _MockResultSpec(WasteType.plastic, 0.48), // Tidak yakin
  ];

  @override
  Future<ClassificationResult> classify(String imagePath) async {
    // Jeda sekitar 600 ms untuk meniru proses nyata
    await Future.delayed(const Duration(milliseconds: 600));

    final int state = _callCount % _cycleSpecs.length;
    _callCount++;

    final spec = _cycleSpecs[state];

    return ClassificationResult(
      wasteType: spec.wasteType,
      confidence: spec.confidence,
      imagePath: imagePath,
      isUncertain: spec.confidence < MlConfig.lowConfidenceThreshold,
      timestamp: DateTime.now(),
    );
  }
}

class _MockResultSpec {
  final WasteType wasteType;
  final double confidence;

  const _MockResultSpec(this.wasteType, this.confidence);
}

