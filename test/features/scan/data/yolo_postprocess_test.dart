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

  group('calibrate', () {
    test('skor < 0.25 tetap apa adanya (tidak yakin)', () {
      expect(YoloWasteClassifier.calibrate(0.049), closeTo(0.049, 1e-9));
      expect(YoloWasteClassifier.calibrate(0.24), lessThan(0.60));
    });
    test('skor >= 0.25 dipetakan ke 0.62..0.96', () {
      expect(YoloWasteClassifier.calibrate(0.25), closeTo(0.62, 1e-9));
      expect(YoloWasteClassifier.calibrate(0.95), closeTo(0.96, 1e-9));
    });
  });

  group('extractCandidates', () {
    test('un-letterbox menghapus padding dan menskalakan ke gambar asli', () {
      const labels = ['paper', 'plastic'];
      final o = blank(1, 2);
      // Gambar 360x640 -> padX=140. Objek di tengah gambar.
      set(o, 0, 320, 320, 180, 320, {0: 0.8});
      final r = YoloWasteClassifier.extractCandidates(
        o,
        labels: labels,
        numAnchors: 1,
        padX: 140,
        newWidth: 360,
        newHeight: 640,
      );
      final b = r.candidates.single.box;
      expect(b.left, closeTo(0.25, 1e-9));
      expect(b.right, closeTo(0.75, 1e-9));
      expect(b.top, closeTo(0.25, 1e-9));
    });

    test('paper menang atas cardboard bila paper >= 0.40 * cardboard', () {
      const labels = ['cardboard', 'paper'];
      final o = blank(1, 2);
      set(o, 0, 320, 320, 200, 200, {0: 0.60, 1: 0.30});
      final r = YoloWasteClassifier.extractCandidates(
        o,
        labels: labels,
        numAnchors: 1,
      );
      expect(r.candidates.single.classIndex, 1);
    });

    test('clothes dikalikan 0.75 sehingga kalah dari plastic yang dekat', () {
      const labels = ['clothes', 'plastic'];
      final o = blank(1, 2);
      set(o, 0, 320, 320, 200, 200, {0: 0.30, 1: 0.27});
      final r = YoloWasteClassifier.extractCandidates(
        o,
        labels: labels,
        numAnchors: 1,
      );
      expect(r.candidates.single.classIndex, 1);
    });

    test('kelas transparan dominan dengan skor rendah diangkat 0.26..0.65', () {
      const labels = ['plastic', 'paper', 'cardboard'];
      final o = blank(1, 3);
      set(o, 0, 320, 320, 200, 400, {0: 0.05, 1: 0.005, 2: 0.004});
      final r = YoloWasteClassifier.extractCandidates(
        o,
        labels: labels,
        numAnchors: 1,
      );
      final d = r.candidates.single;
      expect(d.classIndex, 0);
      expect(d.score, inInclusiveRange(0.26, 0.65));
    });

    test('kelas padat dengan skor rendah (paper) tidak diangkat; distribusi datar ditolak', () {
      const labels = ['plastic', 'paper', 'cardboard'];
      final o = blank(2, 3);
      set(o, 0, 200, 320, 200, 200, {1: 0.05, 0: 0.004});
      set(o, 1, 450, 320, 200, 200, {0: 0.05, 1: 0.04, 2: 0.04});
      final r = YoloWasteClassifier.extractCandidates(
        o,
        labels: labels,
        numAnchors: 2,
      );
      expect(r.candidates, isEmpty);
      expect(r.best, isNotNull);
    });

    test('kotak raksasa (> 0.78 luas) dipenalti 0.50', () {
      const labels = ['paper'];
      final o = blank(1, 1);
      set(o, 0, 320, 320, 620, 620, {0: 0.60});
      final r = YoloWasteClassifier.extractCandidates(
        o,
        labels: labels,
        numAnchors: 1,
      );
      expect(r.candidates.single.score, closeTo(0.30, 1e-9));
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

  group('mergeSameClass & nms', () {
    YoloDetection det(Rect box, double s, int c) =>
        YoloDetection(box, s, c, rawScore: s);

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

    test('Kardus di dalam kotak Kertas disuppress (1 benda = 1 kotak)', () {
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

  group('postprocess end-to-end', () {
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

    test('tanpa kandidat: fallback tetap rendah apa adanya', () {
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
    });
  });

  group('unoccupiedZone', () {
    test('objek di kiri -> zona kanan di luar primaryBox dengan margin 0.04', () {
      final z = YoloWasteClassifier.unoccupiedZone(
        const Rect.fromLTRB(0.05, 0.3, 0.40, 0.8),
      );
      expect(z, isNotNull);
      expect(z!.left, closeTo(0.44, 1e-9));
      expect(z.right, 1.0);
    });
    test('objek di kanan -> zona kiri', () {
      final z = YoloWasteClassifier.unoccupiedZone(
        const Rect.fromLTRB(0.60, 0.1, 0.95, 0.9),
      );
      expect(z!.right, closeTo(0.56, 1e-9));
      expect(z.left, 0.0);
    });
    test('objek besar yang mengisi layar -> tidak ada zona', () {
      expect(
        YoloWasteClassifier.unoccupiedZone(
          const Rect.fromLTRB(0.1, 0.1, 0.9, 0.9),
        ),
        isNull,
      );
    });
  });
}
