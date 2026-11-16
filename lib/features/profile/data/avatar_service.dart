import 'dart:developer' as developer;
import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'avatar_image_compressor.dart';

/// Penyimpanan foto profil di Firebase Storage.
///
/// Foto dikompres & diperkecil dulu (lihat [AvatarImageCompressor]) sebelum
/// diunggah agar hemat kuota dan cepat dimuat.
/// Path objek: `avatars/{uid}/profile.jpg`.
class AvatarService {
  AvatarService([this._storage, this._compressor = const AvatarImageCompressor()]);

  final FirebaseStorage? _storage;
  final AvatarImageCompressor _compressor;

  FirebaseStorage get _storageRef => _storage ?? FirebaseStorage.instance;

  Reference _ref(String userId) =>
      _storageRef.ref('avatars/$userId/profile.jpg');

  /// Mengunggah foto dari [filePath] dan mengembalikan download URL.
  Future<String> upload({
    required String userId,
    required String filePath,
  }) async {
    try {
      final Uint8List bytes = await _compressor.compress(File(filePath));
      final ref = _ref(userId);
      await ref.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg', cacheControl: 'no-cache'),
      );
      return await ref.getDownloadURL();
    } on FirebaseException catch (e) {
      developer.log('Upload foto profil gagal: ${e.code} ${e.message}');
      if (e.code == 'unauthorized') {
        throw Exception('Tidak punya izin mengunggah foto profil.');
      }
      if (e.code == 'canceled') {
        throw Exception('Unggahan foto dibatalkan.');
      }
      throw Exception('Gagal mengunggah foto. Periksa koneksi internet Anda.');
    } catch (e) {
      developer.log('Upload foto profil gagal: $e');
      throw Exception('Gagal mengunggah foto. Periksa koneksi internet Anda.');
    }
  }

  /// Menghapus foto profil. Tidak melempar error bila objek tidak ada.
  Future<void> delete(String userId) async {
    try {
      await _ref(userId).delete();
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found') return;
      developer.log('Hapus foto profil gagal: ${e.code} ${e.message}');
      throw Exception('Gagal menghapus foto profil.');
    } catch (e) {
      developer.log('Hapus foto profil gagal: $e');
      throw Exception('Gagal menghapus foto profil.');
    }
  }
}

final avatarServiceProvider = Provider<AvatarService>((ref) {
  return AvatarService();
});
