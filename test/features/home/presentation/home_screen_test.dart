import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pilahin_app/app.dart';
import 'package:pilahin_app/core/constants/app_constants.dart';
import 'package:pilahin_app/features/auth/presentation/auth_controller.dart';
import 'package:pilahin_app/features/scan/data/scan_camera_service.dart';
import 'package:pilahin_app/features/scan/data/gallery_picker_service.dart';
import 'package:pilahin_app/features/scan/presentation/scan_controller.dart';
import 'package:pilahin_app/features/history/presentation/history_provider.dart';
import '../../history/helpers/fake_history_repository.dart';
import 'package:pilahin_app/features/gamification/presentation/gamification_provider.dart';
import 'package:pilahin_app/features/gamification/data/mock_gamification_repository.dart';

class _MockCameraService implements ScanCameraService {
  @override Future<void> initialize() async {}
  @override Future<void> dispose() async {}
  @override Future<String?> takePicture() async => null;
  @override Future<void> setFlash(bool isFlashOn) async {}
  @override Widget getPreviewWidget() => const SizedBox();
}

class _MockGalleryService implements GalleryPickerService {
  @override Future<String?> pickImage() async => null;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      AppConstants.keyUserSession: true,
      AppConstants.keyIsGuest: false,
    });
  });

  Future<void> pumpApp(WidgetTester tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          scanCameraServiceProvider.overrideWithValue(_MockCameraService()),
          galleryPickerServiceProvider.overrideWithValue(_MockGalleryService()),
          historyRepositoryProvider.overrideWithValue(FakeHistoryRepository()),
          gamificationRepositoryProvider.overrideWithValue(MockGamificationRepository()),
        ],
        child: const App(),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('HomeScreen & Bottom Nav Tests', () {
    testWidgets('menampilkan data dummy di Beranda', (tester) async {
      await pumpApp(tester);
      
      // Pastikan berada di Beranda
      expect(find.text('Beranda'), findsWidgets);
      
      // Tunggu FutureProvider selesai
      await tester.pumpAndSettle();

      // Cek teks dari data dummy
      expect(find.textContaining('Level 3: Penyelamat Bumi'), findsOneWidget);
      expect(find.text('850 Poin'), findsOneWidget);
      expect(find.text('7 Hari Beruntun!'), findsOneWidget);
      expect(find.text('Pilah 3 Sampah Organik'), findsOneWidget);
    });

    testWidgets('navigasi ke Riwayat', (tester) async {
      await pumpApp(tester);
      await tester.pumpAndSettle();

      // Tap tombol Riwayat
      await tester.ensureVisible(find.text('Riwayat'));
      await tester.tap(find.text('Riwayat'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Harusnya tampil placeholder HistoryScreen atau riwayat
      expect(find.text('Riwayat Pemindaian'), findsWidgets);
    });

    testWidgets('pindah tab bottom nav menjaga state', (tester) async {
      await pumpApp(tester);
      await tester.pumpAndSettle();

      // Pindah ke tab Pindai
      await tester.tap(find.text('Pindai').last);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Tampil layar ScanScreen yang asli
      expect(find.text('Pindai Sampah'), findsWidgets);

      // Pindah ke tab Profil
      await tester.tap(find.text('Profil').last);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      
      expect(find.text('Keluar'), findsWidgets);
    });
  });
}
