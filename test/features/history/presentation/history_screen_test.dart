import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pilahin_app/core/waste/waste_types.dart';
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

  testWidgets('HistoryScreen shows title from wasteType and B3 badge', (WidgetTester tester) async {
    final repo = FakeHistoryRepository();
    await repo.add(HistoryEntry(
      scanKey: 'key1',
      wasteType: WasteType.cardboard,
      confidence: 0.942,
      isUncertain: false,
      pointsEarned: 20,
      createdAt: DateTime(2026, 9, 18, 14, 30),
    ));
    await repo.add(HistoryEntry(
      scanKey: 'key2',
      wasteType: WasteType.battery,
      confidence: 0.885,
      isUncertain: false,
      pointsEarned: 20,
      createdAt: DateTime(2026, 9, 18, 15, 0),
    ));

    await tester.pumpWidget(createWidgetUnderTest(repo));
    await tester.pumpAndSettle();

    expect(find.text('Kardus'), findsOneWidget);
    expect(find.text('Baterai'), findsOneWidget);
    expect(find.text('B3'), findsOneWidget); // Tag B3 untuk baterai
    expect(find.text('94,2%'), findsOneWidget);
  });

  testWidgets('HistoryScreen fallback untuk baris lama tanpa jenis sampah', (WidgetTester tester) async {
    final repo = FakeHistoryRepository();
    // Legacy entries (wasteType = null)
    await repo.add(HistoryEntry(
      scanKey: 'legacy_org',
      category: WasteCategory.organik,
      confidence: 0.9,
      isUncertain: false,
      pointsEarned: 10,
      createdAt: DateTime.now(),
    ));
    await repo.add(HistoryEntry(
      scanKey: 'legacy_anorg',
      category: WasteCategory.anorganik,
      confidence: 0.85,
      isUncertain: false,
      pointsEarned: 10,
      createdAt: DateTime.now(),
    ));

    await tester.pumpWidget(createWidgetUnderTest(repo));
    await tester.pumpAndSettle();

    expect(find.text('Sampah Organik'), findsOneWidget);
    expect(find.text('Sampah Anorganik'), findsOneWidget);
  });

  testWidgets('HistoryScreen filter jenis membuka bottom sheet dan memfilter list', (WidgetTester tester) async {
    final repo = FakeHistoryRepository();
    await repo.add(HistoryEntry(
      scanKey: 'key1',
      wasteType: WasteType.cardboard,
      confidence: 0.94,
      isUncertain: false,
      pointsEarned: 20,
      createdAt: DateTime.now(),
    ));
    await repo.add(HistoryEntry(
      scanKey: 'key2',
      wasteType: WasteType.biological,
      confidence: 0.92,
      isUncertain: false,
      pointsEarned: 20,
      createdAt: DateTime.now(),
    ));

    await tester.pumpWidget(createWidgetUnderTest(repo));
    await tester.pumpAndSettle();

    expect(find.text('Kardus'), findsOneWidget);
    expect(find.text('Biologis'), findsOneWidget);

    // Tap chip "Jenis"
    await tester.tap(find.text('Jenis'));
    await tester.pumpAndSettle();

    // Bottom sheet muncul
    expect(find.text('Pilih Jenis Sampah'), findsOneWidget);
    expect(find.text('Semua jenis'), findsOneWidget);

    // Pilih Kardus di dalam bottom sheet
    final kardusOption = find.widgetWithText(ListTile, 'Kardus');
    await tester.ensureVisible(kardusOption);
    await tester.tap(kardusOption);
    await tester.pumpAndSettle();

    // Chip kini aktif dengan label "Jenis: Kardus"
    expect(find.text('Jenis: Kardus'), findsOneWidget);
    expect(find.text('Kardus'), findsOneWidget);
    expect(find.text('Biologis'), findsNothing);

    // Hapus filter jenis via delete icon
    await tester.tap(find.byTooltip('Hapus filter jenis'));
    await tester.pumpAndSettle();

    // Kembali menampilkan keduanya
    expect(find.text('Jenis'), findsOneWidget);
    expect(find.text('Kardus'), findsOneWidget);
    expect(find.text('Biologis'), findsOneWidget);
  });

  testWidgets('HistoryScreen filter gabungan kategori dan jenis (AND) & state Tidak ditemukan', (WidgetTester tester) async {
    final repo = FakeHistoryRepository();
    await repo.add(HistoryEntry(
      scanKey: 'key1',
      wasteType: WasteType.cardboard, // Anorganik
      confidence: 0.94,
      isUncertain: false,
      pointsEarned: 20,
      createdAt: DateTime.now(),
    ));

    await tester.pumpWidget(createWidgetUnderTest(repo));
    await tester.pumpAndSettle();

    // Pilih filter Organik (sementara item adalah Kardus yang Anorganik)
    await tester.tap(find.text('Organik'));
    await tester.pumpAndSettle();

    // Karena Kardus anorganik, kategori Organik menghasilkan kosong -> Tidak ditemukan
    expect(find.text('Tidak ditemukan'), findsOneWidget);

    // Kembali ke Semua
    await tester.tap(find.text('Semua'));
    await tester.pumpAndSettle();
    expect(find.text('Kardus'), findsOneWidget);
  });

  testWidgets('HistoryScreen pencarian mencocokkan nama jenis dan labelKey dataset', (WidgetTester tester) async {
    final repo = FakeHistoryRepository();
    await repo.add(HistoryEntry(
      scanKey: 'key1',
      wasteType: WasteType.cardboard, // labelKey: "cardboard", displayName: "Kardus"
      confidence: 0.94,
      isUncertain: false,
      pointsEarned: 20,
      createdAt: DateTime.now(),
    ));
    await repo.add(HistoryEntry(
      scanKey: 'key2',
      wasteType: WasteType.biological, // labelKey: "biological", displayName: "Biologis"
      confidence: 0.92,
      isUncertain: false,
      pointsEarned: 20,
      createdAt: DateTime.now(),
    ));

    await tester.pumpWidget(createWidgetUnderTest(repo));
    await tester.pumpAndSettle();

    // Cari dengan nama jenis bahasa Indonesia: "kardus"
    await tester.enterText(find.byType(TextField), 'kardus');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('Kardus'), findsOneWidget);
    expect(find.text('Biologis'), findsNothing);

    // Cari dengan labelKey dataset: "biological"
    await tester.enterText(find.byType(TextField), 'biological');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('Kardus'), findsNothing);
    expect(find.text('Biologis'), findsOneWidget);
  });
}
