import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../home/presentation/home_provider.dart';
import '../../history/presentation/history_provider.dart';
import '../../scan/domain/waste_category.dart';

final historyStatsProvider =
    FutureProvider.autoDispose<Map<WasteCategory, int>>((ref) async {
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

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
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
      backgroundColor: const Color(0xFFF3F7F5),
      appBar: AppBar(
        title: const Text(
          'Profil',
          style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF064E3B),
        elevation: 0,
        foregroundColor: Colors.white,
        leading: (ModalRoute.of(context)?.canPop == true)
            ? IconButton(
                tooltip: 'Kembali',
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  } else {
                    try {
                      context.go('/home');
                    } catch (_) {}
                  }
                },
              )
            : null,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(theme, user, homeState.value),
            const SizedBox(height: 22),

            if (AppConstants.gamificationEnabled &&
                homeState.value != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionLabel('PENCAPAIANMU'),
                    const SizedBox(height: 9),
                    _buildStatsRow(homeState.value!),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionLabel('AKTIVITAS PEMILAHAN'),
                  const SizedBox(height: 9),
                  _buildDonutCard(theme),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionLabel('LAINNYA'),
                  const SizedBox(height: 9),
                  _buildMenu(isGuest),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        color: const Color(0xFF047857).withValues(alpha: 0.8),
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.1,
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, dynamic user, dynamic summary) {
    final name = user?.displayName ?? 'Tamu';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final isGuest = user?.isGuest ?? true;
    final email = user?.email ?? (isGuest ? 'Mode Tamu • Akses offline' : '');

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF064E3B), // Deep emerald
            Color(0xFF065F46), // Forest green
            Color(0xFF0F766E), // Teal
          ],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF064E3B),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Lingkaran dekoratif latar belakang
          Positioned(
            right: -25,
            top: -15,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            left: -30,
            bottom: -20,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            child: Column(
              children: [
                // Avatar Modern
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFBBF24), Color(0xFF34D399)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 38,
                    backgroundColor: Colors.white,
                    child: isGuest
                        ? const Icon(
                            Icons.person,
                            size: 40,
                            color: Color(0xFF059669),
                          )
                        : Text(
                            initial,
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF065F46),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 12),

                // Nama Pengguna
                Text(
                  name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),

                const SizedBox(height: 5),
                Text(
                  isGuest
                      ? 'Simpan aktivitasmu dengan masuk ke akun'
                      : 'Terima kasih sudah memilah hari ini',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                ),

                if (email.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    email,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Colors.white.withValues(alpha: 0.82),
                    ),
                  ),
                ],

                // Badge Level
                if (AppConstants.gamificationEnabled && summary != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.shield_rounded,
                          size: 14,
                          color: Color(0xFFFBBF24),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Level ${summary.level}: ${summary.levelName}',
                          style: const TextStyle(
                            color: Color(0xFFECFDF5),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(dynamic summary) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDCEBE4), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(
              icon: Icons.stars_rounded,
              iconColor: const Color(0xFFF59E0B),
              iconBgColor: const Color(0xFFFEF3C7),
              label: 'Poin',
              value: summary.points.toString(),
            ),
          ),
          Container(height: 36, width: 1, color: Colors.grey.shade200),
          Expanded(
            child: _buildStatItem(
              icon: Icons.local_fire_department_rounded,
              iconColor: const Color(0xFFEA580C),
              iconBgColor: const Color(0xFFFFEDD5),
              label: 'Hari Beruntun',
              value: summary.streakDays.toString(),
            ),
          ),
          Container(height: 36, width: 1, color: Colors.grey.shade200),
          Expanded(
            child: _buildStatItem(
              icon: Icons.workspace_premium_rounded,
              iconColor: const Color(0xFF059669),
              iconBgColor: const Color(0xFFD1FAE5),
              label: 'Badge',
              value: summary.unlockedBadges.toString(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String label,
    required String value,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: iconBgColor, shape: BoxShape.circle),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildDonutCard(ThemeData theme) {
    final statsAsync = ref.watch(historyStatsProvider);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFDCEBE4), width: 1),
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
                  color: const Color(0xFF059669).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.pie_chart_rounded,
                  size: 18,
                  color: Color(0xFF059669),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Statistik Pemilahan',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'Perbandingan sampah terdeteksi',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
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
                  // Donut Chart dengan Total di Tengah
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        AnimatedBuilder(
                          animation: _animation,
                          builder: (context, child) {
                            return CustomPaint(
                              size: const Size(120, 120),
                              painter: DonutPainter(
                                organicRatio: data.organicRatio,
                                anorganicRatio: data.anorganicRatio,
                                animationValue: _animation.value,
                              ),
                            );
                          },
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${data.total}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              'Total Item',
                              style: TextStyle(
                                fontSize: 9.5,
                                color: Colors.grey.shade500,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 18),

                  // Keterangan Legend yang Rapi
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLegendItem(
                          'Organik',
                          org,
                          data.organicRatio,
                          const Color(0xFF10B981),
                          const Color(0xFFECFDF5),
                        ),
                        const SizedBox(height: 10),
                        _buildLegendItem(
                          'Anorganik',
                          anorg,
                          data.anorganicRatio,
                          const Color(0xFF0284C7),
                          const Color(0xFFF0F9FF),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: CircularProgressIndicator(),
              ),
            ),
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            height: 90,
            child: CustomPaint(
              painter: DonutPainter(
                organicRatio: 0,
                anorganicRatio: 0,
                animationValue: 1.0,
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Belum ada data',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Mulai pindai sampah untuk melihat statistik pemilahanmu.',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(
    String label,
    int count,
    double ratio,
    Color color,
    Color bgColor,
  ) {
    final pct = (ratio * 100).toStringAsFixed(1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: color.withValues(alpha: 0.9),
                  ),
                ),
                Text(
                  '$count item ($pct%)',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenu(bool isGuest) {
    return Container(
      decoration: BoxDecoration(
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
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            if (AppConstants.gamificationEnabled) ...[
              _buildMenuItem(
                icon: Icons.emoji_events_rounded,
                iconColor: const Color(0xFFF59E0B),
                iconBgColor: const Color(0xFFFEF3C7),
                label: 'Misi & Lencana',
                subtitle: 'Misi harian & koleksi lencana',
                onTap: () {
                  try {
                    context.push('/profile/misi');
                  } catch (_) {}
                },
              ),
              Divider(
                height: 1,
                thickness: 1,
                color: Colors.grey.shade100,
                indent: 64,
              ),
            ],
            _buildMenuItem(
              icon: Icons.history_rounded,
              iconColor: const Color(0xFF0284C7),
              iconBgColor: const Color(0xFFE0F2FE),
              label: 'Riwayat Pemindaian',
              subtitle: 'Daftar riwayat sampah yang dipilah',
              onTap: () {
                try {
                  context.push('/home/riwayat');
                } catch (_) {}
              },
            ),
            Divider(
              height: 1,
              thickness: 1,
              color: Colors.grey.shade100,
              indent: 64,
            ),
            _buildMenuItem(
              icon: Icons.info_outline_rounded,
              iconColor: const Color(0xFF059669),
              iconBgColor: const Color(0xFFD1FAE5),
              label: 'Tentang Aplikasi',
              subtitle: 'Informasi versi & pengembang PBL',
              onTap: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    title: Row(
                      children: const [
                        Icon(Icons.eco, color: Color(0xFF059669)),
                        SizedBox(width: 8),
                        Text(
                          'Tentang PilahIn',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                    content: const Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Aplikasi klasifikasi sampah Organik dan Anorganik berbasis AI.',
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Proyek PBL Politeknik Negeri Malang',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Versi 1.0.0',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text(
                          'Tutup',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF059669),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            Divider(height: 1, thickness: 1, color: Colors.grey.shade100),
            _buildMenuItem(
              icon: Icons.logout_rounded,
              iconColor: const Color(0xFFEF4444),
              iconBgColor: const Color(0xFFFEE2E2),
              label: 'Keluar',
              subtitle: 'Keluar dari sesi akun saat ini',
              textColor: const Color(0xFFDC2626),
              showArrow: false,
              onTap: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    title: const Text(
                      'Keluar dari akun?',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    content: Text(
                      isGuest ? 'Anda akan kembali ke halaman masuk.' : 'Anda harus masuk kembali untuk melanjutkan misi dan melihat profil Anda.',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(
                          'Batal',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          ref.read(authControllerProvider.notifier).logout();
                          try {
                            context.go('/login');
                          } catch (_) {}
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Keluar',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
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
    required Color iconBgColor,
    required String label,
    String? subtitle,
    required VoidCallback onTap,
    Color? textColor,
    bool showArrow = true,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: iconBgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: textColor ?? const Color(0xFF0F172A),
          fontSize: 14.5,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 11.5),
            )
          : null,
      trailing: showArrow
          ? Icon(
              Icons.chevron_right_rounded,
              color: Colors.grey.shade400,
              size: 22,
            )
          : null,
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
    final strokeWidth = radius * 0.32;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    if (organicRatio == 0 && anorganicRatio == 0) {
      paint.color = Colors.grey.shade200;
      paint.strokeCap = StrokeCap.butt;
      canvas.drawCircle(center, radius - strokeWidth / 2, paint);
      return;
    }

    // Background track ring
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = const Color(0xFFF1F5F9);
    canvas.drawCircle(center, radius - strokeWidth / 2, trackPaint);

    // organic (Vibrant Emerald)
    if (organicRatio > 0) {
      final orgSweep = 2 * pi * organicRatio * animationValue;
      paint.color = const Color(0xFF10B981);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        -pi / 2,
        orgSweep,
        false,
        paint,
      );
    }

    // anorganic (Sky Blue / Teal)
    if (anorganicRatio > 0) {
      final anorgSweep = 2 * pi * anorganicRatio * animationValue;
      paint.color = const Color(0xFF0284C7);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        -pi / 2 + (2 * pi * organicRatio),
        anorgSweep,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant DonutPainter oldDelegate) {
    return oldDelegate.organicRatio != organicRatio ||
        oldDelegate.anorganicRatio != anorganicRatio ||
        oldDelegate.animationValue != animationValue;
  }
}
