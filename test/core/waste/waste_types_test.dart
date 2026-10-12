import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilahin_app/core/waste/waste_types.dart';
import 'package:pilahin_app/features/scan/domain/waste_category.dart';

void main() {
  group('WasteType Unit Tests', () {
    test('Semua 12 jenis lengkap dengan nama, ikon, dan kategori', () {
      expect(WasteType.values.length, equals(12));

      for (final type in WasteType.values) {
        expect(type.labelKey.isNotEmpty, isTrue, reason: '${type.name} labelKey tidak boleh kosong');
        expect(type.displayName.isNotEmpty, isTrue, reason: '${type.name} displayName tidak boleh kosong');
        expect(type.icon, isA<IconData>(), reason: '${type.name} harus memiliki ikon Material');
      }
    });

    test('Hanya jenis "biologis" yang berkategori organik', () {
      final organicTypes = WasteType.values.where((t) => t.category == WasteCategory.organik).toList();
      expect(organicTypes.length, equals(1));
      expect(organicTypes.first, equals(WasteType.biological));

      final inorganicTypes = WasteType.values.where((t) => t.category == WasteCategory.anorganik).toList();
      expect(inorganicTypes.length, equals(11));
    });

    test('Hanya jenis "baterai" yang berbahaya (B3)', () {
      final hazardousTypes = WasteType.values.where((t) => t.isHazardous).toList();
      expect(hazardousTypes.length, equals(1));
      expect(hazardousTypes.first, equals(WasteType.battery));
      expect(hazardousTypes.first.isHazardous, isTrue);

      final nonHazardous = WasteType.values.where((t) => !t.isHazardous).toList();
      expect(nonHazardous.length, equals(11));
    });

    test('Kategori turunan dari jenis sampah benar', () {
      expect(WasteType.cardboard.category, equals(WasteCategory.anorganik));
      expect(WasteType.biological.category, equals(WasteCategory.organik));
      expect(WasteType.battery.category, equals(WasteCategory.anorganik));
      expect(WasteType.plastic.category, equals(WasteCategory.anorganik));
      expect(WasteType.paper.category, equals(WasteCategory.anorganik));
      expect(WasteType.metal.category, equals(WasteCategory.anorganik));
      expect(WasteType.brownGlass.category, equals(WasteCategory.anorganik));
      expect(WasteType.greenGlass.category, equals(WasteCategory.anorganik));
      expect(WasteType.whiteGlass.category, equals(WasteCategory.anorganik));
      expect(WasteType.clothes.category, equals(WasteCategory.anorganik));
      expect(WasteType.shoes.category, equals(WasteCategory.anorganik));
      expect(WasteType.trash.category, equals(WasteCategory.anorganik));
    });

    test('Pencarian labelKey melalui fromLabelKey dan findWasteTypeByLabelKey', () {
      final datasetKeys = {
        'battery': WasteType.battery,
        'biological': WasteType.biological,
        'brown-glass': WasteType.brownGlass,
        'cardboard': WasteType.cardboard,
        'clothes': WasteType.clothes,
        'green-glass': WasteType.greenGlass,
        'metal': WasteType.metal,
        'paper': WasteType.paper,
        'plastic': WasteType.plastic,
        'shoes': WasteType.shoes,
        'trash': WasteType.trash,
        'white-glass': WasteType.whiteGlass,
      };

      datasetKeys.forEach((key, expectedType) {
        expect(WasteType.fromLabelKey(key), equals(expectedType));
        expect(findWasteTypeByLabelKey(key), equals(expectedType));
        // Case-insensitive test
        expect(WasteType.fromLabelKey(key.toUpperCase()), equals(expectedType));
      });

      // Unknown key
      expect(WasteType.fromLabelKey('unknown_key'), isNull);
      expect(findWasteTypeByLabelKey('unknown_key'), isNull);
    });
  });
}
