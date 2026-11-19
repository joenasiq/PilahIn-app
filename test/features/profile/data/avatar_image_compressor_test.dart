import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pilahin_app/features/profile/data/avatar_image_compressor.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('pilahin_avatar_test');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<File> writeImage(int width, int height, {bool asPng = true}) async {
    final image = img.Image(width: width, height: height);
    img.fill(image, color: img.ColorRgb8(16, 185, 129));
    final bytes = asPng ? img.encodePng(image) : img.encodeJpg(image);
    final file = File('${tempDir.path}/input.${asPng ? 'png' : 'jpg'}');
    await file.writeAsBytes(bytes);
    return file;
  }

  test('memperkecil gambar besar ke sisi terpanjang 512 px', () async {
    final file = await writeImage(2000, 1200);

    final result = await const AvatarImageCompressor().compress(file);
    final decoded = img.decodeImage(result);

    expect(decoded, isNotNull);
    expect(decoded!.width, 512);
    expect(decoded.height, 307); // 1200 * (512/2000) = 307
    // Hasil selalu JPEG, jadi jauh lebih kecil dari PNG 2000x1200.
    expect(result.length, lessThan(await file.length()));
  });

  test('gambar kecil tidak diperbesar', () async {
    final file = await writeImage(200, 150);

    final result = await const AvatarImageCompressor().compress(file);
    final decoded = img.decodeImage(result);

    expect(decoded!.width, 200);
    expect(decoded.height, 150);
  });

  test('memakai sisi tinggi bila potret', () async {
    final file = await writeImage(400, 1600);

    final result = await const AvatarImageCompressor().compress(file);
    final decoded = img.decodeImage(result);

    expect(decoded!.height, 512);
    expect(decoded.width, 128); // 400 * (512/1600)
  });

  test('byte asli dikembalikan bila gambar tidak bisa didekode', () async {
    final file = File('${tempDir.path}/rusak.jpg');
    final raw = List<int>.generate(64, (i) => i);
    await file.writeAsBytes(raw);

    final result = await const AvatarImageCompressor().compress(file);

    expect(result, equals(raw));
  });

  test('compressInBackground memberi hasil sama dengan compress', () async {
    final file = await writeImage(1600, 900);
    const compressor = AvatarImageCompressor();

    final background = await compressor.compressInBackground(file);
    final direct = await compressor.compress(file);
    final decoded = img.decodeImage(background);

    expect(decoded, isNotNull);
    expect(decoded!.width, 512);
    expect(background, equals(direct));
  });

  test('kualitas lebih rendah menghasilkan byte lebih kecil', () async {
    final file = await writeImage(1200, 1200);
    const compressor = AvatarImageCompressor();

    final high = await compressor.compressInBackground(file, quality: 85);
    final low = await compressor.compressInBackground(file, quality: 40);

    expect(img.decodeImage(low)!.width, 512);
    expect(low.length, lessThan(high.length));
  });
}
