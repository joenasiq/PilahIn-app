import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pilahin_app/core/guest/guest_progress_store.dart';
import 'package:pilahin_app/core/waste/waste_types.dart';
import 'package:pilahin_app/features/history/data/guest_history_repository.dart';
import 'package:pilahin_app/features/history/domain/history_entry.dart';
import 'package:pilahin_app/features/scan/domain/waste_category.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GuestHistoryRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    repo = GuestHistoryRepository(GuestProgressStore(prefs));
  });

  HistoryEntry makeEntry(String scanKey, {WasteType? wasteType}) {
    return HistoryEntry(
      scanKey: scanKey,
      wasteType: wasteType,
      confidence: 0.9,
      isUncertain: false,
      pointsEarned: 20,
      createdAt: DateTime.now(),
    );
  }

  group('GuestHistoryRepository', () {
    test('add + getAll menyimpan scan tamu dengan id unik', () async {
      await repo.add(makeEntry('s1', wasteType: WasteType.plastic));
      await repo.add(makeEntry('s2', wasteType: WasteType.biological));

      final entries = await repo.getAll();
      expect(entries, hasLength(2));
      final ids = entries.map((e) => e.id).toSet();
      expect(ids.length, 2);
    });

    test('add idempoten berdasarkan scanKey', () async {
      await repo.add(makeEntry('s1', wasteType: WasteType.plastic));
      await repo.add(makeEntry('s1', wasteType: WasteType.plastic));
      expect(await repo.count(), 1);
    });

    test('delete menghapus berdasarkan id', () async {
      await repo.add(makeEntry('s1', wasteType: WasteType.plastic));
      await repo.add(makeEntry('s2', wasteType: WasteType.biological));
      final entries = await repo.getAll();
      await repo.delete(entries.first.id!);
      final rest = await repo.getAll();
      expect(rest, hasLength(1));
      expect(rest.single.scanKey, isNot(entries.first.scanKey));
    });

    test('restore mengembalikan entry yang dihapus', () async {
      await repo.add(makeEntry('s1', wasteType: WasteType.plastic));
      final entries = await repo.getAll();
      final entry = entries.single;
      await repo.delete(entry.id!);
      expect(await repo.count(), 0);

      await repo.restore(entry);
      expect(await repo.count(), 1);
      expect((await repo.getAll()).single.scanKey, 's1');
    });

    test('filter kategori dan userId tamu', () async {
      await repo.add(makeEntry('s1', wasteType: WasteType.plastic));
      await repo.add(makeEntry('s2', wasteType: WasteType.biological));

      final organik =
          await repo.getAll(category: WasteCategory.organik);
      expect(organik, hasLength(1));
      expect(organik.single.wasteType, WasteType.biological);

      // userId non-tamu tidak boleh melihat data tamu
      final others = await repo.getAll(userId: 'user_lain');
      expect(others, isEmpty);
    });

    test('countByCategory menghitung per kategori', () async {
      await repo.add(makeEntry('s1', wasteType: WasteType.plastic));
      await repo.add(makeEntry('s2', wasteType: WasteType.biological));
      await repo.add(makeEntry('s3', wasteType: WasteType.paper));

      final counts = await repo.countByCategory();
      expect(counts[WasteCategory.organik], 1);
      expect(counts[WasteCategory.anorganik], 2);
    });

    test('data persisten di SharedPreferences (simulasi restart app)',
        () async {
      await repo.add(makeEntry('s1', wasteType: WasteType.plastic));

      // Instance repository baru dari prefs yang sama = data masih ada.
      SharedPreferences.setMockInitialValues(
          await _dumpCurrent());
      final prefs = await SharedPreferences.getInstance();
      final repo2 = GuestHistoryRepository(GuestProgressStore(prefs));
      expect(await repo2.count(), 1);
    });
  });
}

/// Helper: tidak tersedia API dump bawaan; gunakan key yang sama dengan
/// store agar simulasi restart tetap konsisten.
Future<Map<String, Object>> _dumpCurrent() async {
  final prefs = await SharedPreferences.getInstance();
  return {'guest_scans_v1': prefs.getString('guest_scans_v1') ?? ''};
}
