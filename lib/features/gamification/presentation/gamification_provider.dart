import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_controller.dart';
import '../data/mock_gamification_repository.dart';
import '../data/points_ledger_service.dart';
import '../domain/gamification_repository.dart';
import '../domain/badge.dart';

final gamificationRepositoryProvider = Provider<GamificationRepository>((ref) {
  return MockGamificationRepository();
});

final badgesProvider = FutureProvider.autoDispose<List<AppBadge>>((ref) async {
  final repo = ref.watch(gamificationRepositoryProvider);
  final badges = await repo.getBadges();

  // Badge yang sudah diklaim (mis. streak login 7 hari) ditandai terbuka
  // sesuai data akun yang sedang aktif.
  final prefs = ref.watch(sharedPreferencesProvider);
  final userId = ref.watch(currentUserIdProvider);
  final claimedIds = await PointsLedgerService(prefs)
      .getClaimedBadgeIds(userId);

  if (claimedIds.isEmpty) return badges;

  return badges.map((badge) {
    if (!claimedIds.contains(badge.id) || badge.isOpen) return badge;
    return badge.copyWith(progres: badge.target, tanggalDiraih: DateTime.now());
  }).toList();
});
