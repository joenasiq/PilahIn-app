import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pilahin_app/core/waste/waste_types.dart';
import 'package:pilahin_app/features/gamification/data/mission_service.dart';
import 'package:pilahin_app/features/gamification/data/points_ledger_service.dart';
import 'package:pilahin_app/features/gamification/domain/mission_template.dart';
import 'package:pilahin_app/features/history/domain/history_entry.dart';
import 'package:pilahin_app/features/scan/domain/waste_category.dart';

import '../../history/helpers/fake_history_repository.dart';

void main() {
  const userId = 'user_test';
  late FakeHistoryRepository repository;
  late PointsLedgerService ledger;
  late MissionService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    repository = FakeHistoryRepository();
    ledger = PointsLedgerService(prefs);
    service = MissionService(repository: repository, ledger: ledger);
  });

  Future<void> addScan({
    required String key,
    required WasteType wasteType,
    required DateTime at,
    bool uncertain = false,
  }) {
    return repository.add(
      HistoryEntry(
        scanKey: key,
        userId: userId,
        wasteType: wasteType,
        confidence: uncertain ? 0.4 : 0.9,
        isUncertain: uncertain,
        pointsEarned: 10,
        createdAt: at,
      ),
    );
  }

  test('progres misi harian dihitung dari riwayat hari ini', () async {
    final now = DateTime(2026, 11, 4, 10);
    await addScan(key: 'a', wasteType: WasteType.biological, at: now);
    await addScan(key: 'b', wasteType: WasteType.biological, at: now);
    // Kemarin tidak boleh ikut.
    await addScan(
      key: 'old',
      wasteType: WasteType.biological,
      at: now.subtract(const Duration(days: 1)),
    );

    final missions = await service.dailyMissions(userId: userId, now: now);
    final organic = missions.firstWhere((m) => m.id == 'daily_organik_3');

    expect(organic.progres, 2);
    expect(organic.status, 'berjalan');
  });

  test('hasil tidak yakin tidak dihitung untuk misi', () async {
    final now = DateTime(2026, 11, 4, 10);
    await addScan(
      key: 'uncertain',
      wasteType: WasteType.biological,
      at: now,
      uncertain: true,
    );

    final missions = await service.dailyMissions(userId: userId, now: now);
    final banana = missions.firstWhere((m) => m.id == 'daily_banana_1');
    expect(banana.progres, 0);
  });

  test(
    'misi mingguan dimulai hari Senin dan menghitung sub-kategori unik',
    () async {
      // 2026-11-04 adalah hari Rabu; awal minggu = Senin 2026-11-02.
      final wednesday = DateTime(2026, 11, 4, 10);
      await addScan(
        key: 'w1',
        wasteType: WasteType.plastic,
        at: DateTime(2026, 11, 2, 9),
      );
      await addScan(
        key: 'w2',
        wasteType: WasteType.paper,
        at: DateTime(2026, 11, 3, 9),
      );
      // Minggu sebelumnya tidak dihitung.
      await addScan(
        key: 'old',
        wasteType: WasteType.metal,
        at: DateTime(2026, 11, 1, 9),
      );

      final missions = await service.weeklyMissions(
        userId: userId,
        now: wednesday,
      );
      final variety = missions.firstWhere((m) => m.id == 'weekly_variety_5');
      expect(variety.progres, 2);
    },
  );

  test('klaim misi hanya sekali dan memberi poin penuh', () async {
    final now = DateTime(2026, 11, 4, 10);
    await addScan(key: 'a', wasteType: WasteType.biological, at: now);

    final missions = await service.dailyMissions(userId: userId, now: now);
    final banana = missions.firstWhere((m) => m.id == 'daily_banana_1');
    expect(banana.isClaimable, isTrue);

    final first = await service.claim(userId: userId, mission: banana);
    expect(first.success, isTrue);
    expect(first.points, 15);
    expect(await ledger.getMissionPoints(userId), 15);

    final second = await service.claim(userId: userId, mission: banana);
    expect(second.success, isFalse);
    expect(second.alreadyClaimed, isTrue);
    expect(await ledger.getMissionPoints(userId), 15);
  });

  test('klaim ditolak jika misi belum selesai', () async {
    final now = DateTime(2026, 11, 4, 10);
    final missions = await service.dailyMissions(userId: userId, now: now);
    final organic = missions.firstWhere((m) => m.id == 'daily_organik_3');

    final result = await service.claim(userId: userId, mission: organic);
    expect(result.success, isFalse);
    expect(await ledger.getMissionPoints(userId), 0);
  });

  test('hadiah misi tidak terkena batas poin harian', () async {
    final now = DateTime(2026, 11, 4, 10);
    await addScan(key: 'a', wasteType: WasteType.biological, at: now);
    // Poin harian sudah mencapai batas 150.
    await ledger.addDailyPoints(userId, 150, date: now);

    final missions = await service.dailyMissions(userId: userId, now: now);
    final banana = missions.firstWhere((m) => m.id == 'daily_banana_1');
    final result = await service.claim(userId: userId, mission: banana);

    expect(result.success, isTrue);
    expect(result.points, 15);
    expect(await ledger.getMissionPoints(userId), 15);
    // Poin harian tidak bertambah karena hadiah misi dikecualikan.
    expect(await ledger.getDailyPoints(userId, date: now), 150);
  });

  test('klaim bisa diulang pada periode berikutnya', () async {
    final day1 = DateTime(2026, 11, 4, 10);
    final day2 = DateTime(2026, 11, 5, 10);
    await addScan(key: 'a', wasteType: WasteType.biological, at: day1);
    await addScan(key: 'b', wasteType: WasteType.biological, at: day2);

    final missionsDay1 = await service.dailyMissions(userId: userId, now: day1);
    final bananaDay1 = missionsDay1.firstWhere((m) => m.id == 'daily_banana_1');
    expect(
      (await service.claim(userId: userId, mission: bananaDay1)).success,
      isTrue,
    );

    final missionsDay2 = await service.dailyMissions(userId: userId, now: day2);
    final bananaDay2 = missionsDay2.firstWhere((m) => m.id == 'daily_banana_1');
    expect(bananaDay2.isClaimable, isTrue);
    expect(
      (await service.claim(userId: userId, mission: bananaDay2)).success,
      isTrue,
    );
    expect(await ledger.getMissionPoints(userId), 30);
  });

  test('kunci periode harian dan mingguan sesuai tanggal', () {
    expect(
      MissionService.periodKeyOf(MissionPeriod.daily, DateTime(2026, 11, 4)),
      '2026-11-04',
    );
    expect(
      MissionService.periodKeyOf(MissionPeriod.weekly, DateTime(2026, 11, 4)),
      'W2026-11-02',
    );
  });

  test('misi organik hanya menghitung kategori organik', () async {
    final now = DateTime(2026, 11, 4, 10);
    await addScan(key: 'a', wasteType: WasteType.plastic, at: now);

    final missions = await service.dailyMissions(userId: userId, now: now);
    final organic = missions.firstWhere((m) => m.id == 'daily_organik_3');
    expect(organic.progres, 0);
    expect(organic.target, 3);
    expect(WasteType.plastic.category, WasteCategory.anorganik);
  });
}
