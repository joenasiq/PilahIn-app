import 'package:flutter/material.dart';
import 'point_reward_dialog.dart';

/// Chip reward poin dengan animasi detak halus dan kilauan, dapat diklik untuk membuka dialog selebrasi.
class AnimatedRewardBadge extends StatefulWidget {
  final int points;

  const AnimatedRewardBadge({
    super.key,
    required this.points,
  });

  @override
  State<AnimatedRewardBadge> createState() => _AnimatedRewardBadgeState();
}

class _AnimatedRewardBadgeState extends State<AnimatedRewardBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.06).chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.06, end: 1.0).chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(_pulseController);

    // Animasi denyut 2 kali saat pertama kali muncul, kemudian stabil
    _pulseController.forward().then((_) {
      if (mounted) {
        _pulseController.reverse().then((_) {
          if (mounted) {
            _pulseController.forward().then((_) {
              if (mounted) _pulseController.reverse();
            });
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          alignment: Alignment.centerLeft,
          child: child,
        );
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            PointRewardDialog.show(context, pointsEarned: widget.points);
          },
          borderRadius: BorderRadius.circular(24),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFFEF3C7), // Amber 100
                  Color(0xFFD1FAE5), // Emerald 100
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.5),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF59E0B),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '+${widget.points} Poin Pemindaian',
                  style: const TextStyle(
                    color: Color(0xFF92400E),
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.touch_app_outlined,
                  size: 13,
                  color: Color(0xFFB45309),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
