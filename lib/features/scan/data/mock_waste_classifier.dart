import '../../../core/constants/ml_config.dart';
import '../domain/classification_result.dart';
import '../domain/waste_category.dart';
import '../domain/waste_classifier.dart';

// SEMENTARA - ganti dengan classifier TFLite setelah model tim ML tersedia.
class MockWasteClassifier implements WasteClassifier {
  int _callCount = 0;

  @override
  Future<ClassificationResult> classify(String imagePath) async {
    // Jeda sekitar 600 ms untuk meniru proses nyata
    await Future.delayed(const Duration(milliseconds: 600));

    // Hasil BERGILIR:
    // (1) Organik 92,7%
    // (2) Anorganik 91,2%
    // (3) tidak yakin 48% (isUncertain = true)
    
    final int state = _callCount % 3;
    _callCount++;

    WasteCategory category;
    double confidence;

    if (state == 0) {
      category = WasteCategory.organik;
      confidence = 0.927;
    } else if (state == 1) {
      category = WasteCategory.anorganik;
      confidence = 0.912;
    } else {
      category = WasteCategory.organik; // Sembarang, karena tidak yakin
      confidence = 0.48;
    }

    return ClassificationResult(
      category: category,
      confidence: confidence,
      imagePath: imagePath,
      isUncertain: confidence < MlConfig.lowConfidenceThreshold,
      timestamp: DateTime.now(),
    );
  }
}
