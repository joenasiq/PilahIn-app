import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/mission.dart';
import '../gamification_provider.dart';
import '../mission_provider.dart';
import 'badge_detail_sheet.dart';
import 'badge_tile.dart';
import 'mission_card_widget.dart';

class MissionTab extends ConsumerWidget {
  const MissionTab({super.key});

  Future<void> _claim(
    BuildContext context,
    WidgetRef ref,
    Mission mission,
  ) async {
    final result = await claimMission(ref, mission: mission);
    if (!context.mounted) return;

    final message = result.success
        ? 'Hadiah misi diklaim: +${result.points} poin'
        : (result.alreadyClaimed
              ? 'Hadiah misi ini sudah diklaim'
              : 'Misi belum selesai');

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  Widget _buildMissionSection(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required AsyncValue<List<Mission>> missionsAsync,
    required VoidCallback onRetry,
    bool showStartButton = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        const SizedBox(height: 16),
        missionsAsync.when(
          data: (missions) {
            if (missions.isEmpty) {
              return const Text('Tidak ada misi aktif.');
            }
            return Column(
              children: missions
                  .map(
                    (mission) => MissionCardWidget(
                      mission: mission,
                      onClaim: mission.isClaimable
                          ? () => _claim(context, ref, mission)
                          : null,
                      onStart: showStartButton
                          ? () => context.go('/scan')
                          : null,
                    ),
                  )
                  .toList(),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Column(
            children: [
              const Text('Gagal memuat misi'),
              TextButton(onPressed: onRetry, child: const Text('Coba Lagi')),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dailyAsync = ref.watch(dailyMissionsProvider);
    final weeklyAsync = ref.watch(weeklyMissionsProvider);
    final badgesAsync = ref.watch(badgesProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMissionSection(
            context,
            ref,
            title: 'Misi Harian',
            missionsAsync: dailyAsync,
            onRetry: () => ref.invalidate(dailyMissionsProvider),
            showStartButton: true,
          ),
          const SizedBox(height: 32),
          _buildMissionSection(
            context,
            ref,
            title: 'Misi Mingguan',
            missionsAsync: weeklyAsync,
            onRetry: () => ref.invalidate(weeklyMissionsProvider),
          ),
          const SizedBox(height: 32),
          const Text(
            'Lencana Terbaru Anda',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 16),
          badgesAsync.when(
            data: (badges) {
              final unlocked = badges.where((b) => b.isOpen).toList();
              final locked = badges.where((b) => !b.isOpen).toList();

              final latestUnlocked = unlocked.isNotEmpty ? unlocked.last : null;
              final nearestLocked = locked.isNotEmpty ? locked.first : null;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (latestUnlocked != null)
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () =>
                            BadgeDetailSheet.show(context, latestUnlocked),
                        child: BadgeTile(badge: latestUnlocked),
                      ),
                    ),
                  if (latestUnlocked != null && nearestLocked != null)
                    const SizedBox(width: 16),
                  if (nearestLocked != null)
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () =>
                            BadgeDetailSheet.show(context, nearestLocked),
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
                  onPressed: () => ref.invalidate(badgesProvider),
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
