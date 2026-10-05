import 'package:flutter_test/flutter_test.dart';
import 'package:pilahin_app/features/scan/data/mock_waste_classifier.dart';
import 'package:pilahin_app/features/scan/domain/waste_category.dart';
import 'package:pilahin_app/core/constants/ml_config.dart';

void main() {
  group('MockWasteClassifier Tests', () {
    late MockWasteClassifier classifier;

    setUp(() {
      classifier = MockWasteClassifier();
    });

    test('Mengembalikan hasil bergilir: Organik -> Anorganik -> Tidak Yakin', () async {
      // Siklus 1
      final r1 = await classifier.classify('dummy.jpg');
      expect(r1.category, equals(WasteCategory.organik));
      expect(r1.confidence, equals(0.927));
      expect(r1.isUncertain, isFalse);

      // Siklus 2
      final r2 = await classifier.classify('dummy.jpg');
      expect(r2.category, equals(WasteCategory.anorganik));
      expect(r2.confidence, equals(0.912));
      expect(r2.isUncertain, isFalse);

      // Siklus 3
      final r3 = await classifier.classify('dummy.jpg');
      // Kategori sembarang (Mock mengatur ke organik)
      expect(r3.confidence, equals(0.48));
      expect(r3.isUncertain, equals(0.48 < MlConfig.lowConfidenceThreshold)); // true

      // Kembali ke siklus 1
      final r4 = await classifier.classify('dummy.jpg');
      expect(r4.category, equals(WasteCategory.organik));
      expect(r4.confidence, equals(0.927));
    });
  });
}
