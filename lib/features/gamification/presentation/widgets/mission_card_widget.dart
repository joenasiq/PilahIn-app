import 'package:flutter/material.dart';

import '../../domain/mission.dart';

class MissionCardWidget extends StatelessWidget {
  final Mission mission;
  final VoidCallback? onClaim;
  final VoidCallback? onStart;

  const MissionCardWidget({
    super.key,
    required this.mission,
    this.onClaim,
    this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final isClaimed = mission.isClaimed;
    final isCompleted = mission.isCompleted;
    final pct = mission.progressRatio;
    final pctText = (pct * 100).toInt().toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isClaimed ? Colors.green.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isClaimed ? Colors.green.shade200 : Colors.grey.shade200,
        ),
        boxShadow: isClaimed
            ? []
            : [
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
          Row(
            children: [
              Icon(
                isClaimed
                    ? Icons.check_circle
                    : (isCompleted
                          ? Icons.emoji_events
                          : Icons.local_fire_department),
                color: isClaimed
                    ? Colors.green
                    : (isCompleted ? Colors.amber.shade700 : Colors.orange),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  mission.judul,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              if (!isClaimed)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '+${mission.hadiahPoin} Poin',
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          if (mission.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              mission.description,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5),
            ),
          ],
          const SizedBox(height: 12),
          if (isClaimed)
            Text(
              'Selesai • Hadiah +${mission.hadiahPoin} Poin diklaim',
              style: TextStyle(
                color: Colors.green.shade700,
                fontWeight: FontWeight.w500,
              ),
            )
          else ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                backgroundColor: Colors.grey.shade200,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Progres: ${mission.progres}/${mission.target} ${mission.satuan}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                Text(
                  '$pctText%',
                  style: const TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            if (onStart != null || isCompleted) ...[
              const SizedBox(height: 12),
              if (isCompleted && onClaim != null) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onClaim,
                    icon: const Icon(Icons.card_giftcard, size: 18),
                    label: const Text('Klaim Hadiah'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ),
                ),
                if (onStart != null) const SizedBox(height: 8),
              ],
              if (onStart != null)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onStart,
                    icon: const Icon(Icons.crop_free, size: 18),
                    label: Text(isCompleted ? 'Pindai Lagi' : 'Mulai Misi'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                      side: const BorderSide(color: Colors.blue, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }
}
