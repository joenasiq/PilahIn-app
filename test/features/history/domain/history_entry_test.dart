import 'package:flutter_test/flutter_test.dart';
import 'package:pilahin_app/features/history/domain/history_entry.dart';
import 'package:pilahin_app/features/scan/domain/waste_category.dart';

void main() {
  group('HistoryEntry', () {
    test('toMap and fromMap should map correctly', () {
      final date = DateTime.now();
      final entry = HistoryEntry(
        id: 1,
        scanKey: 'test_key',
        category: WasteCategory.organik,
        confidence: 0.95,
        isUncertain: false,
        itemName: 'Daun',
        pointsEarned: 15,
        imagePath: '/path/to/image.jpg',
        createdAt: date,
      );

      final map = entry.toMap();

      expect(map['id'], 1);
      expect(map['scan_key'], 'test_key');
      expect(map['category'], 'organik');
      expect(map['confidence'], 0.95);
      expect(map['is_uncertain'], 0);
      expect(map['item_name'], 'Daun');
      expect(map['points_earned'], 15);
      expect(map['image_path'], '/path/to/image.jpg');
      expect(map['created_at'], date.millisecondsSinceEpoch);

      final newEntry = HistoryEntry.fromMap(map);

      expect(newEntry.id, entry.id);
      expect(newEntry.scanKey, entry.scanKey);
      expect(newEntry.category, entry.category);
      expect(newEntry.confidence, entry.confidence);
      expect(newEntry.isUncertain, entry.isUncertain);
      expect(newEntry.itemName, entry.itemName);
      expect(newEntry.pointsEarned, entry.pointsEarned);
      expect(newEntry.imagePath, entry.imagePath);
      // Precision loss in SQLite is just ms, so they should be equal
      expect(newEntry.createdAt.millisecondsSinceEpoch, entry.createdAt.millisecondsSinceEpoch);
    });
  });
}
