import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LevelCard(summary: summary),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: QuickActionButton(
                        icon: Icons.crop_free,
                        iconBackgroundColor: Colors.blue,
                        label: 'Pindai Sekarang',
                        onTap: () {
                          context.go('/scan');
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: QuickActionButton(
                        icon: Icons.menu_book,
                        iconBackgroundColor: Colors.green,
                        label: 'Riwayat',
                        onTap: () {
                          context.go('/home/riwayat');
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                StreakCard(streakDays: summary.streakDays),
                const SizedBox(height: 24),
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
