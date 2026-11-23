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

/// Klasifikasi sampah multi-objek memakai YOLOv8n V4 TFLite
/// (Domain-Adapted 3:4 Portrait & Transparency Optimized).
///
/// Alur: decode + letterbox RGB(114,114,114) 640x640 (isolate) -> 1x inferensi ->
/// evaluasi 8400 anchor (raw V4 + Guarded Transparency Assist) ->
/// same-class merge -> class-agnostic spatial NMS ->
/// (opsional) 1x inferensi pada zona kosong >= 45% di luar objek utama -> kalibrasi.
///
/// Input  : [1, 3, 640, 640] (NCHW) atau [1, 640, 640, 3] (NHWC), Float32 0..1.
/// Output : [1, 16, 8400] atau [1, 8400, 16] -> 4 bbox (xc, yc, w, h) + 12 skor.
class YoloWasteClassifier implements WasteClassifier {
  static const String modelAsset = 'assets/models/pilahin_yolov8n.tflite';
  static const String labelsAsset = 'assets/models/labels.txt';
  static const int inputSize = 640;

  // --- Evaluasi anchor (selaras validasi V4: conf=0.20, iou=0.45, agnostic_nms=True) ---
  static const double minRawScore = 0.20;
  static const double clothesFactor = 0.90;
  static const double paperOverCardboardRatio = 0.45;
  static const double minBoxSide = 0.04;
  static const double giantBoxArea = 0.80;
  static const double giantBoxPenalty = 0.55;
  static const int maxCandidates = 120;

  // --- Guarded Transparency Assist (konservatif agar negative background bersih) ---
  static const double assistMinScore = 0.05;
  static const double assistMinDominance = 2.5;
  static const double assistMinShare = 0.45;
  static const double assistMinArea = 0.04;
  static const double assistMaxArea = 0.65;
  static const double assistEffMin = 0.24;
  static const double assistEffMax = 0.58;
  static const Set<String> transparentClasses = {
    'plastic',
    'white-glass',
    'green-glass',
    'brown-glass',
  };

  // --- Tahap A: Same-class merge ---
  static const double mergeIou = 0.12;
  static const double mergeContainment = 0.45;
  static const double mergeEdgeGap = 0.05;
  static const double mergeMaxArea = 0.65;

  // --- Tahap B: Class-agnostic spatial NMS ---
  static const double nmsIou = 0.42;
  static const double nmsContainment = 0.55;
  static const double nmsCenterDist = 0.16;
  static const int maxDetections = 5;

  // --- Kalibrasi jujur ---
  static const double confidentEffectiveScore = 0.22;

  // --- Tahap C: Targeted unoccupied-zone assist ---
  static const double zoneMinEffectiveScore = 0.22;
  static const double zoneMaxIou = 0.12;
  static const double zoneMargin = 0.04;
  static const double zoneMinSize = 0.45;

  Interpreter? _interpreter;
  List<String>? _labels;
  Future<void>? _loading;
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
    final interpreter = await Interpreter.fromAsset(
      modelAsset,
      options: options,
    );
    final inShape = interpreter.getInputTensor(0).shape;
    _channelsFirst = inShape.length == 4 && inShape[1] == 3 && inShape[3] != 3;
    interpreter.allocateTensors();
    _interpreter = interpreter;
  }

  /// Satu kali inferensi. Hasil disalin sekali ke Float32List milik Dart agar
  /// aman dari penimpaan oleh inferensi berikutnya, lalu dipecah per atribut
  /// tanpa alokasi tambahan (sublistView).
  List<List<double>> _infer(
    Float32List input, {
    required int numAttrs,
    required int numAnchors,
    required bool outputChannelsFirst,
  }) {
    final interpreter = _interpreter!;
    interpreter.getInputTensor(0).setTo(
      input.buffer.asUint8List(input.offsetInBytes, input.lengthInBytes),
    );
    interpreter.invoke();

    final bytes = interpreter.getOutputTensor(0).data;
    final raw = Float32List.fromList(
      bytes.buffer.asFloat32List(bytes.offsetInBytes, numAttrs * numAnchors),
    );

    if (outputChannelsFirst) {
      return List<List<double>>.generate(
        numAttrs,
        (attr) => Float32List.sublistView(
          raw,
          attr * numAnchors,
          (attr + 1) * numAnchors,
        ),
        growable: false,
      );
    }
    return List<List<double>>.generate(numAttrs, (attr) {
      final row = Float32List(numAnchors);
      for (var a = 0; a < numAnchors; a++) {
        row[a] = raw[a * numAttrs + attr];
      }
      return row;
    }, growable: false);
  }

  @override
  Future<ClassificationResult> classify(String imagePath) async {
    await _ensureLoaded();
    final interpreter = _interpreter!;
    final labels = _labels!;

    final inShape = interpreter.getInputTensor(0).shape;
    final outShape = interpreter.getOutputTensor(0).shape;
    final numAttrs = 4 + labels.length;
    final outputChannelsFirst = outShape.length >= 3 && outShape[1] == numAttrs;
    final numAnchors = outShape.length >= 3
        ? (outputChannelsFirst ? outShape[2] : outShape[1])
        : 8400;
    final channelsFirst = _channelsFirst;

    final total = Stopwatch()..start();

    // Langkah 1: decode + bakeOrientation + letterbox RGB(114,114,114) di isolate.
    final prepWatch = Stopwatch()..start();
    final tile = await Isolate.run(
      () => _preprocess(imagePath, channelsFirst, 0.0, 0.0, 1.0, 1.0),
    );
    prepWatch.stop();

    final inferWatch = Stopwatch()..start();
    final output = _infer(
      tile.input,
      numAttrs: numAttrs,
      numAnchors: numAnchors,
      outputChannelsFirst: outputChannelsFirst,
    );
    inferWatch.stop();
    debugPrint(
      '[YoloV4] Shapes: in=$inShape out=$outShape | '
      'Preprocess=${prepWatch.elapsedMilliseconds}ms Infer=${inferWatch.elapsedMilliseconds}ms | '
      'Letterbox=${tile.newWidth}x${tile.newHeight} pad=(${tile.padX},${tile.padY})',
    );
    debugPrint(
      '[YoloV4] Top 3 Raw Class Scores (Pass 1): ${_top3(output, labels, numAnchors)}',
    );

    // Langkah 2 & 3 (Tahap A & B): evaluasi anchor, same-class merge, agnostic NMS.
    final extracted = extractCandidates(
      output,
      labels: labels,
      numAnchors: numAnchors,
      padX: tile.padX,
      padY: tile.padY,
      newWidth: tile.newWidth,
      newHeight: tile.newHeight,
      roi: tile.roi,
    );
    var detections = finalizeDetections(
      extracted.candidates,
      fallbackBest: extracted.best,
    );

    // Langkah 3 (Tahap C): Targeted Unoccupied-Zone Assist (opsional & aman).
    var pass2Executed = false;
    if (detections.length == 1 &&
        detections.first.effectiveScore >= confidentEffectiveScore) {
      final primary = detections.first;
      final zone = unoccupiedZone(primary.box);
      if (zone != null) {
        pass2Executed = true;
        final zoneWatch = Stopwatch()..start();
        final zoneTile = await Isolate.run(
          () => _preprocess(
            imagePath,
            channelsFirst,
            zone.left,
            zone.top,
            zone.width,
            zone.height,
          ),
        );
        final zoneOutput = _infer(
          zoneTile.input,
          numAttrs: numAttrs,
          numAnchors: numAnchors,
          outputChannelsFirst: outputChannelsFirst,
        );
        final zoneExtract = extractCandidates(
          zoneOutput,
          labels: labels,
          numAnchors: numAnchors,
          padX: zoneTile.padX,
          padY: zoneTile.padY,
          newWidth: zoneTile.newWidth,
          newHeight: zoneTile.newHeight,
          roi: zoneTile.roi,
        );
        final zoneDetections = finalizeDetections(zoneExtract.candidates);
        final accepted = [
          for (final z in zoneDetections)
            if (z.effectiveScore >= zoneMinEffectiveScore &&
                _iou(primary.box, z.box) < zoneMaxIou &&
                _containment(primary.box, z.box) < 0.50)
              z,
        ];
        zoneWatch.stop();
        debugPrint(
          '[YoloV4] Pass 2 Unoccupied-Zone ${_fmtRect(zone)}: '
          '${zoneWatch.elapsedMilliseconds}ms, diterima=${accepted.length}',
        );
        if (accepted.isNotEmpty) {
          final combined = nms([...detections, ...accepted]);
          detections = combined.length > maxDetections
              ? combined.sublist(0, maxDetections)
              : combined;
        }
      }
    }

    total.stop();
    debugPrint(
      '[YoloV4] Final (${total.elapsedMilliseconds}ms, pass2=$pass2Executed, '
      'totalObjek=${detections.length}):',
    );
    for (final d in detections) {
      debugPrint(
        '[YoloV4]  - ${labels[d.classIndex]} | '
        'raw=${(d.rawScore * 100).toStringAsFixed(1)}% | '
        'eff=${(d.effectiveScore * 100).toStringAsFixed(1)}% | '
        'displayConf=${(d.score * 100).toStringAsFixed(1)}% | '
        'LTRB=${_fmtRect(d.box)}',
      );
    }

    // Thumbnail semua objek dalam 1x decode.
    final timestamp = DateTime.now();
    final tmpDir = (await getTemporaryDirectory()).path;
    final cropSpecs = <({int index, Rect box, String outPath})>[];
    for (var i = 0; i < detections.length; i++) {
      if (WasteType.fromLabelKey(labels[detections[i].classIndex]) == null) {
        continue;
      }
      cropSpecs.add((
        index: i,
        box: detections[i].box,
        outPath:
            '$tmpDir${Platform.pathSeparator}'
            'crop_${timestamp.millisecondsSinceEpoch}_$i.jpg',
      ));
    }
    var cropPaths = <int, String?>{};
    if (cropSpecs.isNotEmpty) {
      try {
        cropPaths = await Isolate.run(
          () => _cropBatchAndSave(imagePath, cropSpecs),
        );
      } catch (_) {
        cropPaths = {};
      }
    }

    final results = <ClassificationResult>[];
    for (var i = 0; i < detections.length; i++) {
      final d = detections[i];
      final wasteType = WasteType.fromLabelKey(labels[d.classIndex]);
      if (wasteType == null) continue;
      results.add(
        ClassificationResult(
          wasteType: wasteType,
          confidence: d.score,
          imagePath: imagePath,
          isUncertain: d.score < MlConfig.lowConfidenceThreshold,
          timestamp: timestamp,
          boundingBox: d.box,
          croppedImagePath: cropPaths[i],
          imageAspectRatio: tile.imageAspectRatio,
        ),
      );
    }
    if (results.isEmpty) {
      throw StateError('Model tidak menghasilkan prediksi');
    }
    return results.first.withDetections(results);
  }

  static String _fmtRect(Rect r) =>
      '(${r.left.toStringAsFixed(3)}, ${r.top.toStringAsFixed(3)}, '
      '${r.right.toStringAsFixed(3)}, ${r.bottom.toStringAsFixed(3)})';

  static String _top3(
    List<List<double>> output,
    List<String> labels,
    int numAnchors,
  ) {
    final maxPerClass = List<double>.filled(labels.length, 0.0);
    for (var c = 0; c < labels.length; c++) {
      final row = output[4 + c];
      for (var a = 0; a < numAnchors; a++) {
        if (row[a] > maxPerClass[c]) maxPerClass[c] = row[a];
      }
    }
    final idx = List<int>.generate(labels.length, (i) => i)
      ..sort((a, b) => maxPerClass[b].compareTo(maxPerClass[a]));
    return idx
        .take(3)
        .map((i) => '${labels[i]} ${(maxPerClass[i] * 100).toStringAsFixed(1)}%')
        .join(', ');
  }

  /// Kalibrasi jujur:
  /// - `s >= 0.22` -> dipetakan halus & proporsional ke `[0.62 .. 0.96]` (yakin).
  /// - `s < 0.22`  -> dipertahankan apa adanya (`< 0.60`, tidak yakin; dan `< 0.20`
  ///   tidak menggambar bounding box palsu di ResultScreen).
  static double calibrate(double s) {
    if (s < confidentEffectiveScore) return s;
    return (0.62 +
            ((s - confidentEffectiveScore) / (0.85 - confidentEffectiveScore)) *
                0.34)
        .clamp(0.62, 0.96);
  }

  /// Post-processing murni (dapat diuji tanpa model).
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
    final e = extractCandidates(
      output,
      labels: labels,
      numAnchors: numAnchors,
      padX: padX,
      padY: padY,
      newWidth: newWidth,
      newHeight: newHeight,
      roi: roi,
    );
    return finalizeDetections(e.candidates, fallbackBest: e.best);
  }

  /// Evaluasi seluruh 8400 anchor dan un-letterbox ke koordinat gambar asli 0..1.
  /// `score` pada hasil adalah skor efektif (belum dikalibrasi), sementara
  /// `rawScore` menyimpan skor asli model V4 (setelah penalti ukuran bila raksasa).
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
    final n = labels.length;
    final lower = [for (final l in labels) l.toLowerCase()];
    final clothesIdx = lower.indexOf('clothes');
    final cardboardIdx = lower.indexOf('cardboard');
    final paperIdx = lower.indexOf('paper');
    final transparent = [for (final l in lower) transparentClasses.contains(l)];

    var maxCoord = 0.0;
    for (var a = 0; a < numAnchors; a++) {
      maxCoord = math.max(maxCoord, math.max(output[2][a], output[3][a]));
    }
    final toCanvas = maxCoord <= 1.5 ? inputSize.toDouble() : 1.0;
    final effW = newWidth > 0 ? newWidth.toDouble() : inputSize.toDouble();
    final effH = newHeight > 0 ? newHeight.toDouble() : inputSize.toDouble();

    final candidates = <YoloDetection>[];
    YoloDetection? best;
    var bestScore = 0.0;

    for (var a = 0; a < numAnchors; a++) {
      var top1 = -1.0;
      var top2 = 0.0;
      var sum = 0.0;
      var cls = 0;
      for (var c = 0; c < n; c++) {
        var s = output[4 + c][a];
        if (c == clothesIdx) s *= clothesFactor;
        sum += s;
        if (s > top1) {
          top2 = top1 < 0 ? 0.0 : top1;
          top1 = s;
          cls = c;
        } else if (s > top2) {
          top2 = s;
        }
      }
      if (top1 <= 0) continue;

      // Tie-breaker ringan: kertas bergaris di meja kayu tidak terbaca kardus.
      if (cls == cardboardIdx && paperIdx >= 0) {
        final p = output[4 + paperIdx][a];
        if (p >= paperOverCardboardRatio * top1) {
          top2 = top1;
          top1 = p;
          cls = paperIdx;
        }
      }

      final dominance = top1 / (top2 + 0.0005);
      final share = top1 / (sum + 0.0001);

      final isNormalCandidate = top1 >= minRawScore;
      final isAssistEligible =
          !isNormalCandidate &&
          transparent[cls] &&
          top1 >= assistMinScore &&
          dominance >= assistMinDominance &&
          share >= assistMinShare;

      // Hindari menghitung kotak untuk anchor yang tidak relevan.
      if (!isNormalCandidate && !isAssistEligible && top1 <= bestScore) {
        continue;
      }

      final xc = output[0][a] * toCanvas;
      final yc = output[1][a] * toCanvas;
      final bw = output[2][a] * toCanvas;
      final bh = output[3][a] * toCanvas;
      final tl = (((xc - bw / 2.0) - padX) / effW).clamp(0.0, 1.0);
      final tt = (((yc - bh / 2.0) - padY) / effH).clamp(0.0, 1.0);
      final tr = (((xc + bw / 2.0) - padX) / effW).clamp(0.0, 1.0);
      final tb = (((yc + bh / 2.0) - padY) / effH).clamp(0.0, 1.0);
      final left = (roi.left + tl * roi.width).clamp(0.0, 1.0);
      final top = (roi.top + tt * roi.height).clamp(0.0, 1.0);
      final right = (roi.left + tr * roi.width).clamp(0.0, 1.0);
      final bottom = (roi.top + tb * roi.height).clamp(0.0, 1.0);
      final w = right - left;
      final h = bottom - top;
      if (w < minBoxSide || h < minBoxSide) continue;

      final boxArea = w * h;
      final penalty = boxArea > giantBoxArea ? giantBoxPenalty : 1.0;

      var eff = -1.0;
      if (isNormalCandidate) {
        eff = top1 * penalty;
      } else if (isAssistEligible &&
          boxArea >= assistMinArea &&
          boxArea <= assistMaxArea) {
        final t =
            (0.5 * ((share - assistMinShare) / (1.0 - assistMinShare)) +
                    0.5 * ((dominance - assistMinDominance) / 6.0))
                .clamp(0.0, 1.0);
        eff = (assistEffMin + (assistEffMax - assistEffMin) * t) * penalty;
      }

      final box = Rect.fromLTRB(left, top, right, bottom);
      final rawWithPenalty = top1 * penalty;
      if (rawWithPenalty > bestScore) {
        bestScore = rawWithPenalty;
        best = YoloDetection(
          box,
          rawWithPenalty,
          cls,
          rawScore: rawWithPenalty,
          effectiveScore: rawWithPenalty,
          dominanceRatio: dominance,
        );
      }
      if (eff >= minRawScore) {
        candidates.add(
          YoloDetection(
            box,
            eff,
            cls,
            rawScore: rawWithPenalty,
            effectiveScore: eff,
            dominanceRatio: dominance,
          ),
        );
      }
    }

    candidates.sort((a, b) => b.score.compareTo(a.score));
    if (candidates.length > maxCandidates) {
      candidates.removeRange(maxCandidates, candidates.length);
    }
    return (candidates: candidates, best: best);
  }

  /// Tahap A (Same-Class Merge) -> Tahap B (Class-Agnostic NMS) -> Kalibrasi.
  /// Objek selain yang pertama harus memenuhi `effectiveScore >= 0.22` agar
  /// tidak memunculkan noise tambahan.
  static List<YoloDetection> finalizeDetections(
    List<YoloDetection> candidates, {
    YoloDetection? fallbackBest,
  }) {
    if (candidates.isEmpty) {
      if (fallbackBest == null) return const [];
      return [_calibrated(fallbackBest)];
    }
    final kept = nms(mergeSameClass(candidates));
    final result = <YoloDetection>[];
    for (final d in kept) {
      if (result.isNotEmpty && d.effectiveScore < confidentEffectiveScore) {
        continue;
      }
      result.add(_calibrated(d));
      if (result.length >= maxDetections) break;
    }
    return result;
  }

  static YoloDetection _calibrated(YoloDetection d) => YoloDetection(
    d.box,
    calibrate(d.effectiveScore),
    d.classIndex,
    rawScore: d.rawScore,
    effectiveScore: d.effectiveScore,
    dominanceRatio: d.dominanceRatio,
  );

  /// Tahap A: gabungkan kotak kelas sama milik satu benda fisik
  /// (`IoU > 0.12`, `containment > 0.45`, atau berdekatan tepi `< 0.05`
  /// selama luas gabungan `<= 0.65`).
  static List<YoloDetection> mergeSameClass(List<YoloDetection> input) {
    final list = [...input]..sort((a, b) => b.score.compareTo(a.score));
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
          final union = Rect.fromLTRB(
            math.min(a.box.left, b.box.left),
            math.min(a.box.top, b.box.top),
            math.max(a.box.right, b.box.right),
            math.max(a.box.bottom, b.box.bottom),
          );
          if (union.width * union.height > mergeMaxArea) continue;
          final bestEff = math.max(a.effectiveScore, b.effectiveScore);
          list[i] = YoloDetection(
            union,
            math.max(a.score, b.score),
            a.classIndex,
            rawScore: math.max(a.rawScore, b.rawScore),
            effectiveScore: bestEff,
            dominanceRatio: math.max(a.dominanceRatio, b.dominanceRatio),
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
    if (_containment(a, b) > mergeContainment ||
        _containment(b, a) > mergeContainment) {
      return true;
    }
    // Berdekatan vertikal (sejajar horizontal) atau horizontal (sejajar vertikal).
    final vGap = math.max(a.top, b.top) - math.min(a.bottom, b.bottom);
    final hOverlap = math.min(a.right, b.right) - math.max(a.left, b.left);
    final minW = math.min(a.width, b.width);
    if (vGap < mergeEdgeGap && hOverlap > 0.5 * minW) return true;
    final hGap = math.max(a.left, b.left) - math.min(a.right, b.right);
    final vOverlap = math.min(a.bottom, b.bottom) - math.max(a.top, b.top);
    final minH = math.min(a.height, b.height);
    return hGap < mergeEdgeGap && vOverlap > 0.5 * minH;
  }

  /// Tahap B: Class-Agnostic Spatial NMS (selaras `agnostic_nms = True` V4).
  /// Satu benda fisik = satu kotak (`IoU > 0.42`, `containment > 0.55`, atau
  /// `centerDistance < 0.16`); benda terpisah dipertahankan.
  static List<YoloDetection> nms(List<YoloDetection> input) {
    final sorted = [...input]..sort((a, b) => b.score.compareTo(a.score));
    final kept = <YoloDetection>[];
    for (final d in sorted) {
      var suppressed = false;
      for (final k in kept) {
        if (_iou(k.box, d.box) > nmsIou ||
            _containment(k.box, d.box) > nmsContainment ||
            _containment(d.box, k.box) > nmsContainment ||
            _centerDistance(k.box, d.box) < nmsCenterDist) {
          suppressed = true;
          break;
        }
      }
      if (!suppressed) kept.add(d);
    }
    return kept;
  }

  /// Tahap C: Mengembalikan zona kosong terbesar (`>= 45%` lebar/tinggi frame)
  /// di luar batas [primary] (dengan margin `0.04`, tidak pernah memotong
  /// [primary]). Mengembalikan `null` bila tidak ada ruang kosong yang cukup luas.
  static Rect? unoccupiedZone(Rect primary) {
    Rect? bestZone;
    var bestSpan = 0.0;

    void consider(double span, Rect rect) {
      if (span >= zoneMinSize && span > bestSpan) {
        bestSpan = span;
        bestZone = rect;
      }
    }

    final rightStart = primary.right + zoneMargin;
    consider(1.0 - rightStart, Rect.fromLTRB(rightStart, 0.0, 1.0, 1.0));

    final leftEnd = primary.left - zoneMargin;
    consider(leftEnd, Rect.fromLTRB(0.0, 0.0, leftEnd, 1.0));

    final bottomStart = primary.bottom + zoneMargin;
    consider(1.0 - bottomStart, Rect.fromLTRB(0.0, bottomStart, 1.0, 1.0));

    final topEnd = primary.top - zoneMargin;
    consider(topEnd, Rect.fromLTRB(0.0, 0.0, 1.0, topEnd));

    return bestZone;
  }

  static double _iou(Rect a, Rect b) {
    final inter = a.intersect(b);
    if (inter.width <= 0 || inter.height <= 0) return 0.0;
    final ia = inter.width * inter.height;
    final union = a.width * a.height + b.width * b.height - ia;
    return union <= 0 ? 0.0 : ia / union;
  }

  /// Porsi luas [inner] yang berada di dalam [outer].
  static double _containment(Rect outer, Rect inner) {
    final inter = outer.intersect(inner);
    if (inter.width <= 0 || inter.height <= 0) return 0.0;
    final area = inner.width * inner.height;
    return area <= 0 ? 0.0 : (inter.width * inter.height) / area;
  }

  static double _centerDistance(Rect a, Rect b) {
    final dx = (a.left + a.right) / 2.0 - (b.left + b.right) / 2.0;
    final dy = (a.top + a.bottom) / 2.0 - (b.top + b.bottom) / 2.0;
    return math.sqrt(dx * dx + dy * dy);
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _loading = null;
  }
}

/// Satu kandidat/hasil deteksi.
class YoloDetection {
  final Rect box; // ternormalisasi 0..1 terhadap gambar asli

  /// Skor tampilan: efektif sebelum kalibrasi pada kandidat, dan confidence
  /// terkalibrasi (`displayConfidence`) pada hasil akhir.
  final double score;
  final int classIndex;

  /// Skor asli model V4 (setelah penalti kotak raksasa bila berlaku).
  final double rawScore;

  /// Skor efektif sebelum kalibrasi (sama dengan [rawScore] atau hasil
  /// Guarded Transparency Assist).
  final double effectiveScore;
  final double dominanceRatio;

  const YoloDetection(
    this.box,
    this.score,
    this.classIndex, {
    this.rawScore = 0,
    double? effectiveScore,
    this.dominanceRatio = 1.0,
  }) : effectiveScore = effectiveScore ?? score;
}

class _TileInput {
  final Float32List input;
  final int padX;
  final int padY;
  final int newWidth;
  final int newHeight;
  final Rect roi; // area di dalam gambar utuh (0..1)
  final double imageAspectRatio; // lebar / tinggi gambar utuh (setelah EXIF)

  const _TileInput({
    required this.input,
    required this.padX,
    required this.padY,
    required this.newWidth,
    required this.newHeight,
    required this.roi,
    required this.imageAspectRatio,
  });
}

/// Decode (sekali) + bakeOrientation + letterbox RGB(114, 114, 114) 640x640
/// untuk ROI tertentu.
_TileInput _preprocess(
  String path,
  bool channelsFirst,
  double roiLeft,
  double roiTop,
  double roiWidth,
  double roiHeight,
) {
  final decoded = img.decodeImage(File(path).readAsBytesSync());
  if (decoded == null) {
    throw StateError('Gambar tidak dapat dibaca: $path');
  }
  final image = img.bakeOrientation(decoded);
  final origW = image.width;
  final origH = image.height;

  final cropX = (roiLeft * origW).round().clamp(0, origW - 1);
  final cropY = (roiTop * origH).round().clamp(0, origH - 1);
  final cropW = (roiWidth * origW).round().clamp(1, origW - cropX);
  final cropH = (roiHeight * origH).round().clamp(1, origH - cropY);
  final region = (cropX == 0 && cropY == 0 && cropW == origW && cropH == origH)
      ? image
      : img.copyCrop(image, x: cropX, y: cropY, width: cropW, height: cropH);

  const size = YoloWasteClassifier.inputSize;
  final scale = math.min(size / region.width, size / region.height);
  final newW = (region.width * scale).round().clamp(1, size);
  final newH = (region.height * scale).round().clamp(1, size);
  final padX = (size - newW) ~/ 2;
  final padY = (size - newH) ~/ 2;

  final resized = img.copyResize(
    region,
    width: newW,
    height: newH,
    interpolation: img.Interpolation.linear,
  );
  final rgb = resized.getBytes(order: img.ChannelOrder.rgb);

  // Warna bar letterbox standar YOLO RGB(114, 114, 114) sesuai pelatihan V4.
  const pad = 114.0 / 255.0;
  const plane = size * size;
  const inv255 = 1.0 / 255.0;
  final data = Float32List(plane * 3)..fillRange(0, plane * 3, pad);
  var src = 0;
  for (var y = 0; y < newH; y++) {
    final row = (y + padY) * size + padX;
    for (var x = 0; x < newW; x++) {
      final idx = row + x;
      final r = rgb[src] * inv255;
      final g = rgb[src + 1] * inv255;
      final b = rgb[src + 2] * inv255;
      src += 3;
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

  return _TileInput(
    input: data,
    padX: padX,
    padY: padY,
    newWidth: newW,
    newHeight: newH,
    roi: Rect.fromLTWH(
      cropX / origW,
      cropY / origH,
      cropW / origW,
      cropH / origH,
    ),
    imageAspectRatio: origH > 0 ? origW / origH : 1.0,
  );
}

/// Potong semua bounding box dengan 1x decode.
Map<int, String?> _cropBatchAndSave(
  String path,
  List<({int index, Rect box, String outPath})> specs,
) {
  final decoded = img.decodeImage(File(path).readAsBytesSync());
  if (decoded == null) return const {};
  final image = img.bakeOrientation(decoded);
  final result = <int, String?>{};
  for (final s in specs) {
    try {
      final x = (s.box.left * image.width).floor().clamp(0, image.width - 1);
      final y = (s.box.top * image.height).floor().clamp(0, image.height - 1);
      final w = ((s.box.right * image.width).ceil() - x).clamp(
        1,
        image.width - x,
      );
      final h = ((s.box.bottom * image.height).ceil() - y).clamp(
        1,
        image.height - y,
      );
      final cropped = img.copyCrop(image, x: x, y: y, width: w, height: h);
      File(s.outPath).writeAsBytesSync(img.encodeJpg(cropped, quality: 85));
      result[s.index] = s.outPath;
    } catch (_) {
      result[s.index] = null;
    }
  }
  return result;
}
