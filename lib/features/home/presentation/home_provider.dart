import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_controller.dart';
import '../../gamification/presentation/user_progress_provider.dart';
import '../data/home_repository.dart';
import '../data/mock_home_repository.dart';
import '../domain/home_summary.dart';
import '../../gamification/presentation/gamification_provider.dart';

final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  final gamificationRepo = ref.watch(gamificationRepositoryProvider);
  return MockHomeRepository(gamificationRepo);
});

final homeSummaryProvider = FutureProvider.autoDispose<HomeSummary>((
  ref,
) async {
  final user = ref.watch(authControllerProvider).value;
  final repository = ref.watch(homeRepositoryProvider);
  final isDemoOrGuest = ref.watch(isDemoOrGuestProvider);
  final progress = await ref.watch(userProgressProvider.future);

  final userName = user != null
      ? (user.isGuest ? 'Tamu' : user.displayName)
      : 'Tamu';

  final summary = await repository.getHomeSummary(
    userName: userName,
    isDemoOrGuest: isDemoOrGuest,
  );

  // Poin di beranda memakai total poin dinamis (riwayat + hadiah login).
  return summary.copyWith(points: progress.totalPoints);
});
