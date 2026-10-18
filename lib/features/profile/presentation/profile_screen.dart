import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../home/presentation/home_provider.dart';
import '../../history/presentation/history_provider.dart';
import '../../scan/domain/waste_category.dart';

final historyStatsProvider = FutureProvider.autoDispose<Map<WasteCategory, int>>((ref) async {
  final repo = ref.watch(historyRepositoryProvider);
  return repo.countByCategory();
});

class DonutData {
  final int organic;
  final int anorganic;

  DonutData({required this.organic, required this.anorganic});

  int get total => organic + anorganic;
  double get organicRatio => total == 0 ? 0 : organic / total;
  double get anorganicRatio => total == 0 ? 0 : anorganic / total;
}

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _animation = CurvedAnimation(parent: _animationController, curve: Curves.easeOut);
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authControllerProvider);
    final user = authState.value;
    final homeState = ref.watch(homeSummaryProvider);
    final isGuest = user?.isGuest ?? true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        leading: IconButton(
          tooltip: 'Kembali',
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(theme, user, homeState.value),
            if (AppConstants.gamificationEnabled && homeState.value != null)
              _buildStatsRow(homeState.value!),
            _buildDonutCard(theme),
            _buildMenu(isGuest),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, dynamic user, dynamic summary) {
    final name = user?.displayName ?? 'Tamu';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final isGuest = user?.isGuest ?? true;

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.blue.shade100,
            child: isGuest
                ? const Icon(Icons.person, size: 40, color: Colors.blue)
                : Text(initial, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.blue)),
          ),
          const SizedBox(height: 12),
          Text(
            name,
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          if (AppConstants.gamificationEnabled && summary != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Text(
                'Level ${summary.level}: ${summary.levelName}',
                style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsRow(dynamic summary) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
      child: Row(
        children: [
          Expanded(child: _buildStatItem('Poin', summary.points.toString())),
          Container(height: 40, width: 1, color: Colors.grey.shade300),
          Expanded(child: _buildStatItem('Hari Beruntun', summary.streakDays.toString())),
          Container(height: 40, width: 1, color: Colors.grey.shade300),
          Expanded(child: _buildStatItem('Badge', summary.unlockedBadges.toString())),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildDonutCard(ThemeData theme) {
    final statsAsync = ref.watch(historyStatsProvider);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Statistik Pemilahan', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          statsAsync.when(
            data: (stats) {
              final org = stats[WasteCategory.organik] ?? 0;
              final anorg = stats[WasteCategory.anorganik] ?? 0;
              final data = DonutData(organic: org, anorganic: anorg);

              if (data.total == 0) {
                return _buildEmptyDonut();
              }

              return Row(
                children: [
                  Expanded(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: AnimatedBuilder(
                        animation: _animation,
                        builder: (context, child) {
                          return CustomPaint(
                            painter: DonutPainter(
                              organicRatio: data.organicRatio,
                              anorganicRatio: data.anorganicRatio,
                              animationValue: _animation.value,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLegendItem('Organik', org, data.organicRatio, Colors.green),
                        const SizedBox(height: 16),
                        _buildLegendItem('Anorganik', anorg, data.anorganicRatio, Colors.blue),
                      ],
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Column(
              children: [
                const Text('Gagal memuat statistik'),
                TextButton(
                  onPressed: () => ref.refresh(historyStatsProvider),
                  child: const Text('Coba Lagi'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyDonut() {
    return Row(
      children: [
        Expanded(
          child: AspectRatio(
            aspectRatio: 1,
            child: CustomPaint(
              painter: DonutPainter(
                organicRatio: 0,
                anorganicRatio: 0,
                animationValue: 1.0,
              ),
            ),
          ),
        ),
        const SizedBox(width: 24),
        const Expanded(
          child: Text('Belum ada data', style: TextStyle(color: Colors.grey)),
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, int count, double ratio, Color color) {
    final pct = (ratio * 100).toStringAsFixed(1);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 4, right: 8),
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('$count item ($pct%)', style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMenu(bool isGuest) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
          if (AppConstants.gamificationEnabled) ...[
            _buildMenuItem(
              icon: Icons.emoji_events,
              iconColor: Colors.orange,
              label: 'Misi & Lencana',
              onTap: () => context.push('/profile/misi'),
            ),
            const Divider(height: 1, thickness: 1, indent: 56),
          ],
          _buildMenuItem(
            icon: Icons.history,
            iconColor: Colors.blue,
            label: 'Riwayat Pemindaian',
            onTap: () => context.push('/home/riwayat'),
          ),
          const Divider(height: 1, thickness: 1, indent: 56),
          _buildMenuItem(
            icon: Icons.info_outline,
            iconColor: Colors.grey,
            label: 'Tentang Aplikasi',
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Tentang PilahIn', style: TextStyle(fontWeight: FontWeight.bold)),
                  content: const Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Aplikasi klasifikasi sampah Organik dan Anorganik'),
                      SizedBox(height: 12),
                      Text('Proyek PBL Politeknik Negeri Malang', style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 12),
                      Text('Versi 1.0.0', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
                  ],
                ),
              );
            },
          ),
          const Divider(height: 1, thickness: 1),
          _buildMenuItem(
            icon: Icons.logout,
            iconColor: Colors.red,
            label: 'Keluar',
            textColor: Colors.red,
            showArrow: false,
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Keluar dari akun?'),
                  content: Text(isGuest 
                    ? 'Anda akan kembali ke halaman masuk.' 
                    : 'Anda harus masuk kembali untuk melanjutkan misi dan melihat profil Anda.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        ref.read(authControllerProvider.notifier).logout();
                        context.go('/login');
                      },
                      child: const Text('Keluar', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required Color iconColor,
    required String label,
    required VoidCallback onTap,
    Color? textColor,
    bool showArrow = true,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withAlpha(25),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor),
      ),
      title: Text(label, style: TextStyle(fontWeight: FontWeight.w500, color: textColor)),
      trailing: showArrow ? const Icon(Icons.chevron_right, color: Colors.grey) : null,
      onTap: onTap,
    );
  }
}

class DonutPainter extends CustomPainter {
  final double organicRatio;
  final double anorganicRatio;
  final double animationValue;

  DonutPainter({
    required this.organicRatio,
    required this.anorganicRatio,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width / 2, size.height / 2);
    final strokeWidth = radius * 0.4;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt; // Standard donut usually uses butt for crisp edges

    if (organicRatio == 0 && anorganicRatio == 0) {
      paint.color = Colors.grey.shade200;
      canvas.drawCircle(center, radius - strokeWidth / 2, paint);
      return;
    }

    // organic (Green)
    final orgSweep = 2 * pi * organicRatio * animationValue;
    paint.color = Colors.green;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
      -pi / 2,
      orgSweep,
      false,
      paint,
    );

    // anorganic (Blue)
    final anorgSweep = 2 * pi * anorganicRatio * animationValue;
    paint.color = Colors.blue;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
      -pi / 2 + (2 * pi * organicRatio),
      anorgSweep,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant DonutPainter oldDelegate) {
    return oldDelegate.organicRatio != organicRatio ||
           oldDelegate.anorganicRatio != anorganicRatio ||
           oldDelegate.animationValue != animationValue;
  }
}
