import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilahin_app/core/constants/app_constants.dart';
import 'package:pilahin_app/core/waste/waste_types.dart';
import 'package:pilahin_app/features/result/data/guidance_content.dart';
import 'package:pilahin_app/features/result/data/guidance_media.dart';
import 'package:pilahin_app/features/result/presentation/guidance_screen.dart';
import 'package:pilahin_app/features/result/presentation/result_screen.dart';
import 'package:pilahin_app/features/scan/domain/classification_result.dart';
import 'package:pilahin_app/features/scan/presentation/classification_controller.dart';

class MockClassificationController extends AsyncNotifier<ClassificationResult?>
    implements ClassificationController {
  final ClassificationResult? initialResult;
  MockClassificationController([this.initialResult]);

  @override
  Future<ClassificationResult?> build() async => initialResult;

  @override
  Future<void> classify(String imagePath) async {}
}

void main() {
  setUp(() {
    AppConstants.showMediaPlaceholders = true;
  });

  Widget createGuidanceTestWidget({
    required ClassificationResult result,
    GuidanceMediaResolver? resolver,
  }) {
    return ProviderScope(
      overrides: [
        if (resolver != null)
          guidanceMediaResolverProvider.overrideWithValue(resolver),
      ],
      child: MaterialApp(
        home: GuidanceScreen(result: result),
      ),
    );
  }

  group('GuidanceScreen Widget Tests', () {
    testWidgets('Panduan Kardus menampilkan langkah pengolahan dan kartu tempat sampah', (tester) async {
      final cardboardResult = ClassificationResult(
        wasteType: WasteType.cardboard,
        confidence: 0.95,
        imagePath: 'dummy.jpg',
        isUncertain: false,
        timestamp: DateTime.now(),
      );

      final fakeResolver = FakeGuidanceMediaResolver();

      await tester.pumpWidget(
        createGuidanceTestWidget(
          result: cardboardResult,
          resolver: fakeResolver,
        ),
      );
      await tester.pumpAndSettle();

      // Judul dan kartu tempat sampah
      expect(find.text('Kardus'), findsWidgets);
      expect(find.text('Buang ke: tempat sampah kuning'), findsOneWidget);

      // Bagian Cara Pengolahan dan langkah kardus
      expect(find.text('Cara Pengolahan'), findsOneWidget);
      expect(find.text('Buka dan Bersihkan'), findsOneWidget);
      expect(find.text('Pipihkan Kardus'), findsOneWidget);

      // Kartu Boleh dilakukan & Hindari
      expect(find.text('Boleh dilakukan'), findsOneWidget);
      expect(find.text('Hindari'), findsOneWidget);

      // Ide pemanfaatan kembali
      expect(find.text('Ide Pemanfaatan Kembali'), findsOneWidget);
    });

    testWidgets('Placeholder tampil saat media kosong dan flag true, tersembunyi saat false', (tester) async {
      final cardboardResult = ClassificationResult(
        wasteType: WasteType.cardboard,
        confidence: 0.95,
        imagePath: 'dummy.jpg',
        isUncertain: false,
        timestamp: DateTime.now(),
      );

      final emptyResolver = FakeGuidanceMediaResolver();

      // 1. Saat showMediaPlaceholders = true
      AppConstants.showMediaPlaceholders = true;
      await tester.pumpWidget(
        createGuidanceTestWidget(
          result: cardboardResult,
          resolver: emptyResolver,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Video panduan belum tersedia'), findsOneWidget);
      expect(find.text('Foto langkah belum tersedia'), findsWidgets);

      // 2. Saat showMediaPlaceholders = false
      AppConstants.showMediaPlaceholders = false;
      await tester.pumpWidget(
        createGuidanceTestWidget(
          result: cardboardResult,
          resolver: emptyResolver,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Video panduan belum tersedia'), findsNothing);
      expect(find.text('Foto langkah belum tersedia'), findsNothing);
    });

    testWidgets('Foto langkah tampil di langkah yang benar saat resolver menyediakan gambar', (tester) async {
      final cardboardResult = ClassificationResult(
        wasteType: WasteType.cardboard,
        confidence: 0.95,
        imagePath: 'dummy.jpg',
        isUncertain: false,
        timestamp: DateTime.now(),
      );

      final mockResolver = FakeGuidanceMediaResolver({
        WasteType.cardboard: const GuidanceMedia(
          stepImages: {
            1: 'assets/guidance/cardboard/step_1.jpg',
            // Langkah 2, 3, 4, 5 tidak ada foto
          },
        ),
      });

      await tester.pumpWidget(
        createGuidanceTestWidget(
          result: cardboardResult,
          resolver: mockResolver,
        ),
      );
      await tester.pumpAndSettle();

      // Terdapat widget gambar aset untuk langkah 1
      final imageFinder = find.byType(Image);
      expect(imageFinder, findsWidgets);

      // Langkah 1 memiliki indikator 'Ketuk untuk perbesar'
      expect(find.text('Ketuk untuk perbesar'), findsOneWidget);

      // Placeholder langkah tetap ada untuk langkah-langkah yang belum ada foto (jika flag true)
      expect(find.text('Foto langkah belum tersedia'), findsWidgets);
    });

    testWidgets('Banner peringatan B3 hanya muncul untuk baterai dan tidak muncul untuk jenis lain', (tester) async {
      final batteryResult = ClassificationResult(
        wasteType: WasteType.battery,
        confidence: 0.90,
        imagePath: 'dummy.jpg',
        isUncertain: false,
        timestamp: DateTime.now(),
      );

      final biologicalResult = ClassificationResult(
        wasteType: WasteType.biological,
        confidence: 0.90,
        imagePath: 'dummy.jpg',
        isUncertain: false,
        timestamp: DateTime.now(),
      );

      // 1. Tes Baterai -> Banner B3 muncul
      await tester.pumpWidget(createGuidanceTestWidget(result: batteryResult));
      await tester.pumpAndSettle();

      expect(find.text('Perhatian: Limbah Berbahaya (B3)'), findsOneWidget);
      expect(find.text('Buang ke: tempat khusus limbah B3'), findsOneWidget);

      // 2. Tes Biologis -> Banner B3 TIDAK muncul
      await tester.pumpWidget(createGuidanceTestWidget(result: biologicalResult));
      await tester.pumpAndSettle();

      expect(find.text('Perhatian: Limbah Berbahaya (B3)'), findsNothing);
      expect(find.text('Buang ke: tempat sampah hijau'), findsOneWidget);
    });
  });

  group('ResultScreen 3 Ringkasan Widget Tests', () {
    testWidgets('Layar Hasil menampilkan 3 ringkasan sesuai jenis yang terdeteksi', (tester) async {
      final batteryResult = ClassificationResult(
        wasteType: WasteType.battery,
        confidence: 0.89,
        imagePath: 'dummy.jpg',
        isUncertain: false,
        timestamp: DateTime.now(),
      );

      final batteryGuidance = GuidanceContent.getGuidance(WasteType.battery);

      final controller = MockClassificationController(batteryResult);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            classificationControllerProvider.overrideWith(() => controller),
          ],
          child: const MaterialApp(
            home: ResultScreen(imagePath: 'dummy.jpg'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Memeriksa ketiga poin ringkasan baterai tampil di layar hasil
      expect(batteryGuidance.summaryPoints.length, 3);
      for (final point in batteryGuidance.summaryPoints) {
        expect(find.text(point), findsOneWidget);
      }
    });
  });
}
