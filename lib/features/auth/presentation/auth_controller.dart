import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/guest/guest_progress_store.dart';
import '../../../core/providers/shared_preferences_provider.dart';
import '../data/firebase_auth_repository.dart';
import '../domain/app_user.dart';
import '../domain/auth_repository.dart';

// SharedPreferences didefinisikan di core (hindari import melingkar);
// di-re-export agar import lama (mis. test & main) tetap berfungsi.
export '../../../core/providers/shared_preferences_provider.dart'
    show sharedPreferencesProvider;

// Provider untuk AuthRepository (berbasis Firebase Auth + Firestore).
// GuestProgressStore disuntik agar login bisa auto-merge progres tamu
// ke akun cloud (Fase 3).
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final guestStore = ref.watch(guestProgressStoreProvider);
  return FirebaseAuthRepository(prefs, guestStore);
});

// AuthController menggunakan AsyncNotifier
class AuthController extends AsyncNotifier<AppUser?> {
  @override
  Future<AppUser?> build() async {
    return _checkSession();
  }

  Future<AppUser?> _checkSession() async {
    final repo = ref.read(authRepositoryProvider);
    return await repo.getCurrentUser();
  }

  Future<void> login(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final repo = ref.read(authRepositoryProvider);
      final user = await repo.login(email, password);
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> loginAsGuest() async {
    state = const AsyncValue.loading();
    try {
      final repo = ref.read(authRepositoryProvider);
      final user = await repo.loginAsGuest();
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> logout() async {
    state = const AsyncValue.loading();
    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.logout();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, AppUser?>(() {
  return AuthController();
});
