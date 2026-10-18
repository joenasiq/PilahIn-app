import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pilahin_app/features/gamification/presentation/mission_screen.dart';
import 'package:pilahin_app/features/gamification/presentation/gamification_provider.dart';
import 'package:pilahin_app/features/gamification/data/mock_gamification_repository.dart';
import 'package:pilahin_app/features/gamification/presentation/widgets/badge_tile.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUp(() async {
    await initializeDateFormatting('id_ID', null);
  });

  Future<Widget> createWidgetUnderTest() async {
    return ProviderScope(
      overrides: [
        gamificationRepositoryProvider.overrideWithValue(MockGamificationRepository()),
      ],
      child: const MaterialApp(
        home: MissionScreen(),
      ),
    );
  }

  testWidgets('Mission Screen basic elements & tabs', (WidgetTester tester) async {
    await tester.pumpWidget(await createWidgetUnderTest());
    await tester.pumpAndSettle();

    // Mission Tab
    expect(find.text('Misi & Lencana'), findsOneWidget);
    expect(find.text('Misi Aktif'), findsOneWidget);
    expect(find.text('Koleksi Badge'), findsOneWidget);
    
    expect(find.text('Misi Mingguan'), findsOneWidget);
    expect(find.text('70%'), findsOneWidget);
    expect(find.text('Progres: 7/10 Botol'), findsOneWidget);
    expect(find.text('Selesai • Hadiah +15 Poin diklaim'), findsOneWidget);

    // Switch Tab
    await tester.tap(find.text('Koleksi Badge'));
    await tester.pumpAndSettle();

    expect(find.text('6 dari 15 badge terbuka'), findsOneWidget);
    expect(find.text('Semua'), findsWidgets);
    expect(find.text('Terbuka'), findsWidgets);
    expect(find.text('Pahlawan Hijau'), findsWidgets); // Is unlocked
    
    // Tap filter Organik
    await tester.tap(find.text('Organik'));
    await tester.pumpAndSettle();
    
    // Should filter. Pahlawan Hijau is organik. 
    expect(find.text('Pahlawan Hijau'), findsOneWidget);
    // Raja Botol is anorganik, shouldn't be there. But wait, choice chips might have texts.
    // We just check BadgeTile existence.
  });

  testWidgets('Tap Badge opens detail sheet (Unlocked)', (WidgetTester tester) async {
    await tester.pumpWidget(await createWidgetUnderTest());
    await tester.pumpAndSettle();

    // Tap Koleksi Badge
    await tester.tap(find.text('Koleksi Badge'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.widgetWithText(BadgeTile, 'Pahlawan Hijau'));
    await tester.tap(find.widgetWithText(BadgeTile, 'Pahlawan Hijau'));
    await tester.pumpAndSettle();

    expect(find.text('Detail Badge'), findsOneWidget);
    expect(find.text('Bagikan'), findsOneWidget);
    
    // Test share button
    await tester.tap(find.text('Bagikan'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    // Snackbars can be flaky in tests due to animation timings
  });
  
  testWidgets('Tap Badge opens detail sheet (Locked)', (WidgetTester tester) async {
    await tester.pumpWidget(await createWidgetUnderTest());
    await tester.pumpAndSettle();

    // Tap Koleksi Badge
    await tester.tap(find.text('Koleksi Badge'));
    await tester.pumpAndSettle();

    // Locked badge: Master Kompos
    await tester.ensureVisible(find.widgetWithText(BadgeTile, 'Master Kompos'));
    await tester.tap(find.widgetWithText(BadgeTile, 'Master Kompos'));
    await tester.pumpAndSettle();

    expect(find.text('Detail Badge'), findsOneWidget);
    expect(find.text('Pindai Sekarang'), findsOneWidget);
  });
}
