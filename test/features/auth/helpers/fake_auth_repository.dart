import 'package:shared_preferences/shared_preferences.dart';

import 'package:pilahin_app/core/constants/app_constants.dart';
import 'package:pilahin_app/features/auth/domain/app_user.dart';
import 'package:pilahin_app/features/auth/domain/auth_repository.dart';

/// Fake auth repository untuk widget/integration test.
///
/// Meniru semantik lama LocalAuthRepository (verifikasi terhadap kredensial
/// demo di [AppConstants]) TANPA membuka database, sehingga widget test
/// tetap hermetic.
class FakeAuthRepository implements AuthRepository {
  final SharedPreferences _prefs;

  FakeAuthRepository(this._prefs);

  @override
  Future<AppUser> login(String email, String password) async {
    final cleanEmail = email.trim().toLowerCase();
    final demoEmail = AppConstants.demoEmail.trim().toLowerCase();

    final isEmailWrong = cleanEmail != demoEmail;
    final isPasswordWrong = password != AppConstants.demoPassword;

    if (isEmailWrong && isPasswordWrong) {
      throw Exception('Email dan kata sandi salah');
    }
    if (isEmailWrong) {
      throw Exception('Email salah');
    }
    if (isPasswordWrong) {
      throw Exception('Kata sandi salah');
    }

    await _prefs.setBool(AppConstants.keyUserSession, true);
    await _prefs.setBool(AppConstants.keyIsGuest, false);
    await _prefs.setString(AppConstants.keyUserId, 'user_1');

    return const AppUser(
      id: 'user_1',
      email: AppConstants.demoEmail,
      displayName: AppConstants.demoDisplayName,
      isGuest: false,
    );
  }

  @override
  Future<AppUser> loginAsGuest() async {
    await _prefs.setBool(AppConstants.keyUserSession, true);
    await _prefs.setBool(AppConstants.keyIsGuest, true);
    await _prefs.setString(AppConstants.keyUserId, 'guest_id');

    return AppUser.guest();
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

    final isGuest = _prefs.getBool(AppConstants.keyIsGuest) ?? true;
    if (isGuest) {
      return AppUser.guest();
    }

    return const AppUser(
      id: 'user_1',
      email: AppConstants.demoEmail,
      displayName: AppConstants.demoDisplayName,
      isGuest: false,
    );
  }
}
