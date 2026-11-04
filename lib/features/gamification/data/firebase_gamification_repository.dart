import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/badge.dart';
import '../domain/gamification_repository.dart';
import '../domain/mission.dart';
import '../domain/progress_calculator.dart';
import '../domain/reference_data.dart';
import 'progression_service.dart';

/// Repository gamifikasi akun, berbasis Firestore.
///
/// Data progres (badge & misi) ditulis oleh [ProgressionService] setelah
/// tiap perubahan scan; repository ini hanya membaca. Jika dokumen belum
/// ada (mis. user belum pernah scan), fallback progres 0 dari definisi.
class FirebaseGamificationRepository implements GamificationRepository {
  FirebaseGamificationRepository(this._firestore, {required this.uid});

  final FirebaseFirestore _firestore;
  final String uid;

  CollectionReference<Map<String, dynamic>> get _badges =>
      _firestore.collection('users').doc(uid).collection('badges');

  CollectionReference<Map<String, dynamic>> get _missions =>
      _firestore.collection('users').doc(uid).collection('missions');

  @override
  Future<List<AppBadge>> getBadges() async {
    final snap = await _badges.get();
    final stored = <String, Map<String, dynamic>>{
      for (final d in snap.docs) d.id: d.data(),
    };

    return kBadges.map((def) {
      final doc = stored[def.code];
      final progress = (doc?['progress'] as int?) ?? 0;
      final unlockedAtMs = doc?['unlocked_at'] as int?;
      return AppBadge(
        id: def.code,
        nama: def.name,
        deskripsi: def.description,
        kategori: def.category,
        iconKey: def.iconKey,
        progres: progress,
        target: def.target,
        satuan: def.unit,
        tanggalDiraih: unlockedAtMs != null
            ? DateTime.fromMillisecondsSinceEpoch(unlockedAtMs)
            : null,
        hadiahPoin: def.rewardPoints,
      );
    }).toList();
  }

  @override
  Future<List<Mission>> getMissions() async {
    // Hanya misi periode berjalan (harian: hari ini, mingguan: Senin ini).
    final now = DateTime.now();
    final snap = await _missions.get();
    final stored = <String, Map<String, dynamic>>{
      for (final d in snap.docs) d.id: d.data(),
    };

    return kMissions.map((def) {
      final periodStart =
          def.period == 'harian' ? dateKey(now) : mondayKey(now);
      final docId = '${def.code}_$periodStart';
      final doc = stored[docId];
      final progress = (doc?['progress'] as int?) ?? 0;
      final status = (doc?['status'] as String?) ??
          (progress >= def.target ? 'selesai-diklaim' : 'berjalan');
      return Mission(
        id: docId,
        judul: def.title,
        progres: progress,
        target: def.target,
        satuan: def.unit,
        hadiahPoin: def.rewardPoints,
        periode: def.period,
        status: status,
      );
    }).toList();
  }
}
