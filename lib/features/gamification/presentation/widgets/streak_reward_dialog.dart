import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Popup perayaan ketika streak scan bertambah.
///
/// Menampilkan api yang berkobar dengan animasi satu kali (3 detik) lalu
/// berhenti — animasi berulang tanpa henti akan membuat `pumpAndSettle`
/// pada widget test menggantung dan menguras baterai.
class StreakRewardDialog extends StatefulWidget {
  final int streakDays;

  const StreakRewardDialog({super.key, required this.streakDays});

  static Future<void> show(BuildContext context, {required int streakDays}) {
    HapticFeedback.mediumImpact();
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Streak Reward',
      barrierColor: Colors.black.withValues(alpha: 0.68),
      transitionDuration: const Duration(milliseconds: 420),
      pageBuilder: (context, anim1, anim2) =>
          StreakRewardDialog(streakDays: streakDays),
      transitionBuilder: (context, anim1, anim2, child) {
        final curved = CurvedAnimation(
          parent: anim1,
          curve: Curves.easeOutBack,
        );
        return ScaleTransition(
          scale: curved,
          child: FadeTransition(opacity: anim1, child: child),
        );
      },
    );
  }

  @override
  State<StreakRewardDialog> createState() => _StreakRewardDialogState();
}

class _StreakRewardDialogState extends State<StreakRewardDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 26),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 26,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: const Color(0xFFF97316).withValues(alpha: 0.28),
                blurRadius: 44,
                spreadRadius: 6,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 172,
                width: 172,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) => CustomPaint(
                    size: const Size(172, 172),
                    painter: FlameBurstPainter(progress: _controller.value),
                  ),
                ),
              ),
              Transform.translate(
                offset: const Offset(0, -14),
                child: Column(
                  children: [
                    const Text(
                      'Streak Bertambah!',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF7C2D12),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFF7ED), Color(0xFFFFEDD5)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFFDBA74)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.local_fire_department_rounded,
                            color: Color(0xFFF97316),
                            size: 30,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${widget.streakDays} Hari Beruntun',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFC2410C),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Api semangatmu makin panas. Jangan putus '
                      'rantainya besok!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.35,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF97316),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Lanjutkan',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Api bergoyang + ember yang naik, digambar murni dengan [Canvas].
class FlameBurstPainter extends CustomPainter {
  FlameBurstPainter({required this.progress});

  /// 0 -> 1 selama dialog tampil.
  final double progress;

  static const int _emberCount = 10;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.62);
    final rect = Rect.fromCircle(center: center, radius: size.width / 2);

    // Glow hangat di belakang api.
    canvas.drawCircle(
      center,
      size.width / 2,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0x33F97316), Color(0x00F97316)],
        ).createShader(rect),
    );

    // Wobble: api "bernafas" tiga kali selama animasi.
    final wobble = math.sin(progress * math.pi * 6);
    final grow = Curves.easeOutCubic.transform(
      (progress / 0.35).clamp(0.0, 1.0),
    );

    _drawFlame(
      canvas,
      size,
      wobble: wobble,
      scale: 0.98 * grow,
      colors: const [Color(0xFFF87171), Color(0xFFEA580C)],
      opacity: 0.45,
    );
    _drawFlame(
      canvas,
      size,
      wobble: wobble * 0.8,
      scale: 0.74 * grow,
      colors: const [Color(0xFFFDBA74), Color(0xFFF97316)],
      opacity: 0.9,
    );
    _drawFlame(
      canvas,
      size,
      wobble: wobble * 0.55,
      scale: 0.46 * grow,
      colors: const [Color(0xFFFEF3C7), Color(0xFFFBBF24)],
      opacity: 1,
    );

    _drawEmbers(canvas, size);
  }

  void _drawFlame(
    Canvas canvas,
    Size size, {
    required double wobble,
    required double scale,
    required List<Color> colors,
    required double opacity,
  }) {
    final w = size.width * scale;
    final h = size.height * 0.86 * scale;
    final cx = size.width / 2;
    final bottom = size.height * 0.9;
    final top = bottom - h;
    final lean = wobble * w * 0.08;

    final path = Path()
      ..moveTo(cx, bottom)
      ..cubicTo(
        cx - w * 0.52,
        bottom - h * 0.24,
        cx - w * 0.46,
        bottom - h * 0.6,
        cx + lean,
        top,
      )
      ..cubicTo(
        cx + w * 0.46,
        bottom - h * 0.6,
        cx + w * 0.52,
        bottom - h * 0.24,
        cx,
        bottom,
      )
      ..close();

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: colors,
      ).createShader(Rect.fromLTWH(cx - w / 2, top, w, h))
      ..color = Colors.white.withValues(alpha: opacity);

    canvas.drawPath(path, paint);
  }

  void _drawEmbers(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < _emberCount; i++) {
      final seed = i * 37.0;
      final phase = (progress * 1.6 + i / _emberCount) % 1.0;
      final dx =
          size.width / 2 + math.sin(seed + phase * math.pi * 2) * size.width * 0.22;
      final dy = size.height * 0.86 - phase * size.height * 0.72;
      final opacity = (1.0 - phase) * 0.9;
      if (opacity <= 0.02) continue;
      paint.color = const Color(0xFFF59E0B).withValues(alpha: opacity);
      canvas.drawCircle(
        Offset(dx, dy),
        2.6 * (1 - phase * 0.5),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant FlameBurstPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
