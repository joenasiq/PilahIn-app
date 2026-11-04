import 'package:cloud_firestore/cloud_firestore.dart';

import '../../gamification/domain/progress_calculator.dart';
import '../../gamification/domain/reference_data.dart';
import '../domain/daily_mission.dart';
import '../domain/home_summary.dart';
import 'home_repository.dart';

/// Repository beranda akun, berbasis Firestore.
///
/// Poin & streak diambil dari `users/{uid}` (cache hasil recompute oleh
/// `ProgressionService`); hitungan badge terbuka + misi harian hari ini
/// dibaca dari subcollection. Jika user baru (belum pernah recompute),
/// semua field di-fallback ke 0.
class FirebaseHomeRepository implements HomeRepository {
  FirebaseHomeRepository(this._firestore, {required this.uid});

  final FirebaseFirestore _firestore;
  final String uid;

  @override
  Future<HomeSummary> getHomeSummary({required String userName}) async {
    final now = DateTime.now();

    final userSnap = await _firestore.collection('users').doc(uid).get();
    final userData = userSnap.data() ?? const <String, dynamic>{};
    final points = (userData['total_points'] as int?) ?? 0;
    final streak = (userData['current_streak'] as int?) ?? 0;

    final badgesSnap =
        await _firestore.collection('users').doc(uid).collection('badges').get();
    final unlockedBadges =
        badgesSnap.docs.where((d) => d.data()['unlocked_at'] != null).length;

    // Kartu misi beranda hanya menampilkan misi harian hari ini.
    final missionsSnap =
        await _firestore.collection('users').doc(uid).collection('missions').get();
    final dailyMissions = <DailyMission>[];
    for (final def in kMissions) {
      if (def.period != 'harian') continue;
      final periodStart = dateKey(now);
      final doc = missionsSnap.docs
          .where((d) => d.id == '${def.code}_$periodStart')
          .firstOrNull;
      final data = doc?.data() ?? const <String, dynamic>{};
      final progress = (data['progress'] as int?) ?? 0;
      final status = (data['status'] as String?) ?? 'berjalan';
      dailyMissions.add(
        DailyMission(
          title: def.title,
          currentProgress: progress > def.target ? def.target : progress,
          targetProgress: def.target,
          rewardPoints: def.rewardPoints,
          status: status == 'selesai-diklaim' ? 'Selesai' : 'Berjalan',
        ),
      );
    }

    final level = levelForPoints(points);
    final next = nextLevelMinPoints(points);
    return HomeSummary(
      userName: userName,
      levelName: level.name,
      level: level.level,
      points: points,
      pointsToNextLevel: next != null ? next - points : 0,
      streakDays: streak,
      unlockedBadges: unlockedBadges,
      totalBadges: kBadges.length,
      dailyMissions: dailyMissions,
    );
  }
}
