import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';

import 'home_provider.dart';
import 'widgets/level_card.dart';
import 'widgets/mission_card.dart';
import 'widgets/quick_action_button.dart';
import 'widgets/streak_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final homeState = ref.watch(homeSummaryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Beranda'),
        centerTitle: false,
      ),
      body: homeState.when(
        data: (summary) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (AppConstants.gamificationEnabled) ...[
                  LevelCard(summary: summary),
                  const SizedBox(height: 20),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: QuickActionButton(
                        icon: Icons.crop_free,
                        iconBackgroundColor: const Color(0xFF059669),
                        label: 'Pindai Sekarang',
                        onTap: () {
                          context.go('/scan');
                        },
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: QuickActionButton(
                        icon: Icons.menu_book,
                        iconBackgroundColor: const Color(0xFF0284C7),
                        label: 'Riwayat',
                        onTap: () {
                          context.go('/home/riwayat');
                        },
                      ),
                    ),
                  ],
                ),
                if (AppConstants.gamificationEnabled) ...[
                  const SizedBox(height: 20),
                  StreakCard(streakDays: summary.streakDays),
                  const SizedBox(height: 22),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Misi Hari Ini',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          context.go('/profile/misi');
                        },
                        child: const Text('Lihat Semua'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (summary.dailyMissions.isNotEmpty)
                    MissionCard(mission: summary.dailyMissions.first)
                  else
                    const Text('Tidak ada misi hari ini.'),
                ],
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Terjadi kesalahan: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(homeSummaryProvider),
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
