import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Menghasilkan hash kata sandi lokal (SHA-256 dengan garam = email).
///
/// Catatan: ini untuk aplikasi lokal-only (tanpa backend). Bukan pengganti
/// bcrypt/argon2 untuk server. Garam memakai email agar password yang sama
/// di akun berbeda menghasilkan hash berbeda.
String hashPassword(String email, String password) {
  final salted = utf8.encode('${email.trim().toLowerCase()}:$password');
  return sha256.convert(salted).toString();
}

/// Membandingkan hash tersimpan dengan hash dari [password] milik [email].
bool verifyPassword(String email, String password, String storedHash) {
  return hashPassword(email, password) == storedHash;
}
