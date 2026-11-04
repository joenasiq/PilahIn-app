import '../../../core/guest/guest_progress_store.dart';
import '../domain/badge.dart';
import '../domain/gamification_repository.dart';
import '../domain/mission.dart';
import '../domain/progress_calculator.dart';
import '../domain/reference_data.dart';

/// Repository gamifikasi tamu: seluruh progres diturunkan (derived) dari
/// scan tamu di [GuestProgressStore] pada setiap baca — tanpa persistensi.
/// Saat tamu login/registrasi, scan di-merge ke akun (lihat
/// `FirebaseAuthRepository._mergeGuestProgress`).
class GuestGamificationRepository implements GamificationRepository {
  GuestGamificationRepository(this._store);

  final GuestProgressStore _store;

  @override
  Future<List<AppBadge>> getBadges() async {
    final scans = _store.loadScans();
    final agg = aggregateScans(scans);

    return kBadges.map((def) {
      final progress = badgeProgress(def, agg);
      return AppBadge(
        id: def.code,
        nama: def.name,
        deskripsi: def.description,
        kategori: def.category,
        iconKey: def.iconKey,
        progres: progress,
        target: def.target,
        satuan: def.unit,
        tanggalDiraih: null, // tamu: tanggal terbuka tidak dilacak
        hadiahPoin: def.rewardPoints,
      );
    }).toList();
  }

  @override
  Future<List<Mission>> getMissions() async {
    final now = DateTime.now();
    final scans = _store.loadScans();

    return kMissions.map((def) {
      final periodStart =
          def.period == 'harian' ? dateKey(now) : mondayKey(now);
      final progress = missionProgress(def, scansInPeriod(scans, def, now: now));
      return Mission(
        id: '${def.code}_$periodStart',
        judul: def.title,
        progres: progress,
        target: def.target,
        satuan: def.unit,
        hadiahPoin: def.rewardPoints,
        periode: def.period,
        status: progress >= def.target ? 'selesai-diklaim' : 'berjalan',
      );
    }).toList();
  }
}
