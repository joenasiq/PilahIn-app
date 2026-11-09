import 'points_policy.dart';

/// Ringkasan poin akun yang dihitung dinamis dari riwayat & penyimpanan lokal.
class UserProgress {
  /// Poin dasar sementara (dummy) yang hanya diberikan ke akun demo/tamu.
  final int basePoints;

  /// Total poin dari pemindaian (riwayat).
  final int scanPoints;

  /// Total poin dari hadiah login harian.
  final int loginPoints;

  /// Total poin dari badge (sementara masih dummy = 0).
  final int badgePoints;

  /// Total poin dari hadiah misi yang sudah diklaim.
  final int missionPoints;

  /// Poin scan + badge/misi yang sudah didapat hari ini.
  final int pointsToday;

  final int dailyLimit;

  const UserProgress({
    required this.basePoints,
    required this.scanPoints,
    required this.loginPoints,
    required this.badgePoints,
    required this.pointsToday,
    this.missionPoints = 0,
    this.dailyLimit = PointsPolicy.dailyLimit,
  });

  int get totalPoints =>
      basePoints + scanPoints + loginPoints + badgePoints + missionPoints;

  int get remainingToday {
    final remaining = dailyLimit - pointsToday;
    return remaining < 0 ? 0 : remaining;
  }
}
