import 'package:flutter_test/flutter_test.dart';
import 'package:pilahin_app/core/waste/waste_types.dart';
import 'package:pilahin_app/features/result/data/guidance_media.dart';

void main() {
  group('GuidanceMediaResolver Unit Tests', () {
    test('parseAssetsForType mendeteksi video, poster, dan langkah secara selektif', () {
      final fakeAssetList = [
        // Aset untuk jenis kardus (cardboard)
        'assets/guidance/cardboard/video.mp4',
        'assets/guidance/cardboard/poster.jpg',
        'assets/guidance/cardboard/step_1.jpg',
        'assets/guidance/cardboard/step_3.png', // langkah 1 dan 3 ada, tetapi 2 tidak ada
        // Aset jenis lain (tidak boleh ikut terdeteksi)
        'assets/guidance/plastic/video.mp4',
        'assets/guidance/plastic/step_2.webp',
      ];

      final media = FlutterAssetGuidanceMediaResolver.parseAssetsForType(
        WasteType.cardboard,
        fakeAssetList,
      );

      // Video dan poster ada
      expect(media.hasVideo, isTrue);
      expect(media.videoPath, 'assets/guidance/cardboard/video.mp4');
      expect(media.hasPoster, isTrue);
      expect(media.posterPath, 'assets/guidance/cardboard/poster.jpg');

      // Langkah 1 dan 3 ada, langkah 2 tidak ada
      expect(media.hasStepImage(1), isTrue);
      expect(media.getStepImage(1), 'assets/guidance/cardboard/step_1.jpg');
      expect(media.hasStepImage(2), isFalse);
      expect(media.getStepImage(2), isNull);
      expect(media.hasStepImage(3), isTrue);
      expect(media.getStepImage(3), 'assets/guidance/cardboard/step_3.png');
    });

    test('parseAssetsForType menangani skenario tanpa video dan ekstensi beragam', () {
      final fakeAssetList = [
        'assets/guidance/battery/poster.png',
        'assets/guidance/battery/step_1.webp',
        'assets/guidance/battery/step_2.jpeg',
      ];

      final media = FlutterAssetGuidanceMediaResolver.parseAssetsForType(
        WasteType.battery,
        fakeAssetList,
      );

      expect(media.hasVideo, isFalse);
      expect(media.videoPath, isNull);
      expect(media.hasPoster, isTrue);
      expect(media.posterPath, 'assets/guidance/battery/poster.png');

      expect(media.hasStepImage(1), isTrue);
      expect(media.getStepImage(1), 'assets/guidance/battery/step_1.webp');
      expect(media.hasStepImage(2), isTrue);
      expect(media.getStepImage(2), 'assets/guidance/battery/step_2.jpeg');
      expect(media.hasStepImage(3), isFalse);
    });

    test('FakeGuidanceMediaResolver mengembalikan GuidanceMedia terkonfigurasi', () async {
      final fakeResolver = FakeGuidanceMediaResolver({
        WasteType.cardboard: const GuidanceMedia(
          videoPath: 'assets/guidance/cardboard/video.mp4',
          stepImages: {1: 'assets/guidance/cardboard/step_1.jpg'},
        ),
      });

      final cardboardMedia = await fakeResolver.resolve(WasteType.cardboard);
      expect(cardboardMedia.hasVideo, isTrue);
      expect(cardboardMedia.stepImages[1], 'assets/guidance/cardboard/step_1.jpg');

      // Jenis tanpa data mengembalikan GuidanceMedia kosong
      final plasticMedia = await fakeResolver.resolve(WasteType.plastic);
      expect(plasticMedia.hasVideo, isFalse);
      expect(plasticMedia.stepImages.isEmpty, isTrue);
    });
  });
}
