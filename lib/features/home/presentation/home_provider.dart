import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/guest/guest_progress_store.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/firebase_home_repository.dart';
import '../data/guest_home_repository.dart';
import '../data/home_repository.dart';
import '../domain/home_summary.dart';

/// Repository beranda sesuai sesi aktif:
/// - tamu / belum login -> [GuestHomeRepository] (turunan lokal)
/// - akun login         -> [FirebaseHomeRepository] (Firestore)
final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  final user = ref.watch(authControllerProvider).value;
  if (user == null || user.isGuest) {
    return GuestHomeRepository(ref.watch(guestProgressStoreProvider));
  }
  return FirebaseHomeRepository(FirebaseFirestore.instance, uid: user.id);
});

final homeSummaryProvider = FutureProvider.autoDispose<HomeSummary>((ref) async {
  final user = ref.watch(authControllerProvider).value;
  final repository = ref.watch(homeRepositoryProvider);

  final userName = user != null
      ? (user.isGuest ? 'Tamu' : user.displayName)
      : 'Tamu';

  return repository.getHomeSummary(userName: userName);
});
