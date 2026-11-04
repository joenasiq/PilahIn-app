// Reference data gamifikasi statis (keputusan tim/PM; bisa direvisi).
// Disimpan di kode (bukan database) karena data statis, bukan data user.

// ---------------------------------------------------------------------------
// Level
// ---------------------------------------------------------------------------

class LevelInfo {
  final int level;
  final String name;
  final int minPoints;

  const LevelInfo(this.level, this.name, this.minPoints);
}

/// Ambang konsisten dengan mock lama (level 3 = 700, level 4 = 1000).
const List<LevelInfo> kLevels = [
  LevelInfo(1, 'Pemilah Pemula', 0),
  LevelInfo(2, 'Juru Kompos', 300),
  LevelInfo(3, 'Penyelamat Bumi', 700),
  LevelInfo(4, 'Duta Daur Ulang', 1000),
  LevelInfo(5, 'Dewa Ekosistem', 2000),
];

/// Level tertinggi yang ambangnya sudah dicapai [points].
LevelInfo levelForPoints(int points) {
  LevelInfo current = kLevels.first;
  for (final lvl in kLevels) {
    if (points >= lvl.minPoints) current = lvl;
  }
  return current;
}

/// Ambang level berikutnya, atau null jika sudah level maksimal.
int? nextLevelMinPoints(int points) {
  for (final lvl in kLevels) {
    if (points < lvl.minPoints) return lvl.minPoints;
  }
  return null;
}

// ---------------------------------------------------------------------------
// Badge
// ---------------------------------------------------------------------------

/// Definisi lencana. [metric] menentukan cara menghitung progres:
/// `total` | `kategori_organik` | `kategori_anorganik` | `jenis` | `streak`.
/// [wasteTypeKeys] hanya dipakai saat `metric == 'jenis'` (labelKey WasteType).
class BadgeDefinition {
  final String code;
  final String name;
  final String description;
  final String category; // organik / anorganik / streak / umum
  final String iconKey;
  final int target;
  final String unit;
  final int rewardPoints;
  final String metric;
  final List<String>? wasteTypeKeys;

  const BadgeDefinition({
    required this.code,
    required this.name,
    required this.description,
    required this.category,
    required this.iconKey,
    required this.target,
    required this.unit,
    required this.rewardPoints,
    required this.metric,
    this.wasteTypeKeys,
  });
}

/// 15 lencana (definisi sama dengan mock lama, plus kolom metric).
const List<BadgeDefinition> kBadges = [
  BadgeDefinition(code: 'pahlawan_hijau', name: 'Pahlawan Hijau', description: 'Mulai memilah sampah organik', category: 'organik', iconKey: 'eco', target: 10, unit: 'organik', rewardPoints: 100, metric: 'kategori_organik'),
  BadgeDefinition(code: 'pemilah_pemula', name: 'Pemilah Pemula', description: '1 pemindaian pertama', category: 'umum', iconKey: 'star', target: 1, unit: 'pemindaian', rewardPoints: 20, metric: 'total'),
  BadgeDefinition(code: 'api_semangat', name: 'Api Semangat', description: '7 hari beruntun', category: 'streak', iconKey: 'local_fire_department', target: 7, unit: 'hari', rewardPoints: 50, metric: 'streak'),
  BadgeDefinition(code: 'raja_botol', name: 'Raja Botol', description: '10 botol plastik terdeteksi', category: 'anorganik', iconKey: 'water_drop', target: 10, unit: 'botol', rewardPoints: 80, metric: 'jenis', wasteTypeKeys: ['plastic']),
  BadgeDefinition(code: 'pengumpul_kertas', name: 'Pengumpul Kertas', description: '20 kertas terdeteksi', category: 'anorganik', iconKey: 'article', target: 20, unit: 'kertas', rewardPoints: 60, metric: 'jenis', wasteTypeKeys: ['paper']),
  BadgeDefinition(code: 'pejuang_lingkungan', name: 'Pejuang Lingkungan', description: '50 total pemindaian', category: 'umum', iconKey: 'public', target: 50, unit: 'pemindaian', rewardPoints: 200, metric: 'total'),
  BadgeDefinition(code: 'master_kompos', name: 'Master Kompos', description: 'Pilah 50 sampah organik untuk membuka badge ini.', category: 'organik', iconKey: 'compost', target: 50, unit: 'organik', rewardPoints: 100, metric: 'kategori_organik'),
  BadgeDefinition(code: 'dewa_daur_ulang', name: 'Dewa Daur Ulang', description: 'Pilah 100 sampah anorganik', category: 'anorganik', iconKey: 'recycling', target: 100, unit: 'anorganik', rewardPoints: 150, metric: 'kategori_anorganik'),
  BadgeDefinition(code: 'legenda_streak', name: 'Legenda Streak', description: '30 hari beruntun', category: 'streak', iconKey: 'local_fire_department', target: 30, unit: 'hari', rewardPoints: 300, metric: 'streak'),
  BadgeDefinition(code: 'penyelamat_bumi', name: 'Penyelamat Bumi', description: '500 total pemindaian', category: 'umum', iconKey: 'language', target: 500, unit: 'pemindaian', rewardPoints: 500, metric: 'total'),
  BadgeDefinition(code: 'ksatria_kaca', name: 'Ksatria Kaca', description: '20 pecahan kaca', category: 'anorganik', iconKey: 'wine_bar', target: 20, unit: 'kaca', rewardPoints: 75, metric: 'jenis', wasteTypeKeys: ['brown-glass', 'green-glass', 'white-glass']),
  BadgeDefinition(code: 'pecinta_sayur', name: 'Pecinta Sayur', description: '100 sisa sayur', category: 'organik', iconKey: 'restaurant', target: 100, unit: 'sayur', rewardPoints: 80, metric: 'jenis', wasteTypeKeys: ['biological']),
  BadgeDefinition(code: 'pemilah_setia', name: 'Pemilah Setia', description: '100 hari beruntun', category: 'streak', iconKey: 'workspace_premium', target: 100, unit: 'hari', rewardPoints: 1000, metric: 'streak'),
  BadgeDefinition(code: 'guardian', name: 'Guardian', description: '1000 total pemindaian', category: 'umum', iconKey: 'shield', target: 1000, unit: 'pemindaian', rewardPoints: 2000, metric: 'total'),
  BadgeDefinition(code: 'organik_spesialis', name: 'Organik Spesialis', description: '500 organik', category: 'organik', iconKey: 'spa', target: 500, unit: 'organik', rewardPoints: 400, metric: 'kategori_organik'),
];

// ---------------------------------------------------------------------------
// Misi
// ---------------------------------------------------------------------------

/// Definisi misi. [metric] menentukan apa yang dihitung;
/// [wasteTypeKeys] hanya dipakai saat `metric == 'jenis'`.
class MissionDefinition {
  final String code;
  final String title;
  final String unit;
  final int target;
  final int rewardPoints;
  final String period; // harian / mingguan
  final String metric; // total | kategori_organik | kategori_anorganik | jenis
  final List<String>? wasteTypeKeys;

  const MissionDefinition({
    required this.code,
    required this.title,
    required this.unit,
    required this.target,
    required this.rewardPoints,
    required this.period,
    required this.metric,
    this.wasteTypeKeys,
  });
}

const List<MissionDefinition> kMissions = [
  MissionDefinition(
    code: 'misi_harian_organik',
    title: 'Pilah 3 Sampah Organik',
    unit: 'Sampah',
    target: 3,
    rewardPoints: 30,
    period: 'harian',
    metric: 'kategori_organik',
  ),
  MissionDefinition(
    code: 'misi_mingguan_plastik',
    title: 'Deteksi 10 Botol Plastik',
    unit: 'Botol',
    target: 10,
    rewardPoints: 50,
    period: 'mingguan',
    metric: 'jenis',
    wasteTypeKeys: ['plastic'],
  ),
];
