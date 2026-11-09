import '../../../core/constants/app_constants.dart';

/// Pola email sederhana: `nama@domain.tld`.
final RegExp _emailPattern = RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$');

/// Memeriksa apakah [email] memiliki format yang wajar.
bool isValidEmail(String email) => _emailPattern.hasMatch(email.trim());

/// Validator form email. Mengembalikan pesan error atau `null` jika valid.
String? validateEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) return 'Email wajib diisi';
  if (!isValidEmail(email)) return 'Format email tidak valid';
  return null;
}

/// Validator form kata sandi dengan minimal [AppConstants.minPasswordLength] karakter.
String? validatePassword(String? value) {
  final password = value ?? '';
  if (password.isEmpty) return 'Kata sandi wajib diisi';
  if (password.length < AppConstants.minPasswordLength) {
    return 'Kata sandi minimal ${AppConstants.minPasswordLength} karakter';
  }
  return null;
}

/// Validator form konfirmasi kata sandi; harus sama dengan [password].
String? validatePasswordConfirmation(String? value, String password) {
  final confirmation = value ?? '';
  if (confirmation.isEmpty) return 'Konfirmasi kata sandi wajib diisi';
  if (confirmation != password) return 'Konfirmasi kata sandi tidak cocok';
  return null;
}
