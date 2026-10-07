import 'package:flutter/material.dart';
import '../../domain/badge.dart';

class BadgeTile extends StatelessWidget {
  final AppBadge badge;

  const BadgeTile({super.key, required this.badge});

  IconData _getIcon(String key) {
    switch (key) {
      case 'eco': return Icons.eco;
      case 'star': return Icons.star;
      case 'local_fire_department': return Icons.local_fire_department;
      case 'water_drop': return Icons.water_drop;
      case 'article': return Icons.article;
      case 'public': return Icons.public;
      case 'compost': return Icons.eco_outlined; // approximate
      case 'recycling': return Icons.recycling;
      case 'wine_bar': return Icons.wine_bar;
      case 'restaurant': return Icons.restaurant;
      case 'workspace_premium': return Icons.workspace_premium;
      case 'shield': return Icons.shield;
      case 'spa': return Icons.spa;
      case 'language': return Icons.language;
      default: return Icons.emoji_events;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOpen = badge.isOpen;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isOpen ? Colors.green.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isOpen ? Colors.green.shade200 : Colors.transparent),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isOpen ? Colors.white : Colors.grey.shade300,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isOpen ? _getIcon(badge.iconKey) : Icons.lock,
              color: isOpen ? Colors.green : Colors.grey,
              size: 32,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            badge.nama,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isOpen ? Colors.black87 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isOpen ? Colors.green : Colors.grey.shade400,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              isOpen ? 'Terbuka' : 'Terkunci',
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isOpen ? badge.deskripsi : 'Pilah ${badge.target} ${badge.satuan}',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: isOpen ? Colors.black54 : Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}
