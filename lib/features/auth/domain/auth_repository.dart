import 'app_user.dart';

abstract class AuthRepository {
  Future<AppUser> login(String email, String password);

  /// Membuat akun baru lalu langsung mengembalikan user yang sudah masuk.
  Future<AppUser> register({
    required String displayName,
    required String email,
    required String password,
  });

  Future<AppUser> loginAsGuest();
  Future<void> logout();
  Future<AppUser?> getCurrentUser();

  /// Menyimpan URL foto profil akun aktif. [photoUrl] null berarti
  /// menghapus foto profil.
  Future<AppUser> updatePhotoUrl(String? photoUrl);
}
