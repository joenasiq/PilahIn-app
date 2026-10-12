import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilahin_app/core/waste/waste_types.dart';
import 'package:pilahin_app/features/result/data/guidance_content.dart';

void main() {
  group('GuidanceContent Unit Tests', () {
    test('Semua 12 jenis sampah memiliki konten lengkap', () {
      expect(WasteType.values.length, 12);

      for (final type in WasteType.values) {
        final guidance = GuidanceContent.getGuidance(type);

        // Judul & Deskripsi tidak kosong
        expect(guidance.title.isNotEmpty, isTrue, reason: 'Title kosong untuk $type');
        expect(guidance.description.isNotEmpty, isTrue, reason: 'Deskripsi kosong untuk $type');

        // Ringkasan tepat 3 poin
        expect(
          guidance.summaryPoints.length,
          3,
          reason: 'summaryPoints harus tepat 3 poin untuk $type',
        );

        // Langkah pengolahan 4 sampai 5 langkah
        expect(
          guidance.steps.length >= 4 && guidance.steps.length <= 5,
          isTrue,
          reason: 'Langkah harus berjumlah 4-5 untuk $type (ditemukan: ${guidance.steps.length})',
        );
        for (final step in guidance.steps) {
          expect(step.title.isNotEmpty, isTrue, reason: 'Judul langkah kosong pada $type');
          expect(step.description.isNotEmpty, isTrue, reason: 'Deskripsi langkah kosong pada $type');
        }

        // Boleh dilakukan: 2-3 poin
        expect(
          guidance.doList.length >= 2 && guidance.doList.length <= 3,
          isTrue,
          reason: 'doList harus 2-3 poin untuk $type (ditemukan: ${guidance.doList.length})',
        );

        // Hindari: 2-3 poin
        expect(
          guidance.dontList.length >= 2 && guidance.dontList.length <= 3,
          isTrue,
          reason: 'dontList harus 2-3 poin untuk $type (ditemukan: ${guidance.dontList.length})',
        );

        // Ide pemanfaatan kembali: 0-3 poin
        expect(
          guidance.reuseIdeas.length <= 3,
          isTrue,
          reason: 'reuseIdeas maksimal 3 untuk $type',
        );
      }
    });

    test('TIDAK ADA teks yang mengandung kata organik atau anorganik di seluruh konten panduan', () {
      void checkText(String text, String fieldName, WasteType type) {
        final lower = text.toLowerCase();
        expect(
          lower.contains('organik'),
          isFalse,
          reason: 'Ditemukan kata "organik" pada $type field $fieldName: "$text"',
        );
        expect(
          lower.contains('anorganik'),
          isFalse,
          reason: 'Ditemukan kata "anorganik" pada $type field $fieldName: "$text"',
        );
      }

      for (final type in WasteType.values) {
        final g = GuidanceContent.getGuidance(type);

        checkText(g.title, 'title', type);
        checkText(g.description, 'description', type);

        for (var i = 0; i < g.summaryPoints.length; i++) {
          checkText(g.summaryPoints[i], 'summaryPoints[$i]', type);
        }

        for (var i = 0; i < g.steps.length; i++) {
          checkText(g.steps[i].title, 'steps[$i].title', type);
          checkText(g.steps[i].description, 'steps[$i].description', type);
        }

        for (var i = 0; i < g.doList.length; i++) {
          checkText(g.doList[i], 'doList[$i]', type);
        }

        for (var i = 0; i < g.dontList.length; i++) {
          checkText(g.dontList[i], 'dontList[$i]', type);
        }

        for (var i = 0; i < g.reuseIdeas.length; i++) {
          checkText(g.reuseIdeas[i], 'reuseIdeas[$i]', type);
        }
      }
    });

    test('Helper getWasteBinInfo menurunkan warna dan tempat sampah dengan benar', () {
      // 1. Jenis berbahaya (B3) -> merah dengan teks "tempat khusus limbah B3"
      final batteryBin = getWasteBinInfo(WasteType.battery);
      expect(batteryBin.color, Colors.red);
      expect(batteryBin.binName, 'tempat khusus limbah B3');
      expect(batteryBin.actionText, 'Buang ke: tempat khusus limbah B3');

      // 2. Kategori organik -> hijau
      final biologicalBin = getWasteBinInfo(WasteType.biological);
      expect(biologicalBin.color, Colors.green);
      expect(biologicalBin.binName, 'tempat sampah hijau');
      expect(biologicalBin.actionText, 'Buang ke: tempat sampah hijau');

      // 3. Kategori anorganik -> kuning
      final cardboardBin = getWasteBinInfo(WasteType.cardboard);
      expect(cardboardBin.color, const Color(0xFFF57F17));
      expect(cardboardBin.binName, 'tempat sampah kuning');
      expect(cardboardBin.actionText, 'Buang ke: tempat sampah kuning');

      final plasticBin = getWasteBinInfo(WasteType.plastic);
      expect(plasticBin.binName, 'tempat sampah kuning');

      final metalBin = getWasteBinInfo(WasteType.metal);
      expect(metalBin.binName, 'tempat sampah kuning');
    });
  });
}
