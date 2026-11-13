import 'dart:ui' show Rect;

import '../../../core/waste/waste_types.dart';
import 'waste_category.dart';

class ClassificationResult {
  final WasteType wasteType;
  final double confidence; // 0.0 - 1.0 (keyakinan untuk wasteType)
  final String imagePath;
  final bool isUncertain;
  final DateTime timestamp;

  /// Bounding box ternormalisasi (0.0 - 1.0). Null bila model tidak
  /// memberikan lokasi objek (mis. MockWasteClassifier).
  final Rect? boundingBox;

  /// Path potongan gambar objek (opsional).
  final String? croppedImagePath;

  /// Rasio aspek gambar asli (`width / height`) setelah koreksi rotasi EXIF.
  final double? imageAspectRatio;

  final List<ClassificationResult>? _detections;

  /// Seluruh objek yang terdeteksi pada foto, diurutkan dari confidence
  /// tertinggi. Untuk hasil tunggal (tanpa multi-object) berisi [this].
  /// Hasil utama (objek pertama) selalu sama dengan objek ber-confidence
  /// tertinggi, sehingga kode lama yang hanya memakai satu hasil tetap valid.
  List<ClassificationResult> get detections => _detections ?? [this];

  /// Kategori SELALU diturunkan dari jenis sampah
  WasteCategory get category => wasteType.category;

  /// Status bahaya diturunkan dari jenis sampah
  bool get isHazardous => wasteType.isHazardous;

  ClassificationResult({
    required this.wasteType,
    required this.confidence,
    required this.imagePath,
    required this.isUncertain,
    required this.timestamp,
    this.boundingBox,
    this.croppedImagePath,
    this.imageAspectRatio,
    List<ClassificationResult>? detections,
  }) : _detections = detections; // ignore: prefer_initializing_formals

  /// Salinan dengan daftar [detections] diganti.
  ClassificationResult withDetections(List<ClassificationResult> detections) {
    return ClassificationResult(
      wasteType: wasteType,
      confidence: confidence,
      imagePath: imagePath,
      isUncertain: isUncertain,
      timestamp: timestamp,
      boundingBox: boundingBox,
      croppedImagePath: croppedImagePath,
      imageAspectRatio: imageAspectRatio,
      detections: detections,
    );
  }
}
