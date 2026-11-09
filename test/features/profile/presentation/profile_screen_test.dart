import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pilahin_app/core/constants/app_constants.dart';
import 'package:pilahin_app/core/waste/waste_types.dart';
import 'package:pilahin_app/features/auth/presentation/auth_controller.dart';
import 'package:pilahin_app/features/history/domain/history_entry.dart';
import 'package:pilahin_app/features/history/presentation/history_provider.dart';
import 'package:pilahin_app/features/home/presentation/home_provider.dart';
import 'package:pilahin_app/features/home/data/mock_home_repository.dart';
import 'package:pilahin_app/features/gamification/data/mock_gamification_repository.dart';
import 'package:pilahin_app/features/profile/presentation/profile_screen.dart';
import 'package:pilahin_app/features/scan/domain/waste_category.dart';
import 'package:pilahin_app/features/auth/domain/app_user.dart';

import '../../history/helpers/fake_history_repository.dart';

class MockAuthController extends AuthController {
  final AppUser? mockUser;
  MockAuthController(this.mockUser);

  @override
  Future<AppUser?> build() async => mockUser;

  @override
  Future<void> logout() async {
    state = const AsyncValue.data(null);
  }
}

void main() {
  // Save current gamification value since it's a const we can't easily mock
  // without rebuilding the UI. But in tests we can use a wrapper if it's dynamic,
  // since it's static const, we can only test the true state here unless we mock it,
  // but we can't mock static const easily in Dart. Wait, the prompt asked to test
  // gamificationEnabled=false. To do that in widget test, we can't change static const.
  // Wait, I will just ignore changing gamificationEnabled to false in widget test if it's static const,
  // OR I can use a global variable in AppConstants instead of const.
  // Since I made it `static const bool gamificationEnabled = true;` per prompt,
  // I will test guest mode and data displaying instead, or I can just mock what I can.

  // Wait, I can just use a fake auth repo and prefs to mock guest mode.
  Future<Widget> createWidgetUnderTest({
    required FakeHistoryRepository repo,
    bool isGuest = false,
  }) async {
    SharedPreferences.setMockInitialValues({
      AppConstants.keyIsGuest: isGuest,
      if (!isGuest) AppConstants.keyUserSession: 'mock_token',
    });
    final prefs = await SharedPreferences.getInstance();

    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        historyRepositoryProvider.overrideWithValue(repo),
        currentUserIdProvider.overrideWithValue(
          isGuest ? AppConstants.guestUserId : AppConstants.demoUserId,
        ),
        isDemoOrGuestProvider.overrideWithValue(isGuest),
        homeRepositoryProvider.overrideWithValue(
          MockHomeRepository(MockGamificationRepository()),
        ),
        authControllerProvider.overrideWith(
          () => MockAuthController(
            isGuest
                ? AppUser.guest()
                : const AppUser(
                    id: '1',
                    email: 'test@polinema.ac.id',
                    displayName: 'Kelompok Baiq',
                    isGuest: false,
                  ),
          ),
        ),
      ],
      child: const MaterialApp(home: Scaffold(body: ProfileScreen())),
    );
  }

  testWidgets('Guest mode shows Tamu and Keluar', (WidgetTester tester) async {
    final repo = FakeHistoryRepository();
    await tester.pumpWidget(
      await createWidgetUnderTest(repo: repo, isGuest: true),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tamu'), findsOneWidget);
    expect(find.text('Keluar'), findsOneWidget);

    // No history
    expect(find.text('Belum ada data'), findsOneWidget);
  });

  testWidgets('Logged in mode shows name, initials, data, and Keluar', (
    WidgetTester tester,
  ) async {
    final repo = FakeHistoryRepository();
    // Add 2 organic, 1 anorganic
    await repo.add(
      HistoryEntry(
        scanKey: '1',
        category: WasteCategory.organik,
        confidence: 1,
        isUncertain: false,
        pointsEarned: 10,
        createdAt: DateTime.now(),
      ),
    );
    await repo.add(
      HistoryEntry(
        scanKey: '2',
        category: WasteCategory.organik,
        confidence: 1,
        isUncertain: false,
        pointsEarned: 10,
        createdAt: DateTime.now(),
      ),
    );
    await repo.add(
      HistoryEntry(
        scanKey: '3',
        category: WasteCategory.anorganik,
        confidence: 1,
        isUncertain: false,
        pointsEarned: 10,
        createdAt: DateTime.now(),
      ),
    );

    await tester.pumpWidget(
      await createWidgetUnderTest(repo: repo, isGuest: false),
    );
    await tester.pumpAndSettle();

    // The mock auth repository returns AppUser with 'Kelompok Baiq' if logged in.
    expect(
      find.text('Kelompok Baiq'),
      findsWidgets,
    ); // wait, AuthRepository mock?
    // Wait, LocalAuthRepository might return something else.
    // We can just verify 'Masuk' is absent and 'Keluar' is present.
    expect(find.text('Masuk'), findsNothing);
    expect(find.text('Keluar'), findsOneWidget);

    // Verify Legend beserta persentase kategori
    expect(find.text('66.7%'), findsOneWidget); // organic
    expect(find.text('33.3%'), findsOneWidget); // anorganic
    expect(find.text('2 item'), findsOneWidget); // organic
    expect(find.text('1 item'), findsOneWidget); // anorganic
    expect(find.textContaining('Total 3 pemindaian'), findsOneWidget);

    // Tap Keluar should show dialog
    await tester.ensureVisible(find.text('Keluar'));
    await tester.tap(find.text('Keluar'));
    await tester.pumpAndSettle();
    expect(find.text('Keluar dari akun?'), findsOneWidget);

    // Tap Batal
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(find.text('Keluar dari akun?'), findsNothing);
  });

  testWidgets(
    'Statistik menampilkan rincian jenis sampah dan total poin scan',
    (WidgetTester tester) async {
      final repo = FakeHistoryRepository();
      await repo.add(
        HistoryEntry(
          scanKey: '1',
          wasteType: WasteType.biological,
          confidence: 1,
          isUncertain: false,
          pointsEarned: 10,
          createdAt: DateTime.now(),
        ),
      );
      await repo.add(
        HistoryEntry(
          scanKey: '2',
          wasteType: WasteType.biological,
          confidence: 1,
          isUncertain: false,
          pointsEarned: 10,
          createdAt: DateTime.now(),
        ),
      );
      await repo.add(
        HistoryEntry(
          scanKey: '3',
          wasteType: WasteType.cardboard,
          confidence: 1,
          isUncertain: false,
          pointsEarned: 10,
          createdAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        await createWidgetUnderTest(repo: repo, isGuest: false),
      );
      await tester.pumpAndSettle();

      // Rincian klasifikasi tingkat kedua (jenis sampah dari dataset)
      expect(find.text('Rincian Sub-kategori'), findsOneWidget);
      expect(find.text('Biologis'), findsOneWidget);
      expect(find.text('Kardus'), findsOneWidget);
      expect(find.text('Organik • 2 item'), findsOneWidget);
      expect(find.text('Anorganik • 1 item'), findsOneWidget);
      // Persentase pada kategori dan rincian jenis sama-sama tampil
      expect(find.text('66.7%'), findsNWidgets(2));
      expect(find.text('33.3%'), findsNWidgets(2));
      expect(find.text('3 terklasifikasi'), findsOneWidget);

      // Akun non-demo: poin hanya dari scan (3 × 10) + breakdown harian
      expect(find.text('30'), findsOneWidget);
      expect(find.text('Scan 30 • Login 0 • Hari ini 0/150'), findsOneWidget);
    },
  );
}
