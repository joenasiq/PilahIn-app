import '../../../core/guest/guest_progress_store.dart';
import '../../gamification/domain/progress_calculator.dart';
import '../../gamification/domain/reference_data.dart';
import '../domain/daily_mission.dart';
import '../domain/home_summary.dart';
import 'home_repository.dart';

/// Repository beranda tamu: seluruh data diturunkan (derived) dari scan
/// tamu di [GuestProgressStore] — tanpa persistensi.
/// Poin tamu = poin scan + hadiah badge terbuka + hadiah misi periode
/// berjalan yang selesai (lihat [computeDerivedPoints]).
class GuestHomeRepository implements HomeRepository {
  GuestHomeRepository(this._store);

  final GuestProgressStore _store;

  @override
  Future<HomeSummary> getHomeSummary({required String userName}) async {
    final now = DateTime.now();
    final scans = _store.loadScans();

    final points = computeDerivedPoints(scans);
    final agg = aggregateScans(scans, now: now);
    final level = levelForPoints(points);
    final next = nextLevelMinPoints(points);

    final unlockedBadges =
        kBadges.where((def) => badgeProgress(def, agg) >= def.target).length;

    // Kartu misi beranda hanya menampilkan misi harian hari ini.
    final dailyMissions = <DailyMission>[];
    for (final def in kMissions) {
      if (def.period != 'harian') continue;
      final progress = missionProgress(def, scansInPeriod(scans, def, now: now));
      dailyMissions.add(
        DailyMission(
          title: def.title,
          currentProgress: progress > def.target ? def.target : progress,
          targetProgress: def.target,
          rewardPoints: def.rewardPoints,
          status: progress >= def.target ? 'Selesai' : 'Berjalan',
        ),
      );
    }

    return HomeSummary(
      userName: userName,
      levelName: level.name,
      level: level.level,
      points: points,
      pointsToNextLevel: next != null ? next - points : 0,
      streakDays: agg.streak,
      unlockedBadges: unlockedBadges,
      totalBadges: kBadges.length,
      dailyMissions: dailyMissions,
    );
  }
}
