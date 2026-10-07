import '../../scan/domain/waste_category.dart';

class HistoryEntry {
  final int? id;
  final String scanKey;
  final WasteCategory category;
  final double confidence;
  final bool isUncertain;
  final String? itemName;
  final int pointsEarned;
  final String? imagePath;
  final DateTime createdAt;

  HistoryEntry({
    this.id,
    required this.scanKey,
    required this.category,
    required this.confidence,
    required this.isUncertain,
    this.itemName,
    required this.pointsEarned,
    this.imagePath,
    required this.createdAt,
  });

  HistoryEntry copyWith({
    int? id,
    String? scanKey,
    WasteCategory? category,
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
      category: category ?? this.category,
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
      'confidence': confidence,
      'is_uncertain': isUncertain ? 1 : 0,
      'item_name': itemName,
      'points_earned': pointsEarned,
      'image_path': imagePath,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory HistoryEntry.fromMap(Map<String, dynamic> map) {
    return HistoryEntry(
      id: map['id'] as int?,
      scanKey: map['scan_key'] as String,
      category: map['category'] == 'organik' ? WasteCategory.organik : WasteCategory.anorganik,
      confidence: map['confidence'] as double,
      isUncertain: (map['is_uncertain'] as int) == 1,
      itemName: map['item_name'] as String?,
      pointsEarned: map['points_earned'] as int,
      imagePath: map['image_path'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }
}
