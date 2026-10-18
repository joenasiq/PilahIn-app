import 'package:flutter/material.dart';
import '../../domain/eco_impact.dart';
import '../../../../core/waste/waste_types.dart';

class EcoImpactCard extends StatelessWidget {
  final WasteType wasteType;

  const EcoImpactCard({
    super.key,
    required this.wasteType,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final impact = getEcoImpactForWasteType(wasteType);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFF0FDF4), // Emerald tint
            const Color(0xFFECFDF5), // Mint tint
            Colors.white,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF86EFAC).withValues(alpha: 0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Tag & Planet Icon
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.energy_savings_leaf, size: 14, color: Color(0xFF047857)),
                      SizedBox(width: 4),
                      Text(
                        'ECO-IMPACT',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: Color(0xFF047857),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.public,
                    size: 18,
                    color: Color(0xFF059669),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Judul
            Text(
              'Dampak Nyata Pemilahanmu',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF065F46),
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tindakan kecilmu memilah ${impact.wasteType.displayName.toLowerCase()} memberi pengaruh besar bagi bumi:',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade700,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 16),

            // 3 Kartu Metrik Dampak
            Row(
              children: [
                // 1. Reduksi CO2
                Expanded(
                  child: _buildMetricTile(
                    icon: Icons.cloud_done_rounded,
                    iconColor: const Color(0xFF059669),
                    backgroundColor: Colors.white,
                    value: '-${impact.co2SavedFormatted}',
                    label: 'Jejak Karbon',
                    sublabel: 'CO₂e dicegah',
                  ),
                ),
                const SizedBox(width: 8),
                // 2. Metrik Utama Sumber Daya
                Expanded(
                  child: _buildMetricTile(
                    icon: impact.primaryMetricIcon,
                    iconColor: const Color(0xFF0284C7),
                    backgroundColor: Colors.white,
                    value: impact.primaryMetricValue,
                    label: impact.primaryMetricLabel,
                    sublabel: 'Hemat Sumber Daya',
                  ),
                ),
                const SizedBox(width: 8),
                // 3. Waktu Dekomposisi di TPA
                Expanded(
                  child: _buildMetricTile(
                    icon: Icons.timelapse_rounded,
                    iconColor: const Color(0xFFD97706),
                    backgroundColor: Colors.white,
                    value: impact.decompositionTime,
                    label: 'Waktu Urai TPA',
                    sublabel: 'Bila terbuang liar',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Kotak Fakta Menarik & Ekuivalensi Lingkungan
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFFA7F3D0).withValues(alpha: 0.8),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.lightbulb_rounded,
                      size: 18,
                      color: Color(0xFFD97706),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tahukah Kamu?',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF92400E),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          impact.environmentalEquivalence,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade800,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Tip Aksi Cepat
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF059669).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline_rounded,
                    size: 16,
                    color: Color(0xFF047857),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      impact.actionTip,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF047857),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required Color iconColor,
    required Color backgroundColor,
    required String value,
    required String label,
    required String sublabel,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: 22, color: iconColor),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          Text(
            sublabel,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9,
              color: Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }
}
