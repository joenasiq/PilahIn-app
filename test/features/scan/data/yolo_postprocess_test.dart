import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:pilahin_app/features/scan/data/yolo_waste_classifier.dart';

void main() {
  const neutral = ['a', 'b', 'c'];

  List<List<double>> blank(int anchors, int numClasses) => List.generate(
    4 + numClasses,
    (_) => List<double>.filled(anchors, 0),
  );

  void set(
    List<List<double>> o,
    int a,
    double xc,
    double yc,
    double w,
    double h,
    int cls,
    double score,
  ) {
    o[0][a] = xc;
    o[1][a] = yc;
    o[2][a] = w;
    o[3][a] = h;
    o[4 + cls][a] = score;
  }

  group('YoloWasteClassifier.calibrate', () {
    test('s < 0.15 tetap rendah (non-sampah seperti laptop 4.9% tetap 4.9%)', () {
      expect(YoloWasteClassifier.calibrate(0.049), closeTo(0.049, 1e-9));
      expect(YoloWasteClassifier.calibrate(0.14), closeTo(0.14, 1e-9));
    });

    test('0.15 <= s < 0.26 dipetakan linear ke 0.30..0.58 (isUncertain = true)', () {
      expect(YoloWasteClassifier.calibrate(0.15), closeTo(0.30, 1e-9));
      expect(YoloWasteClassifier.calibrate(0.205), closeTo(0.44, 1e-6));
      expect(YoloWasteClassifier.calibrate(0.259), lessThan(0.60));
    });

    test('s >= 0.26 dipetakan ke 0.62..0.96 (isUncertain = false)', () {
      expect(YoloWasteClassifier.calibrate(0.26), closeTo(0.62, 1e-9));
      expect(YoloWasteClassifier.calibrate(0.634), greaterThanOrEqualTo(0.62));
      expect(YoloWasteClassifier.calibrate(0.95), closeTo(0.96, 1e-9));
    });
  });

  group('YoloWasteClassifier.postprocess', () {
    test('anti-bias clothes: rival (paper/plastic) >= 45% skor clothes memenangkan anchor', () {
      const labels = ['clothes', 'paper'];
      final o = blank(1, 2);
      o[0][0] = 320;
      o[1][0] = 200;
      o[2][0] = 200;
      o[3][0] = 180;
      o[4 + 0][0] = 0.80; // clothes * 0.35 = 0.28
      o[4 + 1][0] = 0.28; // paper >= 45% * 0.28
      final r = YoloWasteClassifier.postprocess(
        o,
        labels: labels,
        numAnchors: 1,
      );
      expect(r.single.classIndex, 1); // paper menang
      expect(r.single.score, greaterThanOrEqualTo(0.62));
    });

    test('penalti kotak raksasa (width > 0.75 atau area > 0.52) dikali 0.50 & NMS class-specific mempertahankan 2 kelas berdampingan', () {
      const labels = ['plastic', 'paper'];
      final o = blank(3, 2);
      // Anchor 0: kotak raksasa plastic membungkus hampir seluruh layar (width=560/640=0.875) -> dipenalti *0.50
      set(o, 0, 320, 320, 560, 480, 0, 0.70);
      // Anchor 1: botol plastik ketat di kiri
      set(o, 1, 180, 320, 200, 280, 0, 0.50);
      // Anchor 2: kertas di kanan (beririsan sebagian dengan plastik tetapi beda kelas -> TIDAK dihapus NMS!)
      set(o, 2, 340, 320, 220, 280, 1, 0.45);

      final r = YoloWasteClassifier.postprocess(
        o,
        labels: labels,
        numAnchors: 3,
      );
      expect(r.any((d) => d.classIndex == 0), isTrue);
      expect(r.any((d) => d.classIndex == 1), isTrue);
    });

    test('same-class box merging: botol plastik terbelah (41.2% & 37.7%) menyatu jadi 1 kotak', () {
      const labels = ['plastic', 'paper'];
      final o = blank(2, 2);
      set(o, 0, 320, 220, 140, 220, 0, 0.412);
      set(o, 1, 320, 360, 140, 220, 0, 0.377);
      final r = YoloWasteClassifier.postprocess(
        o,
        labels: labels,
        numAnchors: 2,
      );
      expect(r.length, 1);
      expect(r.single.classIndex, 0);
      expect(r.single.rawScore, closeTo(0.633676, 1e-5));
      expect(r.single.score, greaterThanOrEqualTo(0.62));
      expect(r.single.box.top, closeTo((220 - 110) / 640, 1e-9));
      expect(r.single.box.bottom, closeTo((360 + 110) / 640, 1e-9));
    });

    test('roi sub-region mapping memetakan koordinat crop kembali ke gambar utuh', () {
      const labels = ['paper', 'plastic'];
      final o = blank(1, 2);
      // Objek tepat di tengah tile (320, 320) ukuran 320x320 (0.5x0.5 dari tile)
      set(o, 0, 320, 320, 320, 320, 0, 0.60);
      // Tile adalah Center Zoom 60%: left=0.20, top=0.20, width=0.60, height=0.60
      final r = YoloWasteClassifier.postprocess(
        o,
        labels: labels,
        numAnchors: 1,
        roi: const Rect.fromLTWH(0.20, 0.20, 0.60, 0.60),
      );
      expect(r.single.box.left, closeTo(0.20 + 0.25 * 0.60, 1e-9));
      expect(r.single.box.right, closeTo(0.20 + 0.75 * 0.60, 1e-9));
    });

    test('fallback: skor asli rendah < 0.15 dipertahankan apa adanya', () {
      final o = blank(2, 3);
      set(o, 0, 320, 320, 100, 100, 1, 0.049);
      set(o, 1, 100, 100, 50, 50, 2, 0.02);
      final r = YoloWasteClassifier.postprocess(
        o,
        labels: neutral,
        numAnchors: 2,
      );
      expect(r.length, 1);
      expect(r.single.classIndex, 1);
      expect(r.single.score, closeTo(0.049, 1e-9));
    });
  });
}
