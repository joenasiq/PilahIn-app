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

    test('0.15 <= s < 0.18 dipetakan linear ke 0.30..0.58 (isUncertain = true)', () {
      expect(YoloWasteClassifier.calibrate(0.15), closeTo(0.30, 1e-9));
      expect(YoloWasteClassifier.calibrate(0.165), closeTo(0.44, 1e-6));
      expect(YoloWasteClassifier.calibrate(0.179), lessThan(0.60));
    });

    test('s >= 0.18 dipetakan ke 0.62..0.96 (objek ke-1 & ke-2 valid yakin)', () {
      expect(YoloWasteClassifier.calibrate(0.18), closeTo(0.62, 1e-9));
      expect(YoloWasteClassifier.calibrate(0.35), greaterThanOrEqualTo(0.62));
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
      o[4 + 0][0] = 0.80; // clothes * 0.22 = 0.176
      o[4 + 1][0] = 0.28; // paper >= 45% * 0.176
      final r = YoloWasteClassifier.postprocess(
        o,
        labels: labels,
        numAnchors: 1,
      );
      expect(r.single.classIndex, 1); // paper menang
      expect(r.single.score, greaterThanOrEqualTo(0.62));
    });

    test('Transparency Recovery (Tahap B): botol plastik bening (raw 0.7% vs juara kedua 0.2%) dengan konsensus cluster dipulihkan menjadi yakin', () {
      const labels = ['plastic', 'paper', 'cardboard'];
      final o = blank(4, 3);
      // 3 anchor beririsan pada botol plastik bening: plastic=0.007 (0.7%), runner-up=0.002 (0.2%)
      for (var a = 0; a < 3; a++) {
        set(o, a, 320 + a * 4.0, 320 + a * 4.0, 180, 260, 0, 0.007);
        o[4 + 1][a] = 0.002;
        o[4 + 2][a] = 0.001;
      }
      // 1 anchor background acak
      set(o, 3, 100, 100, 80, 80, 1, 0.003);
      o[4 + 2][3] = 0.0025;

      final r = YoloWasteClassifier.postprocess(
        o,
        labels: labels,
        numAnchors: 4,
      );
      expect(r.length, 1);
      expect(r.single.classIndex, 0); // plastic
      expect(r.single.score, greaterThanOrEqualTo(0.62));
    });

    test('Inner-Core Priority (Masalah #3): kertas di atas meja kayu coklat memenangkan paper dan menekan kotak luar cardboard', () {
      const labels = ['paper', 'cardboard'];
      final o = blank(2, 2);
      // Anchor 0: kotak luar lebih besar yang ikut menelan pinggiran meja kayu -> menebak cardboard (0.68)
      set(o, 0, 320, 320, 340, 360, 1, 0.68);
      // Anchor 1: kotak inti ketat tepat di atas kertas putih -> menebak paper (0.48)
      set(o, 1, 320, 320, 240, 260, 0, 0.48);

      final r = YoloWasteClassifier.postprocess(
        o,
        labels: labels,
        numAnchors: 2,
      );
      expect(r.length, 1);
      expect(r.single.classIndex, 0); // paper menang melawan cardboard
      expect(r.single.score, greaterThanOrEqualTo(0.62));
    });

    test('Aturan 1: satu objek fisik tidak boleh menghasilkan 2 label bertumpuk (Kertas + Kardus)', () {
      const labels = ['paper', 'cardboard'];
      final o = blank(2, 2);
      // Anchor 0: Kertas di sisi kiri (skor tinggi)
      set(o, 0, 180, 320, 220, 280, 0, 0.82);
      // Anchor 1: Kardus terkandung di objek kertas yang sama (>58% containment / pusat dekat)
      set(o, 1, 190, 330, 160, 200, 1, 0.55);

      final r = YoloWasteClassifier.postprocess(
        o,
        labels: labels,
        numAnchors: 2,
      );
      expect(r.length, 1);
      expect(r.single.classIndex, 0);
    });

    test('Aturan 2: kotak lebar (boxWidth > 0.68) yang menelan 2 objek dipenalti & 2 objek kiri-kanan bertahan', () {
      const labels = ['plastic', 'paper'];
      final o = blank(3, 2);
      // Anchor 0: kotak lebar plastic membungkus hampir seluruh layar (width=520/640=0.8125)
      set(o, 0, 320, 320, 520, 320, 0, 0.70);
      // Anchor 1: kertas ketat di sisi kiri
      set(o, 1, 150, 320, 180, 260, 1, 0.75);
      // Anchor 2: botol plastik ketat di sisi kanan
      set(o, 2, 480, 320, 160, 280, 0, 0.32);

      final r = YoloWasteClassifier.postprocess(
        o,
        labels: labels,
        numAnchors: 3,
      );
      expect(r.length, 2);
      expect(r[0].classIndex, 1); // Kertas di kiri
      expect(r[1].classIndex, 0); // Plastik di kanan
      expect(r[1].box.width, lessThan(0.55));
      expect(r[1].score, greaterThanOrEqualTo(0.62));
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

    test('Aturan 3 & 4: complementaryZones dan pickComplementary menemukan objek ke-2 di sisi berlawanan', () {
      const primaryLeft = Rect.fromLTRB(0.08, 0.25, 0.44, 0.75);
      final zonesRight = YoloWasteClassifier.complementaryZones(
        primaryLeft,
        0.85,
      );
      expect(zonesRight.length, 1);
      expect(zonesRight.single.left, closeTo(0.42, 1e-9));
      expect(zonesRight.single.right, closeTo(1.0, 1e-9));

      const bottleRight = YoloDetection(
        Rect.fromLTRB(0.55, 0.22, 0.86, 0.78),
        0.24,
        1,
        rawScore: 0.24,
      );
      const overlappingCardboard = YoloDetection(
        Rect.fromLTRB(0.10, 0.28, 0.42, 0.72),
        0.60,
        2,
        rawScore: 0.60,
      );
      final picked = YoloWasteClassifier.pickComplementary(
        primaryLeft,
        const [overlappingCardboard, bottleRight],
      );
      expect(picked, isNotNull);
      expect(picked!.classIndex, 1);
      expect(YoloWasteClassifier.calibrate(picked.score), greaterThanOrEqualTo(0.62));
    });

    test('roi sub-region mapping memetakan koordinat crop kembali ke gambar utuh', () {
      const labels = ['paper', 'plastic'];
      final o = blank(1, 2);
      set(o, 0, 320, 320, 320, 320, 0, 0.60);
      final r = YoloWasteClassifier.postprocess(
        o,
        labels: labels,
        numAnchors: 1,
        roi: const Rect.fromLTWH(0.20, 0.20, 0.60, 0.60),
      );
      expect(r.single.box.left, closeTo(0.20 + 0.25 * 0.60, 1e-9));
      expect(r.single.box.right, closeTo(0.20 + 0.75 * 0.60, 1e-9));
    });

    test('fallback: skor asli rendah < 0.15 tanpa konsensus cluster dipertahankan apa adanya', () {
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
