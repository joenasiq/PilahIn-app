import 'package:flutter_test/flutter_test.dart';
import 'package:pilahin_app/core/waste/waste_types.dart';
import 'package:pilahin_app/features/history/domain/history_entry.dart';
import 'package:pilahin_app/features/scan/domain/waste_category.dart';

import '../helpers/fake_history_repository.dart';

void main() {
  group('Riwayat terpisah per akun', () {
    late FakeHistoryRepository repository;

    setUp(() {
      repository = FakeHistoryRepository();
    });

    Future<void> seed() async {
      await repository.add(
        HistoryEntry(
          scanKey: 'a1',
          userId: 'user_a',
          wasteType: WasteType.plastic,
          confidence: 0.9,
          isUncertain: false,
          pointsEarned: 10,
          createdAt: DateTime(2026, 11, 1, 10),
        ),
      );
      await repository.add(
        HistoryEntry(
          scanKey: 'a2',
          userId: 'user_a',
          wasteType: WasteType.plastic,
          confidence: 0.9,
          isUncertain: false,
          pointsEarned: 5,
          createdAt: DateTime(2026, 11, 1, 11),
        ),
      );
      await repository.add(
        HistoryEntry(
          scanKey: 'b1',
          userId: 'user_b',
          wasteType: WasteType.biological,
          confidence: 0.9,
          isUncertain: false,
          pointsEarned: 10,
          createdAt: DateTime(2026, 11, 1, 12),
        ),
      );
      // Hasil tidak yakin tidak masuk statistik kategori/sub-kategori.
      await repository.add(
        HistoryEntry(
          scanKey: 'a3',
          userId: 'user_a',
          wasteType: WasteType.cardboard,
          confidence: 0.4,
          isUncertain: true,
          pointsEarned: 3,
          createdAt: DateTime(2026, 11, 1, 13),
        ),
      );
    }

    test('jumlah & poin hanya menghitung akun terkait', () async {
      await seed();

      expect(await repository.count(userId: 'user_a'), 3);
      expect(await repository.count(userId: 'user_b'), 1);
      expect(await repository.sumPointsEarned(userId: 'user_a'), 18);
      expect(await repository.sumPointsEarned(userId: 'user_b'), 10);
    });

    test(
      'statistik kategori & sub-kategori mengabaikan hasil tidak yakin',
      () async {
        await seed();

        final categories = await repository.countByCategory(userId: 'user_a');
        expect(categories[WasteCategory.anorganik], 2);
        expect(categories[WasteCategory.organik], 0);

        final types = await repository.countByWasteType(userId: 'user_a');
        expect(types[WasteType.plastic], 2);
        expect(types.containsKey(WasteType.cardboard), isFalse);
      },
    );

    test('cek scan hari ini hanya untuk akun dan tanggal terkait', () async {
      await seed();

      expect(
        await repository.hasScannedWasteTypeOn(
          userId: 'user_a',
          wasteType: WasteType.plastic,
          day: DateTime(2026, 11, 1),
        ),
        isTrue,
      );
      expect(
        await repository.hasScannedWasteTypeOn(
          userId: 'user_b',
          wasteType: WasteType.plastic,
          day: DateTime(2026, 11, 1),
        ),
        isFalse,
      );
      expect(
        await repository.hasScannedWasteTypeOn(
          userId: 'user_a',
          wasteType: WasteType.plastic,
          day: DateTime(2026, 11, 2),
        ),
        isFalse,
      );
    });
  });
}
