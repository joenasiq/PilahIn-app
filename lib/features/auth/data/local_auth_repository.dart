import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_constants.dart';
import '../domain/app_user.dart';
import '../domain/auth_repository.dart';

class LocalAuthRepository implements AuthRepository {
  final SharedPreferences _prefs;

  LocalAuthRepository(this._prefs);

  @override
  Future<AppUser> login(String email, String password) async {
    // Simulasi delay jaringan
    await Future.delayed(const Duration(seconds: 1));

    if (email == AppConstants.demoEmail && password == AppConstants.demoPassword) {
      await _prefs.setBool(AppConstants.keyUserSession, true);
      await _prefs.setBool(AppConstants.keyIsGuest, false);
      
      return const AppUser(
        id: 'user_1',
        email: AppConstants.demoEmail,
        displayName: AppConstants.demoDisplayName,
        isGuest: false,
      );
    }
    
    throw Exception('Email atau kata sandi salah');
  }

  @override
  Future<AppUser> loginAsGuest() async {
    await Future.delayed(const Duration(milliseconds: 500));
    await _prefs.setBool(AppConstants.keyUserSession, true);
    await _prefs.setBool(AppConstants.keyIsGuest, true);
    
    return AppUser.guest();
  }

  @override
  Future<void> logout() async {
    await _prefs.remove(AppConstants.keyUserSession);
    await _prefs.remove(AppConstants.keyIsGuest);
  }

  @override
  Future<AppUser?> getCurrentUser() async {
    final hasSession = _prefs.getBool(AppConstants.keyUserSession) ?? false;
    if (!hasSession) return null;

    final isGuest = _prefs.getBool(AppConstants.keyIsGuest) ?? false;
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
