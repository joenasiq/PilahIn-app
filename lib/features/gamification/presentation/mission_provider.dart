import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_controller.dart';
import '../../history/presentation/history_provider.dart';
import '../data/mission_service.dart';
import '../data/points_ledger_service.dart';
import '../domain/mission.dart';
import 'user_progress_provider.dart';

/// Service misi untuk akun yang sedang aktif.
final missionServiceProvider = Provider<MissionService>((ref) {
  return MissionService(
    repository: ref.watch(historyRepositoryProvider),
    ledger: PointsLedgerService(ref.watch(sharedPreferencesProvider)),
  );
});

/// Misi harian akun aktif. Progres dihitung dari riwayat hari ini sehingga
/// otomatis berubah setiap kali ada pemindaian baru.
final dailyMissionsProvider = FutureProvider.autoDispose<List<Mission>>((
  ref,
) async {
  ref.watch(historyNotifierProvider);
  final userId = ref.watch(currentUserIdProvider);
  return ref.watch(missionServiceProvider).dailyMissions(userId: userId);
});

/// Misi mingguan akun aktif (periode dimulai hari Senin).
final weeklyMissionsProvider = FutureProvider.autoDispose<List<Mission>>((
  ref,
) async {
  ref.watch(historyNotifierProvider);
  final userId = ref.watch(currentUserIdProvider);
  return ref.watch(missionServiceProvider).weeklyMissions(userId: userId);
});

/// Misi harian pertama yang belum diklaim (dipakai di Beranda).
final featuredDailyMissionProvider = FutureProvider.autoDispose<Mission?>((
  ref,
) async {
  final missions = await ref.watch(dailyMissionsProvider.future);
  if (missions.isEmpty) return null;
  for (final mission in missions) {
    if (!mission.isClaimed) return mission;
  }
  return missions.first;
});

/// Mengklaim hadiah misi lalu menyegarkan data terkait.
Future<MissionClaimResult> claimMission(
  WidgetRef ref, {
  required Mission mission,
}) async {
  final userId = ref.read(currentUserIdProvider);
  final result = await ref
      .read(missionServiceProvider)
      .claim(userId: userId, mission: mission);

  if (result.success) {
    ref.invalidate(dailyMissionsProvider);
    ref.invalidate(weeklyMissionsProvider);
    ref.invalidate(featuredDailyMissionProvider);
    ref.invalidate(userProgressProvider);
  }
  return result;
}
