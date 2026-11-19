import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Offset, Rect, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pilahin_app/features/profile/data/avatar_cropper.dart';

void main() {
  group('computeAvatarCropRect', () {
    test('gambar persegi: seluruh gambar dipakai tanpa zoom', () {
      final rect = computeAvatarCropRect(
        imageSize: const Size(1000, 1000),
        viewportSide: 300,
      );

      expect(rect.left, closeTo(0, 0.01));
      expect(rect.top, closeTo(0, 0.01));
      expect(rect.width, closeTo(1000, 0.01));
      expect(rect.height, closeTo(1000, 0.01));
    });

    test('gambar lanskap: crop persegi di tengah', () {
      final rect = computeAvatarCropRect(
        imageSize: const Size(2000, 1000),
        viewportSide: 300,
      );

      expect(rect.width, closeTo(1000, 0.01));
      expect(rect.height, closeTo(1000, 0.01));
      // Sisi kiri & kanan terpotong sama banyak.
      expect(rect.left, closeTo(500, 0.01));
      expect(rect.top, closeTo(0, 0.01));
    });

    test('gambar potret: crop persegi di tengah', () {
      final rect = computeAvatarCropRect(
        imageSize: const Size(1000, 2000),
        viewportSide: 300,
      );

      expect(rect.width, closeTo(1000, 0.01));
      expect(rect.height, closeTo(1000, 0.01));
      expect(rect.left, closeTo(0, 0.01));
      expect(rect.top, closeTo(500, 0.01));
    });

    test('zoom 2x memotong setengah sisi', () {
      final rect = computeAvatarCropRect(
        imageSize: const Size(1000, 1000),
        viewportSide: 300,
        scale: 2,
      );

      expect(rect.width, closeTo(500, 0.01));
      expect(rect.height, closeTo(500, 0.01));
      expect(rect.left, closeTo(250, 0.01));
      expect(rect.top, closeTo(250, 0.01));
    });

    test('geseran melewati batas tetap di dalam gambar', () {
      final rect = computeAvatarCropRect(
        imageSize: const Size(2000, 1000),
        viewportSide: 300,
        offset: const Offset(5000, 5000),
      );

      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(2000));
      expect(rect.bottom, lessThanOrEqualTo(1000));
      expect(rect.width, closeTo(rect.height, 0.01));
    });

    test('ukuran tidak valid menghasilkan Rect kosong', () {
      expect(
        computeAvatarCropRect(imageSize: Size.zero, viewportSide: 300),
        Rect.zero,
      );
      expect(
        computeAvatarCropRect(
          imageSize: const Size(100, 100),
          viewportSide: 0,
        ),
        Rect.zero,
      );
    });

    test('hasil selalu persegi untuk berbagai rasio', () {
      const sizes = [
        Size(4000, 3000),
        Size(3000, 4000),
        Size(1920, 1080),
        Size(1080, 1920),
        Size(800, 800),
      ];
      for (final size in sizes) {
        for (final scale in [1.0, 1.5, 3.0]) {
          final rect = computeAvatarCropRect(
            imageSize: size,
            viewportSide: 300,
            scale: scale,
            offset: const Offset(40, -25),
          );
          expect(
            rect.width,
            closeTo(rect.height, 0.01),
            reason: '$size @ $scale',
          );
          expect(rect.left, greaterThanOrEqualTo(-0.01), reason: '$size');
          expect(rect.top, greaterThanOrEqualTo(-0.01), reason: '$size');
          expect(rect.right, lessThanOrEqualTo(size.width + 0.01));
          expect(rect.bottom, lessThanOrEqualTo(size.height + 0.01));
        }
      }
    });
  });

  group('clampAvatarOffset', () {
    test('gambar dengan rasio sama tidak bisa digeser', () {
      final offset = clampAvatarOffset(
        imageSize: const Size(1000, 1000),
        viewportSide: 300,
        scale: 1,
        offset: const Offset(500, 500),
      );

      expect(offset.dx, closeTo(0, 0.01));
      expect(offset.dy, closeTo(0, 0.01));
    });

    test('lanskap hanya bisa digeser horizontal sebesar sisa gambar', () {
      final offset = clampAvatarOffset(
        imageSize: const Size(2000, 1000),
        viewportSide: 300,
        scale: 1,
        offset: const Offset(1000, 1000),
      );

      // Lebar tampil 600 px, viewport 300 -> sisa 150 di tiap sisi.
      expect(offset.dx, closeTo(150, 0.01));
      expect(offset.dy, closeTo(0, 0.01));
    });

    test('zoom menambah ruang geser', () {
      final atOne = clampAvatarOffset(
        imageSize: const Size(2000, 1000),
        viewportSide: 300,
        scale: 1,
        offset: const Offset(9999, 9999),
      );
      final atTwo = clampAvatarOffset(
        imageSize: const Size(2000, 1000),
        viewportSide: 300,
        scale: 2,
        offset: const Offset(9999, 9999),
      );

      expect(atTwo.dx, greaterThan(atOne.dx));
      expect(atTwo.dy, greaterThan(atOne.dy));
    });
  });

  group('cropAvatarCircle', () {
    test('menghasilkan PNG 512x512 dengan sudut transparan', () async {
      final image = img.Image(width: 2000, height: 1000);
      img.fill(image, color: img.ColorRgb8(16, 185, 129));
      final source = AvatarCropSource(
        bytes: img.encodePng(image),
        width: 2000,
        height: 1000,
      );

      final rect = computeAvatarCropRect(
        imageSize: source.size,
        viewportSide: 300,
      );
      final result = await cropAvatarCircle(source: source, cropRect: rect);
      final decoded = img.decodeImage(result);

      expect(decoded, isNotNull);
      expect(decoded!.width, avatarOutputDimension);
      expect(decoded.height, avatarOutputDimension);
      // PNG signature
      expect(result.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
      expect(decoded.hasAlpha, isTrue);
    });

    test('piksel pojok transparan, piksel tengah opak', () async {
      final image = img.Image(width: 600, height: 600);
      img.fill(image, color: img.ColorRgb8(5, 150, 105));
      final source = AvatarCropSource(
        bytes: img.encodePng(image),
        width: 600,
        height: 600,
      );

      final result = await cropAvatarCircle(
        source: source,
        cropRect: const Rect.fromLTWH(0, 0, 600, 600),
      );
      final decoded = img.decodeImage(result)!;

      expect(decoded.getPixel(0, 0).a, 0);
      expect(decoded.getPixel(decoded.width - 1, 0).a, 0);
      final center = decoded.width ~/ 2;
      expect(decoded.getPixel(center, center).a, 255);
    });

    test('maxBytes kecil memaksa dimensi turun tapi tetap PNG', () async {
      final image = img.Image(width: 800, height: 800);
      // Piksel acak (deterministik) supaya PNG tidak mudah dikompres.
      var seed = 12345;
      for (var y = 0; y < image.height; y++) {
        for (var x = 0; x < image.width; x++) {
          seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF;
          image.setPixelRgba(
            x,
            y,
            seed & 0xFF,
            (seed >> 8) & 0xFF,
            (seed >> 16) & 0xFF,
            255,
          );
        }
      }
      final source = AvatarCropSource(
        bytes: img.encodePng(image),
        width: 800,
        height: 800,
      );

      // Batas 450 KB: 512 px (noise acak) pasti lebih besar, jadi crop harus
      // turun dimensi sampai muat.
      const limit = 450 * 1024;
      final result = await cropAvatarCircle(
        source: source,
        cropRect: const Rect.fromLTWH(0, 0, 800, 800),
        maxBytes: limit,
      );
      final decoded = img.decodeImage(result)!;

      expect(result.length, lessThanOrEqualTo(limit));
      expect(decoded.width, lessThan(avatarOutputDimension));
      expect(decoded.width, decoded.height);
      expect(result.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
    });

    test('crop rect di luar batas tetap menghasilkan gambar valid', () async {
      final image = img.Image(width: 300, height: 300);
      img.fill(image, color: img.ColorRgb8(5, 150, 105));
      final source = AvatarCropSource(
        bytes: img.encodePng(image),
        width: 300,
        height: 300,
      );

      final result = await cropAvatarCircle(
        source: source,
        cropRect: const Rect.fromLTWH(-500, -500, 4000, 4000),
      );

      expect(img.decodeImage(result)!.width, avatarOutputDimension);
    });

    test('byte rusak melempar FormatException', () async {
      final source = AvatarCropSource(
        bytes: Uint8List.fromList(List<int>.generate(32, (i) => i)),
        width: 10,
        height: 10,
      );

      expect(
        () => cropAvatarCircle(
          source: source,
          cropRect: const Rect.fromLTWH(0, 0, 10, 10),
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('shrinkAvatarPng', () {
    test('byte yang sudah kecil dikembalikan apa adanya', () async {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final result = await shrinkAvatarPng(bytes, maxBytes: 1024);

      expect(result, equals(bytes));
    });

    test('PNG besar dikecilkan tanpa kehilangan alpha', () async {
      final image = img.Image(width: 700, height: 700);
      var seed = 98765;
      for (var y = 0; y < image.height; y++) {
        for (var x = 0; x < image.width; x++) {
          seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF;
          image.setPixelRgba(
            x,
            y,
            seed & 0xFF,
            (seed >> 8) & 0xFF,
            (seed >> 16) & 0xFF,
            255,
          );
        }
      }
      final original = Uint8List.fromList(img.encodePng(image, level: 9));

      final result = await shrinkAvatarPng(original, maxBytes: 40 * 1024);
      final decoded = img.decodeImage(result);

      expect(decoded, isNotNull);
      expect(decoded!.width, lessThan(700));
      expect(decoded.numChannels, 4);
    });
  });

  group('prepareAvatarCropSource', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('pilahin_crop_test');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    Future<File> writeImage(int width, int height) async {
      final image = img.Image(width: width, height: height);
      img.fill(image, color: img.ColorRgb8(52, 211, 153));
      final file = File('${tempDir.path}/src.png');
      await file.writeAsBytes(img.encodePng(image));
      return file;
    }

    test('foto besar diperkecil ke sisi terpanjang 1024', () async {
      final file = await writeImage(2000, 1200);

      final source = await prepareAvatarCropSource(file.path);

      expect(source.width, maxSourceDimension);
      expect(source.height, 614);
      expect(img.decodeImage(source.bytes), isNotNull);
    });

    test('foto kecil tidak diperbesar', () async {
      final file = await writeImage(400, 300);

      final source = await prepareAvatarCropSource(file.path);

      expect(source.width, 400);
      expect(source.height, 300);
    });

    test('file tidak ada melempar FormatException', () async {
      expect(
        () => prepareAvatarCropSource('${tempDir.path}/tidak-ada.png'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
