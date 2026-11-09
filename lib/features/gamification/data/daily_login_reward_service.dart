import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import 'points_ledger_service.dart';

/// Hasil pengecekan hadiah login harian.
class DailyLoginReward {
  final bool claimed;
  final bool alreadyClaimedToday;
  final int day;
  final int points;
  final bool badgeAwarded;

  const DailyLoginReward({
    required this.claimed,
    required this.alreadyClaimedToday,
    required this.day,
    required this.points,
    required this.badgeAwarded,
  });

  static const DailyLoginReward none = DailyLoginReward(
    claimed: false,
    alreadyClaimedToday: false,
    day: 0,
    points: 0,
    badgeAwarded: false,
  );
}

/// Hadiah login harian: hari ke-1 = 2 poin, hari ke-2 = 3 poin, dst.
/// Hari ke-7 = 8 poin sekaligus membuka badge streak login (sekali seumur akun).
/// Setelah hari ke-7, siklus kembali ke hari ke-1.
class DailyLoginRewardService {
  final SharedPreferences _prefs;

  DailyLoginRewardService(this._prefs);

  static const int maxStreakDay = 7;

  Future<DailyLoginReward> claimIfEligible(
    String userId, {
    DateTime? now,
  }) async {
    final ledger = PointsLedgerService(_prefs);
    final today = now ?? DateTime.now();

    final lastClaim = await ledger.getLastLoginClaim(userId);
    if (lastClaim != null && _isSameDay(lastClaim, today)) {
      final streak = await ledger.getLoginStreak(userId);
      return DailyLoginReward(
        claimed: false,
        alreadyClaimedToday: true,
        day: streak,
        points: 0,
        badgeAwarded: false,
      );
    }

    final previousStreak = await ledger.getLoginStreak(userId);
    final continues = lastClaim != null && _isYesterday(lastClaim, today);
    var newStreak = continues ? previousStreak + 1 : 1;
    if (newStreak > maxStreakDay) newStreak = 1;

    final points = newStreak + 1;

    await ledger.setLoginStreak(userId, newStreak);
    await ledger.setLastLoginClaim(userId, today);
    await ledger.addLoginPoints(userId, points);

    var badgeAwarded = false;
    if (newStreak == maxStreakDay &&
        !await ledger.hasClaimedBadge(
          userId,
          AppConstants.loginStreakBadgeId,
        )) {
      await ledger.claimBadge(userId, AppConstants.loginStreakBadgeId);
      badgeAwarded = true;
    }

    return DailyLoginReward(
      claimed: true,
      alreadyClaimedToday: false,
      day: newStreak,
      points: points,
      badgeAwarded: badgeAwarded,
    );
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static bool _isYesterday(DateTime previous, DateTime today) {
    final yesterday = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(const Duration(days: 1));
    return _isSameDay(previous, yesterday);
  }
}
