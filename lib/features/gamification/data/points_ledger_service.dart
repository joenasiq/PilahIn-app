import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';

/// Penyimpanan poin sementara berbasis SharedPreferences (belum memakai DB).
///
/// Semua kunci dipisahkan per akun (`userId`) agar statistik tiap akun
/// tidak saling tercampur.
class PointsLedgerService {
  final SharedPreferences _prefs;

  PointsLedgerService(this._prefs);

  static String _dateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static String _dailyKey(String userId) =>
      '${AppConstants.keyDailyPointsPrefix}_$userId';

  static String _loginKey(String userId) =>
      '${AppConstants.keyLoginPointsPrefix}_$userId';

  static String _streakKey(String userId) =>
      '${AppConstants.keyLoginStreakPrefix}_$userId';

  static String _lastClaimKey(String userId) =>
      '${AppConstants.keyLastLoginClaimPrefix}_$userId';

  static String _claimedBadgesKey(String userId) =>
      '${AppConstants.keyClaimedBadgesPrefix}_$userId';

  static String _claimedMissionsKey(String userId) =>
      '${AppConstants.keyClaimedMissionsPrefix}_$userId';

  static String _missionPointsKey(String userId) =>
      '${AppConstants.keyMissionPointsPrefix}_$userId';

  // -------------------------------------------------------- Poin harian scan

  /// Total poin (scan + badge/misi) yang didapat pada [date].
  Future<int> getDailyPoints(String userId, {DateTime? date}) async {
    final raw = _prefs.getString(_dailyKey(userId));
    if (raw == null || raw.isEmpty) return 0;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return 0;
      final storedDate = decoded['date'] as String?;
      if (storedDate != _dateKey(date ?? DateTime.now())) return 0;
      return (decoded['points'] as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Menambahkan [points] ke total poin pada [date]. Mengembalikan total baru.
  Future<int> addDailyPoints(
    String userId,
    int points, {
    DateTime? date,
  }) async {
    if (points <= 0) return getDailyPoints(userId, date: date);

    final target = date ?? DateTime.now();
    final current = await getDailyPoints(userId, date: target);
    final updated = current + points;
    await _prefs.setString(
      _dailyKey(userId),
      jsonEncode({'date': _dateKey(target), 'points': updated}),
    );
    return updated;
  }

  // ---------------------------------------------------- Poin hadiah login

  /// Akumulasi poin dari hadiah login (di luar batas harian scan).
  Future<int> getLoginPoints(String userId) async {
    return _prefs.getInt(_loginKey(userId)) ?? 0;
  }

  Future<int> addLoginPoints(String userId, int points) async {
    if (points <= 0) return getLoginPoints(userId);
    final updated = (await getLoginPoints(userId)) + points;
    await _prefs.setInt(_loginKey(userId), updated);
    return updated;
  }

  // ------------------------------------------------- Streak & klaim login

  Future<int> getLoginStreak(String userId) async {
    return _prefs.getInt(_streakKey(userId)) ?? 0;
  }

  Future<void> setLoginStreak(String userId, int streak) async {
    await _prefs.setInt(_streakKey(userId), streak);
  }

  Future<DateTime?> getLastLoginClaim(String userId) async {
    final raw = _prefs.getString(_lastClaimKey(userId));
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> setLastLoginClaim(String userId, DateTime date) async {
    await _prefs.setString(_lastClaimKey(userId), _dateKey(date));
  }

  // --------------------------------------------------------------- Badge

  Future<Set<String>> getClaimedBadgeIds(String userId) async {
    final list = _prefs.getStringList(_claimedBadgesKey(userId)) ?? const [];
    return list.toSet();
  }

  Future<bool> hasClaimedBadge(String userId, String badgeId) async {
    return (await getClaimedBadgeIds(userId)).contains(badgeId);
  }

  Future<void> claimBadge(String userId, String badgeId) async {
    final ids = await getClaimedBadgeIds(userId);
    if (ids.contains(badgeId)) return;
    ids.add(badgeId);
    await _prefs.setStringList(_claimedBadgesKey(userId), ids.toList());
  }

  // -------------------------------------------------------------- Misi

  /// Kunci misi yang sudah diklaim (format `missionId:periodKey`).
  Future<Set<String>> getClaimedMissionKeys(String userId) async {
    final list = _prefs.getStringList(_claimedMissionsKey(userId)) ?? const [];
    return list.toSet();
  }

  /// Menandai misi sudah diklaim. Mengembalikan `false` jika sudah pernah.
  Future<bool> claimMission(String userId, String missionKey) async {
    final keys = await getClaimedMissionKeys(userId);
    if (keys.contains(missionKey)) return false;
    keys.add(missionKey);
    await _prefs.setStringList(_claimedMissionsKey(userId), keys.toList());
    return true;
  }

  /// Total poin dari hadiah misi (tidak terkena batas poin harian).
  Future<int> getMissionPoints(String userId) async {
    return _prefs.getInt(_missionPointsKey(userId)) ?? 0;
  }

  Future<int> addMissionPoints(String userId, int points) async {
    if (points <= 0) return getMissionPoints(userId);
    final updated = (await getMissionPoints(userId)) + points;
    await _prefs.setInt(_missionPointsKey(userId), updated);
    return updated;
  }
}
