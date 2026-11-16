import 'dart:developer' as developer;
import 'dart:io';
import 'dart:typed_data';

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
  Future<Uint8List> compress(File file) async {
    final raw = await file.readAsBytes();
    try {
      final decoded = img.decodeImage(raw);
      if (decoded == null) return raw;

      var resized = decoded;
      if (decoded.width > maxDimension || decoded.height > maxDimension) {
        resized = decoded.width >= decoded.height
            ? img.copyResize(decoded, width: maxDimension)
            : img.copyResize(decoded, height: maxDimension);
      }

      final encoded = img.encodeJpg(resized, quality: jpegQuality);
      return Uint8List.fromList(encoded);
    } catch (e) {
      developer.log('Kompresi foto profil dilewati: $e');
      return raw;
    }
  }
}
