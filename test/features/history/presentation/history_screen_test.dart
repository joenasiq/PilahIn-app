import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pilahin_app/features/history/domain/history_entry.dart';
import 'package:pilahin_app/features/history/presentation/history_provider.dart';
import 'package:pilahin_app/features/history/presentation/history_screen.dart';
import 'package:pilahin_app/features/scan/domain/waste_category.dart';

import '../helpers/fake_history_repository.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
  });

  Widget createWidgetUnderTest(FakeHistoryRepository repo) {
    return ProviderScope(
      overrides: [
        historyRepositoryProvider.overrideWithValue(repo),
      ],
      child: const MaterialApp(
        home: HistoryScreen(),
      ),
    );
  }

  testWidgets('HistoryScreen shows empty state initially', (WidgetTester tester) async {
    final repo = FakeHistoryRepository();
    await tester.pumpWidget(createWidgetUnderTest(repo));
    await tester.pumpAndSettle(); // Wait for data load

    expect(find.text('Belum ada riwayat pemindaian'), findsOneWidget);
    expect(find.text('Mulai Pindai'), findsOneWidget);
  });

  testWidgets('HistoryScreen shows list of entries', (WidgetTester tester) async {
    final repo = FakeHistoryRepository();
    await repo.add(HistoryEntry(
      scanKey: 'key1',
      category: WasteCategory.organik,
      confidence: 0.95,
      isUncertain: false,
      pointsEarned: 10,
      createdAt: DateTime(2026, 9, 18, 14, 30),
      itemName: 'Daun Pisang',
    ));
    await tester.pumpWidget(createWidgetUnderTest(repo));
    await tester.pumpAndSettle();

    expect(find.text('Daun Pisang'), findsOneWidget);
    expect(find.text('18 Sep 2026 • 14:30'), findsOneWidget);
    expect(find.text('95,0%'), findsOneWidget);
  });

  testWidgets('HistoryScreen filter and search', (WidgetTester tester) async {
    final repo = FakeHistoryRepository();
    await repo.add(HistoryEntry(
      scanKey: 'key1',
      category: WasteCategory.organik,
      confidence: 0.9,
      isUncertain: false,
      pointsEarned: 10,
      createdAt: DateTime.now(),
      itemName: 'Daun Pisang',
    ));
    await repo.add(HistoryEntry(
      scanKey: 'key2',
      category: WasteCategory.anorganik,
      confidence: 0.8,
      isUncertain: false,
      pointsEarned: 10,
      createdAt: DateTime.now(),
      itemName: 'Botol Plastik',
    ));

    await tester.pumpWidget(createWidgetUnderTest(repo));
    await tester.pumpAndSettle();

    expect(find.text('Daun Pisang'), findsOneWidget);
    expect(find.text('Botol Plastik'), findsOneWidget);

    // Filter Organik
    await tester.tap(find.text('Organik').first);
    await tester.pumpAndSettle();

    expect(find.text('Daun Pisang'), findsOneWidget);
    expect(find.text('Botol Plastik'), findsNothing);

    // Filter Semua
    await tester.tap(find.text('Semua'));
    await tester.pumpAndSettle();

    // Search
    await tester.enterText(find.byType(TextField), 'Botol');
    await tester.pump(const Duration(milliseconds: 350)); // Wait for debounce
    await tester.pumpAndSettle();

    expect(find.text('Daun Pisang'), findsNothing);
    expect(find.text('Botol Plastik'), findsOneWidget);

    // Not found
    await tester.enterText(find.byType(TextField), 'XYZ');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('Tidak ditemukan'), findsOneWidget);
  });
}
