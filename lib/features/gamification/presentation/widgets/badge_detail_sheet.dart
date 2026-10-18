import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../domain/badge.dart';

class BadgeDetailSheet extends StatelessWidget {
  final AppBadge badge;

  const BadgeDetailSheet({super.key, required this.badge});

  static Future<void> show(BuildContext context, AppBadge badge) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BadgeDetailSheet(badge: badge),
    );
  }

  IconData _getIcon(String key) {
    switch (key) {
      case 'eco': return Icons.eco;
      case 'star': return Icons.star;
      case 'local_fire_department': return Icons.local_fire_department;
      case 'water_drop': return Icons.water_drop;
      case 'article': return Icons.article;
      case 'public': return Icons.public;
      case 'compost': return Icons.eco_outlined;
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
    final pct = (badge.progres / badge.target).clamp(0.0, 1.0);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24).copyWith(bottom: 24 + MediaQuery.of(context).padding.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            const Text('Detail Badge', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isOpen ? Colors.green.shade50 : Colors.grey.shade200,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isOpen ? _getIcon(badge.iconKey) : Icons.lock,
                color: isOpen ? Colors.green : Colors.grey,
                size: 64,
              ),
            ),
            const SizedBox(height: 16),
            Text(badge.nama, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(color: isOpen ? Colors.green : Colors.grey.shade400, borderRadius: BorderRadius.circular(16)),
              child: Text(isOpen ? 'Terbuka' : 'Terkunci', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 16),
            Text(badge.deskripsi, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 14)),
            if (isOpen && badge.tanggalDiraih != null) ...[
              const SizedBox(height: 8),
              Text('Diraih ${DateFormat('d MMM yyyy', 'id_ID').format(badge.tanggalDiraih!)}', style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
            const SizedBox(height: 24),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: pct,
                backgroundColor: Colors.grey.shade200,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                minHeight: 12,
              ),
            ),
            const SizedBox(height: 8),
            Text('${badge.progres}/${badge.target} ${badge.satuan}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Text(isOpen ? 'Hadiah badge: +${badge.hadiahPoin} Poin' : '+${badge.hadiahPoin} Poin saat terbuka', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: isOpen
                  ? OutlinedButton(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: 'Aku mendapat badge ${badge.nama} di PilahIn!'));
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Teks disalin')));
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.blue),
                        foregroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                      child: const Text('Bagikan', style: TextStyle(fontWeight: FontWeight.bold)),
                    )
                  : ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context); // Close bottom sheet
                        context.go('/scan');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                      child: const Text('Pindai Sekarang', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
