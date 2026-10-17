import 'package:flutter/material.dart';

class StreakCard extends StatelessWidget {
  final int streakDays;

  const StreakCard({super.key, required this.streakDays});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dayLabels = ['S', 'S', 'R', 'K', 'J', 'S', 'M'];
    final activeCount = streakDays.clamp(0, 7);

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFFDF5), // Soft amber tint
            Color(0xFFFFF7ED), // Light orange tint
            Color(0xFFFEF3C7), // Warm yellow tint
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFFDBA74).withValues(alpha: 0.8),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEA580C).withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          children: [
            // Baris Atas: Ikon Api Membara + Judul & Deskripsi
            Row(
              children: [
                // Ikon Api Bergradasi
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFFFBBF24), // Amber
                        Color(0xFFF97316), // Orange
                        Color(0xFFEF4444), // Crimson Fire
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF97316).withValues(alpha: 0.4),
                        blurRadius: 12,
                        spreadRadius: 1,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.local_fire_department_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 14),

                // Teks Utama
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '$streakDays Hari Beruntun!',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF9A3412),
                              fontSize: 17,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEA580C).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'HOT',
                              style: TextStyle(
                                color: Color(0xFFC2410C),
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Pertahankan konsistensi memilah sampah Anda.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF78350F).withValues(alpha: 0.85),
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Indikator 7 Hari Konsistensi (Sen - Min)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFFFED7AA),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(7, (index) {
                  final isDone = index < activeCount;
                  return Column(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: isDone
                              ? const LinearGradient(
                                  colors: [Color(0xFFF97316), Color(0xFFEF4444)],
                                )
                              : null,
                          color: isDone ? null : const Color(0xFFF3F4F6),
                          border: isDone
                              ? Border.all(color: Colors.white, width: 1.5)
                              : Border.all(color: Colors.grey.shade300, width: 1),
                          boxShadow: isDone
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFFF97316).withValues(alpha: 0.3),
                                    blurRadius: 6,
                                  ),
                                ]
                              : null,
                        ),
                        child: Icon(
                          isDone ? Icons.local_fire_department : Icons.circle_outlined,
                          size: isDone ? 18 : 12,
                          color: isDone ? Colors.white : Colors.grey.shade400,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dayLabels[index],
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isDone ? FontWeight.bold : FontWeight.w500,
                          color: isDone ? const Color(0xFFC2410C) : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
