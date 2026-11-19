import 'package:flutter/material.dart';
import '../../domain/badge.dart';
import '../badge_colors.dart';
import '../badge_icons.dart';

class BadgeTile extends StatelessWidget {
  final AppBadge badge;

  const BadgeTile({super.key, required this.badge});

  @override
  Widget build(BuildContext context) {
    final isOpen = badge.isOpen;
    final colors = badgeColorFor(badge.id);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isOpen ? colors.start.withValues(alpha: 0.08) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOpen
              ? colors.start.withValues(alpha: 0.25)
              : Colors.transparent,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: isOpen
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [colors.start, colors.end],
                    )
                  : null,
              color: isOpen ? null : Colors.grey.shade300,
            ),
            child: Icon(
              isOpen ? badgeIconFor(badge.iconKey) : Icons.lock,
              color: isOpen ? Colors.white : Colors.grey,
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
              color: isOpen ? colors.end : Colors.grey.shade400,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              isOpen ? 'Terbuka' : 'Terkunci',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
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
