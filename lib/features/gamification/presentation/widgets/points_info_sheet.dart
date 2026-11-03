import 'package:flutter/material.dart';

import '../../domain/points_policy.dart';

/// Penjelasan aturan perolehan poin agar mekanisme gamifikasi transparan.
class PointsInfoSheet extends StatelessWidget {
  const PointsInfoSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const PointsInfoSheet(),
    );
  }

  Widget _buildRule({
    required IconData icon,
    required Color color,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.all(24)
          .copyWith(bottom: 24 + MediaQuery.of(context).padding.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Cara Mendapatkan Poin',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 20),
            _buildRule(
              icon: Icons.new_releases,
              color: Colors.green,
              title: 'Pemindaian sub-kategori baru',
              description:
                  '+${PointsPolicy.pointsNewSubcategory} poin saat pertama kali memindai '
                  'sebuah sub-kategori (mis. Plastik) di hari itu.',
            ),
            _buildRule(
              icon: Icons.repeat,
              color: Colors.orange,
              title: 'Pemindaian ulang',
              description:
                  '+${PointsPolicy.pointsRepeatSubcategory} poin bila sub-kategori yang sama '
                  'sudah pernah dipindai hari ini.',
            ),
            _buildRule(
              icon: Icons.help_outline,
              color: Colors.amber,
              title: 'Hasil belum yakin',
              description:
                  '+${PointsPolicy.pointsUncertain} poin. Hasil ini tidak dihitung ke '
                  'statistik kategori maupun sub-kategori.',
            ),
            _buildRule(
              icon: Icons.event_available,
              color: Colors.blue,
              title: 'Hadiah login harian',
              description:
                  'Hari ke-1 = 2 poin, hari ke-2 = 3 poin, bertambah 1 poin tiap hari '
                  'hingga hari ke-7. Poin hadiah login tidak terkena batas harian.',
            ),
            _buildRule(
              icon: Icons.workspace_premium,
              color: Colors.purple,
              title: 'Badge & misi',
              description:
                  'Misi harian dan mingguan dihitung dari riwayat pemindaian. Hadiah '
                  'misi diklaim lewat tombol Klaim dan tidak terkena batas harian. '
                  'Badge streak login 7 hari hanya diberikan sekali per akun.',
            ),
            const Divider(height: 24),
            Text(
              'Batas poin dari pemindaian & badge: maksimal '
              '${PointsPolicy.dailyLimit} poin per hari. Hadiah login dan misi '
              'dikecualikan dari batas ini.',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: const Text('Mengerti'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
