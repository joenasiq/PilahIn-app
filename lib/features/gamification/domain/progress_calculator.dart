import '../../history/domain/history_entry.dart';
import '../../scan/domain/waste_category.dart';
import 'reference_data.dart';

/// Fungsi-fungsi murni untuk menghitung gamifikasi dari data scan.
///
/// Semua fungsi di sini deterministik dan bebas I/O (parameter `now`
/// dapat disuntik) sehingga mudah diuji unit tanpa Firebase.

/// Kunci tanggal lokal 'YYYY-MM-DD' untuk [dt] (zona waktu perangkat).
String dateKey(DateTime dt) {
  return '${dt.year.toString().padLeft(4, '0')}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';
}

/// Kunci periode mingguan: tanggal hari Senin dari minggu yang memuat [dt].
/// Semua misi mingguan menggunakan kunci ini sebagai `period_start`.
String mondayKey(DateTime dt) {
  final monday = dt.subtract(Duration(days: dt.weekday - DateTime.monday));
  return dateKey(monday);
}

/// Streak = jumlah hari lokal beruntun (dengan minimal 1 scan) yang
/// diakhiri hari ini; jika belum ada scan hari ini, boleh diakhiri kemarin.
/// Jika tidak ada scan hari ini maupun kemarin, streak = 0.
int computeStreak(Iterable<HistoryEntry> scans, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final days = scans.map((e) => dateKey(e.createdAt)).toSet();
  if (days.isEmpty) return 0;

  DateTime cursor;
  if (days.contains(dateKey(reference))) {
    cursor = reference;
  } else {
    final yesterday = reference.subtract(const Duration(days: 1));
    if (days.contains(dateKey(yesterday))) {
      cursor = yesterday;
    } else {
      return 0;
    }
  }

  var streak = 0;
  while (days.contains(dateKey(cursor))) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return streak;
}

/// Agregasi scan untuk keperluan gamifikasi.
class ScanAggregates {
  final int total;
  final int organik;
  final int anorganik;
  final int streak;

  /// labelKey [WasteType] -> jumlah scan (hanya jenis non-null).
  final Map<String, int> byType;

  const ScanAggregates({
    required this.total,
    required this.organik,
    required this.anorganik,
    required this.streak,
    required this.byType,
  });
}

/// Hitung agregasi [scans] (total, per kategori, per jenis, streak).
ScanAggregates aggregateScans(Iterable<HistoryEntry> scans, {DateTime? now}) {
  final list = scans.toList();
  var organik = 0;
  final byType = <String, int>{};
  for (final e in list) {
    if (e.category == WasteCategory.organik) organik++;
    final key = e.wasteType?.labelKey;
    if (key != null) byType[key] = (byType[key] ?? 0) + 1;
  }
  return ScanAggregates(
    total: list.length,
    organik: organik,
    anorganik: list.length - organik,
    streak: computeStreak(list, now: now),
    byType: byType,
  );
}

/// Progres [def] berdasarkan [agg]. Nilai mentah (bisa melebihi target);
/// consumer yang membatasinya bila perlu.
int badgeProgress(BadgeDefinition def, ScanAggregates agg) {
  switch (def.metric) {
    case 'total':
      return agg.total;
    case 'kategori_organik':
      return agg.organik;
    case 'kategori_anorganik':
      return agg.anorganik;
    case 'streak':
      return agg.streak;
    case 'jenis':
      final keys = def.wasteTypeKeys ?? const <String>[];
      var sum = 0;
      for (final key in keys) {
        sum += agg.byType[key] ?? 0;
      }
      return sum;
    default:
      return 0;
  }
}

/// Ambil scan yang terjadi dalam periode [def]
/// (harian: hari ini; mingguan: Senin yang sama).
List<HistoryEntry> scansInPeriod(
  Iterable<HistoryEntry> scans,
  MissionDefinition def, {
  DateTime? now,
}) {
  final reference = now ?? DateTime.now();
  final periodStart =
      def.period == 'harian' ? dateKey(reference) : mondayKey(reference);
  return scans
      .where((e) {
        final key =
            def.period == 'harian' ? dateKey(e.createdAt) : mondayKey(e.createdAt);
        return key == periodStart;
      })
      .toList();
}

/// Progres [def] dihitung dari [periodScans] (scan periode berjalan saja).
int missionProgress(MissionDefinition def, List<HistoryEntry> periodScans) {
  switch (def.metric) {
    case 'total':
      return periodScans.length;
    case 'kategori_organik':
      return periodScans
          .where((e) => e.category == WasteCategory.organik)
          .length;
    case 'kategori_anorganik':
      return periodScans
          .where((e) => e.category == WasteCategory.anorganik)
          .length;
    case 'jenis':
      final Set<String> keys = (def.wasteTypeKeys ?? const <String>[]).toSet();
      return periodScans
          .where((e) {
            final key = e.wasteType?.labelKey;
            return key != null && keys.contains(key);
          })
          .length;
    default:
      return 0;
  }
}

/// Total poin tamu (turunan, tanpa persistensi):
/// poin seluruh scan + hadiah badge terbuka + hadiah misi periode
/// berjalan yang selesai. Untuk akun, hitungannya ada di
/// `ProgressionService` (misi semua periode ikut terhitung).
int computeDerivedPoints(Iterable<HistoryEntry> scans) {
  final list = scans.toList();
  var points = 0;
  for (final e in list) {
    points += e.pointsEarned;
  }
  final agg = aggregateScans(list);
  for (final def in kBadges) {
    if (badgeProgress(def, agg) >= def.target) {
      points += def.rewardPoints;
    }
  }
  for (final def in kMissions) {
    if (missionProgress(def, scansInPeriod(list, def)) >= def.target) {
      points += def.rewardPoints;
    }
  }
  return points;
}
