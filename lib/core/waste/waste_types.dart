import 'package:flutter/material.dart';
import '../../features/scan/domain/waste_category.dart';

// Pemetaan SEMENTARA; keputusan akhir ada pada tim ML dan PM.
enum WasteType {
  battery(
    labelKey: 'battery',
    displayName: 'Baterai',
    category: WasteCategory.anorganik,
    isHazardous: true,
    icon: Icons.battery_alert,
  ),
  biological(
    labelKey: 'biological',
    displayName: 'Biologis',
    category: WasteCategory.organik,
    isHazardous: false,
    icon: Icons.eco,
  ),
  brownGlass(
    labelKey: 'brown-glass',
    displayName: 'Kaca Cokelat',
    category: WasteCategory.anorganik,
    isHazardous: false,
    icon: Icons.wine_bar,
  ),
  cardboard(
    labelKey: 'cardboard',
    displayName: 'Kardus',
    category: WasteCategory.anorganik,
    isHazardous: false,
    icon: Icons.inventory_2,
  ),
  clothes(
    labelKey: 'clothes',
    displayName: 'Pakaian',
    category: WasteCategory.anorganik,
    isHazardous: false,
    icon: Icons.checkroom,
  ),
  greenGlass(
    labelKey: 'green-glass',
    displayName: 'Kaca Hijau',
    category: WasteCategory.anorganik,
    isHazardous: false,
    icon: Icons.wine_bar,
  ),
  metal(
    labelKey: 'metal',
    displayName: 'Logam',
    category: WasteCategory.anorganik,
    isHazardous: false,
    icon: Icons.hardware,
  ),
  paper(
    labelKey: 'paper',
    displayName: 'Kertas',
    category: WasteCategory.anorganik,
    isHazardous: false,
    icon: Icons.description,
  ),
  plastic(
    labelKey: 'plastic',
    displayName: 'Plastik',
    category: WasteCategory.anorganik,
    isHazardous: false,
    icon: Icons.local_drink,
  ),
  shoes(
    labelKey: 'shoes',
    displayName: 'Sepatu',
    category: WasteCategory.anorganik,
    isHazardous: false,
    icon: Icons.hiking,
  ),
  trash(
    labelKey: 'trash',
    displayName: 'Residu',
    category: WasteCategory.anorganik,
    isHazardous: false,
    icon: Icons.delete_outline,
  ),
  whiteGlass(
    labelKey: 'white-glass',
    displayName: 'Kaca Bening',
    category: WasteCategory.anorganik,
    isHazardous: false,
    icon: Icons.wine_bar,
  );

  final String labelKey;
  final String displayName;
  final WasteCategory category;
  final bool isHazardous;
  final IconData icon;

  const WasteType({
    required this.labelKey,
    required this.displayName,
    required this.category,
    required this.isHazardous,
    required this.icon,
  });

  /// Mencari jenis sampah berdasarkan [labelKey] dataset.
  static WasteType? fromLabelKey(String key) {
    for (final type in WasteType.values) {
      if (type.labelKey.toLowerCase() == key.toLowerCase()) {
        return type;
      }
    }
    return null;
  }
}

/// Fungsi pembantu untuk mencari jenis sampah berdasarkan labelKey.
WasteType? findWasteTypeByLabelKey(String key) => WasteType.fromLabelKey(key);
