import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../history/presentation/history_provider.dart';
import '../data/points_ledger_service.dart';
import '../domain/user_progress.dart';

/// Poin total akun aktif: poin dasar (khusus demo/tamu) + poin scan dari
/// riwayat + poin hadiah login. Otomatis berubah saat riwayat/akun berubah.
final userProgressProvider = FutureProvider.autoDispose<UserProgress>((
  ref,
) async {
  final userId = ref.watch(currentUserIdProvider);
  final isDemoOrGuest = ref.watch(isDemoOrGuestProvider);
  final stats = await ref.watch(historyStatsProvider.future);
  final prefs = ref.watch(sharedPreferencesProvider);
  final ledger = PointsLedgerService(prefs);

  final loginPoints = await ledger.getLoginPoints(userId);
  final missionPoints = await ledger.getMissionPoints(userId);
  final pointsToday = await ledger.getDailyPoints(userId);

  return UserProgress(
    basePoints: isDemoOrGuest ? AppConstants.dummyBasePoints : 0,
    scanPoints: stats.totalPoints,
    loginPoints: loginPoints,
    badgePoints: 0,
    missionPoints: missionPoints,
    pointsToday: pointsToday,
  );
});
