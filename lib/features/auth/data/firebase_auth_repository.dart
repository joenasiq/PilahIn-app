import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/firebase/scan_doc_id.dart';
import '../../../core/guest/guest_progress_store.dart';
import '../../gamification/data/progression_service.dart';
import '../domain/app_user.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_validators.dart';

/// Autentikasi berbasis Firebase (Auth + Firestore).
///
/// - Akun & kredensial dikelola Firebase Auth (email/password).
/// - Profil user ada di Firestore: `users/{uid}` (dibuat otomatis saat
///   login pertama, termasuk untuk user yang dibuat via konsol Firebase).
/// - Sesi tamu tetap murni lokal (tanpa akun Firebase).
///
/// Pesan error dipertahankan konsisten dengan versi sebelumnya:
/// - email tidak terdaftar              -> 'Email dan kata sandi salah'
/// - email terdaftar, password salah    -> 'Kata sandi salah'
class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._prefs, this._guestStore);

  final SharedPreferences _prefs;
  final GuestProgressStore _guestStore;

  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  @override
  Future<AppUser> login(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw _authErrorException(e);
    }

    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) {
      throw Exception('Gagal masuk. Silakan coba lagi.');
    }

    final profile = await _ensureUserDocument(firebaseUser);

    // Auto-merge progres tamu ke akun (jika ada). Gagal merge tidak
    // membatalkan login: data tamu tetap di lokal, dicoba lagi login depan.
    try {
      await _mergeGuestProgress(firebaseUser.uid);
    } catch (e) {
      developer.log('Auto-merge progres tamu gagal: $e');
    }

    await _prefs.setBool(AppConstants.keyUserSession, true);
    await _prefs.setBool(AppConstants.keyIsGuest, false);
    await _prefs.setString(AppConstants.keyUserId, firebaseUser.uid);

    return _toAppUser(firebaseUser, profile);
  }

  @override
  Future<AppUser> register({
    required String displayName,
    required String email,
    required String password,
  }) async {
    final name = displayName.trim();
    final cleanEmail = email.trim().toLowerCase();

    // Urutan & pesan validasi disamakan dengan versi lokal
    // (LocalAuthRepository) agar pesan UI konsisten.
    if (name.isEmpty) throw Exception('Nama wajib diisi');
    if (!isValidEmail(cleanEmail)) throw Exception('Format email tidak valid');
    if (password.length < AppConstants.minPasswordLength) {
      throw Exception(
        'Kata sandi minimal ${AppConstants.minPasswordLength} karakter',
      );
    }
    // Email demo adalah akun sistem, tidak boleh didaftarkan ulang.
    if (cleanEmail == AppConstants.demoEmail.trim().toLowerCase()) {
      throw Exception('Email sudah terdaftar');
    }

    User firebaseUser;
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );
      firebaseUser = cred.user!;
    } on FirebaseAuthException catch (e) {
      throw _registerException(e);
    }

    // Nama display di Firebase (best effort; display_name di Firestore
    // tetap diisi eksplisit lewat _ensureUserDocument).
    try {
      await firebaseUser.updateDisplayName(name);
    } catch (_) {
      // Tidak fatal: profil Firestore memakai nama dari parameter.
    }

    final profile =
        await _ensureUserDocument(firebaseUser, displayName: name);

    // Auto-merge progres tamu ke akun (jika ada). Gagal merge tidak
    // membatalkan registrasi: data tamu tetap di lokal, dicoba lagi
    // saat login berikutnya.
    try {
      await _mergeGuestProgress(firebaseUser.uid);
    } catch (e) {
      developer.log('Auto-merge progres tamu gagal: $e');
    }

    await _prefs.setBool(AppConstants.keyUserSession, true);
    await _prefs.setBool(AppConstants.keyIsGuest, false);
    await _prefs.setString(AppConstants.keyUserId, firebaseUser.uid);

    return _toAppUser(firebaseUser, profile);
  }

  @override
  Future<AppUser> loginAsGuest() async {
    // Pastikan tidak ada akun Firebase aktif (hindari state campur).
    if (_auth.currentUser != null) {
      await _auth.signOut();
    }
    await _prefs.setBool(AppConstants.keyUserSession, true);
    await _prefs.setBool(AppConstants.keyIsGuest, true);
    await _prefs.remove(AppConstants.keyUserId);
    return AppUser.guest();
  }

  @override
  Future<void> logout() async {
    if (_auth.currentUser != null) {
      await _auth.signOut();
    }
    await _prefs.remove(AppConstants.keyUserSession);
    await _prefs.remove(AppConstants.keyIsGuest);
    await _prefs.remove(AppConstants.keyUserId);
  }

  @override
  Future<AppUser?> getCurrentUser() async {
    final hasSession = _prefs.getBool(AppConstants.keyUserSession) ?? false;
    if (!hasSession) return null;

    final isGuest = _prefs.getBool(AppConstants.keyIsGuest) ?? true;
    if (isGuest) return AppUser.guest();

    final userId = _prefs.getString(AppConstants.keyUserId);
    final firebaseUser = _auth.currentUser;
    if (userId == null || firebaseUser == null || firebaseUser.uid != userId) {
      // Sesi basi (state auth Firebase sudah hilang).
      return null;
    }

    Map<String, dynamic>? profile;
    try {
      final snap = await _firestore
          .collection('users')
          .doc(userId)
          .get(); // default: serverAndCache (fallback ke cache saat offline)
      if (snap.exists) profile = snap.data();
    } catch (_) {
      // Offline & belum ada cache: lanjut dengan profil minimal.
    }
    return _toAppUser(firebaseUser, profile);
  }

  /// Pastikan dokumen profil user ada (untuk user yang dibuat di luar app,
  /// mis. lewat konsol Firebase). [displayName] diisi eksplisit saat
  /// registrasi (display name Firebase kadang belum tersinkron).
  Future<Map<String, dynamic>?> _ensureUserDocument(
    User user, {
    String? displayName,
  }) async {
    final ref = _firestore.collection('users').doc(user.uid);
    final snap = await ref.get();
    if (snap.exists) return snap.data();

    final data = {
      'display_name': displayName ?? _defaultDisplayName(user),
      'total_points': 0,
      'current_streak': 0,
      'best_streak': 0,
      'last_active_date': null,
      'created_at': Timestamp.now(),
    };
    await ref.set(data, SetOptions(merge: true));
    return data;
  }

  /// Migrasi progres tamu ke akun (auto-merge):
  /// 1. Tulis semua scan tamu ke `users/{uid}/scans` (batch; doc ID =
  ///    `sanitizeScanDocId(scanKey)`, merge agar aman diulang).
  /// 2. Recompute gamifikasi (poin/streak/badge/misi) — scan tamu ikut.
  /// 3. Kosongkan [GuestProgressStore].
  Future<void> _mergeGuestProgress(String uid) async {
    final guestScans = _guestStore.loadScans();
    if (guestScans.isEmpty) return;

    final scansRef =
        _firestore.collection('users').doc(uid).collection('scans');
    final batch = _firestore.batch();
    for (final scan in guestScans) {
      final data = scan.toMap()..remove('id');
      data['user_id'] = uid;
      data['scan_key'] = scan.scanKey;
      batch.set(
        scansRef.doc(sanitizeScanDocId(scan.scanKey)),
        data,
        SetOptions(merge: true),
      );
    }
    await batch.commit();

    await ProgressionService(_firestore, uid: uid).recomputeAll();

    await _guestStore.clear();
  }

  String _defaultDisplayName(User user) {
    if (user.displayName != null && user.displayName!.trim().isNotEmpty) {
      return user.displayName!.trim();
    }
    final email = user.email ?? '';
    final at = email.indexOf('@');
    return at > 0 ? email.substring(0, at) : 'Pengguna';
  }

  AppUser _toAppUser(User user, Map<String, dynamic>? profile) {
    return AppUser(
      id: user.uid,
      email: user.email ?? '',
      displayName:
          (profile?['display_name'] as String?) ?? _defaultDisplayName(user),
      isGuest: false,
    );
  }

  Exception _authErrorException(FirebaseAuthException e) {
    switch (e.code) {
      case 'wrong-password':
        return Exception('Kata sandi salah');
      case 'user-not-found':
      case 'invalid-email':
      case 'invalid-credential':
        return Exception('Email dan kata sandi salah');
      case 'too-many-requests':
        return Exception('Terlalu banyak percobaan. Silakan coba lagi nanti.');
      case 'network-request-failed':
        return Exception('Koneksi terputus. Periksa koneksi internet Anda.');
      default:
        return Exception('Gagal masuk. Silakan coba lagi.');
    }
  }

  /// Pemetaan error khusus registrasi (`createUserWithEmailAndPassword`).
  Exception _registerException(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return Exception('Email sudah terdaftar');
      case 'weak-password':
        return Exception('Kata sandi terlalu lemah');
      case 'too-many-requests':
        return Exception('Terlalu banyak percobaan. Silakan coba lagi nanti.');
      case 'network-request-failed':
        return Exception('Koneksi terputus. Periksa koneksi internet Anda.');
      default:
        return Exception('Gagal mendaftar. Silakan coba lagi.');
    }
  }
}
