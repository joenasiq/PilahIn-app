import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/classification_result.dart';
import '../domain/waste_classifier.dart';
import '../data/mock_waste_classifier.dart';

// Provider untuk implementasi WasteClassifier.
// Saat ini mengembalikan MockWasteClassifier. Ganti di sini bila TFLite sudah siap.
final wasteClassifierProvider = Provider<WasteClassifier>((ref) {
  return MockWasteClassifier();
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
