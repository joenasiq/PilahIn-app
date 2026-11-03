import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../domain/app_user.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_validators.dart';

/// Data akun yang terdaftar secara lokal.
///
/// Kata sandi tidak disimpan sebagai teks biasa: yang disimpan hanya
/// hash SHA-256 dari `salt + kata sandi`.
class _LocalAccount {
  final String id;
  final String email;
  final String displayName;
  final String passwordHash;
  final String salt;

  const _LocalAccount({
    required this.id,
    required this.email,
    required this.displayName,
    required this.passwordHash,
    required this.salt,
  });

  factory _LocalAccount.fromMap(Map<String, dynamic> map) {
    return _LocalAccount(
      id: map['id'] as String,
      email: map['email'] as String,
      displayName: map['display_name'] as String? ?? '',
      passwordHash: map['password_hash'] as String,
      salt: map['salt'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'display_name': displayName,
      'password_hash': passwordHash,
      'salt': salt,
    };
  }

  AppUser toAppUser() {
    return AppUser(
      id: id,
      email: email,
      displayName: displayName,
      isGuest: false,
    );
  }
}

class LocalAuthRepository implements AuthRepository {
  final SharedPreferences _prefs;

  LocalAuthRepository(this._prefs);

  static final Random _random = Random.secure();

  // ---------------------------------------------------------------- Algoritma

  /// Membaca seluruh akun terdaftar dari penyimpanan lokal.
  Future<List<_LocalAccount>> _readAccounts() async {
    final raw = _prefs.getString(AppConstants.keyRegisteredAccounts);
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(_LocalAccount.fromMap)
          .toList();
    } catch (_) {
      // Data rusak tidak boleh membuat aplikasi gagal dibuka.
      return [];
    }
  }

  Future<void> _saveAccounts(List<_LocalAccount> accounts) async {
    final raw = jsonEncode(accounts.map((a) => a.toMap()).toList());
    await _prefs.setString(AppConstants.keyRegisteredAccounts, raw);
  }

  /// Salt acak per akun agar dua kata sandi sama menghasilkan hash berbeda.
  String _generateSalt() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    return base64Url.encode(bytes);
  }

  String _hashPassword(String password, String salt) {
    return sha256.convert(utf8.encode('$salt$password')).toString();
  }

  Future<void> _startSession(AppUser user) async {
    await _prefs.setBool(AppConstants.keyUserSession, true);
    await _prefs.setBool(AppConstants.keyIsGuest, user.isGuest);
    await _prefs.setString(AppConstants.keyUserId, user.id);
    await _prefs.setString(AppConstants.keyUserEmail, user.email);
    await _prefs.setString(AppConstants.keyUserName, user.displayName);
  }

  // ------------------------------------------------------------------- Publik

  @override
  Future<AppUser> login(String email, String password) async {
    // Simulasi delay jaringan
    await Future.delayed(const Duration(seconds: 1));

    final cleanEmail = email.trim().toLowerCase();
    final demoEmail = AppConstants.demoEmail.trim().toLowerCase();
    final isDemoEmail = cleanEmail == demoEmail;
    final isDemoPassword = password == AppConstants.demoPassword;

    // Akun demo bawaan aplikasi.
    if (isDemoEmail) {
      if (!isDemoPassword) throw Exception('Kata sandi salah');
      const user = AppUser(
        id: 'user_1',
        email: AppConstants.demoEmail,
        displayName: AppConstants.demoDisplayName,
        isGuest: false,
      );
      await _startSession(user);
      return user;
    }

    // Akun hasil pendaftaran.
    final accounts = await _readAccounts();
    _LocalAccount? account;
    for (final candidate in accounts) {
      if (candidate.email.toLowerCase() == cleanEmail) {
        account = candidate;
        break;
      }
    }

    if (account == null) {
      // Pesan gabungan saat email tidak dikenal sekaligus kata sandi salah.
      throw Exception(
        password == AppConstants.demoPassword
            ? 'Email salah'
            : 'Email dan kata sandi salah',
      );
    }
    if (_hashPassword(password, account.salt) != account.passwordHash) {
      throw Exception('Kata sandi salah');
    }

    final user = account.toAppUser();
    await _startSession(user);
    return user;
  }

  @override
  Future<AppUser> register({
    required String displayName,
    required String email,
    required String password,
  }) async {
    await Future.delayed(const Duration(milliseconds: 700));

    final name = displayName.trim();
    final cleanEmail = email.trim().toLowerCase();

    // Validasi: nama, email, lalu panjang kata sandi minimal 8 karakter.
    if (name.isEmpty) throw Exception('Nama wajib diisi');
    if (!isValidEmail(cleanEmail)) throw Exception('Format email tidak valid');
    if (password.length < AppConstants.minPasswordLength) {
      throw Exception(
        'Kata sandi minimal ${AppConstants.minPasswordLength} karakter',
      );
    }

    // Email tidak boleh sama dengan akun demo atau akun terdaftar lainnya.
    if (cleanEmail == AppConstants.demoEmail.trim().toLowerCase()) {
      throw Exception('Email sudah terdaftar');
    }

    final accounts = await _readAccounts();
    final isDuplicate = accounts.any(
      (a) => a.email.toLowerCase() == cleanEmail,
    );
    if (isDuplicate) throw Exception('Email sudah terdaftar');

    final salt = _generateSalt();
    final account = _LocalAccount(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      email: cleanEmail,
      displayName: name,
      salt: salt,
      passwordHash: _hashPassword(password, salt),
    );

    await _saveAccounts([...accounts, account]);

    final user = account.toAppUser();
    await _startSession(user);
    return user;
  }

  @override
  Future<AppUser> loginAsGuest() async {
    await Future.delayed(const Duration(milliseconds: 500));
    final user = AppUser.guest();
    await _startSession(user);
    return user;
  }

  @override
  Future<void> logout() async {
    await _prefs.remove(AppConstants.keyUserSession);
    await _prefs.remove(AppConstants.keyIsGuest);
    await _prefs.remove(AppConstants.keyUserId);
    await _prefs.remove(AppConstants.keyUserEmail);
    await _prefs.remove(AppConstants.keyUserName);
  }

  @override
  Future<AppUser?> getCurrentUser() async {
    final hasSession = _prefs.getBool(AppConstants.keyUserSession) ?? false;
    if (!hasSession) return null;

    final isGuest = _prefs.getBool(AppConstants.keyIsGuest) ?? false;
    if (isGuest) {
      return AppUser.guest();
    }

    final email = _prefs.getString(AppConstants.keyUserEmail);
    final name = _prefs.getString(AppConstants.keyUserName);
    final id = _prefs.getString(AppConstants.keyUserId);

    // Sesi lama (versi sebelum pendaftaran akun) tidak menyimpan data user.
    if (email == null || email.isEmpty) {
      return const AppUser(
        id: 'user_1',
        email: AppConstants.demoEmail,
        displayName: AppConstants.demoDisplayName,
        isGuest: false,
      );
    }

    return AppUser(
      id: id ?? 'user_1',
      email: email,
      displayName: name ?? email.split('@').first,
      isGuest: false,
    );
  }
}
