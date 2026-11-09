import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pilahin_app/core/constants/app_constants.dart';
import 'package:pilahin_app/features/gamification/data/daily_login_reward_service.dart';
import 'package:pilahin_app/features/gamification/data/points_ledger_service.dart';

void main() {
  const userId = 'user_test';
  late SharedPreferences prefs;
  late DailyLoginRewardService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    service = DailyLoginRewardService(prefs);
  });

  test('hari pertama memberi 2 poin', () async {
    final reward = await service.claimIfEligible(
      userId,
      now: DateTime(2026, 11, 1),
    );

    expect(reward.claimed, isTrue);
    expect(reward.day, 1);
    expect(reward.points, 2);
    expect(reward.badgeAwarded, isFalse);
  });

  test('klaim kedua di hari yang sama ditolak', () async {
    final now = DateTime(2026, 11, 1);
    await service.claimIfEligible(userId, now: now);
    final second = await service.claimIfEligible(userId, now: now);

    expect(second.claimed, isFalse);
    expect(second.alreadyClaimedToday, isTrue);
    expect(second.points, 0);
  });

  test('streak bertambah tiap hari dan mencapai hari ke-7', () async {
    for (var day = 1; day <= 7; day++) {
      final reward = await service.claimIfEligible(
        userId,
        now: DateTime(2026, 11, day),
      );
      expect(reward.day, day);
      expect(reward.points, day + 1);
      expect(reward.badgeAwarded, day == 7);
    }
  });

  test('melewatkan satu hari mereset streak ke hari pertama', () async {
    await service.claimIfEligible(userId, now: DateTime(2026, 11, 1));
    final reward = await service.claimIfEligible(
      userId,
      now: DateTime(2026, 11, 3),
    );

    expect(reward.day, 1);
    expect(reward.points, 2);
  });

  test('setelah hari ke-7 siklus kembali ke hari ke-1', () async {
    for (var day = 1; day <= 7; day++) {
      await service.claimIfEligible(userId, now: DateTime(2026, 11, day));
    }
    final reward = await service.claimIfEligible(
      userId,
      now: DateTime(2026, 11, 8),
    );

    expect(reward.day, 1);
    expect(reward.points, 2);
  });

  test('badge streak login hanya diberikan sekali seumur akun', () async {
    for (var day = 1; day <= 7; day++) {
      await service.claimIfEligible(userId, now: DateTime(2026, 11, day));
    }
    // Siklus kedua: hari ke-7 berikutnya tidak memberi badge lagi.
    var secondCycleBadge = false;
    for (var day = 8; day <= 14; day++) {
      final reward = await service.claimIfEligible(
        userId,
        now: DateTime(2026, 11, day),
      );
      if (reward.badgeAwarded) secondCycleBadge = true;
    }

    expect(secondCycleBadge, isFalse);
    final ledger = PointsLedgerService(prefs);
    expect(
      await ledger.hasClaimedBadge(userId, AppConstants.loginStreakBadgeId),
      isTrue,
    );
  });

  test('poin login diakumulasi terpisah dari poin harian', () async {
    await service.claimIfEligible(userId, now: DateTime(2026, 11, 1));
    await service.claimIfEligible(userId, now: DateTime(2026, 11, 2));

    final ledger = PointsLedgerService(prefs);
    expect(await ledger.getLoginPoints(userId), 5); // 2 + 3
    expect(await ledger.getDailyPoints(userId), 0);
  });
}
