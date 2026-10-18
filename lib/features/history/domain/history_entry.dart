import '../../../core/waste/waste_types.dart';
import '../../scan/domain/waste_category.dart';

class HistoryEntry {
  final int? id;
  final String scanKey;
  final WasteCategory? _storedCategory;
  final WasteType? wasteType;
  final double confidence;
  final bool isUncertain;
  final String? itemName;
  final int pointsEarned;
  final String? imagePath;
  final DateTime createdAt;

  /// Kategori diturunkan dari jenis; jika jenis null, pakai kolom kategori yang sudah tersimpan.
  WasteCategory get category => wasteType?.category ?? _storedCategory ?? WasteCategory.anorganik;

  /// Status bahaya diturunkan dari jenis sampah
  bool get isHazardous => wasteType?.isHazardous ?? false;

  HistoryEntry({
    this.id,
    required this.scanKey,
    WasteCategory? category,
    this.wasteType,
    required this.confidence,
    required this.isUncertain,
    this.itemName,
    required this.pointsEarned,
    this.imagePath,
    required this.createdAt,
  }) : _storedCategory = category ?? wasteType?.category;

  HistoryEntry copyWith({
    int? id,
    String? scanKey,
    WasteCategory? category,
    WasteType? wasteType,
    double? confidence,
    bool? isUncertain,
    String? itemName,
    int? pointsEarned,
    String? imagePath,
    DateTime? createdAt,
  }) {
    return HistoryEntry(
      id: id ?? this.id,
      scanKey: scanKey ?? this.scanKey,
      category: category ?? _storedCategory,
      wasteType: wasteType ?? this.wasteType,
      confidence: confidence ?? this.confidence,
      isUncertain: isUncertain ?? this.isUncertain,
      itemName: itemName ?? this.itemName,
      pointsEarned: pointsEarned ?? this.pointsEarned,
      imagePath: imagePath ?? this.imagePath,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'scan_key': scanKey,
      'category': category == WasteCategory.organik ? 'organik' : 'anorganik',
      'waste_type': wasteType?.labelKey,
      'confidence': confidence,
      'is_uncertain': isUncertain ? 1 : 0,
      'item_name': itemName,
      'points_earned': pointsEarned,
      'image_path': imagePath,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory HistoryEntry.fromMap(Map<String, dynamic> map) {
    final wasteTypeStr = map['waste_type'] as String?;
    final wasteType = wasteTypeStr != null ? WasteType.fromLabelKey(wasteTypeStr) : null;
    final categoryStr = map['category'] as String?;
    final storedCategory = categoryStr == 'organik' ? WasteCategory.organik : WasteCategory.anorganik;

    return HistoryEntry(
      id: map['id'] as int?,
      scanKey: map['scan_key'] as String,
      category: storedCategory,
      wasteType: wasteType,
      confidence: (map['confidence'] as num).toDouble(),
      isUncertain: (map['is_uncertain'] as int) == 1,
      itemName: map['item_name'] as String?,
      pointsEarned: map['points_earned'] as int,
      imagePath: map['image_path'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }
}
