import 'package:flutter_test/flutter_test.dart';
import 'package:pilahin_app/core/waste/waste_types.dart';
import 'package:pilahin_app/features/history/domain/history_entry.dart';
import 'package:pilahin_app/features/scan/domain/waste_category.dart';

void main() {
  group('HistoryEntry', () {
    test('toMap and fromMap should map correctly with wasteType', () {
      final date = DateTime.now();
      final entry = HistoryEntry(
        id: 1,
        scanKey: 'test_key',
        wasteType: WasteType.battery,
        confidence: 0.95,
        isUncertain: false,
        itemName: 'Baterai Bekas',
        pointsEarned: 15,
        imagePath: '/path/to/image.jpg',
        createdAt: date,
      );

      expect(entry.category, equals(WasteCategory.anorganik));
      expect(entry.isHazardous, isTrue);

      final map = entry.toMap();

      expect(map['id'], 1);
      expect(map['scan_key'], 'test_key');
      expect(map['category'], 'anorganik');
      expect(map['waste_type'], 'battery');
      expect(map['confidence'], 0.95);
      expect(map['is_uncertain'], 0);
      expect(map['item_name'], 'Baterai Bekas');
      expect(map['points_earned'], 15);
      expect(map['image_path'], '/path/to/image.jpg');
      expect(map['created_at'], date.millisecondsSinceEpoch);

      final newEntry = HistoryEntry.fromMap(map);

      expect(newEntry.id, entry.id);
      expect(newEntry.scanKey, entry.scanKey);
      expect(newEntry.wasteType, equals(WasteType.battery));
      expect(newEntry.category, equals(WasteCategory.anorganik));
      expect(newEntry.isHazardous, isTrue);
      expect(newEntry.confidence, entry.confidence);
      expect(newEntry.isUncertain, entry.isUncertain);
      expect(newEntry.itemName, entry.itemName);
      expect(newEntry.pointsEarned, entry.pointsEarned);
      expect(newEntry.imagePath, entry.imagePath);
      expect(newEntry.createdAt.millisecondsSinceEpoch, entry.createdAt.millisecondsSinceEpoch);
    });

    test('Data lama dengan waste_type null tetap membaca category tersimpan', () {
      final date = DateTime.now();
      final legacyMap = {
        'id': 99,
        'scan_key': 'legacy_key',
        'category': 'organik',
        'waste_type': null,
        'confidence': 0.88,
        'is_uncertain': 0,
        'item_name': 'Sisa Sayur',
        'points_earned': 10,
        'image_path': null,
        'created_at': date.millisecondsSinceEpoch,
      };

      final legacyEntry = HistoryEntry.fromMap(legacyMap);

      expect(legacyEntry.wasteType, isNull);
      expect(legacyEntry.category, equals(WasteCategory.organik));
      expect(legacyEntry.isHazardous, isFalse);
      expect(legacyEntry.itemName, equals('Sisa Sayur'));
    });
  });
}
