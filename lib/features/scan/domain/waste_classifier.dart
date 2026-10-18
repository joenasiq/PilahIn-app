import 'classification_result.dart';

abstract class WasteClassifier {
  Future<ClassificationResult> classify(String imagePath);
}
