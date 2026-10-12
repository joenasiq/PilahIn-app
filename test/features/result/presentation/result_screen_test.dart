import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pilahin_app/core/constants/ml_config.dart';
import 'package:pilahin_app/core/waste/waste_types.dart';
import 'package:pilahin_app/features/result/presentation/guidance_screen.dart';
import 'package:pilahin_app/features/result/presentation/result_screen.dart';
import 'package:pilahin_app/features/scan/domain/classification_result.dart';
import 'package:pilahin_app/features/scan/presentation/classification_controller.dart';

// Controller tiruan
class MockClassificationController extends AsyncNotifier<ClassificationResult?> implements ClassificationController {
  @override
  Future<ClassificationResult?> build() async => null;

  void setCardboard() {
    state = AsyncValue.data(
      ClassificationResult(
        wasteType: WasteType.cardboard,
        confidence: 0.942,
        imagePath: 'dummy.jpg',
        isUncertain: false,
        timestamp: DateTime.now(),
      ),
    );
  }

  void setBiological() {
    state = AsyncValue.data(
      ClassificationResult(
        wasteType: WasteType.biological,
        confidence: 0.927,
        imagePath: 'dummy.jpg',
        isUncertain: false,
        timestamp: DateTime.now(),
      ),
    );
  }

  void setBattery() {
    state = AsyncValue.data(
      ClassificationResult(
        wasteType: WasteType.battery,
        confidence: 0.885,
        imagePath: 'dummy.jpg',
        isUncertain: false,
        timestamp: DateTime.now(),
      ),
    );
  }

  void setUncertainPlastic() {
    state = AsyncValue.data(
      ClassificationResult(
        wasteType: WasteType.plastic,
        confidence: 0.48,
        imagePath: 'dummy.jpg',
        isUncertain: true,
        timestamp: DateTime.now(),
      ),
    );
  }

  void setOrganic() => setBiological();
  void setInorganic() => setCardboard();
  void setUncertain() => setUncertainPlastic();

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

  testWidgets('Menampilkan hasil cardboard: Anorganik dan chip Kardus', (tester) async {
    await tester.pumpWidget(createTestWidget(const ResultScreen(imagePath: 'dummy.jpg')));
    mockController.setCardboard();
    await tester.pumpAndSettle();

    expect(find.text('Anorganik'), findsOneWidget);
    expect(find.text('94.2%'), findsOneWidget);
    expect(find.text('Jenis sampah'), findsOneWidget);
    expect(find.text('Kardus'), findsOneWidget);
    expect(find.text('Limbah B3 • Berbahaya'), findsNothing);
  });

  testWidgets('Menampilkan hasil biological: Organik dan chip Biologis', (tester) async {
    await tester.pumpWidget(createTestWidget(const ResultScreen(imagePath: 'dummy.jpg')));
    mockController.setBiological();
    await tester.pumpAndSettle();

    expect(find.text('Organik'), findsOneWidget);
    expect(find.text('92.7%'), findsOneWidget);
    expect(find.text('Biologis'), findsOneWidget);
    expect(find.text('+15 Poin Pemindaian'), findsOneWidget);
    expect(find.text('Limbah B3 • Berbahaya'), findsNothing);
  });

  testWidgets('Menampilkan hasil battery: Anorganik dan chip B3', (tester) async {
    await tester.pumpWidget(createTestWidget(const ResultScreen(imagePath: 'dummy.jpg')));
    mockController.setBattery();
    await tester.pumpAndSettle();

    expect(find.text('Anorganik'), findsOneWidget);
    expect(find.text('88.5%'), findsOneWidget);
    expect(find.text('Baterai'), findsOneWidget);
    expect(find.text('Limbah B3 • Berbahaya'), findsOneWidget);
  });

  testWidgets('Menampilkan keadaan tidak yakin: Mungkin: Plastik dan banner', (tester) async {
    await tester.pumpWidget(createTestWidget(const ResultScreen(imagePath: 'dummy.jpg')));
    mockController.setUncertainPlastic();
    await tester.pumpAndSettle();

    expect(find.text('48.0%'), findsOneWidget);
    expect(find.text('Mungkin: Plastik'), findsOneWidget);
    expect(find.text('Hasil kurang yakin. Coba pindai ulang dengan pencahayaan lebih terang dan objek lebih dekat.'), findsOneWidget);
    expect(find.text('Pindai Ulang'), findsOneWidget);
  });

  testWidgets('Tombol Panduan Lengkap membuka layar panduan dengan nama jenis', (tester) async {
    await tester.pumpWidget(createTestWidget(const ResultScreen(imagePath: 'dummy.jpg')));
    mockController.setCardboard();
    await tester.pumpAndSettle();

    final btn = find.text('Panduan Lengkap');
    expect(btn, findsOneWidget);
    await tester.ensureVisible(btn);

    await tester.tap(btn);
    await tester.pumpAndSettle();

    // Harusnya masuk ke layar Panduan Pengelolaan
    expect(find.byType(GuidanceScreen), findsOneWidget);
    // Chip jenis dan judul menggunakan nama jenis: Kardus
    expect(find.text('Kardus'), findsWidgets);
    expect(find.text('Cara Pengolahan'), findsOneWidget);

    // Back
    final backBtn = find.byIcon(Icons.arrow_back).first;
    await tester.tap(backBtn);
    await tester.pumpAndSettle();

    expect(find.byType(ResultScreen), findsOneWidget);
  });
}
