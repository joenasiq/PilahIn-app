import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_controller.dart';
import '../data/home_repository.dart';
import '../data/mock_home_repository.dart';
import '../domain/home_summary.dart';
import '../../gamification/presentation/gamification_provider.dart';

final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  final gamificationRepo = ref.watch(gamificationRepositoryProvider);
  return MockHomeRepository(gamificationRepo);
});

final homeSummaryProvider = FutureProvider.autoDispose<HomeSummary>((ref) async {
  final user = ref.watch(authControllerProvider).value;
  final repository = ref.watch(homeRepositoryProvider);
  
  final userName = user != null 
      ? (user.isGuest ? 'Tamu' : user.displayName) 
      : 'Tamu';
      
  return repository.getHomeSummary(userName: userName);
});
