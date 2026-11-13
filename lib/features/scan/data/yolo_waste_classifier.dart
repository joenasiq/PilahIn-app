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

  /// Ambang kandidat standar (skor setelah koreksi kelas & ukuran kotak).
  static const double detectionThreshold = 0.15;

  /// Ambang NMS IoU.
  static const double iouThreshold = 0.40;

  /// Deduplikasi satu objek fisik (lintas & sesama kelas): kotak B dibuang bila
  /// IoMin (proporsi kotak lebih kecil di dalam kotak lebih besar) > 0.58
  /// atau jarak pusatnya < 0.18.
  static const double containmentThreshold = 0.58;
  static const double sameObjectCenterDist = 0.18;

  /// Kotak lebar yang menelan 2 objek sekaligus.
  static const double wideBoxWidth = 0.68;
  static const double wideBoxMinHeight = 0.35;
  static const double narrowBoxWidth = 0.55;
  static const double wideBoxPenalty = 0.35;

  /// Pencarian objek ke-2 & Transparency Recovery.
  static const double sensitiveMinScore = 0.12;
  static const double complementMinScore = 0.18;
  static const double complementMaxTileArea = 0.75;
  static const double complementOverlapMax = 0.15;
  static const double complementCenterMin = 0.22;

  /// Parameter Transparency Recovery (Relative Dominance & Spatial Consensus).
  static const double lowAmpMinScore = 0.004;
  static const double minDominanceRatio = 2.4;
  static const int minConsensusAnchors = 3;

  static const int maxDetections = 5;
  static const double minBoxSide = 0.03;

  /// Penalti kotak raksasa yang menelan 2 objek / meja sekaligus.
  static const double giantBoxWidth = 0.75;
  static const double giantBoxArea = 0.52;
  static const double giantBoxPenalty = 0.50;

  /// Koreksi kelas pemicu bias pada meja/latar gelap.
  static const Map<String, double> classFactors = {
    'clothes': 0.22,
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
    'white-glass',
    'green-glass',
    'brown-glass',
    'battery',
  };
  static const double clothesRivalRatio = 0.45;

  /// Merge kotak kelas sama yang terbelah.
  static const double mergeIou = 0.08;
  static const double mergeCenterDx = 0.25;
  static const double mergeCenterDy = 0.20;

  /// Objek tambahan hanya ditampilkan bila skor mentahnya >= nilai ini saat
  /// objek utama sudah yakin.
  static const double secondaryMinScore = 0.18;

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
  /// (`Uint8List`) dan zero-copy `Float32List.sublistView` tanpa alokasi list
  /// baru di heap yang memicu GC berat.
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
      // Shape [1, 16, 8400]: gunakan zero-copy Float32List.sublistView.
      return List<List<double>>.generate(
        numAttrs,
        (attr) => Float32List.sublistView(
          outFloats,
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
          final row = Float32List(numAnchors);
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

    // TAHAP A: Single-Decode + Fast Adaptive Letterbox 640x640 di Isolate.
    final mainTile = await Isolate.run(
      () => _preprocessMainTile(imagePath, channelsFirst),
    );

    final inferWatch = Stopwatch()..start();
    final mainOutput = _runFastInference(
      interpreter,
      mainTile.input,
      numAttrs: numAttrs,
      numAnchors: numAnchors,
      isChannelsFirstOutput: isChannelsFirstOutput,
    );
    inferWatch.stop();
    debugPrint(
      '[YoloWasteClassifier] Pass-1 inference: ${inferWatch.elapsedMilliseconds} ms',
    );
    _debugPrintTopClassScores(mainOutput, labels, numAnchors);

    // TAHAP B: Ekstraksi kandidat + Relative Dominance & Transparency Recovery.
    final mainCandidates = extractCandidates(
      mainOutput,
      labels: labels,
      numAnchors: numAnchors,
      padX: mainTile.padX,
      padY: mainTile.padY,
      newWidth: mainTile.newWidth,
      newHeight: mainTile.newHeight,
      roi: mainTile.roi,
    );

    final recoveredTransparent = recoverTransparentObjects(
      mainCandidates.lowAmp,
    );

    final pool = <YoloDetection>[
      ...mainCandidates.candidates,
      ...recoveredTransparent,
    ];
    final sensitivePool = <YoloDetection>[
      ...mainCandidates.sensitive,
      ...recoveredTransparent,
    ];
    YoloDetection? bestFallback = mainCandidates.best;

    // TAHAP C: Inner-Core Priority, Composite Box Rejection, Clustering & NMS.
    var detections = finalizeDetections(
      pool,
      fallbackBest: bestFallback,
      labels: labels,
    );

    // Cek objek ke-2 dari sensitivePool / Transparency Recovery di luar primaryBox.
    if (detections.isNotEmpty &&
        detections.length == 1 &&
        detections.first.rawScore >= sensitiveMinScore) {
      final primary = detections.first;
      final extra = pickComplementary(
        primary.box,
        sensitivePool,
        minScore: complementMinScore,
      );
      if (extra != null) {
        pool.add(extra);
        detections = finalizeDetections(
          pool,
          fallbackBest: bestFallback,
          labels: labels,
        );
      } else if (_hasOppositeSideHint(primary.box, mainCandidates.lowAmp)) {
        // Hanya jalankan 1x targeted crop pada zona seberang bila memang
        // terdapat indikasi sinyal objek lemah di sisi seberang (mencegah
        // object splitting & menjaga latensi < 800 ms pada foto 1 objek).
        final zones = complementaryZones(primary.box, primary.rawScore);
        if (zones.isNotEmpty) {
          final compWatch = Stopwatch()..start();
          final tiles = await Isolate.run(
            () => _buildTilesForRois(imagePath, [zones.first], channelsFirst),
          );
          final zoneCandidates = <YoloDetection>[];
          for (final tile in tiles) {
            final zoneOut = _runFastInference(
              interpreter,
              tile.input,
              numAttrs: numAttrs,
              numAnchors: numAnchors,
              isChannelsFirstOutput: isChannelsFirstOutput,
            );
            final zone = extractCandidates(
              zoneOut,
              labels: labels,
              numAnchors: numAnchors,
              padX: tile.padX,
              padY: tile.padY,
              newWidth: tile.newWidth,
              newHeight: tile.newHeight,
              roi: tile.roi,
              rejectTileArea: complementMaxTileArea,
            );
            final zoneRec = recoverTransparentObjects(zone.lowAmp);
            zoneCandidates.addAll(
              mergeSameClass(
                nms([...zone.candidates, ...zoneRec]),
              ),
            );
          }
          compWatch.stop();
          debugPrint(
            '[YoloWasteClassifier] Targeted complementary zone: '
            '${compWatch.elapsedMilliseconds} ms',
          );
          final zoneExtra = pickComplementary(primary.box, zoneCandidates);
          if (zoneExtra != null) {
            pool.add(zoneExtra);
            detections = finalizeDetections(
              pool,
              fallbackBest: bestFallback,
              labels: labels,
            );
          }
        }
      }
    }

    totalWatch.stop();
    debugPrint(
      '[YoloWasteClassifier] Total pipeline: ${totalWatch.elapsedMilliseconds} ms | '
      'mainPad=(${mainTile.padX},${mainTile.padY}) '
      'mainScaled=${mainTile.newWidth}x${mainTile.newHeight} '
      'detections=${detections.length}',
    );
    for (final d in detections) {
      debugPrint(
        '[YoloWasteClassifier]  - ${labels[d.classIndex]} '
        'conf=${(d.score * 100).toStringAsFixed(1)}% '
        'raw=${(d.rawScore * 100).toStringAsFixed(1)}% '
        'dom=${d.dominanceRatio.toStringAsFixed(2)} box=${d.box}',
      );
    }

    final timestamp = DateTime.now();
    final tmpDir = (await getTemporaryDirectory()).path;

    // Potong seluruh bounding box dalam 1 kali pemanggilan Isolate (Single Decode).
    final cropSpecs = <({int index, Rect box, String outPath})>[];
    for (var i = 0; i < detections.length; i++) {
      final d = detections[i];
      if (WasteType.fromLabelKey(labels[d.classIndex]) == null) continue;
      final outPath =
          '$tmpDir${Platform.pathSeparator}'
          'crop_${timestamp.millisecondsSinceEpoch}_$i.jpg';
      cropSpecs.add((index: i, box: d.box, outPath: outPath));
    }

    Map<int, String?> cropPaths = const {};
    if (cropSpecs.isNotEmpty) {
      try {
        cropPaths = await Isolate.run(
          () => _cropBatchAndSave(imagePath, cropSpecs),
        );
      } catch (_) {
        cropPaths = const {};
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
          imageAspectRatio: mainTile.imageAspectRatio,
        ),
      );
    }

    if (results.isEmpty) {
      throw StateError('Model tidak menghasilkan prediksi');
    }
    return results.first.withDetections(results);
  }

  /// Memeriksa apakah ada minimal 2 anchor dengan dominasi >= 1.8 di zona
  /// seberang `primary` sebelum memutuskan perlu tidaknya complementary crop.
  static bool _hasOppositeSideHint(Rect primary, List<YoloDetection> lowAmp) {
    if (primary.width >= 0.60) return false;
    var count = 0;
    for (final c in lowAmp) {
      if (c.rawScore < 0.025 || c.dominanceRatio < 1.8) continue;
      if (_containment(primary, c.box) < complementOverlapMax &&
          _centerDistance(primary, c.box) > complementCenterMin) {
        count++;
        if (count >= 2) return true;
      }
    }
    return false;
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
  /// - 0.15 <= s < 0.18: linear ke 0.30..0.58 (tetap tidak yakin)
  /// - s >= 0.18       : kurva halus ke 0.62..0.96 (objek valid ke-1 & ke-2 yakin)
  static double calibrate(double s) {
    if (s < 0.15) return s;
    if (s < 0.18) return 0.30 + ((s - 0.15) / (0.18 - 0.15)) * 0.28;
    return (0.62 + ((s - 0.18) / (0.85 - 0.18)) * 0.34).clamp(0.62, 0.96);
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
    final recovered = recoverTransparentObjects(extracted.lowAmp);
    return finalizeDetections(
      [...extracted.candidates, ...recovered],
      fallbackBest: extracted.best,
      labels: labels,
    );
  }

  /// Mengekstrak kandidat anchor dari satu tile/pass dan memetakannya ke
  /// koordinat ternormalisasi gambar asli (0.0 .. 1.0) sesuai [roi].
  static ({
    List<YoloDetection> candidates,
    List<YoloDetection> sensitive,
    List<YoloDetection> lowAmp,
    YoloDetection? best,
  })
  extractCandidates(
    List<List<double>> output, {
    required List<String> labels,
    required int numAnchors,
    int padX = 0,
    int padY = 0,
    int newWidth = inputSize,
    int newHeight = inputSize,
    Rect roi = const Rect.fromLTWH(0.0, 0.0, 1.0, 1.0),
    double? rejectTileArea,
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
    final sensitive = <YoloDetection>[];
    final lowAmp = <YoloDetection>[];
    YoloDetection? best;

    for (var a = 0; a < numAnchors; a++) {
      var score = -1.0;
      var secondScore = 0.0;
      var cls = 0;
      for (var c = 0; c < numClasses; c++) {
        final s = output[4 + c][a] * factors[c];
        if (s > score) {
          secondScore = score > 0 ? score : 0.0;
          score = s;
          cls = c;
        } else if (s > secondScore) {
          secondScore = s;
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
          secondScore = 0.0;
          for (var c = 0; c < numClasses; c++) {
            if (c == cls || lower[c] == 'clothes') continue;
            final s = output[4 + c][a] * factors[c];
            if (s > secondScore) secondScore = s;
          }
        }
      }

      final xc = output[0][a] * toCanvas;
      final yc = output[1][a] * toCanvas;
      final bw = output[2][a] * toCanvas;
      final bh = output[3][a] * toCanvas;

      // Koordinat lokal di dalam tile/crop (tanpa early clamping sebelum ROI
      // agar kotak tidak terpotong semu di batas ROI).
      final rawTileLeft = ((xc - bw / 2.0) - padX) / effW;
      final rawTileTop = ((yc - bh / 2.0) - padY) / effH;
      final rawTileRight = ((xc + bw / 2.0) - padX) / effW;
      final rawTileBottom = ((yc + bh / 2.0) - padY) / effH;

      final tileLeft = rawTileLeft.clamp(0.0, 1.0);
      final tileTop = rawTileTop.clamp(0.0, 1.0);
      final tileRight = rawTileRight.clamp(0.0, 1.0);
      final tileBottom = rawTileBottom.clamp(0.0, 1.0);
      final tileW = tileRight - tileLeft;
      final tileH = tileBottom - tileTop;
      if (tileW < minBoxSide || tileH < minBoxSide) continue;
      if (rejectTileArea != null && tileW * tileH > rejectTileArea) continue;

      // Petakan kembali dari koordinat tile ke koordinat gambar utuh (0.0 .. 1.0)
      final left = (roi.left + rawTileLeft * roi.width).clamp(0.0, 1.0);
      final top = (roi.top + rawTileTop * roi.height).clamp(0.0, 1.0);
      final right = (roi.left + rawTileRight * roi.width).clamp(0.0, 1.0);
      final bottom = (roi.top + rawTileBottom * roi.height).clamp(0.0, 1.0);
      final width = right - left;
      final height = bottom - top;
      if (width < minBoxSide || height < minBoxSide) continue;

      final area = width * height;
      // Penalti kotak raksasa yang menelan 2 objek sekaligus / meja:
      if (width > giantBoxWidth ||
          area > giantBoxArea ||
          tileW > giantBoxWidth ||
          tileW * tileH > giantBoxArea) {
        score *= giantBoxPenalty;
      }

      final dominanceRatio = score / (secondScore + 0.0005);
      final clamped = score.clamp(0.0, 1.0);
      final det = YoloDetection(
        Rect.fromLTRB(left, top, right, bottom),
        clamped,
        cls,
        rawScore: clamped,
        dominanceRatio: dominanceRatio,
      );
      if (best == null || det.score > best.score) best = det;
      if (score >= detectionThreshold) {
        candidates.add(det);
      } else if (score >= lowAmpMinScore &&
          dominanceRatio >= 2.0 &&
          width <= 0.65 &&
          area >= 0.015 &&
          area <= 0.48) {
        lowAmp.add(det);
      }
      if (score >= sensitiveMinScore) sensitive.add(det);
    }

    return (
      candidates: candidates,
      sensitive: sensitive,
      lowAmp: lowAmp,
      best: best,
    );
  }

  /// Tahap B (Transparency Recovery): Memulihkan objek transparan (mis. botol
  /// plastik bening dengan rawScore 0.7% vs juara kedua 0.2%) menggunakan
  /// Relative Dominance Ratio (>= [minDominance]) & Spatial Anchor Consensus
  /// (>= [minClusterSize] anchor beririsan pada kelas yang sama).
  ///
  /// Objek non-sampah seperti laptop yang distribusi kelasnya datar (entropi
  /// tinggi) atau tidak memiliki konsensus cluster tidak akan terangkat.
  static List<YoloDetection> recoverTransparentObjects(
    List<YoloDetection> lowAmpPool, {
    int minClusterSize = minConsensusAnchors,
    double minDominance = minDominanceRatio,
  }) {
    if (lowAmpPool.length < minClusterSize) return const [];

    final used = List<bool>.filled(lowAmpPool.length, false);
    final recovered = <YoloDetection>[];

    // Urutkan dari dominanceRatio * rawScore tertinggi.
    final indexed = List<int>.generate(lowAmpPool.length, (i) => i)
      ..sort((a, b) {
        final sa = lowAmpPool[a].rawScore * lowAmpPool[a].dominanceRatio;
        final sb = lowAmpPool[b].rawScore * lowAmpPool[b].dominanceRatio;
        return sb.compareTo(sa);
      });

    for (final seedIdx in indexed) {
      if (used[seedIdx]) continue;
      final seed = lowAmpPool[seedIdx];
      if (seed.dominanceRatio < minDominance) continue;

      final cluster = <YoloDetection>[seed];
      used[seedIdx] = true;

      for (final j in indexed) {
        if (used[j]) continue;
        final cand = lowAmpPool[j];
        if (cand.classIndex != seed.classIndex) continue;
        if (_iou(seed.box, cand.box) >= 0.35 ||
            _containment(seed.box, cand.box) >= 0.60 ||
            _containment(cand.box, seed.box) >= 0.60) {
          cluster.add(cand);
          used[j] = true;
        }
      }

      if (cluster.length < minClusterSize) continue;

      // Hitung Weighted Box Fusion (rata-rata koordinat berbobot skor).
      var sumW = 0.0;
      var left = 0.0;
      var top = 0.0;
      var right = 0.0;
      var bottom = 0.0;
      var maxDom = 0.0;
      for (final c in cluster) {
        final w = c.rawScore * c.dominanceRatio;
        sumW += w;
        left += c.box.left * w;
        top += c.box.top * w;
        right += c.box.right * w;
        bottom += c.box.bottom * w;
        if (c.dominanceRatio > maxDom) maxDom = c.dominanceRatio;
      }
      if (sumW <= 0) continue;

      final fusedBox = Rect.fromLTRB(
        (left / sumW).clamp(0.0, 1.0),
        (top / sumW).clamp(0.0, 1.0),
        (right / sumW).clamp(0.0, 1.0),
        (bottom / sumW).clamp(0.0, 1.0),
      );
      if (fusedBox.width > 0.65 || fusedBox.width * fusedBox.height > 0.48) {
        continue;
      }

      final recoveredScore =
          (0.18 +
                  0.03 * (maxDom - minDominance).clamp(0.0, 5.0) +
                  0.012 * math.min(cluster.length, 10))
              .clamp(0.18, 0.40);

      recovered.add(
        YoloDetection(
          fusedBox,
          recoveredScore,
          seed.classIndex,
          rawScore: recoveredScore,
          dominanceRatio: maxDom,
        ),
      );
    }

    return recovered;
  }

  /// Menjalankan Inner-Core Context Priority, Wide-Box Penalty, NMS,
  /// Same-Class Box Merging, deduplikasi ketat 1 objek fisik = 1 kotak,
  /// dan Soft Confidence Calibration.
  static List<YoloDetection> finalizeDetections(
    List<YoloDetection> candidates, {
    YoloDetection? fallbackBest,
    List<String>? labels,
  }) {
    if (candidates.isEmpty) {
      if (fallbackBest == null) return const [];
      return [
        YoloDetection(
          fallbackBest.box,
          calibrate(fallbackBest.score),
          fallbackBest.classIndex,
          rawScore: fallbackBest.rawScore,
          dominanceRatio: fallbackBest.dominanceRatio,
        ),
      ];
    }

    final corePrioritized = labels != null
        ? applyInnerCorePriority(candidates, labels)
        : candidates;
    final penalized = applyWideBoxPenalty(corePrioritized);
    if (penalized.isEmpty) {
      if (fallbackBest == null) return const [];
      return [
        YoloDetection(
          fallbackBest.box,
          calibrate(fallbackBest.score),
          fallbackBest.classIndex,
          rawScore: fallbackBest.rawScore,
          dominanceRatio: fallbackBest.dominanceRatio,
        ),
      ];
    }
    // 1. NMS awal (membiarkan belahan vertikal/horizontal kelas sama untuk digabung)
    // 2. Same-Class Box Merging (menyatukan objek yang terbelah)
    // 3. NMS ketat (satu objek fisik = satu kotak lintas & sesama kelas)
    final merged = nms(
      mergeSameClass(nms(penalized)),
      allowSplitSameClass: false,
    );
    final result = <YoloDetection>[];
    for (final d in merged) {
      result.add(
        YoloDetection(
          d.box,
          calibrate(d.score),
          d.classIndex,
          rawScore: d.rawScore,
          dominanceRatio: d.dominanceRatio,
        ),
      );
    }
    // Jika objek utama sudah yakin, objek tambahan harus punya skor mentah
    // >= 0.18 dan kotak ketat (width <= 0.68).
    if (result.isNotEmpty && result.first.score >= 0.62) {
      result.removeWhere(
        (d) =>
            !identical(d, result.first) &&
            (d.rawScore < secondaryMinScore || d.box.width > wideBoxWidth),
      );
    }
    return result.length > maxDetections
        ? result.sublist(0, maxDetections)
        : result;
  }

  /// Mencegah Background Context Leakage (Masalah #3: Kertas di atas meja kayu
  /// coklat terbaca `cardboard`, atau kertas berbayangan terbaca `clothes`).
  /// Jika terdapat kotak luar yang lebih besar (`cardboard`/`clothes`) yang
  /// membungkus kotak inti (`paper`/`plastic`/`metal`/`biological`) yang lebih
  /// ketat di dalamnya, kotak luar dikenai penalti konteks latar.
  static List<YoloDetection> applyInnerCorePriority(
    List<YoloDetection> input,
    List<String> labels,
  ) {
    final lower = [for (final l in labels) l.toLowerCase()];
    const leakyClasses = {'cardboard', 'clothes'};
    const coreClasses = {
      'paper',
      'plastic',
      'metal',
      'biological',
      'white-glass',
      'green-glass',
      'brown-glass',
      'battery',
    };

    final result = <YoloDetection>[];
    for (final d in input) {
      if (d.classIndex < 0 || d.classIndex >= lower.length) {
        result.add(d);
        continue;
      }
      final clsName = lower[d.classIndex];
      if (!leakyClasses.contains(clsName)) {
        result.add(d);
        continue;
      }

      final outerArea = d.box.width * d.box.height;
      var hasTightInnerCore = false;
      for (final inner in input) {
        if (identical(inner, d) ||
            inner.classIndex < 0 ||
            inner.classIndex >= lower.length) {
          continue;
        }
        final innerName = lower[inner.classIndex];
        if (!coreClasses.contains(innerName)) continue;
        final innerArea = inner.box.width * inner.box.height;
        if (outerArea >= innerArea * 1.15 &&
            _containment(d.box, inner.box) >= 0.65 &&
            inner.score >= d.score * 0.50) {
          hasTightInnerCore = true;
          break;
        }
      }

      if (!hasTightInnerCore) {
        result.add(d);
        continue;
      }
      final penalizedScore = d.score * 0.40;
      if (penalizedScore >= detectionThreshold) {
        result.add(
          YoloDetection(
            d.box,
            penalizedScore,
            d.classIndex,
            rawScore: penalizedScore,
            dominanceRatio: d.dominanceRatio,
          ),
        );
      }
    }
    return result;
  }

  /// Kotak lebar (width > 0.68 dan height > 0.35) atau kotak komposit yang
  /// menelan 2 objek terpisah dipenalti 0.35 bila ada kandidat anchor lain
  /// yang lebih sempit (width < 0.55) di dalamnya.
  static List<YoloDetection> applyWideBoxPenalty(List<YoloDetection> input) {
    final result = <YoloDetection>[];
    for (final d in input) {
      final wide =
          d.box.width > wideBoxWidth && d.box.height > wideBoxMinHeight;
      var swallows = false;
      if (wide) {
        for (final n in input) {
          if (identical(n, d) || n.box.width >= narrowBoxWidth) continue;
          final cx = (n.box.left + n.box.right) / 2.0;
          if (cx >= d.box.left && cx <= d.box.right) {
            swallows = true;
            break;
          }
        }
      } else if (d.box.width > 0.58) {
        // Cek apakah kotak ini menelan >= 2 objek kecil yang saling terpisah.
        final contained = <YoloDetection>[];
        for (final n in input) {
          if (identical(n, d) || n.box.width >= 0.50) continue;
          if (_containment(d.box, n.box) >= 0.65) {
            contained.add(n);
          }
        }
        for (var i = 0; i < contained.length && !swallows; i++) {
          for (var j = i + 1; j < contained.length; j++) {
            if (_iou(contained[i].box, contained[j].box) < 0.12) {
              swallows = true;
              break;
            }
          }
        }
      }
      if (!swallows) {
        result.add(d);
        continue;
      }
      final s = d.score * wideBoxPenalty;
      if (s >= detectionThreshold) {
        result.add(
          YoloDetection(
            d.box,
            s,
            d.classIndex,
            rawScore: s,
            dominanceRatio: d.dominanceRatio,
          ),
        );
      }
    }
    return result;
  }

  /// Cross-Class Overlap & IoMin Containment Suppression (Satu Objek Fisik =
  /// Satu Kotak). Kandidat B dihapus oleh A (skor lebih tinggi) bila memenuhi
  /// SALAH SATU kondisi:
  /// 1. `iou(A, B) > 0.40`
  /// 2. `IoMin(A, B) = max(containment(A, B), containment(B, A)) > 0.58`
  /// 3. `centerDistance(A, B) < 0.18`
  ///
  /// Saat [allowSplitSameClass] bernilai true (sebelum [mergeSameClass]),
  /// dua belahan dari kelas yang sama yang memenuhi [_shouldMerge] diizinkan
  /// lolos agar dapat disatukan menjadi 1 kotak utuh.
  static List<YoloDetection> nms(
    List<YoloDetection> input, {
    double iou = iouThreshold,
    bool allowSplitSameClass = true,
  }) {
    final sorted = [...input]..sort((a, b) => b.score.compareTo(a.score));
    final kept = <YoloDetection>[];
    for (final d in sorted) {
      var suppressed = false;
      for (final k in kept) {
        final overlap = _iou(k.box, d.box);
        final inB = _containment(k.box, d.box); // porsi B di dalam A
        final inA = _containment(d.box, k.box); // porsi A di dalam B
        final centerDist = _centerDistance(k.box, d.box);

        if (allowSplitSameClass &&
            k.classIndex == d.classIndex &&
            _shouldMerge(k.box, d.box) &&
            overlap <= iou &&
            inB <= 0.85 &&
            inA <= 0.85) {
          continue;
        }

        if (overlap > iou ||
            inB > containmentThreshold ||
            inA > containmentThreshold ||
            centerDist < sameObjectCenterDist) {
          suppressed = true;
          break;
        }
      }
      if (!suppressed) kept.add(d);
      if (kept.length >= maxDetections * 4) break;
    }
    return kept;
  }

  /// Porsi luas [inner] yang berada di dalam [outer] (0..1).
  static double _containment(Rect outer, Rect inner) {
    final inter = outer.intersect(inner);
    if (inter.width <= 0 || inter.height <= 0) return 0.0;
    final innerArea = inner.width * inner.height;
    return innerArea <= 0 ? 0.0 : (inter.width * inter.height) / innerArea;
  }

  /// Memilih objek ke-2 terbaik dari [pool] yang berada di luar [primary]
  /// (tumpang tindih < 15%, jarak pusat > 0.22, dan kotak ketat <= 0.68),
  /// setelah same-class merging, dengan skor >= [minScore].
  static YoloDetection? pickComplementary(
    Rect primary,
    List<YoloDetection> pool, {
    double minScore = complementMinScore,
  }) {
    final outside = pool.where((c) {
      if (c.box.width > wideBoxWidth) return false;
      if (_containment(primary, c.box) >= complementOverlapMax) return false;
      if (_containment(c.box, primary) >= complementOverlapMax) return false;
      return _centerDistance(primary, c.box) > complementCenterMin;
    }).toList();
    if (outside.isEmpty) return null;
    final merged = nms(
      mergeSameClass(nms(outside)),
      allowSplitSameClass: false,
    );
    if (merged.isEmpty) return null;
    final best = merged.first;
    return best.score >= minScore && best.box.width <= wideBoxWidth
        ? best
        : null;
  }

  /// Zona pelengkap (koordinat gambar utuh 0..1) yang perlu di-crop bila
  /// objek utama hanya menempati sebagian layar atau kotaknya terlalu lebar.
  static List<Rect> complementaryZones(Rect primary, double primaryScore) {
    final cx = (primary.left + primary.right) / 2.0;
    final cy = (primary.top + primary.bottom) / 2.0;
    if (primary.width > 0.65 || primaryScore < 0.26) {
      return const [
        Rect.fromLTRB(0.0, 0.15, 0.55, 0.85), // zona kiri
        Rect.fromLTRB(0.45, 0.15, 1.0, 0.85), // zona kanan
      ];
    }
    if (primary.width < 0.62) {
      return cx < 0.52
          ? const [Rect.fromLTRB(0.42, 0.15, 1.0, 0.85)]
          : const [Rect.fromLTRB(0.0, 0.15, 0.58, 0.85)];
    }
    if (primary.height < 0.62) {
      return cy < 0.52
          ? const [Rect.fromLTRB(0.0, 0.42, 1.0, 1.0)]
          : const [Rect.fromLTRB(0.0, 0.0, 1.0, 0.58)];
    }
    return const [];
  }

  static double _centerDistance(Rect a, Rect b) {
    final dx = (a.left + a.right) / 2.0 - (b.left + b.right) / 2.0;
    final dy = (a.top + a.bottom) / 2.0 - (b.top + b.bottom) / 2.0;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// Menggabungkan kotak berkelas sama yang beririsan (IoU > 0.08) atau yang
  /// bersentuhan secara vertikal maupun horizontal (satu objek yang terbelah).
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
    final dx = ((a.left + a.right) / 2 - (b.left + b.right) / 2).abs();
    final touchVertically =
        b.top <= a.bottom + 0.02 && a.top <= b.bottom + 0.02;
    if (dx < mergeCenterDx && touchVertically) return true;

    // Cegah fragmentasi horizontal bila 1 objek di tengah terbelah kiri-kanan.
    final dy = ((a.top + a.bottom) / 2 - (b.top + b.bottom) / 2).abs();
    final touchHorizontally =
        b.left <= a.right + 0.02 && a.left <= b.right + 0.02;
    final combinedWidth =
        math.max(a.right, b.right) - math.min(a.left, b.left);
    return dy < mergeCenterDy &&
        touchHorizontally &&
        combinedWidth <= wideBoxWidth;
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

  /// Rasio dominasi kelas juara ke-1 terhadap juara ke-2 pada anchor ini.
  final double dominanceRatio;

  const YoloDetection(
    this.box,
    this.score,
    this.classIndex, {
    this.rawScore = 0,
    this.dominanceRatio = 1.0,
  });
}

class _TileInput {
  final Float32List input;
  final int padX;
  final int padY;
  final int newWidth;
  final int newHeight;
  final Rect roi; // proporsi di dalam gambar utuh (0..1)
  final double imageAspectRatio;

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

/// Membaca gambar di Isolate sekali saja, menyamakan rasio ekstrem 16:9 dengan
/// viewfinder 4:3 bila perlu, dan menyusun tensor NCHW Letterbox 640x640.
_TileInput _preprocessMainTile(
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

  // Hanya pangkas sedikit tepi atas/bawah bila rasio sensor sangat memanjang
  // (> 1.45, misal 16:9 = 1.77) agar cocok dengan preview 3:4 di ScanScreen.
  Rect mainRoi = const Rect.fromLTWH(0.0, 0.0, 1.0, 1.0);
  if (origH / origW > 1.45) {
    mainRoi = const Rect.fromLTWH(0.0, 0.06, 1.0, 0.88);
  } else if (origW / origH > 1.45) {
    mainRoi = const Rect.fromLTWH(0.06, 0.0, 0.88, 1.0);
  }
  return _buildTile(oriented, mainRoi, channelsFirst);
}

/// Membangun tile untuk ROI tertentu (zona pelengkap) di isolate.
List<_TileInput> _buildTilesForRois(
  String path,
  List<Rect> rois,
  bool channelsFirst,
) {
  final decoded = img.decodeImage(File(path).readAsBytesSync());
  if (decoded == null) {
    throw StateError('Gambar tidak dapat dibaca: $path');
  }
  final oriented = img.bakeOrientation(decoded);
  return [for (final roi in rois) _buildTile(oriented, roi, channelsFirst)];
}

_TileInput _buildTile(img.Image fullImage, Rect roi, bool channelsFirst) {
  final origW = fullImage.width;
  final origH = fullImage.height;
  final imageAspectRatio = origH > 0 ? origW / origH : 1.0;

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

  // Hitung statistik pencahayaan & keseimbangan putih (Gray-World + Shadow Lift)
  // dalam iterasi linear cepat untuk meredam bayangan gelap & warna meja kayu.
  var sumR = 0.0;
  var sumG = 0.0;
  var sumB = 0.0;
  for (final p in resized) {
    sumR += p.r;
    sumG += p.g;
    sumB += p.b;
  }
  final totalPixels = (newWidth * newHeight).toDouble();
  final meanR = totalPixels > 0 ? sumR / totalPixels : 128.0;
  final meanG = totalPixels > 0 ? sumG / totalPixels : 128.0;
  final meanB = totalPixels > 0 ? sumB / totalPixels : 128.0;
  final meanLum = 0.299 * meanR + 0.587 * meanG + 0.114 * meanB;
  final avgGray = (meanR + meanG + meanB) / 3.0;

  // Lift pencahayaan lembut hanya bila gambar terlalu gelap/berbayang (< 105).
  final lumLift = meanLum < 105.0
      ? (112.0 / math.max(meanLum, 48.0)).clamp(1.0, 1.28)
      : 1.0;

  // Koreksi white balance lembut (50% kekuatan) bila ada bias warna hangat/kayu.
  final rBal = avgGray > 20.0 && meanR > 1.0
      ? (0.5 + 0.5 * (avgGray / meanR)).clamp(0.90, 1.12)
      : 1.0;
  final gBal = avgGray > 20.0 && meanG > 1.0
      ? (0.5 + 0.5 * (avgGray / meanG)).clamp(0.92, 1.10)
      : 1.0;
  final bBal = avgGray > 20.0 && meanB > 1.0
      ? (0.5 + 0.5 * (avgGray / meanB)).clamp(0.90, 1.15)
      : 1.0;

  final rScale = (lumLift * rBal) / 255.0;
  final gScale = (lumLift * gBal) / 255.0;
  final bScale = (lumLift * bBal) / 255.0;

  // Kanvas letterbox 640x640 dengan warna abu-abu standar YOLO RGB(114, 114, 114).
  const padVal = 114.0 / 255.0;
  final data = Float32List(size * size * 3);
  data.fillRange(0, data.length, padVal);

  const plane = size * size;
  var x = 0;
  var y = 0;
  var rowOffset = padY * size + padX;
  for (final p in resized) {
    final r = (p.r * rScale).clamp(0.0, 1.0);
    final g = (p.g * gScale).clamp(0.0, 1.0);
    final b = (p.b * bScale).clamp(0.0, 1.0);
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
    x++;
    if (x >= newWidth) {
      x = 0;
      y++;
      rowOffset = (y + padY) * size + padX;
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
    imageAspectRatio: imageAspectRatio,
  );
}

/// Memotong seluruh bounding box dari gambar asli dalam 1 kali decode di Isolate.
Map<int, String?> _cropBatchAndSave(
  String path,
  List<({int index, Rect box, String outPath})> specs,
) {
  final decoded = img.decodeImage(File(path).readAsBytesSync());
  if (decoded == null) return const {};
  final oriented = img.bakeOrientation(decoded);
  final result = <int, String?>{};
  for (final spec in specs) {
    try {
      final box = spec.box;
      final x = (box.left * oriented.width).floor().clamp(0, oriented.width - 1);
      final y =
          (box.top * oriented.height).floor().clamp(0, oriented.height - 1);
      final w = ((box.right * oriented.width).ceil() - x).clamp(
        1,
        oriented.width - x,
      );
      final h = ((box.bottom * oriented.height).ceil() - y).clamp(
        1,
        oriented.height - y,
      );
      final cropped = img.copyCrop(oriented, x: x, y: y, width: w, height: h);
      File(spec.outPath).writeAsBytesSync(img.encodeJpg(cropped, quality: 85));
      result[spec.index] = spec.outPath;
    } catch (_) {
      result[spec.index] = null;
    }
  }
  return result;
}
