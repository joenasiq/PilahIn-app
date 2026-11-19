import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../gamification/domain/badge.dart';
import '../../../gamification/presentation/badge_colors.dart';
import '../../../gamification/presentation/badge_icons.dart';
import '../../../gamification/presentation/gamification_provider.dart';
import '../../../gamification/presentation/widgets/badge_detail_sheet.dart';

/// Menampilkan badge yang sudah didapat di Beranda dalam satu baris
/// horizontal yang bisa digeser. Badge yang belum terbuka tidak ditampilkan.
class BadgeShowcase extends ConsumerWidget {
  const BadgeShowcase({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badgesAsync = ref.watch(badgesProvider);

    return badgesAsync.maybeWhen(
      data: (badges) {
        final unlocked = badges.where((b) => b.isOpen).toList()
          ..sort((a, b) {
            final da = a.tanggalDiraih;
            final db = b.tanggalDiraih;
            if (da == null && db == null) return 0;
            if (da == null) return 1;
            if (db == null) return -1;
            return db.compareTo(da);
          });

        return _Card(
          unlocked: unlocked,
          total: badges.length,
        );
      },
      // Saat memuat/gagal, jangan ganggu tata letak Beranda.
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.unlocked, required this.total});

  final List<AppBadge> unlocked;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFDCEBE4)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  size: 18,
                  color: Color(0xFFF59E0B),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lencana Saya',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                        fontSize: 15.5,
                      ),
                    ),
                    Text(
                      '${unlocked.length} dari $total badge terbuka',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => context.go('/profile/misi'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Lihat Semua',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF059669),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (unlocked.isEmpty)
            _buildEmptyState(context)
          else
            SizedBox(
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: unlocked.length,
                separatorBuilder: (_, _) => const SizedBox(width: 14),
                itemBuilder: (context, index) {
                  return _BadgeBubble(badge: unlocked[index]);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.lock_rounded, size: 20, color: Colors.grey.shade400),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Belum ada lencana. Pindai sampah untuk membuka lencana pertamamu.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: () => context.go('/scan'),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: const Size(0, 32),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text(
            'Mulai Pindai',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF059669),
            ),
          ),
        ),
      ],
    );
  }
}

class _BadgeBubble extends StatelessWidget {
  const _BadgeBubble({required this.badge});

  final AppBadge badge;

  @override
  Widget build(BuildContext context) {
    final colors = badgeColorFor(badge.id);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => BadgeDetailSheet.show(context, badge),
      child: SizedBox(
        width: 68,
        child: Column(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [colors.start, colors.end],
                ),
                border: Border.all(color: const Color(0xFFFCD34D), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: colors.end.withValues(alpha: 0.28),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                badgeIconFor(badge.iconKey),
                color: Colors.white,
                size: 26,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              badge.nama,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10.5,
                height: 1.2,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
