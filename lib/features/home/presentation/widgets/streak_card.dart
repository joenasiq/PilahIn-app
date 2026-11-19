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
            Color(0xFFFFFCF5), // Krim sangat lembut
            Color(0xFFFFF6E8), // Hangat tipis
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFFDE4BE), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          children: [
            // Baris Atas: Ikon Api + Judul & Deskripsi
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
                        Color(0xFFFCD34D), // Amber terang
                        Color(0xFFF59E0B), // Amber
                        Color(0xFFEA580C), // Oranye hangat
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.32),
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
                      Text(
                        '$streakDays Hari Beruntun!',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF78350F),
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Pertahankan konsistensi memilah sampah Anda.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF92400E).withValues(alpha: 0.75),
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
                border: Border.all(color: const Color(0xFFFEF0D5), width: 1),
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
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFFFBBF24),
                                    Color(0xFFF97316),
                                  ],
                                )
                              : null,
                          color: isDone ? null : const Color(0xFFF8FAFC),
                          border: isDone
                              ? Border.all(color: Colors.white, width: 1.5)
                              : Border.all(
                                  color: const Color(0xFFE2E8F0),
                                  width: 1,
                                ),
                          boxShadow: isDone
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFFF59E0B)
                                        .withValues(alpha: 0.28),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: isDone
                            ? const Icon(
                                Icons.check_rounded,
                                size: 18,
                                color: Colors.white,
                              )
                            : Center(
                                child: Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFCBD5E1),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dayLabels[index],
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isDone
                              ? FontWeight.bold
                              : FontWeight.w500,
                          color: isDone
                              ? const Color(0xFFB45309)
                              : const Color(0xFF94A3B8),
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
