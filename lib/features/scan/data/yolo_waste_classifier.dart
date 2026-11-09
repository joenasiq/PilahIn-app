import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import '../../../core/constants/ml_config.dart';
import '../../../core/waste/waste_types.dart';
import '../domain/classification_result.dart';
import '../domain/waste_classifier.dart';

/// Klasifikasi sampah multi-objek memakai YOLOv8n TFLite.
///
/// Input  : [1, 3, 640, 640] atau [1, 640, 640, 3] Float32 (0..1)
/// Output : [1, 16, 8400] atau [1, 8400, 16] -> 4 bbox (xc, yc, w, h) + 12 skor kelas.
///
/// [classify] mengembalikan objek ber-confidence tertinggi, dengan seluruh
/// objek tersedia lewat [ClassificationResult.detections].
class YoloWasteClassifier implements WasteClassifier {
  static const String modelAsset = 'assets/models/pilahin_yolov8n.tflite';
  static const String labelsAsset = 'assets/models/labels.txt';
  static const int inputSize = 640;

  /// Ambang kandidat awal (skor setelah koreksi kelas & ukuran kotak).
  static const double detectionThreshold = 0.15;

  /// NMS Strictly Class-Specific (hanya untuk kotak dengan kelas yang sama).
  static const double iouThreshold = 0.40;

  /// Dua kotak berbeda kelas hanya dihapus salah satunya jika titik pusat &
  /// ukurannya hampir 100% identik di objek yang sama persis.
  static const double crossClassIdenticalIou = 0.82;
  static const double crossClassIdenticalCenterDist = 0.08;

  static const int maxDetections = 5;
  static const double minBoxSide = 0.03;

  /// Penalti kotak raksasa yang menelan 2 objek / meja sekaligus.
  static const double giantBoxWidth = 0.75;
  static const double giantBoxArea = 0.52;
  static const double giantBoxPenalty = 0.50;

  /// Koreksi kelas pemicu bias pada meja/latar gelap.
  static const Map<String, double> classFactors = {
    'clothes': 0.35,
    'shoes': 0.55,
  };

  /// Kelas sampah yang boleh mengalahkan `clothes` bila skornya >= 45%
  /// dari skor `clothes` pada anchor yang sama.
  static const Set<String> clothesRivals = {
    'paper',
    'plastic',
    'cardboard',
    'trash',
    'biological',
    'metal',
  };
  static const double clothesRivalRatio = 0.45;

  /// Merge kotak kelas sama yang terbelah.
  static const double mergeIou = 0.08;
  static const double mergeCenterDx = 0.25;

  /// Objek tambahan hanya ditampilkan bila skornya >= nilai ini saat objek
  /// utama sudah yakin.
  static const double secondaryMinScore = 0.16;

  Interpreter? _interpreter;
  List<String>? _labels;
  Future<void>? _loading;

  /// Model hasil export ini menerima input channel-first [1, 3, 640, 640]
  /// (transpose ke NHWC dilakukan di dalam model). Dideteksi dari shape tensor.
  bool _channelsFirst = true;

  Future<void> _ensureLoaded() {
    return _loading ??= _load().catchError((Object e) {
      _loading = null; // izinkan percobaan ulang
      throw e;
    });
  }

  Future<void> _load() async {
    final labelsRaw = await rootBundle.loadString(labelsAsset);
    _labels = labelsRaw
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final options = InterpreterOptions()..threads = 4;
    _interpreter = await Interpreter.fromAsset(
      modelAsset,
      options: options,
    );
    final inShape = _interpreter!.getInputTensor(0).shape;
    _channelsFirst = inShape.length == 4 && inShape[1] == 3 && inShape[3] != 3;
    _interpreter!.allocateTensors();
  }

  /// Menjalankan inferensi TFLite secara cepat menggunakan buffer byte langsung
  /// (`Uint8List`) tanpa alokasi nested List 4D di Dart yang memicu GC berat.
  List<List<double>> _runFastInference(
    Interpreter interpreter,
    Float32List inputFloats, {
    required int numAttrs,
    required int numAnchors,
    required bool isChannelsFirstOutput,
  }) {
    final inputBytes = inputFloats.buffer.asUint8List(
      inputFloats.offsetInBytes,
      inputFloats.lengthInBytes,
    );
    interpreter.getInputTensor(0).setTo(inputBytes);
    interpreter.invoke();

    final outputBytes = interpreter.getOutputTensor(0).data;
    final outFloats = outputBytes.buffer.asFloat32List(
      outputBytes.offsetInBytes,
      numAttrs * numAnchors,
    );

    if (isChannelsFirstOutput) {
      // Shape [1, 16, 8400]: blok memori per atribut sudah kontigu.
      return List<List<double>>.generate(
        numAttrs,
        (attr) => outFloats.sublist(
          attr * numAnchors,
          (attr + 1) * numAnchors,
        ),
        growable: false,
      );
    } else {
      // Shape [1, 8400, 16] -> transposisi ke [16][8400].
      return List<List<double>>.generate(
        numAttrs,
        (attr) {
          final row = Float64List(numAnchors);
          for (var a = 0; a < numAnchors; a++) {
            row[a] = outFloats[a * numAttrs + attr];
          }
          return row;
        },
        growable: false,
      );
    }
  }

  @override
  Future<ClassificationResult> classify(String imagePath) async {
    await _ensureLoaded();
    final interpreter = _interpreter!;
    final labels = _labels!;

    final inShape = interpreter.getInputTensor(0).shape;
    final outShape = interpreter.getOutputTensor(0).shape;
    debugPrint('[YoloWasteClassifier] Input Tensor Shape : $inShape');
    debugPrint('[YoloWasteClassifier] Output Tensor Shape: $outShape');

    final numAttrs = 4 + labels.length;
    final bool isChannelsFirstOutput =
        outShape.length >= 3 && outShape[1] == numAttrs;
    final int numAnchors = outShape.length >= 3
        ? (isChannelsFirstOutput ? outShape[2] : outShape[1])
        : 8400;

    final channelsFirst = _channelsFirst;
    final totalWatch = Stopwatch()..start();

    // PASS 1: Smart Aspect-Ratio Center Window + Letterbox 640x640 di isolate.
    final pass1 = await Isolate.run(
      () => _preprocessMainAndSubRegions(imagePath, channelsFirst),
    );

    final inferWatch = Stopwatch()..start();
    final mainOutput = _runFastInference(
      interpreter,
      pass1.mainTile.input,
      numAttrs: numAttrs,
      numAnchors: numAnchors,
      isChannelsFirstOutput: isChannelsFirstOutput,
    );
    inferWatch.stop();
    debugPrint(
      '[YoloWasteClassifier] Pass-1 inference: ${inferWatch.elapsedMilliseconds} ms',
    );
    _debugPrintTopClassScores(mainOutput, labels, numAnchors);

    // Kumpulkan kandidat dari Pass 1 (sudah dipetakan ke koordinat gambar utuh).
    final mainCandidates = extractCandidates(
      mainOutput,
      labels: labels,
      numAnchors: numAnchors,
      padX: pass1.mainTile.padX,
      padY: pass1.mainTile.padY,
      newWidth: pass1.mainTile.newWidth,
      newHeight: pass1.mainTile.newHeight,
      roi: pass1.mainTile.roi,
    );

    var detections = finalizeDetections(
      mainCandidates.candidates,
      fallbackBest: mainCandidates.best,
    );

    // Cek apakah perlu Pass Kedua (Multi-Scale Tile / Quadrant Assist):
    // (a) <= 1 objek yakin (< 0.60), ATAU
    // (b) ada objek dengan kotak terlalu lebar/tinggi (> 0.65), ATAU
    // (c) skor tertinggi masih < 0.50.
    final confidentCount = detections
        .where((d) => d.score >= MlConfig.lowConfidenceThreshold)
        .length;
    final hasOversizedBox = detections.any(
      (d) => d.box.width > 0.65 || d.box.height > 0.65,
    );
    final topRawScore = detections.isEmpty ? 0.0 : detections.first.rawScore;
    final needSubRegionPass =
        confidentCount <= 1 || hasOversizedBox || topRawScore < 0.50;

    if (needSubRegionPass && pass1.subTiles.isNotEmpty) {
      final allCandidates = <YoloDetection>[...mainCandidates.candidates];
      YoloDetection? bestFallback = mainCandidates.best;

      final subWatch = Stopwatch()..start();
      for (final tile in pass1.subTiles) {
        final subOut = _runFastInference(
          interpreter,
          tile.input,
          numAttrs: numAttrs,
          numAnchors: numAnchors,
          isChannelsFirstOutput: isChannelsFirstOutput,
        );
        final subExtracted = extractCandidates(
          subOut,
          labels: labels,
          numAnchors: numAnchors,
          padX: tile.padX,
          padY: tile.padY,
          newWidth: tile.newWidth,
          newHeight: tile.newHeight,
          roi: tile.roi,
        );
        allCandidates.addAll(subExtracted.candidates);
        if (subExtracted.best != null &&
            (bestFallback == null ||
                subExtracted.best!.score > bestFallback.score)) {
          bestFallback = subExtracted.best;
        }
      }
      subWatch.stop();
      debugPrint(
        '[YoloWasteClassifier] Pass-2 (${pass1.subTiles.length} sub-regions) '
        'inference: ${subWatch.elapsedMilliseconds} ms',
      );

      detections = finalizeDetections(
        allCandidates,
        fallbackBest: bestFallback,
      );
    }

    totalWatch.stop();
    debugPrint(
      '[YoloWasteClassifier] Total pipeline: ${totalWatch.elapsedMilliseconds} ms | '
      'mainPad=(${pass1.mainTile.padX},${pass1.mainTile.padY}) '
      'mainScaled=${pass1.mainTile.newWidth}x${pass1.mainTile.newHeight} '
      'detections=${detections.length}',
    );
    for (final d in detections) {
      debugPrint(
        '[YoloWasteClassifier]  - ${labels[d.classIndex]} '
        'conf=${(d.score * 100).toStringAsFixed(1)}% '
        'raw=${(d.rawScore * 100).toStringAsFixed(1)}% box=${d.box}',
      );
    }

    final timestamp = DateTime.now();
    final results = <ClassificationResult>[];
    final tmpDir = (await getTemporaryDirectory()).path;
    for (var i = 0; i < detections.length; i++) {
      final d = detections[i];
      final wasteType = WasteType.fromLabelKey(labels[d.classIndex]);
      if (wasteType == null) continue;
      String? cropPath;
      try {
        final outPath =
            '$tmpDir${Platform.pathSeparator}'
            'crop_${timestamp.millisecondsSinceEpoch}_$i.jpg';
        cropPath = await Isolate.run(
          () => _cropAndSave(imagePath, d.box, outPath),
        );
      } catch (_) {
        cropPath = null; // crop gagal tidak boleh menggagalkan klasifikasi
      }
      results.add(
        ClassificationResult(
          wasteType: wasteType,
          confidence: d.score,
          imagePath: imagePath,
          isUncertain: d.score < MlConfig.lowConfidenceThreshold,
          timestamp: timestamp,
          boundingBox: d.box,
          croppedImagePath: cropPath,
        ),
      );
    }

    if (results.isEmpty) {
      throw StateError('Model tidak menghasilkan prediksi');
    }
    return results.first.withDetections(results);
  }

  void _debugPrintTopClassScores(
    List<List<double>> output,
    List<String> labels,
    int numAnchors,
  ) {
    final maxPerClass = List<double>.filled(labels.length, 0.0);
    for (var c = 0; c < labels.length; c++) {
      final row = output[4 + c];
      var m = 0.0;
      for (var a = 0; a < numAnchors; a++) {
        if (row[a] > m) m = row[a];
      }
      maxPerClass[c] = m;
    }
    final indices = List<int>.generate(labels.length, (i) => i)
      ..sort((a, b) => maxPerClass[b].compareTo(maxPerClass[a]));
    final top3 = indices
        .take(3)
        .map(
          (i) =>
              '${labels[i]} (${(maxPerClass[i] * 100).toStringAsFixed(1)}%)',
        )
        .join(', ');
    debugPrint('[YoloWasteClassifier] Top 3 Raw Class Scores: $top3');
  }

  /// Kalibrasi lembut skor menjadi confidence akhir.
  /// - s < 0.15        : tetap (non-sampah seperti laptop tetap rendah)
  /// - 0.15 <= s < 0.26: linear ke 0.30..0.58 (tetap tidak yakin)
  /// - s >= 0.26       : kurva halus ke 0.62..0.96
  static double calibrate(double s) {
    if (s < 0.15) return s;
    if (s < 0.26) return 0.30 + ((s - 0.15) / (0.26 - 0.15)) * 0.28;
    return (0.62 + ((s - 0.26) / (0.85 - 0.26)) * 0.34).clamp(0.62, 0.96);
  }

  /// Post-processing murni (bisa diuji tanpa model).
  /// [output] berbentuk [4 + numClasses][numAnchors].
  static List<YoloDetection> postprocess(
    List<List<double>> output, {
    required List<String> labels,
    required int numAnchors,
    int padX = 0,
    int padY = 0,
    int newWidth = inputSize,
    int newHeight = inputSize,
    Rect roi = const Rect.fromLTWH(0.0, 0.0, 1.0, 1.0),
  }) {
    final extracted = extractCandidates(
      output,
      labels: labels,
      numAnchors: numAnchors,
      padX: padX,
      padY: padY,
      newWidth: newWidth,
      newHeight: newHeight,
      roi: roi,
    );
    return finalizeDetections(
      extracted.candidates,
      fallbackBest: extracted.best,
    );
  }

  /// Mengekstrak kandidat anchor dari satu tile/pass dan memetakannya ke
  /// koordinat ternormalisasi gambar asli (0.0 .. 1.0) sesuai [roi].
  static ({List<YoloDetection> candidates, YoloDetection? best})
  extractCandidates(
    List<List<double>> output, {
    required List<String> labels,
    required int numAnchors,
    int padX = 0,
    int padY = 0,
    int newWidth = inputSize,
    int newHeight = inputSize,
    Rect roi = const Rect.fromLTWH(0.0, 0.0, 1.0, 1.0),
  }) {
    final numClasses = labels.length;
    final lower = [for (final l in labels) l.toLowerCase()];
    final factors = [for (final l in lower) classFactors[l] ?? 1.0];
    final rivalIdx = [
      for (var c = 0; c < numClasses; c++)
        if (clothesRivals.contains(lower[c])) c,
    ];

    var maxCoord = 0.0;
    for (var a = 0; a < numAnchors; a++) {
      maxCoord = math.max(maxCoord, math.max(output[2][a], output[3][a]));
    }
    final toCanvas = maxCoord <= 1.5 ? inputSize.toDouble() : 1.0;
    final effW = newWidth > 0 ? newWidth.toDouble() : inputSize.toDouble();
    final effH = newHeight > 0 ? newHeight.toDouble() : inputSize.toDouble();

    final candidates = <YoloDetection>[];
    YoloDetection? best;

    for (var a = 0; a < numAnchors; a++) {
      var score = -1.0;
      var cls = 0;
      for (var c = 0; c < numClasses; c++) {
        final s = output[4 + c][a] * factors[c];
        if (s > score) {
          score = s;
          cls = c;
        }
      }

      // Anti-bias clothes: kelas sampah dengan skor >= 45% skor clothes
      // pada anchor yang sama memenangkan anchor tersebut.
      if (lower[cls] == 'clothes') {
        var rivalScore = 0.0;
        var rival = -1;
        for (final c in rivalIdx) {
          final s = output[4 + c][a] * factors[c];
          if (s >= score * clothesRivalRatio && s > rivalScore) {
            rivalScore = s;
            rival = c;
          }
        }
        if (rival >= 0) {
          cls = rival;
          score = rivalScore;
        }
      }

      final xc = output[0][a] * toCanvas;
      final yc = output[1][a] * toCanvas;
      final bw = output[2][a] * toCanvas;
      final bh = output[3][a] * toCanvas;

      // Koordinat lokal di dalam tile/crop (0.0 .. 1.0)
      final tileLeft = (((xc - bw / 2.0) - padX) / effW).clamp(0.0, 1.0);
      final tileTop = (((yc - bh / 2.0) - padY) / effH).clamp(0.0, 1.0);
      final tileRight = (((xc + bw / 2.0) - padX) / effW).clamp(0.0, 1.0);
      final tileBottom = (((yc + bh / 2.0) - padY) / effH).clamp(0.0, 1.0);
      final tileW = tileRight - tileLeft;
      final tileH = tileBottom - tileTop;
      if (tileW < minBoxSide || tileH < minBoxSide) continue;

      // Petakan kembali dari koordinat tile ke koordinat gambar utuh (0.0 .. 1.0)
      final left = (roi.left + tileLeft * roi.width).clamp(0.0, 1.0);
      final top = (roi.top + tileTop * roi.height).clamp(0.0, 1.0);
      final right = (roi.left + tileRight * roi.width).clamp(0.0, 1.0);
      final bottom = (roi.top + tileBottom * roi.height).clamp(0.0, 1.0);
      final width = right - left;
      final height = bottom - top;
      if (width < minBoxSide || height < minBoxSide) continue;

      // Penalti kotak raksasa yang menelan 2 objek sekaligus / meja:
      // periksa baik ukuran di dalam tile maupun ukuran di gambar utuh.
      if (width > giantBoxWidth ||
          width * height > giantBoxArea ||
          tileW > giantBoxWidth ||
          tileW * tileH > giantBoxArea) {
        score *= giantBoxPenalty;
      }

      final clamped = score.clamp(0.0, 1.0);
      final det = YoloDetection(
        Rect.fromLTRB(left, top, right, bottom),
        clamped,
        cls,
        rawScore: clamped,
      );
      if (best == null || det.score > best.score) best = det;
      if (score >= detectionThreshold) candidates.add(det);
    }

    return (candidates: candidates, best: best);
  }

  /// Menjalankan Class-Specific NMS, Same-Class Box Merging, dan Soft
  /// Confidence Calibration pada kumpulan kandidat.
  static List<YoloDetection> finalizeDetections(
    List<YoloDetection> candidates, {
    YoloDetection? fallbackBest,
  }) {
    if (candidates.isEmpty) {
      if (fallbackBest == null) return const [];
      return [
        YoloDetection(
          fallbackBest.box,
          calibrate(fallbackBest.score),
          fallbackBest.classIndex,
          rawScore: fallbackBest.rawScore,
        ),
      ];
    }

    final merged = mergeSameClass(nms(candidates));
    final result = <YoloDetection>[];
    for (final d in merged) {
      result.add(
        YoloDetection(
          d.box,
          calibrate(d.score),
          d.classIndex,
          rawScore: d.rawScore,
        ),
      );
    }
    // Jika objek utama sudah yakin, objek tambahan harus punya skor >= 0.16.
    if (result.isNotEmpty && result.first.score >= 0.62) {
      result.removeWhere(
        (d) => !identical(d, result.first) && d.rawScore < secondaryMinScore,
      );
    }
    return result.length > maxDetections
        ? result.sublist(0, maxDetections)
        : result;
  }

  /// Strictly Class-Specific NMS:
  /// - Jika kelas SAMA (`k.classIndex == d.classIndex`), hapus bila `IoU > 0.40`
  ///   (kecuali berada di zona spasial berbeda dengan `IoU < 0.30`).
  /// - Jika kelas BERBEDA (`k.classIndex != d.classIndex`), JANGAN saling
  ///   menghapus kecuali kedua kotak memiliki titik pusat & ukuran yang hampir
  ///   100% identik di objek yang sama persis (`IoU > 0.82` DAN jarak pusat `< 0.08`).
  static List<YoloDetection> nms(
    List<YoloDetection> input, {
    double iou = iouThreshold,
  }) {
    final sorted = [...input]..sort((a, b) => b.score.compareTo(a.score));
    final kept = <YoloDetection>[];
    for (final d in sorted) {
      var suppressed = false;
      for (final k in kept) {
        final overlap = _iou(k.box, d.box);
        if (k.classIndex == d.classIndex) {
          if (_inDifferentSpatialZones(k.box, d.box) && overlap < 0.30) {
            continue;
          }
          if (overlap > iou) {
            suppressed = true;
            break;
          }
        } else {
          // Berbeda kelas: hanya hapus jika benar-benar di titik & ukuran yang identik
          final centerDist = _centerDistance(k.box, d.box);
          if (overlap > crossClassIdenticalIou &&
              centerDist < crossClassIdenticalCenterDist) {
            suppressed = true;
            break;
          }
        }
      }
      if (!suppressed) kept.add(d);
      if (kept.length >= maxDetections * 4) break;
    }
    return kept;
  }

  static double _centerDistance(Rect a, Rect b) {
    final dx = (a.left + a.right) / 2.0 - (b.left + b.right) / 2.0;
    final dy = (a.top + a.bottom) / 2.0 - (b.top + b.bottom) / 2.0;
    return math.sqrt(dx * dx + dy * dy);
  }

  static bool _inDifferentSpatialZones(Rect a, Rect b) {
    final cyA = (a.top + a.bottom) / 2.0;
    final cyB = (b.top + b.bottom) / 2.0;
    final topBottomSplit = (cyA < 0.52) != (cyB < 0.52);
    final cxA = (a.left + a.right) / 2.0;
    final cxB = (b.left + b.right) / 2.0;
    final leftRightSplit = (cxA < 0.50) != (cxB < 0.50);
    return topBottomSplit || leftRightSplit;
  }

  /// Menggabungkan kotak berkelas sama yang beririsan (IoU > 0.08) atau yang
  /// berdekatan secara horizontal dan bersentuhan vertikal (satu objek
  /// panjang yang terbelah). Skor digabung: 1 - (1 - s1)(1 - s2).
  static List<YoloDetection> mergeSameClass(List<YoloDetection> input) {
    final list = [...input];
    var changed = true;
    while (changed) {
      changed = false;
      outer:
      for (var i = 0; i < list.length; i++) {
        for (var j = i + 1; j < list.length; j++) {
          final a = list[i];
          final b = list[j];
          if (a.classIndex != b.classIndex) continue;
          if (!_shouldMerge(a.box, b.box)) continue;
          final box = Rect.fromLTRB(
            math.min(a.box.left, b.box.left),
            math.min(a.box.top, b.box.top),
            math.max(a.box.right, b.box.right),
            math.max(a.box.bottom, b.box.bottom),
          );
          final score = 1.0 - ((1.0 - a.score) * (1.0 - b.score));
          list[i] = YoloDetection(
            box,
            score,
            a.classIndex,
            rawScore: score,
          );
          list.removeAt(j);
          changed = true;
          break outer;
        }
      }
    }
    list.sort((a, b) => b.score.compareTo(a.score));
    return list;
  }

  static bool _shouldMerge(Rect a, Rect b) {
    if (_iou(a, b) > mergeIou) return true;
    final dx = ((a.left + a.right) / 2 - (b.left + b.right) / 2).abs();
    final touchVertically =
        b.top <= a.bottom + 0.02 && a.top <= b.bottom + 0.02;
    return dx < mergeCenterDx && touchVertically;
  }

  static double _iou(Rect a, Rect b) {
    final inter = a.intersect(b);
    if (inter.width <= 0 || inter.height <= 0) return 0.0;
    final interArea = inter.width * inter.height;
    final union = a.width * a.height + b.width * b.height - interArea;
    return union <= 0 ? 0.0 : interArea / union;
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _loading = null;
  }
}

/// Satu kandidat deteksi mentah.
class YoloDetection {
  final Rect box; // ternormalisasi 0..1 terhadap gambar asli
  /// Confidence akhir (terkalibrasi) yang ditampilkan ke pengguna.
  final double score;
  final int classIndex;

  /// Skor sebelum kalibrasi (setelah koreksi kelas/ukuran/merge).
  final double rawScore;

  const YoloDetection(
    this.box,
    this.score,
    this.classIndex, {
    this.rawScore = 0,
  });
}

class _TileInput {
  final Float32List input;
  final int padX;
  final int padY;
  final int newWidth;
  final int newHeight;
  final Rect roi; // proporsi di dalam gambar utuh (0..1)

  const _TileInput({
    required this.input,
    required this.padX,
    required this.padY,
    required this.newWidth,
    required this.newHeight,
    required this.roi,
  });
}

class _MultiPassPreprocessed {
  final _TileInput mainTile;
  final List<_TileInput> subTiles;

  const _MultiPassPreprocessed({
    required this.mainTile,
    required this.subTiles,
  });
}

/// Membaca gambar sekali di Isolate, menerapkan Center-Crop / Aspect-Ratio
/// Smart Padding untuk pass utama (jika `origH / origW > 1.35`, fokus ke 80%
/// tinggi tengah gambar), serta menyiapkan sub-region fokus (Center Zoom 60%
/// + 2 zona belahan) untuk Pass Kedua bila diperlukan.
_MultiPassPreprocessed _preprocessMainAndSubRegions(
  String path,
  bool channelsFirst,
) {
  final bytes = File(path).readAsBytesSync();
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw StateError('Gambar tidak dapat dibaca: $path');
  }
  final oriented = img.bakeOrientation(decoded);
  final origW = oriented.width;
  final origH = oriented.height;

  // LANGKAH 2: Jika rasio potret terlalu memanjang (origH / origW > 1.35),
  // ambil window vertikal tengah 80% tinggi gambar agar lebar efektif objek
  // di kanvas 640x640 meningkat drastis.
  Rect mainRoi = const Rect.fromLTWH(0.0, 0.0, 1.0, 1.0);
  if (origH / origW > 1.35) {
    mainRoi = const Rect.fromLTWH(0.0, 0.10, 1.0, 0.80);
  } else if (origW / origH > 1.35) {
    mainRoi = const Rect.fromLTWH(0.10, 0.0, 0.80, 1.0);
  }
  final mainTile = _buildTile(oriented, mainRoi, channelsFirst);

  // LANGKAH 4: Sub-regions untuk objek kecil / 2 objek berdampingan:
  // 1) Center Zoom 60% tengah gambar (memperbesar objek ~1.7x)
  // 2) Dua zona fokus sesuai orientasi gambar (Atas-Bawah atau Kiri-Kanan)
  final subTiles = <_TileInput>[
    _buildTile(
      oriented,
      const Rect.fromLTWH(0.15, 0.15, 0.70, 0.70),
      channelsFirst,
    ),
    if (origH >= origW) ...[
      _buildTile(
        oriented,
        const Rect.fromLTWH(0.0, 0.05, 1.0, 0.55),
        channelsFirst,
      ),
      _buildTile(
        oriented,
        const Rect.fromLTWH(0.0, 0.40, 1.0, 0.55),
        channelsFirst,
      ),
    ] else ...[
      _buildTile(
        oriented,
        const Rect.fromLTWH(0.0, 0.0, 0.58, 1.0),
        channelsFirst,
      ),
      _buildTile(
        oriented,
        const Rect.fromLTWH(0.42, 0.0, 0.58, 1.0),
        channelsFirst,
      ),
    ],
  ];

  return _MultiPassPreprocessed(mainTile: mainTile, subTiles: subTiles);
}

_TileInput _buildTile(img.Image fullImage, Rect roi, bool channelsFirst) {
  final origW = fullImage.width;
  final origH = fullImage.height;

  final cropX = (roi.left * origW).round().clamp(0, origW - 1);
  final cropY = (roi.top * origH).round().clamp(0, origH - 1);
  final cropW = (roi.width * origW).round().clamp(1, origW - cropX);
  final cropH = (roi.height * origH).round().clamp(1, origH - cropY);

  final region = (cropX == 0 && cropY == 0 && cropW == origW && cropH == origH)
      ? fullImage
      : img.copyCrop(fullImage, x: cropX, y: cropY, width: cropW, height: cropH);

  const size = YoloWasteClassifier.inputSize;
  final scale = math.min(size / region.width, size / region.height);
  final newWidth = (region.width * scale).round().clamp(1, size);
  final newHeight = (region.height * scale).round().clamp(1, size);
  final padX = (size - newWidth) ~/ 2;
  final padY = (size - newHeight) ~/ 2;

  final resized = img.copyResize(
    region,
    width: newWidth,
    height: newHeight,
    interpolation: img.Interpolation.linear,
  );

  // Kanvas letterbox 640x640 dengan warna abu-abu standar YOLO RGB(114, 114, 114).
  const padVal = 114.0 / 255.0;
  final data = Float32List(size * size * 3);
  data.fillRange(0, data.length, padVal);

  const plane = size * size;
  const inv255 = 1.0 / 255.0;
  for (var y = 0; y < newHeight; y++) {
    final rowOffset = (y + padY) * size + padX;
    for (var x = 0; x < newWidth; x++) {
      final p = resized.getPixel(x, y);
      final r = p.r * inv255;
      final g = p.g * inv255;
      final b = p.b * inv255;
      final idx = rowOffset + x;
      if (channelsFirst) {
        data[idx] = r;
        data[plane + idx] = g;
        data[2 * plane + idx] = b;
      } else {
        final base = idx * 3;
        data[base] = r;
        data[base + 1] = g;
        data[base + 2] = b;
      }
    }
  }

  final actualRoi = Rect.fromLTWH(
    cropX / origW,
    cropY / origH,
    cropW / origW,
    cropH / origH,
  );

  return _TileInput(
    input: data,
    padX: padX,
    padY: padY,
    newWidth: newWidth,
    newHeight: newHeight,
    roi: actualRoi,
  );
}

/// Potong gambar asli (sudah dikoreksi rotasi) sesuai [box] ternormalisasi.
String? _cropAndSave(String path, Rect box, String outPath) {
  final decoded = img.decodeImage(File(path).readAsBytesSync());
  if (decoded == null) return null;
  final oriented = img.bakeOrientation(decoded);
  final x = (box.left * oriented.width).floor().clamp(0, oriented.width - 1);
  final y = (box.top * oriented.height).floor().clamp(0, oriented.height - 1);
  final w = ((box.right * oriented.width).ceil() - x).clamp(
    1,
    oriented.width - x,
  );
  final h = ((box.bottom * oriented.height).ceil() - y).clamp(
    1,
    oriented.height - y,
  );
  final cropped = img.copyCrop(oriented, x: x, y: y, width: w, height: h);
  File(outPath).writeAsBytesSync(img.encodeJpg(cropped, quality: 85));
  return outPath;
}
