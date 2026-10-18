import 'app_user.dart';

abstract class AuthRepository {
  Future<AppUser> login(String email, String password);
  Future<AppUser> loginAsGuest();
  Future<void> logout();
  Future<AppUser?> getCurrentUser();
}
