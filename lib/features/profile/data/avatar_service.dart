import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'avatar_cropper.dart';
import 'avatar_image_compressor.dart';

/// Kegagalan unggah foto profil yang sudah diterjemahkan ke bahasa manusia.
///
/// [retryable] menandakan apakah percobaan ulang masuk akal (mis. koneksi
/// lambat/putus) atau tidak (mis. izin ditolak / foto terlalu besar).
class AvatarUploadException implements Exception {
  const AvatarUploadException(
    this.message, {
    this.code,
    this.retryable = false,
  });

  final String message;
  final String? code;
  final bool retryable;

  @override
  String toString() => message;
}

/// Penyimpanan foto profil di Firestore (bukan Firebase Storage).
///
/// Firebase Storage mensyaratkan paket Blaze sejak Okt 2024, sedangkan
/// Firestore sudah tersedia di paket gratis. Karena itu foto dikompres lalu
/// disimpan sebagai teks base64 di dokumen terpisah:
///
/// `users/{uid}/meta/avatar` -> { base64, bytes, marker, updated_at }
///
/// Hasil crop disimpan sebagai **PNG ber-alpha** agar sudutnya benar-benar
/// bulat/transparan. Foto lama yang masih JPEG tetap didukung.
///
/// Dokumen terpisah dipakai agar pembacaan profil (nama/email/poin) tidak
/// ikut mengunduh gambar. Batas dokumen Firestore 1 MiB, base64 membengkak
/// 4/3, jadi payload biner dibatasi ±[maxPayloadBytes] (700 KB).
class AvatarService {
  AvatarService([
    this._firestore,
    this._compressor = const AvatarImageCompressor(),
  ]);

  /// Batas waktu satu operasi baca/tulis Firestore.
  static const Duration operationTimeout = Duration(seconds: 60);

  /// Batas ukuran biner sebelum base64. 700 KB -> ±933 KB base64, masih di
  /// bawah batas 1 MiB per dokumen Firestore.
  static const int maxPayloadBytes = 700 * 1024;

  /// Kualitas kompresi yang dicoba berurutan sampai ukuran muat.
  static const List<int> qualitySteps = [85, 70, 55, 40];

  /// Awalan penanda versi foto. Nilai ini yang disimpan ke `photo_url` agar
  /// UI tahu foto berubah dan perlu memuat ulang.
  static const String markerPrefix = 'fs:';

  final FirebaseFirestore? _firestore;
  final AvatarImageCompressor _compressor;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _doc(String userId) => _db
      .collection('users')
      .doc(userId)
      .collection('meta')
      .doc('avatar');

  /// Mengunggah foto dari [filePath] dan mengembalikan penanda versi
  /// (`fs:<millis>`), bukan URL.
  ///
  /// [onProgress] dipanggil 0..1. Tahap kompresi tidak punya progres nyata,
  /// jadi nilainya melompat dari 0 ke 1 setelah data siap dikirim.
  Future<String> upload({
    required String userId,
    required String filePath,
    void Function(double progress)? onProgress,
  }) async {
    onProgress?.call(0);

    final file = File(filePath);
    if (!await file.exists()) {
      throw const AvatarUploadException(
        'Foto tidak dapat dibaca. Coba pilih foto lain.',
        code: 'file-unreadable',
      );
    }

    final bytes = await _prepareFileBytes(file);
    return uploadBytes(userId: userId, bytes: bytes, onProgress: onProgress);
  }

  /// Mengunggah foto yang sudah dipotong (byte JPEG) dan mengembalikan
  /// penanda versi.
  ///
  /// Dipakai alur crop: layar crop menghasilkan byte 512x512, lalu byte itu
  /// langsung disimpan tanpa membaca ulang file.
  Future<String> uploadBytes({
    required String userId,
    required Uint8List bytes,
    void Function(double progress)? onProgress,
  }) async {
    if (bytes.isEmpty) {
      throw const AvatarUploadException(
        'Foto tidak dapat dibaca. Coba pilih foto lain.',
        code: 'file-unreadable',
      );
    }

    onProgress?.call(0.4);
    final prepared = await _fitToLimit(bytes);
    onProgress?.call(0.7);

    final marker = '$markerPrefix${DateTime.now().millisecondsSinceEpoch}';
    try {
      await _doc(userId)
          .set({
            'base64': base64Encode(prepared),
            'bytes': prepared.length,
            'marker': marker,
            'updated_at': FieldValue.serverTimestamp(),
          })
          .timeout(operationTimeout);
    } on TimeoutException {
      throw const AvatarUploadException(
        'Koneksi terlalu lambat. Coba lagi saat sinyal lebih baik.',
        code: 'timeout',
        retryable: true,
      );
    } on FirebaseException catch (e) {
      _logFailure('simpan', e);
      throw mapAvatarUploadError(e.code);
    } catch (e) {
      _logFailure('simpan', e);
      throw const AvatarUploadException(
        'Gagal menyimpan foto. Coba lagi.',
        code: 'unknown',
        retryable: true,
      );
    }

    onProgress?.call(1);
    return marker;
  }

  /// Mengambil byte foto profil. Null bila belum ada foto.
  Future<Uint8List?> fetch(String userId) async {
    try {
      final snapshot = await _doc(userId).get().timeout(operationTimeout);
      final data = snapshot.data();
      if (data == null) return null;

      final encoded = data['base64'];
      if (encoded is! String || encoded.isEmpty) return null;
      return base64Decode(encoded);
    } on TimeoutException {
      developer.log('Ambil foto profil timeout (user: $userId)');
      return null;
    } on FirebaseException catch (e) {
      _logFailure('ambil', e);
      return null;
    } catch (e) {
      _logFailure('ambil', e);
      return null;
    }
  }

  /// Menghapus foto profil. Tidak melempar error bila belum ada foto.
  Future<void> delete(String userId) async {
    try {
      await _doc(userId).delete().timeout(operationTimeout);
    } on FirebaseException catch (e) {
      if (e.code == 'not-found') return;
      _logFailure('hapus', e);
      throw Exception('Gagal menghapus foto profil.');
    } catch (e) {
      _logFailure('hapus', e);
      throw Exception('Gagal menghapus foto profil.');
    }
  }

  /// Kompres file dengan kualitas menurun sampai muat di batas dokumen.
  Future<Uint8List> _prepareFileBytes(File file) async {
    Uint8List? smallest;
    for (final quality in qualitySteps) {
      final bytes = await _compressFile(file, quality);
      if (bytes.isEmpty) continue;
      smallest = bytes;
      if (bytes.length <= maxPayloadBytes) return bytes;
      developer.log(
        'Foto profil ${bytes.length} byte masih > $maxPayloadBytes, '
        'coba kualitas berikutnya.',
      );
    }

    if (smallest == null) {
      throw const AvatarUploadException(
        'Foto tidak dapat dibaca. Coba pilih foto lain.',
        code: 'file-unreadable',
      );
    }
    throw const AvatarUploadException(
      'Foto terlalu besar. Coba pilih foto lain yang lebih kecil.',
      code: 'file-too-large',
    );
  }

  /// Byte hasil crop biasanya sudah kecil; kalau masih terlalu besar,
  /// kecilkan lagi tanpa menghilangkan transparansi.
  ///
  /// PNG ber-alpha TIDAK boleh di-encode ulang ke JPEG, karena sudut
  /// transparan akan hilang dan foto jadi kotak lagi.
  Future<Uint8List> _fitToLimit(Uint8List bytes) async {
    if (bytes.length <= maxPayloadBytes) return bytes;

    if (isPngBytes(bytes)) {
      final shrunk = await shrinkAvatarPng(
        bytes,
        maxBytes: maxPayloadBytes,
      );
      if (shrunk.length <= maxPayloadBytes) return shrunk;
      throw const AvatarUploadException(
        'Foto terlalu besar. Coba pilih foto lain yang lebih kecil.',
        code: 'file-too-large',
      );
    }

    Uint8List smallest = bytes;
    for (final quality in qualitySteps) {
      final compressed = await _compressBytes(bytes, quality);
      if (compressed.isEmpty) continue;
      smallest = compressed;
      if (compressed.length <= maxPayloadBytes) return compressed;
    }

    if (smallest.length <= maxPayloadBytes) return smallest;
    throw const AvatarUploadException(
      'Foto terlalu besar. Coba pilih foto lain yang lebih kecil.',
      code: 'file-too-large',
    );
  }

  Future<Uint8List> _compressFile(File file, int quality) async {
    try {
      // Isolate terpisah supaya UI tidak membeku saat mendekode foto besar.
      return await _compressor.compressInBackground(file, quality: quality);
    } catch (e) {
      developer.log('Kompresi di isolate gagal, memakai isolate utama: $e');
      try {
        return await _compressor.compress(file, quality: quality);
      } catch (e) {
        developer.log('Baca/kompres foto profil gagal: $e');
        throw const AvatarUploadException(
          'Foto tidak dapat dibaca. Coba pilih foto lain.',
          code: 'file-unreadable',
        );
      }
    }
  }

  Future<Uint8List> _compressBytes(Uint8List bytes, int quality) async {
    try {
      return await _compressor.compressBytesInBackground(
        bytes,
        quality: quality,
      );
    } catch (e) {
      developer.log('Kompresi byte di isolate gagal, memakai isolate utama: $e');
      return _compressor.compressBytes(bytes, quality: quality);
    }
  }

  void _logFailure(String aksi, Object error) {
    if (error is FirebaseException) {
      developer.log(
        'Gagal $aksi foto profil (Firestore): ${error.code} ${error.message}',
      );
      return;
    }
    developer.log('Gagal $aksi foto profil (Firestore): $error');
  }
}

/// Awalan signature file PNG: `89 50 4E 47 0D 0A 1A 0A`.
const List<int> pngSignature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

/// True bila [bytes] adalah file PNG (dipakai untuk memilih jalur kompresi
/// yang mempertahankan transparansi).
bool isPngBytes(Uint8List bytes) {
  if (bytes.length < pngSignature.length) return false;
  for (var i = 0; i < pngSignature.length; i++) {
    if (bytes[i] != pngSignature[i]) return false;
  }
  return true;
}

/// Menerjemahkan kode error Firestore menjadi pesan yang bisa
/// ditindaklanjuti pengguna. Dipisah dari [AvatarService] agar bisa diuji
/// tanpa Firebase.
AvatarUploadException mapAvatarUploadError(String code) {
  switch (code) {
    case 'permission-denied':
      return const AvatarUploadException(
        'Tidak punya izin menyimpan foto profil.',
        code: 'permission-denied',
      );
    case 'unauthenticated':
      return const AvatarUploadException(
        'Sesi berakhir. Silakan masuk kembali lalu coba lagi.',
        code: 'unauthenticated',
      );
    case 'unavailable':
    case 'deadline-exceeded':
    case 'aborted':
    case 'internal':
    case 'unknown':
      return AvatarUploadException(
        'Koneksi tidak stabil. Foto belum tersimpan — coba lagi.',
        code: code,
        retryable: true,
      );
    case 'resource-exhausted':
    case 'quota-exceeded':
      return AvatarUploadException(
        'Kuota penyimpanan sedang penuh. Coba lagi nanti.',
        code: code,
      );
    case 'invalid-argument':
    case 'out-of-range':
      return const AvatarUploadException(
        'Foto tidak didukung. Coba pilih foto lain.',
        code: 'invalid-argument',
      );
    case 'not-found':
      return const AvatarUploadException(
        'Data profil tidak ditemukan. Masuk ulang lalu coba lagi.',
        code: 'not-found',
      );
    case 'failed-precondition':
      return const AvatarUploadException(
        'Layanan database belum siap. Coba lagi sebentar lagi.',
        code: 'failed-precondition',
        retryable: true,
      );
    default:
      return AvatarUploadException(
        'Gagal menyimpan foto. Coba lagi.',
        code: code,
        retryable: true,
      );
  }
}

final avatarServiceProvider = Provider<AvatarService>((ref) {
  return AvatarService();
});

/// Byte foto profil untuk [userId], dimuat ulang saat [marker] berubah.
///
/// Null berarti akun belum punya foto. Key berupa record agar Riverpod
/// otomatis membuang cache saat penanda versi berganti.
final avatarBytesProvider =
    FutureProvider.family<Uint8List?, ({String userId, String marker})>(
  (ref, key) => ref.read(avatarServiceProvider).fetch(key.userId),
);
