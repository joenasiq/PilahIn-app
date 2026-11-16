import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:pilahin_app/features/scan/data/scan_image_cropper.dart';

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.tempPath);

  final String tempPath;

  @override
  Future<String?> getTemporaryPath() async => tempPath;
}

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('pilahin_crop_test');
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  String writeImage(int width, int height, {bool fillAll = true}) {
    final image = img.Image(width: width, height: height);
    if (fillAll) {
      for (final pixel in image) {
        pixel
          ..r = 200
          ..g = 40
          ..b = 40;
      }
    }
    final path =
        '${tempDir.path}${Platform.pathSeparator}in_${width}x$height.jpg';
    File(path).writeAsBytesSync(img.encodeJpg(image, quality: 90));
    return path;
  }

  img.Image decode(String path) =>
      img.bakeOrientation(img.decodeImage(File(path).readAsBytesSync())!);

  test('foto 9:16 (720x1280) dipotong tengah menjadi 3:4', () async {
    final outPath = await cropImageToScanAspect(writeImage(720, 1280));
    final out = decode(outPath);

    expect(out.width, 720);
    expect(out.height, 960);
    expect(out.width / out.height, closeTo(scanAspectRatio, 0.001));
  });

  test('foto landscape (1280x720) dipotong kiri/kanan menjadi 3:4', () async {
    final outPath = await cropImageToScanAspect(writeImage(1280, 720));
    final out = decode(outPath);

    expect(out.width, 540);
    expect(out.height, 720);
    expect(out.width / out.height, closeTo(scanAspectRatio, 0.001));
  });

  test('foto yang sudah 3:4 tidak dipotong ulang', () async {
    final source = writeImage(720, 960);
    final outPath = await cropImageToScanAspect(source);

    expect(outPath, source);
  });

  test('file tidak terbaca mengembalikan path asli', () async {
    final missing = '${tempDir.path}${Platform.pathSeparator}missing.jpg';
    final outPath = await cropImageToScanAspect(missing);

    expect(outPath, missing);
  });

  test('crop tidak mengubah isi piksel (tidak stretch)', () async {
    // Gambar 2 warna: kiri merah, kanan biru. Center-crop 16:9 -> 3:4 harus
    // membuang tepi kiri & kanan, bukan meregangkan warna.
    final image = img.Image(width: 1600, height: 900);
    for (final pixel in image) {
      final isRed = pixel.x < image.width ~/ 2;
      pixel
        ..r = isRed ? 255 : 0
        ..g = 0
        ..b = isRed ? 0 : 255;
    }
    final source =
        '${tempDir.path}${Platform.pathSeparator}two_color.jpg';
    File(source).writeAsBytesSync(img.encodeJpg(image, quality: 100));

    final out = decode(await cropImageToScanAspect(source));

    expect(out.width / out.height, closeTo(scanAspectRatio, 0.001));
    // Tepi kiri tetap merah, tepi kanan tetap biru.
    expect(out.getPixel(0, out.height ~/ 2).r, greaterThan(200));
    expect(out.getPixel(out.width - 1, out.height ~/ 2).b, greaterThan(200));
  });
}
