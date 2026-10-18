import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/gamification_repository.dart';
import '../data/mock_gamification_repository.dart';
import '../domain/mission.dart';
import '../domain/badge.dart';

final gamificationRepositoryProvider = Provider<GamificationRepository>((ref) {
  return MockGamificationRepository();
});

final activeMissionsProvider = FutureProvider.autoDispose<List<Mission>>((ref) async {
  final repo = ref.watch(gamificationRepositoryProvider);
  return repo.getMissions();
});

final badgesProvider = FutureProvider.autoDispose<List<AppBadge>>((ref) async {
  final repo = ref.watch(gamificationRepositoryProvider);
  return repo.getBadges();
});
