import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../data/local_auth_repository.dart';
import '../domain/app_user.dart';
import '../domain/auth_repository.dart';

// Provider untuk SharedPreferences
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden');
});

// Provider untuk AuthRepository
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return LocalAuthRepository(prefs);
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

  Future<void> register({
    required String displayName,
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    try {
      final repo = ref.read(authRepositoryProvider);
      final user = await repo.register(
        displayName: displayName,
        email: email,
        password: password,
      );
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

final authControllerProvider = AsyncNotifierProvider<AuthController, AppUser?>(
  () {
    return AuthController();
  },
);

/// Id akun yang sedang aktif. Dipakai untuk memisahkan riwayat, poin, dan
/// hadiah login antar akun pada perangkat yang sama.
final currentUserIdProvider = Provider<String>((ref) {
  final user = ref.watch(authControllerProvider).value;
  if (user == null || user.id.isEmpty) return AppConstants.demoUserId;
  return user.id;
});

/// Apakah akun aktif adalah akun demo atau tamu (mendapat poin dasar dummy).
final isDemoOrGuestProvider = Provider<bool>((ref) {
  final user = ref.watch(authControllerProvider).value;
  if (user == null) return true;
  return user.isGuest || user.id == AppConstants.demoUserId;
});
