import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gamification_provider.dart';
import 'mission_card_widget.dart';
import 'badge_tile.dart';
import 'badge_detail_sheet.dart';

class MissionTab extends ConsumerWidget {
  const MissionTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final missionsAsync = ref.watch(activeMissionsProvider);
    final badgesAsync = ref.watch(badgesProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Misi Mingguan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 16),
          missionsAsync.when(
            data: (missions) {
              if (missions.isEmpty) return const Text('Tidak ada misi aktif.');
              return Column(
                children: missions.map((m) => MissionCardWidget(mission: m)).toList(),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Column(
              children: [
                const Text('Gagal memuat misi'),
                TextButton(
                  onPressed: () => ref.refresh(activeMissionsProvider),
                  child: const Text('Coba Lagi'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          const Text('Lencana Terbaru Anda', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 16),
          badgesAsync.when(
            data: (badges) {
              final unlocked = badges.where((b) => b.isOpen).toList();
              final locked = badges.where((b) => !b.isOpen).toList();

              // Sort by some criteria if needed, here we just pick first
              final latestUnlocked = unlocked.isNotEmpty ? unlocked.last : null;
              final nearestLocked = locked.isNotEmpty ? locked.first : null;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (latestUnlocked != null)
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => BadgeDetailSheet.show(context, latestUnlocked),
                        child: BadgeTile(badge: latestUnlocked),
                      ),
                    ),
                  if (latestUnlocked != null && nearestLocked != null)
                    const SizedBox(width: 16),
                  if (nearestLocked != null)
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => BadgeDetailSheet.show(context, nearestLocked),
                        child: BadgeTile(badge: nearestLocked),
                      ),
                    ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Column(
              children: [
                const Text('Gagal memuat lencana'),
                TextButton(
                  onPressed: () => ref.refresh(badgesProvider),
                  child: const Text('Coba Lagi'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
