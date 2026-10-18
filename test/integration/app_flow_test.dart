import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pilahin_app/app.dart';
import 'package:pilahin_app/core/constants/app_constants.dart';

import 'package:pilahin_app/features/auth/presentation/auth_controller.dart';
import 'package:pilahin_app/features/scan/presentation/scan_controller.dart';
import 'package:pilahin_app/features/gamification/presentation/gamification_provider.dart';
import 'package:pilahin_app/features/history/presentation/history_provider.dart';
import 'package:pilahin_app/features/scan/data/scan_camera_service.dart';
import 'package:pilahin_app/features/gamification/data/mock_gamification_repository.dart';

import '../features/history/helpers/fake_history_repository.dart';

// Fake ScanService
class FakeScanService implements ScanCameraService {
  bool get isInitialized => true;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<String?> takePicture() async {
    return 'fake_image.jpg';
  }

  Future<void> toggleFlash() async {}

  @override
  Future<void> setFlash(bool isFlashOn) async {}

  @override
  Widget getPreviewWidget() {
    return const SizedBox();
  }
}

void main() {
  late SharedPreferences prefs;

  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    final fakeHistoryRepo = FakeHistoryRepository();
    final fakeGamificationRepo = MockGamificationRepository();
    
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          scanCameraServiceProvider.overrideWithValue(FakeScanService()),
          historyRepositoryProvider.overrideWithValue(fakeHistoryRepo),
          gamificationRepositoryProvider.overrideWithValue(fakeGamificationRepo),
        ],
        child: const App(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 3)); // For splash screen
  }

  testWidgets('Alur 1: Buka -> Tamu -> Profil -> Keluar -> Login', (WidgetTester tester) async {
    await pumpApp(tester);
    
    // Login
    expect(find.text('Masuk Sebagai Tamu'), findsOneWidget);
    await tester.tap(find.text('Masuk Sebagai Tamu'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    // Beranda
    expect(find.text('Beranda'), findsWidgets);
    
    // Ke Profil
    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Tamu'), findsWidgets);
    
    // Logout
    final logoutFinder = find.text('Keluar').last;
    await tester.ensureVisible(logoutFinder);
    await tester.tap(logoutFinder);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    
    // Dialog Konfirmasi
    expect(find.text('Keluar dari akun?'), findsOneWidget);
    await tester.tap(find.text('Keluar').last); // The button
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    
    // Kembali ke login
    expect(find.text('Masuk Sebagai Tamu'), findsOneWidget);
  });

  testWidgets('Alur 2: Login -> Pindai -> Hasil -> Panduan -> Riwayat -> 1 entri', (WidgetTester tester) async {
    await pumpApp(tester);
    
    // Login
    await tester.enterText(find.byType(TextFormField).first, AppConstants.demoEmail);
    await tester.enterText(find.byType(TextFormField).last, AppConstants.demoPassword);
    await tester.tap(find.text('Masuk'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    // Pindai
    expect(find.text('Beranda'), findsWidgets); // Ensure we reached home
    await tester.tap(find.descendant(
      of: find.byType(BottomNavigationBar),
      matching: find.byIcon(Icons.crop_free),
    )); // Bottom Nav
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    
    // Ambil foto
    await tester.tap(find.bySemanticsLabel('Ambil foto'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2)); // Wait for analysis
    await tester.pumpAndSettle();
    
    // Hasil
    expect(find.text('Hasil Pemindaian'), findsWidgets);
    expect(find.text('Tidak ada gambar yang dipilih'), findsNothing);
    
    // Panduan Lengkap
    final panduanFinder = find.text('Panduan Lengkap');
    expect(panduanFinder, findsWidgets);
    await tester.ensureVisible(panduanFinder);
    await tester.tap(panduanFinder);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Panduan Pengelolaan'), findsWidgets); // Appbar title
    
    // Kembali ke hasil
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    
    // Kembali ke scan
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    
    // Beranda
    await tester.tap(find.byIcon(Icons.home_outlined));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    
    // Riwayat
    await tester.tap(find.byIcon(Icons.menu_book));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Riwayat Pemindaian'), findsWidgets);
    
    // Pastikan 1 entri tersimpan
    expect(find.byType(Card), findsWidgets);
  });

  testWidgets('Alur 3: Profil -> Misi -> Detail Badge -> Pindai Sekarang -> Tab Pindai', (WidgetTester tester) async {
    await pumpApp(tester);
    
    // Login as guest
    await tester.tap(find.text('Masuk Sebagai Tamu'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Go to Profile
    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Go to Misi & Lencana
    final misiFinder = find.text('Misi & Lencana');
    await tester.ensureVisible(misiFinder);
    await tester.tap(misiFinder);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Go to Koleksi Badge tab
    await tester.tap(find.text('Koleksi Badge'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Tap locked badge
    final masterKomposFinder = find.text('Master Kompos');
    await tester.ensureVisible(masterKomposFinder);
    await tester.tap(masterKomposFinder);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Detail Badge sheet
    expect(find.text('Terkunci'), findsWidgets);
    
    // Pindai Sekarang is inside the sheet
    final pindaiBtnFinder = find.widgetWithText(ElevatedButton, 'Pindai Sekarang');
    await tester.ensureVisible(pindaiBtnFinder);
    await tester.tap(pindaiBtnFinder);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    // Tab Pindai
    expect(find.text('Arahkan Kamera ke Sampah'), findsOneWidget);
  });

  testWidgets('Alur 4: Back sistem dari Pindai kembali ke Beranda', (WidgetTester tester) async {
    await pumpApp(tester);
    
    // Login as guest
    await tester.tap(find.text('Masuk Sebagai Tamu'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Go to Pindai
    await tester.tap(find.byIcon(Icons.crop_free).first);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Arahkan Kamera ke Sampah'), findsOneWidget);

    // Trigger system back pop
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter/navigation',
      const JSONMethodCodec().encodeMethodCall(const MethodCall('popRoute')),
      (_) {},
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Should be on Beranda
    expect(find.text('Beranda'), findsWidgets);
  });
}
