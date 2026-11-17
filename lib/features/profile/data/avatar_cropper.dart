import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Offset, Rect, Size;

import 'package:image/image.dart' as img;

/// Sumber gambar untuk layar crop foto profil.
///
/// Sudah diperkecil ke maks [maxSourceDimension] dan orientasinya dibakar,
/// supaya layar crop tidak perlu menahan foto 12 MP di memori.
class AvatarCropSource {
  const AvatarCropSource({
    required this.bytes,
    required this.width,
    required this.height,
  });

  final Uint8List bytes;
  final int width;
  final int height;

  Size get size => Size(width.toDouble(), height.toDouble());
}

/// Sisi terpanjang gambar sumber setelah diperkecil.
const int maxSourceDimension = 1024;

/// Sisi hasil akhir foto profil (persegi, sudut transparan).
const int avatarOutputDimension = 512;

/// Batas ukuran PNG sebelum base64. 700 KB -> ±933 KB base64, masih di
/// bawah batas 1 MiB per dokumen Firestore.
const int avatarCircleMaxBytes = 700 * 1024;

/// Dimensi yang dicoba berurutan sampai PNG muat di [avatarCircleMaxBytes].
///
/// PNG tidak punya parameter kualitas, jadi satu-satunya cara mengecilkan
/// adalah menurunkan dimensi.
const List<int> avatarPngSizeSteps = [512, 448, 384, 320, 288, 256];

/// Batas zoom di layar crop.
const double minAvatarCropScale = 1.0;
const double maxAvatarCropScale = 4.0;

/// Membaca [sourcePath] lalu menyiapkan gambar untuk layar crop.
///
/// Dekode, perbaikan orientasi, dan encode dijalankan di isolate terpisah
/// agar UI tidak membeku. Melempar [FormatException] bila gambar tidak bisa
/// didekode.
Future<AvatarCropSource> prepareAvatarCropSource(String sourcePath) async {
  final result = await Isolate.run(() => _prepareSource(sourcePath));
  if (result == null) {
    throw const FormatException('Foto tidak dapat dibaca');
  }
  return result;
}

AvatarCropSource? _prepareSource(String sourcePath) {
  final file = File(sourcePath);
  if (!file.existsSync()) return null;

  final decoded = img.decodeImage(file.readAsBytesSync());
  if (decoded == null) return null;

  var image = img.bakeOrientation(decoded);
  if (image.width > maxSourceDimension || image.height > maxSourceDimension) {
    image = image.width >= image.height
        ? img.copyResize(image, width: maxSourceDimension)
        : img.copyResize(image, height: maxSourceDimension);
  }

  return AvatarCropSource(
    bytes: Uint8List.fromList(img.encodeJpg(image, quality: 90)),
    width: image.width,
    height: image.height,
  );
}

/// Skala minimum agar gambar menutup penuh area crop persegi.
///
/// Dipakai layar crop untuk menghitung ukuran tampil gambar.
double avatarCoverScale({required Size imageSize, required double viewportSide}) {
  if (imageSize.width <= 0 || imageSize.height <= 0 || viewportSide <= 0) {
    return 1;
  }
  return (viewportSide / imageSize.width) > (viewportSide / imageSize.height)
      ? viewportSide / imageSize.width
      : viewportSide / imageSize.height;
}

/// Menghitung area gambar (dalam piksel gambar asli) yang akan dipotong.
///
/// [offset] adalah geseran pusat gambar dari pusat area crop, [scale] adalah
/// zoom pengguna (1 = pas menutup area). Hasil selalu persegi dan sudah
/// di-clamp ke dalam batas gambar, jadi tidak mungkin keluar kanvas.
Rect computeAvatarCropRect({
  required Size imageSize,
  required double viewportSide,
  double scale = minAvatarCropScale,
  Offset offset = Offset.zero,
}) {
  if (imageSize.width <= 0 || imageSize.height <= 0 || viewportSide <= 0) {
    return Rect.zero;
  }

  final safeScale = scale.clamp(minAvatarCropScale, maxAvatarCropScale);
  final effectiveScale =
      avatarCoverScale(imageSize: imageSize, viewportSide: viewportSide) *
          safeScale;

  // Sisi area crop dalam satuan piksel gambar.
  final cropSide = (viewportSide / effectiveScale).clamp(
    1.0,
    imageSize.width < imageSize.height ? imageSize.width : imageSize.height,
  );

  // Pusat gambar di koordinat gambar (sebelum digeser).
  final centerX = imageSize.width / 2 - offset.dx / effectiveScale;
  final centerY = imageSize.height / 2 - offset.dy / effectiveScale;

  final maxLeft = imageSize.width - cropSide;
  final maxTop = imageSize.height - cropSide;

  final left = (centerX - cropSide / 2).clamp(0.0, maxLeft);
  final top = (centerY - cropSide / 2).clamp(0.0, maxTop);

  return Rect.fromLTWH(left, top, cropSide, cropSide);
}

/// Batas geseran maksimum agar gambar tidak menyisakan ruang kosong.
Offset clampAvatarOffset({
  required Size imageSize,
  required double viewportSide,
  required double scale,
  required Offset offset,
}) {
  if (imageSize.width <= 0 || imageSize.height <= 0 || viewportSide <= 0) {
    return Offset.zero;
  }

  final effectiveScale =
      avatarCoverScale(imageSize: imageSize, viewportSide: viewportSide) *
          scale.clamp(minAvatarCropScale, maxAvatarCropScale);

  final displayedWidth = imageSize.width * effectiveScale;
  final displayedHeight = imageSize.height * effectiveScale;

  final maxX = ((displayedWidth - viewportSide) / 2).clamp(0.0, double.infinity);
  final maxY =
      ((displayedHeight - viewportSide) / 2).clamp(0.0, double.infinity);

  return Offset(
    offset.dx.clamp(-maxX, maxX),
    offset.dy.clamp(-maxY, maxY),
  );
}

/// Memotong [source] sesuai [cropRect], mengecilkannya menjadi persegi, lalu
/// memotong sudutnya menjadi lingkaran dengan tepi anti-aliasing.
///
/// Hasilnya **PNG ber-alpha**: piksel di luar lingkaran transparan penuh.
/// Bila hasil melebihi [maxBytes], dimensi diturunkan bertahap mengikuti
/// [avatarPngSizeSteps].
///
/// Berjalan di isolate terpisah. Melempar [FormatException] bila sumber tidak
/// bisa didekode.
Future<Uint8List> cropAvatarCircle({
  required AvatarCropSource source,
  required Rect cropRect,
  int maxBytes = avatarCircleMaxBytes,
}) async {
  final result = await Isolate.run(
    () => _cropCircle(source.bytes, cropRect, maxBytes),
  );
  if (result == null) {
    throw const FormatException('Foto tidak dapat dibaca');
  }
  return result;
}

Uint8List? _cropCircle(Uint8List bytes, Rect cropRect, int maxBytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;

  final x = cropRect.left.round().clamp(0, decoded.width - 1);
  final y = cropRect.top.round().clamp(0, decoded.height - 1);
  final width = cropRect.width.round().clamp(1, decoded.width - x);
  final height = cropRect.height.round().clamp(1, decoded.height - y);

  final cropped = img.copyCrop(
    decoded,
    x: x,
    y: y,
    width: width,
    height: height,
  );

  Uint8List? smallest;
  for (final dimension in avatarPngSizeSteps) {
    var resized = img.copyResize(
      cropped,
      width: dimension,
      height: dimension,
      interpolation: img.Interpolation.average,
    );
    // Pastikan kanal alpha tersedia; setPixelRgba diabaikan bila gambar
    // hanya punya 3 kanal.
    if (resized.numChannels != 4) {
      resized = resized.convert(numChannels: 4);
    }
    _applyCircleMask(resized);
    final encoded = Uint8List.fromList(img.encodePng(resized, level: 9));
    smallest = encoded;
    if (encoded.length <= maxBytes) return encoded;
  }

  return smallest;
}

/// Membuat piksel di luar lingkaran menjadi transparan.
///
/// Tepi diberi alpha bertingkat (anti-aliasing) agar tidak bergerigi:
/// `coverage = radius - jarak + 0.5`, di-clamp 0..1.
void _applyCircleMask(img.Image image) {
  final size = image.width;
  final center = (size - 1) / 2;
  final radius = size / 2;

  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final dx = x - center;
      final dy = y - center;
      final distance = math.sqrt(dx * dx + dy * dy);
      final coverage = (radius - distance + 0.5).clamp(0.0, 1.0);
      final pixel = image.getPixel(x, y);
      image.setPixelRgba(
        x,
        y,
        pixel.r,
        pixel.g,
        pixel.b,
        (255 * coverage).round(),
      );
    }
  }
}

/// Mengecilkan PNG yang sudah ber-alpha tanpa menghilangkan transparansi.
///
/// Dipakai [AvatarService] ketika byte hasil crop masih terlalu besar untuk
/// dokumen Firestore. Berbeda dengan kompresor JPEG, fungsi ini tidak pernah
/// meng-encode ulang ke JPEG.
Future<Uint8List> shrinkAvatarPng(
  Uint8List bytes, {
  int maxBytes = avatarCircleMaxBytes,
}) async {
  if (bytes.length <= maxBytes) return bytes;

  final result = await Isolate.run(() => _shrinkPng(bytes, maxBytes));
  return result ?? bytes;
}

Uint8List? _shrinkPng(Uint8List bytes, int maxBytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;

  Uint8List? smallest;
  for (final dimension in avatarPngSizeSteps) {
    if (dimension >= decoded.width) continue;
    var resized = img.copyResize(
      decoded,
      width: dimension,
      height: dimension,
      interpolation: img.Interpolation.average,
    );
    if (resized.numChannels != 4) {
      resized = resized.convert(numChannels: 4);
    }
    final encoded = Uint8List.fromList(img.encodePng(resized, level: 9));
    smallest = encoded;
    if (encoded.length <= maxBytes) return encoded;
  }

  return smallest;
}

