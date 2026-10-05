import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pilahin_app/features/result/presentation/result_screen.dart';
import 'package:pilahin_app/features/result/presentation/guidance_screen.dart';
import 'package:pilahin_app/features/scan/domain/classification_result.dart';
import 'package:pilahin_app/features/scan/domain/waste_category.dart';
import 'package:pilahin_app/features/scan/presentation/classification_controller.dart';
import 'package:pilahin_app/core/constants/ml_config.dart';

// Controller tiruan
class MockClassificationController extends AsyncNotifier<ClassificationResult?> implements ClassificationController {
  @override
  Future<ClassificationResult?> build() async => null;

  void setOrganic() {
    state = AsyncValue.data(
      ClassificationResult(
        category: WasteCategory.organik,
        confidence: 0.927,
        imagePath: 'dummy.jpg',
        isUncertain: false,
        timestamp: DateTime.now(),
      ),
    );
  }

  void setInorganic() {
    state = AsyncValue.data(
      ClassificationResult(
        category: WasteCategory.anorganik,
        confidence: 0.912,
        imagePath: 'dummy.jpg',
        isUncertain: false,
        timestamp: DateTime.now(),
      ),
    );
  }

  void setUncertain() {
    state = AsyncValue.data(
      ClassificationResult(
        category: WasteCategory.organik,
        confidence: 0.48,
        imagePath: 'dummy.jpg',
        isUncertain: true,
        timestamp: DateTime.now(),
      ),
    );
  }

  void setErrorState() {
    state = AsyncValue.error('Gagal', StackTrace.empty);
  }

  @override
  Future<void> classify(String imagePath) async {}
}

void main() {
  late MockClassificationController mockController;

  setUp(() {
    mockController = MockClassificationController();
    MlConfig.showScanPoints = true; // reset
  });

  Widget createTestWidget(Widget child) {
    final router = GoRouter(
      initialLocation: '/scan/hasil',
      routes: [
        GoRoute(
          path: '/scan/hasil',
          builder: (context, state) => const ResultScreen(imagePath: 'dummy.jpg'),
        ),
        GoRoute(
          path: '/scan/panduan',
          builder: (context, state) {
            final result = state.extra as ClassificationResult?;
            return GuidanceScreen(result: result);
          },
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        classificationControllerProvider.overrideWith(() => mockController),
      ],
      child: MaterialApp.router(
        routerConfig: router,
      ),
    );
  }

  testWidgets('Menampilkan hasil Organik (92,7%) dengan pil poin', (tester) async {
    await tester.pumpWidget(createTestWidget(const ResultScreen(imagePath: 'dummy.jpg')));
    mockController.setOrganic();
    await tester.pumpAndSettle();

    expect(find.text('Organik'), findsOneWidget);
    expect(find.text('92.7%'), findsOneWidget);
    expect(find.text('+15 Poin Pemindaian'), findsOneWidget);
    expect(find.text('Tidak yakin dengan hasil klasifikasi ini.'), findsNothing);
  });

  testWidgets('Menyembunyikan pil poin jika showScanPoints=false', (tester) async {
    MlConfig.showScanPoints = false;
    await tester.pumpWidget(createTestWidget(const ResultScreen(imagePath: 'dummy.jpg')));
    mockController.setInorganic();
    await tester.pumpAndSettle();

    expect(find.text('Anorganik'), findsOneWidget);
    expect(find.text('91.2%'), findsOneWidget);
    expect(find.text('+15 Poin Pemindaian'), findsNothing);
  });

  testWidgets('Menampilkan banner tidak yakin jika isUncertain', (tester) async {
    await tester.pumpWidget(createTestWidget(const ResultScreen(imagePath: 'dummy.jpg')));
    mockController.setUncertain();
    await tester.pumpAndSettle();

    expect(find.text('48.0%'), findsOneWidget);
    expect(find.text('Hasil kurang yakin. Coba pindai ulang dengan pencahayaan lebih terang dan objek lebih dekat.'), findsOneWidget);
    expect(find.text('Pindai Ulang'), findsOneWidget);
  });

  testWidgets('Tombol Panduan Lengkap membuka konten kategori yang benar dan kembali', (tester) async {
    await tester.pumpWidget(createTestWidget(const ResultScreen(imagePath: 'dummy.jpg')));
    mockController.setOrganic();
    await tester.pumpAndSettle();

    // Pastikan tombol ada dan terlihat
    final btn = find.text('Panduan Lengkap');
    expect(btn, findsOneWidget);
    await tester.ensureVisible(btn);

    // Tap dan navigasi
    await tester.tap(btn);
    await tester.pumpAndSettle();

    // Harusnya masuk ke layar Panduan Pengelolaan
    expect(find.byType(GuidanceScreen), findsOneWidget);
    expect(find.text('Langkah Pengelolaan'), findsOneWidget);
    expect(find.text('Campurkan dengan daun kering dalam komposter'), findsOneWidget);

    // Back
    final backBtn = find.byIcon(Icons.arrow_back).first;
    await tester.tap(backBtn);
    await tester.pumpAndSettle();

    // Harusnya kembali ke ResultScreen tanpa berubah
    expect(find.byType(ResultScreen), findsOneWidget);
    expect(find.text('Organik'), findsOneWidget);
  });
}
