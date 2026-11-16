import 'dart:io';
import 'dart:isolate';

import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

/// Rasio aspek target seluruh alur pindai (lebar / tinggi).
/// Dipakai oleh preview kamera dan hasil foto agar konsisten 3:4.
const double scanAspectRatio = 3 / 4;

/// Memotong [sourcePath] menjadi rasio 3:4 memakai center-crop.
///
/// Potongan diambil dari tengah (sisi kiri/kanan atau atas/bawah), sehingga
/// gambar tidak pernah diregangkan. Bila gambar sudah 3:4 atau gagal dibaca,
/// path asli dikembalikan agar pemindaian tetap berjalan.
Future<String> cropImageToScanAspect(String sourcePath) async {
  try {
    final tmpDir = await getTemporaryDirectory();
    final outPath =
        '${tmpDir.path}${Platform.pathSeparator}'
        'scan_${DateTime.now().microsecondsSinceEpoch}.jpg';
    final result = await Isolate.run(() => _cropFile(sourcePath, outPath));
    return result ?? sourcePath;
  } catch (_) {
    return sourcePath;
  }
}

/// Dijalankan di isolate terpisah: decode -> bake EXIF -> center-crop 3:4 ->
/// encode JPEG. Mengembalikan null bila tidak perlu / tidak bisa dipotong.
String? _cropFile(String sourcePath, String outPath) {
  final file = File(sourcePath);
  if (!file.existsSync()) return null;

  final decoded = img.decodeImage(file.readAsBytesSync());
  if (decoded == null) return null;

  final image = img.bakeOrientation(decoded);
  final width = image.width;
  final height = image.height;
  if (width <= 0 || height <= 0) return null;

  final current = width / height;
  if ((current - scanAspectRatio).abs() <= scanAspectRatio * 0.005) {
    return null;
  }

  late final img.Image cropped;
  if (current > scanAspectRatio) {
    final newWidth = (height * scanAspectRatio).round().clamp(1, width);
    final left = ((width - newWidth) / 2).round();
    cropped = img.copyCrop(
      image,
      x: left,
      y: 0,
      width: newWidth,
      height: height,
    );
  } else {
    final newHeight = (width / scanAspectRatio).round().clamp(1, height);
    final top = ((height - newHeight) / 2).round();
    cropped = img.copyCrop(
      image,
      x: 0,
      y: top,
      width: width,
      height: newHeight,
    );
  }

  File(outPath).writeAsBytesSync(img.encodeJpg(cropped, quality: 92));
  return outPath;
}
