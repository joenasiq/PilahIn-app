import 'package:flutter_test/flutter_test.dart';
import 'package:pilahin_app/core/constants/ml_config.dart';
import 'package:pilahin_app/core/waste/waste_types.dart';
import 'package:pilahin_app/features/scan/data/mock_waste_classifier.dart';
import 'package:pilahin_app/features/scan/domain/waste_category.dart';

void main() {
  group('MockWasteClassifier Tests', () {
    late MockWasteClassifier classifier;

    setUp(() {
      classifier = MockWasteClassifier();
    });

    test('Urutan 13 keadaan classifier tiruan benar: 12 jenis + 1 tidak yakin, lalu berulang', () async {
      // 1. cardboard (Anorganik)
      final r1 = await classifier.classify('dummy.jpg');
      expect(r1.wasteType, equals(WasteType.cardboard));
      expect(r1.category, equals(WasteCategory.anorganik));
      expect(r1.confidence, inInclusiveRange(0.85, 0.97));
      expect(r1.isUncertain, isFalse);

      // 2. biological (Organik)
      final r2 = await classifier.classify('dummy.jpg');
      expect(r2.wasteType, equals(WasteType.biological));
      expect(r2.category, equals(WasteCategory.organik));
      expect(r2.confidence, inInclusiveRange(0.85, 0.97));
      expect(r2.isUncertain, isFalse);

      // 3. plastic (Anorganik)
      final r3 = await classifier.classify('dummy.jpg');
      expect(r3.wasteType, equals(WasteType.plastic));
      expect(r3.category, equals(WasteCategory.anorganik));
      expect(r3.confidence, inInclusiveRange(0.85, 0.97));
      expect(r3.isUncertain, isFalse);

      // 4. battery (Anorganik, B3)
      final r4 = await classifier.classify('dummy.jpg');
      expect(r4.wasteType, equals(WasteType.battery));
      expect(r4.category, equals(WasteCategory.anorganik));
      expect(r4.isHazardous, isTrue);
      expect(r4.confidence, inInclusiveRange(0.85, 0.97));
      expect(r4.isUncertain, isFalse);

      // 5. paper
      final r5 = await classifier.classify('dummy.jpg');
      expect(r5.wasteType, equals(WasteType.paper));
      expect(r5.category, equals(WasteCategory.anorganik));

      // 6. metal
      final r6 = await classifier.classify('dummy.jpg');
      expect(r6.wasteType, equals(WasteType.metal));

      // 7. brown-glass
      final r7 = await classifier.classify('dummy.jpg');
      expect(r7.wasteType, equals(WasteType.brownGlass));

      // 8. green-glass
      final r8 = await classifier.classify('dummy.jpg');
      expect(r8.wasteType, equals(WasteType.greenGlass));

      // 9. white-glass
      final r9 = await classifier.classify('dummy.jpg');
      expect(r9.wasteType, equals(WasteType.whiteGlass));

      // 10. clothes
      final r10 = await classifier.classify('dummy.jpg');
      expect(r10.wasteType, equals(WasteType.clothes));

      // 11. shoes
      final r11 = await classifier.classify('dummy.jpg');
      expect(r11.wasteType, equals(WasteType.shoes));

      // 12. trash
      final r12 = await classifier.classify('dummy.jpg');
      expect(r12.wasteType, equals(WasteType.trash));

      // 13. tidak yakin (plastic 48%)
      final r13 = await classifier.classify('dummy.jpg');
      expect(r13.wasteType, equals(WasteType.plastic));
      expect(r13.confidence, equals(0.48));
      expect(r13.isUncertain, isTrue);
      expect(r13.confidence < MlConfig.lowConfidenceThreshold, isTrue);

      // Ulang ke awal: cardboard
      final r14 = await classifier.classify('dummy.jpg');
      expect(r14.wasteType, equals(WasteType.cardboard));
      expect(r14.category, equals(WasteCategory.anorganik));
      expect(r14.isUncertain, isFalse);
    });
  });
}
