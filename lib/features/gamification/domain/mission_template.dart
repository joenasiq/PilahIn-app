/// Metrik yang dipakai untuk menghitung progres sebuah misi dari riwayat scan.
enum MissionMetric {
  /// Total seluruh pemindaian valid.
  totalScans,

  /// Pemindaian dengan kategori organik.
  organicScans,

  /// Pemindaian sub-kategori plastik.
  plasticScans,

  /// Pemindaian sub-kategori biologis (termasuk kulit pisang).
  biologicalScans,

  /// Jumlah sub-kategori berbeda yang pernah dipindai.
  distinctWasteTypes,
}

/// Periode berulang sebuah misi.
enum MissionPeriod { daily, weekly }

/// Template misi. Progresnya selalu dihitung ulang dari riwayat scan,
/// jadi tidak perlu disimpan dan otomatis reset tiap periode.
class MissionTemplate {
  final String id;
  final String title;
  final String description;
  final MissionMetric metric;
  final int target;
  final int rewardPoints;
  final MissionPeriod period;
  final String unit;

  const MissionTemplate({
    required this.id,
    required this.title,
    required this.description,
    required this.metric,
    required this.target,
    required this.rewardPoints,
    required this.period,
    required this.unit,
  });
}

class MissionTemplates {
  static const List<MissionTemplate> daily = [
    MissionTemplate(
      id: 'daily_organik_3',
      title: 'Pilah 3 Sampah Organik',
      description: 'Pindai 3 sampah organik seperti sisa makanan atau daun.',
      metric: MissionMetric.organicScans,
      target: 3,
      rewardPoints: 30,
      period: MissionPeriod.daily,
      unit: 'Sampah',
    ),
    MissionTemplate(
      id: 'daily_scan_5',
      title: 'Pindai 5 Sampah',
      description: 'Lakukan 5 pemindaian sampah apa pun hari ini.',
      metric: MissionMetric.totalScans,
      target: 5,
      rewardPoints: 25,
      period: MissionPeriod.daily,
      unit: 'Sampah',
    ),
    MissionTemplate(
      id: 'daily_plastic_2',
      title: 'Deteksi 2 Plastik',
      description: 'Pindai 2 sampah plastik seperti botol atau kemasan.',
      metric: MissionMetric.plasticScans,
      target: 2,
      rewardPoints: 20,
      period: MissionPeriod.daily,
      unit: 'Sampah',
    ),
    MissionTemplate(
      id: 'daily_banana_1',
      title: 'Pindai Kulit Pisang Pertama',
      description: 'Pindai satu sampah biologis, misalnya kulit pisang.',
      metric: MissionMetric.biologicalScans,
      target: 1,
      rewardPoints: 15,
      period: MissionPeriod.daily,
      unit: 'Sampah',
    ),
  ];

  static const List<MissionTemplate> weekly = [
    MissionTemplate(
      id: 'weekly_plastic_10',
      title: 'Deteksi 10 Botol Plastik',
      description: 'Kumpulkan 10 pemindaian sampah plastik minggu ini.',
      metric: MissionMetric.plasticScans,
      target: 10,
      rewardPoints: 50,
      period: MissionPeriod.weekly,
      unit: 'Botol',
    ),
    MissionTemplate(
      id: 'weekly_scan_20',
      title: 'Pindai 20 Sampah',
      description: 'Lakukan 20 pemindaian sampah selama seminggu.',
      metric: MissionMetric.totalScans,
      target: 20,
      rewardPoints: 75,
      period: MissionPeriod.weekly,
      unit: 'Sampah',
    ),
    MissionTemplate(
      id: 'weekly_variety_5',
      title: 'Coba 5 Sub-kategori Berbeda',
      description: 'Pindai 5 sub-kategori sampah yang berbeda.',
      metric: MissionMetric.distinctWasteTypes,
      target: 5,
      rewardPoints: 60,
      period: MissionPeriod.weekly,
      unit: 'Sub-kategori',
    ),
  ];
}
