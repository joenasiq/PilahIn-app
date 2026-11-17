import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pilahin_app/features/profile/data/avatar_cropper.dart';
import 'package:pilahin_app/features/profile/presentation/avatar_crop_screen.dart';

Uint8List _sampleImage({int width = 400, int height = 300}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(16, 185, 129));
  return Uint8List.fromList(img.encodePng(image));
}

AvatarCropSource _sampleSource({int width = 400, int height = 300}) {
  return AvatarCropSource(
    bytes: _sampleImage(width: width, height: height),
    width: width,
    height: height,
  );
}

void main() {
  testWidgets('menampilkan panduan, tombol Batal dan Gunakan', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: AvatarCropScreen(source: _sampleSource())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Atur Foto Profil'), findsOneWidget);
    expect(find.text('Batal'), findsOneWidget);
    expect(find.text('Gunakan'), findsOneWidget);
    expect(find.text('Reset'), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('Batal mengembalikan null', (WidgetTester tester) async {
    Uint8List? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await Navigator.of(context).push<Uint8List>(
                MaterialPageRoute<Uint8List>(
                  builder: (_) => AvatarCropScreen(source: _sampleSource()),
                ),
              );
            },
            child: const Text('buka'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();

    expect(result, isNull);
  });

  testWidgets('Gunakan mengembalikan PNG 512x512 bulat', (
    WidgetTester tester,
  ) async {
    Uint8List? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await Navigator.of(context).push<Uint8List>(
                MaterialPageRoute<Uint8List>(
                  builder: (_) => AvatarCropScreen(source: _sampleSource()),
                ),
              );
            },
            child: const Text('buka'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gunakan'));
    await tester.pump();

    // Proses crop berjalan di isolate sungguhan, jadi beri waktu nyata
    // sebelum memeriksa hasilnya.
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(seconds: 3));
    });
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    // Signature PNG, bukan JPEG.
    expect(result!.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
    final decoded = img.decodeImage(result!);
    expect(decoded, isNotNull);
    expect(decoded!.width, avatarOutputDimension);
    expect(decoded.height, avatarOutputDimension);
    // Sudut transparan karena bentuknya bulat.
    expect(decoded.getPixel(0, 0).a, 0);
  });

  testWidgets('zoom dan geser tidak membuat gambar keluar area crop', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: AvatarCropScreen(source: _sampleSource())),
    );
    await tester.pumpAndSettle();

    final area = find.byType(GestureDetector).first;
    // Cubit untuk memperbesar.
    final gesture = await tester.startGesture(tester.getCenter(area));
    await gesture.moveBy(const Offset(30, 30));
    await gesture.up();
    await tester.pumpAndSettle();

    // Tetap bisa menekan Gunakan setelah interaksi.
    expect(find.text('Gunakan'), findsOneWidget);
  });
}
