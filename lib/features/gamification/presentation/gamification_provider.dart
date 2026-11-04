import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/guest/guest_progress_store.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/firebase_gamification_repository.dart';
import '../data/guest_gamification_repository.dart';
import '../data/progression_service.dart';
import '../domain/badge.dart';
import '../domain/gamification_repository.dart';
import '../domain/mission.dart';

/// Repository gamifikasi sesuai sesi aktif:
/// - tamu / belum login -> [GuestGamificationRepository] (turunan lokal)
/// - akun login         -> [FirebaseGamificationRepository] (Firestore)
///
/// Provider ini berganti instance saat auth berubah; konsumen
/// (FutureProvider di bawah) otomatis re-read.
final gamificationRepositoryProvider =
    Provider<GamificationRepository>((ref) {
  final user = ref.watch(authControllerProvider).value;
  if (user == null || user.isGuest) {
    return GuestGamificationRepository(ref.watch(guestProgressStoreProvider));
  }
  return FirebaseGamificationRepository(FirebaseFirestore.instance,
      uid: user.id);
});

/// Layanan recompute gamifikasi akun (null untuk tamu: tidak ada cloud).
/// Dipanggil setelah scan tersimpan (history_provider) dan setelah
/// auto-merge tamu (FirebaseAuthRepository).
final progressionServiceProvider = Provider<ProgressionService?>((ref) {
  final user = ref.watch(authControllerProvider).value;
  if (user == null || user.isGuest) return null;
  return ProgressionService(FirebaseFirestore.instance, uid: user.id);
});

final activeMissionsProvider = FutureProvider.autoDispose<List<Mission>>((ref) async {
  final repo = ref.watch(gamificationRepositoryProvider);
  return repo.getMissions();
});

final badgesProvider = FutureProvider.autoDispose<List<AppBadge>>((ref) async {
  final repo = ref.watch(gamificationRepositoryProvider);
  return repo.getBadges();
});
