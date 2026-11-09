import 'package:flutter_test/flutter_test.dart';
import 'package:pilahin_app/core/waste/waste_types.dart';
import 'package:pilahin_app/features/gamification/domain/progress_calculator.dart';
import 'package:pilahin_app/features/gamification/domain/reference_data.dart';
import 'package:pilahin_app/features/history/domain/history_entry.dart';
import 'package:pilahin_app/features/scan/domain/waste_category.dart';

// Acuan waktu tetap agar test deterministik.
// 2026-11-03 = Selasa -> Senin pekan itu = 2026-11-02.
final _now = DateTime(2026, 11, 3, 10, 30);

HistoryEntry entry(
  DateTime createdAt, {
  WasteType? wasteType,
  int points = 15,
  int i = 0,
}) {
  return HistoryEntry(
    scanKey: 'k$i',
    wasteType: wasteType,
    confidence: 0.9,
    isUncertain: false,
    pointsEarned: points,
    createdAt: createdAt,
  );
}

BadgeDefinition badge(String code) => kBadges.firstWhere((b) => b.code == code);

MissionDefinition mission(String code) =>
    kMissions.firstWhere((m) => m.code == code);

void main() {
  group('dateKey', () {
    test('format YYYY-MM-DD dengan zero-padding', () {
      expect(dateKey(DateTime(2026, 3, 5)), '2026-03-05');
      expect(dateKey(DateTime(2026, 11, 3)), '2026-11-03');
      expect(dateKey(DateTime(2026, 12, 31)), '2026-12-31');
    });
  });

  group('mondayKey', () {
    test('menghasilkan tanggal Senin dari minggu yang sama', () {
      // 2026-11-02 = Senin, 2026-11-03 = Selasa, 2026-11-08 = Minggu
      expect(mondayKey(DateTime(2026, 11, 2)), '2026-11-02');
      expect(mondayKey(DateTime(2026, 11, 3)), '2026-11-02');
      expect(mondayKey(DateTime(2026, 11, 8)), '2026-11-02');
      // Minggu berikutnya
      expect(mondayKey(DateTime(2026, 11, 9)), '2026-11-09');
    });
  });

  group('computeStreak', () {
    test('tanpa scan = 0', () {
      expect(computeStreak(const [], now: _now), 0);
    });

    test('satu scan hari ini = 1', () {
      expect(computeStreak([entry(_now)], now: _now), 1);
    });

    test('scan beruntun hari ini + kemarin + 2 hari lalu = 3', () {
      final scans = [
        entry(_now),
        entry(_now.subtract(const Duration(days: 1)), i: 1),
        entry(_now.subtract(const Duration(days: 2)), i: 2),
      ];
      expect(computeStreak(scans, now: _now), 3);
    });

    test('tanpa scan hari ini: rentang boleh diakhiri kemarin', () {
      final scans = [
        entry(_now.subtract(const Duration(days: 1)), i: 1),
        entry(_now.subtract(const Duration(days: 2)), i: 2),
      ];
      expect(computeStreak(scans, now: _now), 2);
    });

    test('tidak ada scan hari ini/kemarin = 0', () {
      final scans = [
        entry(_now.subtract(const Duration(days: 2)), i: 1),
        entry(_now.subtract(const Duration(days: 3)), i: 2),
      ];
      expect(computeStreak(scans, now: _now), 0);
    });

    test('gap di tengah rentang menghentikan streak', () {
      final scans = [
        entry(_now),
        entry(_now.subtract(const Duration(days: 1)), i: 1),
        entry(_now.subtract(const Duration(days: 3)), i: 2),
      ];
      expect(computeStreak(scans, now: _now), 2);
    });
  });

  group('aggregateScans', () {
    test('menghitung total, kategori, jenis, streak', () {
      final scans = [
        entry(_now, wasteType: WasteType.biological),
        entry(_now, wasteType: WasteType.biological, i: 1),
        entry(_now, wasteType: WasteType.plastic, i: 2),
        entry(_now, wasteType: WasteType.paper, i: 3),
      ];
      final agg = aggregateScans(scans, now: _now);
      expect(agg.total, 4);
      expect(agg.organik, 2);
      expect(agg.anorganik, 2);
      expect(agg.streak, 1);
      expect(agg.byType, {
        'biological': 2,
        'plastic': 1,
        'paper': 1,
      });
    });

    test('wasteType null tetap dihitung berdasarkan kategori tersimpan', () {
      final e = HistoryEntry(
        scanKey: 'x',
        category: WasteCategory.organik,
        confidence: 0.5,
        isUncertain: true,
        pointsEarned: 0,
        createdAt: _now,
      );
      final agg = aggregateScans([e], now: _now);
      expect(agg.total, 1);
      expect(agg.organik, 1);
      expect(agg.byType, isEmpty);
    });
  });

  group('badgeProgress', () {
    final scans = [
      entry(_now, wasteType: WasteType.biological),
      entry(_now, wasteType: WasteType.biological, i: 1),
      entry(_now, wasteType: WasteType.biological, i: 2),
      entry(_now, wasteType: WasteType.plastic, i: 3),
      entry(_now, wasteType: WasteType.paper, i: 4),
      entry(_now, wasteType: WasteType.greenGlass, i: 5),
    ];
    final agg = aggregateScans(scans, now: _now);

    test('metric total', () {
      expect(badgeProgress(badge('pemilah_pemula'), agg), 6);
    });

    test('metric kategori_organik', () {
      expect(badgeProgress(badge('pahlawan_hijau'), agg), 3);
    });

    test('metric kategori_anorganik', () {
      expect(badgeProgress(badge('dewa_daur_ulang'), agg), 3);
    });

    test('metric jenis (satu labelKey)', () {
      expect(badgeProgress(badge('raja_botol'), agg), 1); // plastic
    });

    test('metric jenis (beberapa labelKey dijumlah)', () {
      expect(badgeProgress(badge('ksatria_kaca'), agg), 1); // green-glass
    });

    test('metric streak', () {
      expect(badgeProgress(badge('api_semangat'), agg), 1);
    });
  });

  group('scansInPeriod & missionProgress', () {
    final defHari = mission('misi_harian_organik');
    final defMinggu = mission('misi_mingguan_plastik');

    test('misi harian hanya menghitung scan hari ini', () {
      final scans = [
        entry(_now, wasteType: WasteType.biological),
        entry(_now, wasteType: WasteType.biological, i: 1),
        entry(_now, wasteType: WasteType.plastic, i: 2),
        // Kemarin: tidak ikut
        entry(_now.subtract(const Duration(days: 1)),
            wasteType: WasteType.biological, i: 3),
      ];
      final inPeriod = scansInPeriod(scans, defHari, now: _now);
      expect(inPeriod, hasLength(3));
      expect(missionProgress(defHari, inPeriod), 2); // 2 organik
    });

    test('misi mingguan menghitung scan sejak Senin (termasuk kemarin)', () {
      final scans = [
        entry(_now, wasteType: WasteType.plastic), // Selasa
        entry(_now.subtract(const Duration(days: 1)),
            wasteType: WasteType.plastic, i: 1), // Senin
        entry(_now.subtract(const Duration(days: 3)),
            wasteType: WasteType.plastic, i: 2), // Sabtu pekan lalu
      ];
      final inPeriod = scansInPeriod(scans, defMinggu, now: _now);
      expect(inPeriod, hasLength(2));
      expect(missionProgress(defMinggu, inPeriod), 2);
    });

    test('metric total & jenis pada misi', () {
      final defTotal = MissionDefinition(
        code: 'test_total',
        title: 'Test',
        unit: 'Sampah',
        target: 3,
        rewardPoints: 10,
        period: 'harian',
        metric: 'total',
      );
      final defJenis = MissionDefinition(
        code: 'test_jenis',
        title: 'Test',
        unit: 'Kaca',
        target: 2,
        rewardPoints: 10,
        period: 'mingguan',
        metric: 'jenis',
        wasteTypeKeys: const ['green-glass', 'white-glass'],
      );

      final scans = [
        entry(_now, wasteType: WasteType.biological),
        entry(_now, wasteType: WasteType.plastic, i: 1),
        entry(_now, wasteType: WasteType.greenGlass, i: 2),
        entry(_now, wasteType: WasteType.whiteGlass, i: 3),
      ];

      final harian = scansInPeriod(scans, defTotal, now: _now);
      expect(missionProgress(defTotal, harian), 4);

      final mingguan = scansInPeriod(scans, defJenis, now: _now);
      expect(missionProgress(defJenis, mingguan), 2);
    });
  });

  group('level', () {
    test('levelForPoints memilih level tertinggi yang ambangnya tercapai', () {
      expect(levelForPoints(0).name, 'Pemilah Pemula');
      expect(levelForPoints(299).level, 1);
      expect(levelForPoints(300).name, 'Juru Kompos');
      expect(levelForPoints(699).level, 2);
      expect(levelForPoints(700).name, 'Penyelamat Bumi');
      expect(levelForPoints(1000).name, 'Duta Daur Ulang');
      expect(levelForPoints(2000).name, 'Dewa Ekosistem');
      expect(levelForPoints(99999).level, 5);
    });

    test('nextLevelMinPoints = ambang level berikutnya, null di level maks',
        () {
      expect(nextLevelMinPoints(0), 300);
      expect(nextLevelMinPoints(300), 700);
      expect(nextLevelMinPoints(999), 1000);
      expect(nextLevelMinPoints(2000), isNull);
      expect(nextLevelMinPoints(5000), isNull);
    });
  });

  group('computeDerivedPoints (poin tamu)', () {
    test('tanpa scan = 0', () {
      expect(computeDerivedPoints(const []), 0);
    });

    test('poin scan + hadiah badge + hadiah misi harian', () {
      // 3 scan organik hari ini: 3x15 = 45
      // badge 'pemilah_pemula' (total >= 1): +20
      // misi harian organik (3): +30
      final scans = [
        entry(_now, wasteType: WasteType.biological),
        entry(_now, wasteType: WasteType.biological, i: 1),
        entry(_now, wasteType: WasteType.biological, i: 2),
      ];
      expect(computeDerivedPoints(scans), 45 + 20 + 30);
    });

    test('badge kategori ikut dihitung saat target tercapai', () {
      // 10 scan organik: 150 poin; pahlawan_hijau (+100);
      // pemilah_pemula (+20); misi harian (+30) -> 300
      final scans = [
        for (var i = 0; i < 10; i++)
          entry(_now, wasteType: WasteType.biological, i: i),
      ];
      expect(computeDerivedPoints(scans), 150 + 100 + 20 + 30);
    });
  });
}
