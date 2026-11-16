import 'package:flutter/material.dart';

/// Satu sumber pemetaan `iconKey` badge (dari `reference_data.dart`) ke ikon
/// Material, dipakai bersama oleh tile, detail sheet, dan showcase beranda.
IconData badgeIconFor(String key) {
  switch (key) {
    case 'eco':
      return Icons.eco;
    case 'star':
      return Icons.star;
    case 'local_fire_department':
      return Icons.local_fire_department;
    case 'water_drop':
      return Icons.water_drop;
    case 'article':
      return Icons.article;
    case 'public':
      return Icons.public;
    case 'compost':
      return Icons.eco_outlined;
    case 'recycling':
      return Icons.recycling;
    case 'wine_bar':
      return Icons.wine_bar;
    case 'restaurant':
      return Icons.restaurant;
    case 'workspace_premium':
      return Icons.workspace_premium;
    case 'shield':
      return Icons.shield;
    case 'spa':
      return Icons.spa;
    case 'language':
      return Icons.language;
    default:
      return Icons.emoji_events;
  }
}
