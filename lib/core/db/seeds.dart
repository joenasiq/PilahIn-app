import 'package:sqflite/sqflite.dart';

import '../constants/app_constants.dart';
import '../waste/waste_types.dart';
import '../../features/result/domain/eco_impact.dart';
import '../../features/scan/domain/waste_category.dart';
import 'password_hasher.dart';

/// Nama ikon (string `Icons.*`) per jenis sampah.
/// Disalin dari field `icon` enum [WasteType]; dipakai sebagai referensi
/// di tabel `waste_types` (UI tetap memakai enum langsung).
const Map<WasteType, String> kWasteIconKey = {
  WasteType.battery: 'battery_alert',
  WasteType.biological: 'eco',
  WasteType.brownGlass: 'wine_bar',
  WasteType.cardboard: 'inventory_2',
  WasteType.clothes: 'checkroom',
  WasteType.greenGlass: 'wine_bar',
  WasteType.metal: 'hardware',
  WasteType.paper: 'description',
  WasteType.plastic: 'local_drink',
  WasteType.shoes: 'hiking',
  WasteType.trash: 'delete_outline',
  WasteType.whiteGlass: 'wine_bar',
};

/// Nama ikon metrik utama eco-impact per jenis sampah
/// (disalin dari `primaryMetricIcon` di [EcoImpact]).
const Map<WasteType, String> kEcoPrimaryIconKey = {
  WasteType.plastic: 'waves',
  WasteType.biological: 'eco',
  WasteType.paper: 'water_drop_outlined',
  WasteType.cardboard: 'forest_outlined',
  WasteType.metal: 'bolt',
  WasteType.battery: 'shield_outlined',
  WasteType.brownGlass: 'local_fire_department_outlined',
  WasteType.greenGlass: 'local_fire_department_outlined',
  WasteType.whiteGlass: 'local_fire_department_outlined',
  WasteType.clothes: 'water_drop',
  WasteType.shoes: 'recycling',
  WasteType.trash: 'delete_outline',
};

/// Menyisipkan data reference (idempoten, aman dipanggil ulang saat upgrade).
///
/// Sumber kebenaran:
/// - `waste_types`  <- enum [WasteType] (core/waste/waste_types.dart)
/// - `eco_impact`   <- [getEcoImpactForWasteType] (features/result/domain/eco_impact.dart)
/// - `users` demo   <- [AppConstants.demoEmail] / [AppConstants.demoPassword]
///
/// Batas level & definisi badge/misi di sini adalah keputusan tim (PM);
/// angka ambang level 3 = 700 dan level 4 = 1000 konsisten dengan mock
/// lama (850 poin, sisa 150 menuju level berikutnya).
Future<void> insertSeedData(DatabaseExecutor db) async {
  final now = DateTime.now().millisecondsSinceEpoch;

  // ---- users (tamu + akun demo) ----
  await db.insert('users', {
    'id': 'guest_id',
    'email': null,
    'password_hash': null,
    'display_name': 'Tamu',
    'is_guest': 1,
    'total_points': 0,
    'current_streak': 0,
    'best_streak': 0,
    'last_active_date': null,
    'created_at': now,
    'updated_at': now,
  }, conflictAlgorithm: ConflictAlgorithm.ignore);

  await db.insert('users', {
    'id': 'user_1',
    'email': AppConstants.demoEmail.trim().toLowerCase(),
    'password_hash': hashPassword(AppConstants.demoEmail, AppConstants.demoPassword),
    'display_name': AppConstants.demoDisplayName,
    'is_guest': 0,
    'total_points': 0,
    'current_streak': 0,
    'best_streak': 0,
    'last_active_date': null,
    'created_at': now,
    'updated_at': now,
  }, conflictAlgorithm: ConflictAlgorithm.ignore);

  // ---- waste_types (12 baris dari enum) ----
  for (final type in WasteType.values) {
    await db.insert('waste_types', {
      'label_key': type.labelKey,
      'display_name': type.displayName,
      'category': type.category == WasteCategory.organik ? 'organik' : 'anorganik',
      'is_hazardous': type.isHazardous ? 1 : 0,
      'icon_key': kWasteIconKey[type],
      'is_active': 1,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  // ---- eco_impact (12 baris, 1:1 dengan waste_types) ----
  final typeIds = {
    for (final row in await db.query('waste_types'))
      row['label_key'] as String: row['id'] as int,
  };
  for (final type in WasteType.values) {
    final impact = getEcoImpactForWasteType(type);
    await db.insert('eco_impact', {
      'waste_type_id': typeIds[type.labelKey],
      'co2_saved_kg': impact.co2SavedKg,
      'primary_metric_label': impact.primaryMetricLabel,
      'primary_metric_value': impact.primaryMetricValue,
      'primary_metric_icon': kEcoPrimaryIconKey[type],
      'decomposition_time': impact.decompositionTime,
      'environmental_equivalence': impact.environmentalEquivalence,
      'action_tip': impact.actionTip,
      'highlight_fact': impact.highlightFact,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  // ---- levels ----
  const levels = [
    (1, 'Pemilah Pemula', 0),
    (2, 'Juru Kompos', 300),
    (3, 'Penyelamat Bumi', 700),
    (4, 'Duta Daur Ulang', 1000),
    (5, 'Dewa Ekosistem', 2000),
  ];
  for (final (level, name, minPoints) in levels) {
    await db.insert('levels', {
      'level': level,
      'name': name,
      'min_points': minPoints,
      'icon_key': 'workspace_premium',
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  // ---- badges (15 definisi lencana; metric = cara hitung progres) ----
  const badges = [
    // code, nama, deskripsi, kategori, ikon, target, satuan, hadiah, metric, wasteTypeIds
    ('pahlawan_hijau', 'Pahlawan Hijau', 'Mulai memilah sampah organik', 'organik', 'eco', 10, 'organik', 100, 'kategori_organik', null),
    ('pemilah_pemula', 'Pemilah Pemula', '1 pemindaian pertama', 'umum', 'star', 1, 'pemindaian', 20, 'total', null),
    ('api_semangat', 'Api Semangat', '7 hari beruntun', 'streak', 'local_fire_department', 7, 'hari', 50, 'streak', null),
    ('raja_botol', 'Raja Botol', '10 botol plastik terdeteksi', 'anorganik', 'water_drop', 10, 'botol', 80, 'jenis', 'plastic'),
    ('pengumpul_kertas', 'Pengumpul Kertas', '20 kertas terdeteksi', 'anorganik', 'article', 20, 'kertas', 60, 'jenis', 'paper'),
    ('pejuang_lingkungan', 'Pejuang Lingkungan', '50 total pemindaian', 'umum', 'public', 50, 'pemindaian', 200, 'total', null),
    ('master_kompos', 'Master Kompos', 'Pilah 50 sampah organik untuk membuka badge ini.', 'organik', 'compost', 50, 'organik', 100, 'kategori_organik', null),
    ('dewa_daur_ulang', 'Dewa Daur Ulang', 'Pilah 100 sampah anorganik', 'anorganik', 'recycling', 100, 'anorganik', 150, 'kategori_anorganik', null),
    ('legenda_streak', 'Legenda Streak', '30 hari beruntun', 'streak', 'local_fire_department', 30, 'hari', 300, 'streak', null),
    ('penyelamat_bumi', 'Penyelamat Bumi', '500 total pemindaian', 'umum', 'language', 500, 'pemindaian', 500, 'total', null),
    ('ksatria_kaca', 'Ksatria Kaca', '20 pecahan kaca', 'anorganik', 'wine_bar', 20, 'kaca', 75, 'jenis', 'brown-glass,green-glass,white-glass'),
    ('pecinta_sayur', 'Pecinta Sayur', '100 sisa sayur', 'organik', 'restaurant', 100, 'sayur', 80, 'jenis', 'biological'),
    ('pemilah_setia', 'Pemilah Setia', '100 hari beruntun', 'streak', 'workspace_premium', 100, 'hari', 1000, 'streak', null),
    ('guardian', 'Guardian', '1000 total pemindaian', 'umum', 'shield', 1000, 'pemindaian', 2000, 'total', null),
    ('organik_spesialis', 'Organik Spesialis', '500 organik', 'organik', 'spa', 500, 'organik', 400, 'kategori_organik', null),
  ];
  for (final (code, name, description, category, icon, target, unit, reward, metric, typeIds) in badges) {
    await db.insert('badges', {
      'code': code,
      'name': name,
      'description': description,
      'category': category,
      'icon_key': icon,
      'target': target,
      'unit': unit,
      'reward_points': reward,
      'metric': metric,
      'waste_type_ids': typeIds,
      'is_active': 1,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  // ---- missions (2 definisi misi) ----
  final plasticId = typeIds['plastic'];
  await db.insert('missions', {
    'code': 'misi_harian_organik',
    'title': 'Pilah 3 Sampah Organik',
    'unit': 'Sampah',
    'target': 3,
    'reward_points': 30,
    'period': 'harian',
    'metric': 'kategori_organik',
    'waste_type_id': null,
    'is_active': 1,
  }, conflictAlgorithm: ConflictAlgorithm.ignore);

  await db.insert('missions', {
    'code': 'misi_mingguan_plastik',
    'title': 'Deteksi 10 Botol Plastik',
    'unit': 'Botol',
    'target': 10,
    'reward_points': 50,
    'period': 'mingguan',
    'metric': 'jenis',
    'waste_type_id': plasticId,
    'is_active': 1,
  }, conflictAlgorithm: ConflictAlgorithm.ignore);
}
