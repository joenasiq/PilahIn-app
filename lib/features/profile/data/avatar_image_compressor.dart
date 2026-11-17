import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Kompres & perkecil foto profil sebelum diunggah.
///
/// Dipisah dari [AvatarService] agar bisa diuji tanpa Firebase.
class AvatarImageCompressor {
  const AvatarImageCompressor({
    this.maxDimension = 512,
    this.jpegQuality = 85,
  });

  /// Ukuran sisi terpanjang gambar setelah dikompres.
  final int maxDimension;

  /// Kualitas JPEG hasil kompresi (0-100).
  final int jpegQuality;

  /// Mengembalikan byte JPEG hasil kompresi. Bila gambar gagal didekode,
  /// byte asli dikembalikan apa adanya agar unggahan tetap bisa dilakukan.
  Future<Uint8List> compress(File file, {int? quality}) async {
    final raw = await file.readAsBytes();
    return _compressBytes((
      bytes: raw,
      maxDimension: maxDimension,
      quality: quality ?? jpegQuality,
    ));
  }

  /// Sama seperti [compress], tetapi proses dekode/encode dijalankan di
  /// isolate terpisah agar UI tidak membeku saat memproses foto besar.
  ///
  /// [quality] opsional untuk mengompres ulang dengan kualitas lebih rendah
  /// ketika hasil pertama masih terlalu besar untuk Firestore.
  Future<Uint8List> compressInBackground(File file, {int? quality}) async {
    final raw = await file.readAsBytes();
    return compute(
      _compressBytes,
      (
        bytes: raw,
        maxDimension: maxDimension,
        quality: quality ?? jpegQuality,
      ),
    );
  }

  /// Mengompres byte gambar yang sudah ada di memori (mis. hasil crop).
  Future<Uint8List> compressBytes(Uint8List bytes, {int? quality}) async {
    return _compressBytes((
      bytes: bytes,
      maxDimension: maxDimension,
      quality: quality ?? jpegQuality,
    ));
  }

  /// Versi isolate dari [compressBytes].
  Future<Uint8List> compressBytesInBackground(
    Uint8List bytes, {
    int? quality,
  }) async {
    return compute(
      _compressBytes,
      (
        bytes: bytes,
        maxDimension: maxDimension,
        quality: quality ?? jpegQuality,
      ),
    );
  }
}

/// Dipakai baik di isolate utama maupun di isolate background.
Uint8List _compressBytes(
  ({Uint8List bytes, int maxDimension, int quality}) input,
) {
  final raw = input.bytes;
  try {
    final decoded = img.decodeImage(raw);
    if (decoded == null) return raw;

    var resized = decoded;
    if (decoded.width > input.maxDimension ||
        decoded.height > input.maxDimension) {
      resized = decoded.width >= decoded.height
          ? img.copyResize(decoded, width: input.maxDimension)
          : img.copyResize(decoded, height: input.maxDimension);
    }

    final encoded = img.encodeJpg(resized, quality: input.quality);
    return Uint8List.fromList(encoded);
  } catch (e) {
    developer.log('Kompresi foto profil dilewati: $e');
    return raw;
  }
}
