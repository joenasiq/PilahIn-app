import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/db/users_repository.dart';
import '../../../core/db/password_hasher.dart';
import '../domain/app_user.dart';
import '../domain/auth_repository.dart';

/// Autentikasi lokal: kredensial diverifikasi terhadap tabel `users`
/// (SQLite), sesi disimpan di SharedPreferences.
///
/// Pesan error dipertahankan konsisten dengan versi sebelumnya:
/// - email tidak terdaftar (apapun password)   -> 'Email dan kata sandi salah'
/// - email terdaftar tapi password salah       -> 'Kata sandi salah'
class LocalAuthRepository implements AuthRepository {
  final SharedPreferences _prefs;
  final UsersRepository _usersRepo;

  LocalAuthRepository(this._prefs, this._usersRepo);

  @override
  Future<AppUser> login(String email, String password) async {
    // Simulasi delay jaringan (dipertahankan dari versi sebelumnya)
    await Future.delayed(const Duration(seconds: 1));

    final cleanEmail = email.trim().toLowerCase();
    final user = await _usersRepo.findByEmail(cleanEmail);

    if (user == null) {
      // Email tidak terdaftar; password tidak bisa diverifikasi.
      throw Exception('Email dan kata sandi salah');
    }
    if (!verifyPassword(cleanEmail, password, user.passwordHash ?? '')) {
      throw Exception('Kata sandi salah');
    }

    await _prefs.setBool(AppConstants.keyUserSession, true);
    await _prefs.setBool(AppConstants.keyIsGuest, false);
    await _prefs.setString(AppConstants.keyUserId, user.id);

    return _toAppUser(user);
  }

  @override
  Future<AppUser> loginAsGuest() async {
    await Future.delayed(const Duration(milliseconds: 500));

    final guest = await _usersRepo.getOrCreateGuest();
    await _prefs.setBool(AppConstants.keyUserSession, true);
    await _prefs.setBool(AppConstants.keyIsGuest, true);
    await _prefs.setString(AppConstants.keyUserId, guest.id);

    return _toAppUser(guest);
  }

  @override
  Future<void> logout() async {
    await _prefs.remove(AppConstants.keyUserSession);
    await _prefs.remove(AppConstants.keyIsGuest);
    await _prefs.remove(AppConstants.keyUserId);
  }

  @override
  Future<AppUser?> getCurrentUser() async {
    final hasSession = _prefs.getBool(AppConstants.keyUserSession) ?? false;
    if (!hasSession) return null;

    // Sesi baru: user id tersimpan di prefs.
    final userId = _prefs.getString(AppConstants.keyUserId);
    if (userId != null) {
      final user = await _usersRepo.findById(userId);
      if (user != null) return _toAppUser(user);
    }

    // Fallback untuk sesi era sebelum user_id disimpan di prefs:
    // keputusan tamu/akun diambil dari flag lama; akun non-tamu diasumsikan
    // akun demo (satu-satunya akun yang ada di DB).
    final isGuest = _prefs.getBool(AppConstants.keyIsGuest) ?? true;
    if (isGuest) {
      final guest = await _usersRepo.getOrCreateGuest();
      return _toAppUser(guest);
    }
    final demo = await _usersRepo.findByEmail(AppConstants.demoEmail);
    return demo == null ? null : _toAppUser(demo);
  }

  AppUser _toAppUser(DbUser user) {
    return AppUser(
      id: user.id,
      email: user.email ?? '',
      displayName: user.displayName,
      isGuest: user.isGuest,
    );
  }
}
