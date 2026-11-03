import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pilahin_app/core/waste/waste_types.dart';
import 'package:pilahin_app/features/auth/presentation/auth_controller.dart';
import 'package:pilahin_app/features/gamification/data/mock_gamification_repository.dart';
import 'package:pilahin_app/features/gamification/presentation/gamification_provider.dart';
import 'package:pilahin_app/features/gamification/presentation/mission_screen.dart';
import 'package:pilahin_app/features/gamification/presentation/widgets/badge_tile.dart';
import 'package:pilahin_app/features/history/domain/history_entry.dart';
import 'package:pilahin_app/features/history/presentation/history_provider.dart';

import '../../history/helpers/fake_history_repository.dart';

void main() {
  setUp(() async {
    await initializeDateFormatting('id_ID', null);
  });

  Future<Widget> createWidgetUnderTest({
    FakeHistoryRepository? repository,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final router = GoRouter(
      initialLocation: '/profile/misi',
      routes: [
        GoRoute(
          path: '/profile/misi',
          builder: (context, state) => const MissionScreen(),
        ),
        GoRoute(
          path: '/scan',
          builder: (context, state) =>
              const Scaffold(body: Text('Halaman Pindai')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        gamificationRepositoryProvider.overrideWithValue(
          MockGamificationRepository(),
        ),
        sharedPreferencesProvider.overrideWithValue(prefs),
        currentUserIdProvider.overrideWithValue('user_1'),
        historyRepositoryProvider.overrideWithValue(
          repository ?? FakeHistoryRepository(),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  testWidgets('Mission Screen menampilkan misi harian & mingguan dinamis', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(await createWidgetUnderTest());
    await tester.pumpAndSettle();

    expect(find.text('Misi & Lencana'), findsOneWidget);
    expect(find.text('Misi Aktif'), findsOneWidget);
    expect(find.text('Koleksi Badge'), findsOneWidget);

    // Misi harian dari template, progres awal 0 karena riwayat kosong.
    expect(find.text('Misi Harian'), findsOneWidget);
    expect(find.text('Pilah 3 Sampah Organik'), findsOneWidget);
    expect(find.text('Pindai Kulit Pisang Pertama'), findsOneWidget);
    expect(find.text('Progres: 0/3 Sampah'), findsOneWidget);
    // Deskripsi singkat tiap misi harian tampil.
    expect(
      find.text('Pindai 3 sampah organik seperti sisa makanan atau daun.'),
      findsOneWidget,
    );
    expect(
      find.text('Pindai satu sampah biologis, misalnya kulit pisang.'),
      findsOneWidget,
    );
    // Tombol untuk menjalankan misi harian.
    expect(find.text('Mulai Misi'), findsWidgets);

    // Misi mingguan juga tampil.
    expect(find.text('Misi Mingguan'), findsOneWidget);
    expect(find.text('Deteksi 10 Botol Plastik'), findsOneWidget);
    expect(find.text('Coba 5 Sub-kategori Berbeda'), findsOneWidget);
  });

  testWidgets('Tombol Mulai Misi membuka halaman Pindai', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(await createWidgetUnderTest());
    await tester.pumpAndSettle();

    final startButton = find.widgetWithText(OutlinedButton, 'Mulai Misi').first;
    await tester.ensureVisible(startButton);
    await tester.tap(startButton);
    await tester.pumpAndSettle();

    expect(find.text('Halaman Pindai'), findsOneWidget);
  });

  testWidgets('Progres misi mengikuti riwayat dan bisa diklaim', (
    WidgetTester tester,
  ) async {
    final repository = FakeHistoryRepository();
    final now = DateTime.now();
    for (var i = 0; i < 3; i++) {
      await repository.add(
        HistoryEntry(
          scanKey: 'organic_$i',
          userId: 'user_1',
          wasteType: WasteType.biological,
          confidence: 0.9,
          isUncertain: false,
          pointsEarned: 10,
          createdAt: now.subtract(Duration(minutes: i)),
        ),
      );
    }

    await tester.pumpWidget(
      await createWidgetUnderTest(repository: repository),
    );
    await tester.pumpAndSettle();

    // Misi organik 3/3 selesai dan menampilkan tombol klaim.
    expect(find.text('Progres: 3/3 Sampah'), findsOneWidget);
    expect(find.text('Klaim Hadiah'), findsWidgets);

    final claimButton = find
        .widgetWithText(ElevatedButton, 'Klaim Hadiah')
        .first;
    await tester.ensureVisible(claimButton);
    await tester.tap(claimButton);
    await tester.pumpAndSettle();

    // Setelah klaim, status berubah dan tombol hilang untuk misi tersebut.
    expect(find.textContaining('Hadiah misi diklaim'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('Selesai • Hadiah +30 Poin diklaim'), findsOneWidget);
  });

  testWidgets('Tap Badge opens detail sheet (Unlocked)', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(await createWidgetUnderTest());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Koleksi Badge'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.widgetWithText(BadgeTile, 'Pahlawan Hijau'),
    );
    await tester.tap(find.widgetWithText(BadgeTile, 'Pahlawan Hijau'));
    await tester.pumpAndSettle();

    expect(find.text('Detail Badge'), findsOneWidget);
    expect(find.text('Bagikan'), findsOneWidget);

    await tester.tap(find.text('Bagikan'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('Tap Badge opens detail sheet (Locked)', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(await createWidgetUnderTest());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Koleksi Badge'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.widgetWithText(BadgeTile, 'Master Kompos'));
    await tester.tap(find.widgetWithText(BadgeTile, 'Master Kompos'));
    await tester.pumpAndSettle();

    expect(find.text('Detail Badge'), findsOneWidget);
    expect(find.text('Pindai Sekarang'), findsOneWidget);
  });
}
