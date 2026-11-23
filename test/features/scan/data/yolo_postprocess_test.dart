import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:pilahin_app/features/scan/data/yolo_waste_classifier.dart';

void main() {
  List<List<double>> blank(int anchors, int numClasses) => List.generate(
    4 + numClasses,
    (_) => List<double>.filled(anchors, 0),
  );

  // Koordinat dalam piksel kanvas 640 (letterbox penuh, tanpa padding).
  void set(
    List<List<double>> o,
    int a,
    double xc,
    double yc,
    double w,
    double h,
    Map<int, double> scores,
  ) {
    o[0][a] = xc;
    o[1][a] = yc;
    o[2][a] = w;
    o[3][a] = h;
    scores.forEach((c, s) => o[4 + c][a] = s);
  }

  group('calibrate (V4)', () {
    test('skor < 0.22 tetap apa adanya (tidak yakin)', () {
      expect(YoloWasteClassifier.calibrate(0.049), closeTo(0.049, 1e-9));
      expect(YoloWasteClassifier.calibrate(0.19), lessThan(0.20));
      expect(YoloWasteClassifier.calibrate(0.21), lessThan(0.60));
    });

    test('skor >= 0.22 dipetakan halus & proporsional ke 0.62..0.96', () {
      expect(YoloWasteClassifier.calibrate(0.22), closeTo(0.62, 1e-9));
      expect(
        YoloWasteClassifier.calibrate(0.50),
        greaterThan(YoloWasteClassifier.calibrate(0.30)),
      );
      expect(YoloWasteClassifier.calibrate(0.95), closeTo(0.96, 1e-9));
    });
  });

  group('extractCandidates (V4)', () {
    test('un-letterbox 3:4 portrait (480x640, padX=80) ke koordinat gambar asli', () {
      const labels = ['paper', 'plastic'];
      final o = blank(1, 2);
      // Gambar 3:4 -> 480x640, padX=80. Objek tepat di tengah gambar.
      set(o, 0, 320, 320, 240, 320, {0: 0.8});
      final r = YoloWasteClassifier.extractCandidates(
        o,
        labels: labels,
        numAnchors: 1,
        padX: 80,
        newWidth: 480,
        newHeight: 640,
      );
      final b = r.candidates.single.box;
      expect(b.left, closeTo(0.25, 1e-9));
      expect(b.right, closeTo(0.75, 1e-9));
      expect(b.top, closeTo(0.25, 1e-9));
      expect(b.bottom, closeTo(0.75, 1e-9));
    });

    test('tie-breaker ringan: paper menang atas cardboard bila paper >= 0.45 * cardboard', () {
      const labels = ['cardboard', 'paper'];
      final o = blank(2, 2);
      set(o, 0, 200, 320, 200, 200, {0: 0.60, 1: 0.28}); // 0.28 >= 0.27 -> paper
      set(o, 1, 450, 320, 200, 200, {0: 0.60, 1: 0.20}); // 0.20 < 0.27 -> cardboard
      final r = YoloWasteClassifier.extractCandidates(
        o,
        labels: labels,
        numAnchors: 2,
      );
      expect(r.candidates.length, 2);
      expect(r.candidates.any((d) => d.classIndex == 1), isTrue);
      expect(r.candidates.any((d) => d.classIndex == 0), isTrue);
    });

    test('clothes faktor ringan 0.90 tidak memotong skor secara ekstrem', () {
      const labels = ['clothes', 'plastic'];
      final o = blank(1, 2);
      set(o, 0, 320, 320, 200, 200, {0: 0.50, 1: 0.10});
      final r = YoloWasteClassifier.extractCandidates(
        o,
        labels: labels,
        numAnchors: 1,
      );
      expect(r.candidates.single.classIndex, 0);
      expect(r.candidates.single.rawScore, closeTo(0.45, 1e-9));
    });

    test('Guarded Transparency Assist: kelas transparan dominan (0.05..0.20, dom>=2.5, share>=0.45, area 0.04..0.65) diangkat 0.24..0.58', () {
      const labels = ['plastic', 'paper', 'cardboard'];
      final o = blank(1, 3);
      // area = (200/640)*(384/640) = 0.3125 * 0.6 = 0.1875 (dalam 0.04..0.65)
      set(o, 0, 320, 320, 200, 384, {0: 0.08, 1: 0.015, 2: 0.01});
      final r = YoloWasteClassifier.extractCandidates(
        o,
        labels: labels,
        numAnchors: 1,
      );
      final d = r.candidates.single;
      expect(d.classIndex, 0);
      expect(d.rawScore, closeTo(0.08, 1e-9));
      expect(d.effectiveScore, inInclusiveRange(0.24, 0.58));
    });

    test('Guarded Transparency Assist menolak skor < 0.05, distribusi datar, kelas padat, dan kotak terlalu kecil/besar', () {
      const labels = ['plastic', 'paper', 'cardboard'];
      final o = blank(4, 3);
      // 0: skor < 0.05 (meja kosong)
      set(o, 0, 150, 320, 200, 200, {0: 0.03, 1: 0.005});
      // 1: distribusi datar (dominance < 2.5)
      set(o, 1, 300, 320, 200, 200, {0: 0.08, 1: 0.05, 2: 0.04});
      // 2: kelas padat (paper) bukan transparan
      set(o, 2, 450, 320, 200, 200, {1: 0.09, 0: 0.01});
      // 3: plastik terlalu kecil (area = 0.1*0.1 = 0.01 < 0.04)
      set(o, 3, 550, 320, 64, 64, {0: 0.10, 1: 0.01});
      final r = YoloWasteClassifier.extractCandidates(
        o,
        labels: labels,
        numAnchors: 4,
      );
      expect(r.candidates, isEmpty);
      expect(r.best, isNotNull);
      expect(r.best!.score, lessThan(0.20));
    });

    test('kotak raksasa (> 0.80 luas) dipenalti 0.55', () {
      const labels = ['paper'];
      final o = blank(1, 1);
      // area = (600/640)^2 = 0.8789 > 0.80
      set(o, 0, 320, 320, 600, 600, {0: 0.60});
      final r = YoloWasteClassifier.extractCandidates(
        o,
        labels: labels,
        numAnchors: 1,
      );
      expect(r.candidates.single.score, closeTo(0.33, 1e-9));
    });

    test('kotak terlalu kecil (< 0.04) diabaikan', () {
      const labels = ['paper'];
      final o = blank(1, 1);
      set(o, 0, 320, 320, 10, 10, {0: 0.9});
      final r = YoloWasteClassifier.extractCandidates(
        o,
        labels: labels,
        numAnchors: 1,
      );
      expect(r.candidates, isEmpty);
    });
  });

  group('mergeSameClass & agnostic nms (V4)', () {
    YoloDetection det(Rect box, double s, int c) =>
        YoloDetection(box, s, c, rawScore: s, effectiveScore: s);

    test('dua kotak kelas sama bersentuhan vertikal digabung jadi satu', () {
      final r = YoloWasteClassifier.mergeSameClass([
        det(const Rect.fromLTRB(0.4, 0.1, 0.6, 0.45), 0.5, 0),
        det(const Rect.fromLTRB(0.4, 0.46, 0.6, 0.8), 0.4, 0),
      ]);
      expect(r.length, 1);
      expect(r.single.box.top, closeTo(0.1, 1e-9));
      expect(r.single.box.bottom, closeTo(0.8, 1e-9));
      expect(r.single.score, closeTo(0.5, 1e-9));
    });

    test('merge ditolak bila luas gabungan > 0.65', () {
      final r = YoloWasteClassifier.mergeSameClass([
        det(const Rect.fromLTRB(0.0, 0.0, 0.7, 0.7), 0.5, 0),
        det(const Rect.fromLTRB(0.3, 0.3, 1.0, 1.0), 0.4, 0),
      ]);
      expect(r.length, 2);
    });

    test('Kardus di dalam kotak Kertas disuppress (agnostic NMS)', () {
      final r = YoloWasteClassifier.nms([
        det(const Rect.fromLTRB(0.1, 0.3, 0.45, 0.7), 0.9, 1),
        det(const Rect.fromLTRB(0.15, 0.35, 0.40, 0.65), 0.7, 0),
      ]);
      expect(r.length, 1);
      expect(r.single.classIndex, 1);
    });

    test('Kertas kiri dan Plastik kanan dua-duanya dipertahankan', () {
      final r = YoloWasteClassifier.nms([
        det(const Rect.fromLTRB(0.05, 0.3, 0.35, 0.7), 0.9, 1),
        det(const Rect.fromLTRB(0.60, 0.2, 0.90, 0.8), 0.5, 0),
      ]);
      expect(r.length, 2);
    });
  });

  group('postprocess end-to-end (V4)', () {
    test('dua objek berdampingan menghasilkan dua objek yakin', () {
      const labels = ['plastic', 'paper'];
      final o = blank(2, 2);
      set(o, 0, 130, 320, 190, 280, {1: 0.85});
      set(o, 1, 480, 320, 180, 360, {0: 0.40});
      final r = YoloWasteClassifier.postprocess(
        o,
        labels: labels,
        numAnchors: 2,
      );
      expect(r.length, 2);
      expect(r[0].classIndex, 1);
      expect(r[1].classIndex, 0);
      expect(r[1].score, greaterThanOrEqualTo(0.62));
    });

    test('tanpa kandidat (meja kosong): fallback tetap rendah < 0.20 apa adanya', () {
      const labels = ['a', 'b'];
      final o = blank(1, 2);
      set(o, 0, 320, 320, 100, 100, {1: 0.049});
      final r = YoloWasteClassifier.postprocess(
        o,
        labels: labels,
        numAnchors: 1,
      );
      expect(r.single.classIndex, 1);
      expect(r.single.score, closeTo(0.049, 1e-9));
      expect(r.single.score, lessThan(0.20));
    });
  });

  group('unoccupiedZone (V4 >= 45%)', () {
    test('objek di kiri menyisakan ruang kanan >= 45% -> zona kanan di luar primaryBox', () {
      // primary.right = 0.40 -> rightStart = 0.44 -> span = 0.56 >= 0.45
      final z = YoloWasteClassifier.unoccupiedZone(
        const Rect.fromLTRB(0.05, 0.3, 0.40, 0.8),
      );
      expect(z, isNotNull);
      expect(z!.left, closeTo(0.44, 1e-9));
      expect(z.right, 1.0);
    });

    test('objek di kanan menyisakan ruang kiri >= 45% -> zona kiri', () {
      // primary.left = 0.60 -> leftEnd = 0.56 >= 0.45
      final z = YoloWasteClassifier.unoccupiedZone(
        const Rect.fromLTRB(0.60, 0.1, 0.95, 0.9),
      );
      expect(z, isNotNull);
      expect(z!.right, closeTo(0.56, 1e-9));
      expect(z.left, 0.0);
    });

    test('objek di tengah yang tidak menyisakan ruang >= 45% -> null (tidak membelah objek)', () {
      final z = YoloWasteClassifier.unoccupiedZone(
        const Rect.fromLTRB(0.25, 0.20, 0.75, 0.80),
      );
      expect(z, isNull);
    });
  });
}
