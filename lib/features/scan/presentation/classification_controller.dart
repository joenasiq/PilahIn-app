import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/classification_result.dart';
import '../domain/waste_classifier.dart';
import '../data/yolo_waste_classifier.dart';

// Provider untuk implementasi WasteClassifier.
// Memakai YoloWasteClassifier (YOLOv8n TFLite). MockWasteClassifier tetap
// tersedia untuk test lewat override provider ini.
final wasteClassifierProvider = Provider<WasteClassifier>((ref) {
  final classifier = YoloWasteClassifier();
  ref.onDispose(classifier.dispose);
  return classifier;
});

class ClassificationController extends AsyncNotifier<ClassificationResult?> {
  @override
  Future<ClassificationResult?> build() async {
    return null;
  }

  Future<void> classify(String imagePath) async {
    state = const AsyncValue.loading();
    try {
      final classifier = ref.read(wasteClassifierProvider);
      final result = await classifier.classify(imagePath);
      state = AsyncValue.data(result);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final classificationControllerProvider = AsyncNotifierProvider.autoDispose<ClassificationController, ClassificationResult?>(
  ClassificationController.new
);
