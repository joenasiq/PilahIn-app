import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../history/domain/history_entry.dart';
import '../domain/progress_calculator.dart';
import '../domain/reference_data.dart';

/// Layanan recompute gamifikasi akun (cloud).
///
/// Prinsip: `total_points` selalu dihitung ulang dari nol setiap kali ada
/// perubahan (scan baru/dihapus/merge tamu):
///
/// ```
/// total_points = sum(scan.points_earned)
///              + sum(hadiah badge yang terbuka)
///              + sum(hadiah misi 'selesai-diklaim', semua periode)
/// ```
///
/// sehingga data selalu "self-healing" (tidak ada drift/ketagihan).
/// Badge yang sudah terbuka tidak pernah dikunci lagi, dan misi yang sudah
/// selesai dianggap otomatis diklaim (UI tidak punya tombol klaim).
///
/// Alur [recomputeAll]: 4 read (scans, user, badges, missions) + 1 WriteBatch.
class ProgressionService {
  ProgressionService(this._firestore, {required this.uid});

  final FirebaseFirestore _firestore;
  final String uid;

  DocumentReference<Map<String, dynamic>> get _userDoc =>
      _firestore.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> get _scans =>
      _firestore.collection('users').doc(uid).collection('scans');

  CollectionReference<Map<String, dynamic>> get _badges =>
      _firestore.collection('users').doc(uid).collection('badges');

  CollectionReference<Map<String, dynamic>> get _missions =>
      _firestore.collection('users').doc(uid).collection('missions');

  /// Hitung ulang seluruh gamifikasi user dan tulis balik dalam 1 batch.
  Future<void> recomputeAll() async {
    // 1. Muat seluruh scan user (sumber kebenaran agregasi).
    final scanSnap = await _scans.get();
    final scans = <HistoryEntry>[];
    for (final d in scanSnap.docs) {
      try {
        scans.add(
            HistoryEntry.fromMap(Map<String, dynamic>.from(d.data())));
      } catch (e) {
        developer.log(
            'ProgressionService: doc scan tidak valid, di-skip (${d.id}): $e');
      }
    }

    // 2. Muat dokumen user (untuk best_streak).
    final userSnap = await _userDoc.get();
    final userData = userSnap.data() ?? const <String, dynamic>{};

    // 3. Muat badge & misi tersimpan (status terbuka/diklaim permanen).
    final badgesSnap = await _badges.get();
    final storedBadges = <String, Map<String, dynamic>>{
      for (final d in badgesSnap.docs) d.id: d.data(),
    };
    final missionsSnap = await _missions.get();
    final storedMissions = <String, Map<String, dynamic>>{
      for (final d in missionsSnap.docs) d.id: d.data(),
    };

    final now = DateTime.now();
    final agg = aggregateScans(scans, now: now);

    // ---- Badge: progres baru; yang sudah terbuka tidak pernah terkunci.
    var badgeRewardSum = 0;
    final batch = _firestore.batch();
    for (final def in kBadges) {
      final computed = badgeProgress(def, agg);
      final stored = storedBadges[def.code];
      final storedUnlockedAt = stored?['unlocked_at'] as int?;
      final nowUnlocked = computed >= def.target || storedUnlockedAt != null;
      if (nowUnlocked) badgeRewardSum += def.rewardPoints;

      // Progres yang disimpan: minimal target jika sudah terbuka, agar UI
      // (mengecek progres >= target) tidak menampilkan badge terbuka
      // sebagai terkunci lagi meskipun progres turun (mis. scan dihapus).
      final progressToStore =
          nowUnlocked ? (computed > def.target ? computed : def.target) : computed;

      batch.set(
        _badges.doc(def.code),
        {
          'code': def.code,
          'progress': progressToStore,
          'unlocked_at':
              storedUnlockedAt ??
              (nowUnlocked ? now.millisecondsSinceEpoch : null),
        },
      );
    }

    // ---- Misi: hitung ulang periode berjalan; selesai = otomatis diklaim.
    // Misi periode lama tidak disentuh (hadiahnya tetap terhitung).
    final currentDocIds = <String>{
      for (final def in kMissions)
        '${def.code}_${def.period == 'harian' ? dateKey(now) : mondayKey(now)}',
    };
    var missionRewardSum = 0;
    for (final entry in storedMissions.entries) {
      if (!currentDocIds.contains(entry.key) &&
          entry.value['status'] == 'selesai-diklaim') {
        missionRewardSum += (entry.value['reward_points'] as int?) ?? 0;
      }
    }
    for (final def in kMissions) {
      final periodStart =
          def.period == 'harian' ? dateKey(now) : mondayKey(now);
      final docId = '${def.code}_$periodStart';
      final stored = storedMissions[docId];
      final wasClaimed = (stored?['status'] as String?) == 'selesai-diklaim';
      final computed = missionProgress(def, scansInPeriod(scans, def, now: now));
      final status =
          (wasClaimed || computed >= def.target) ? 'selesai-diklaim' : 'berjalan';
      if (status == 'selesai-diklaim') {
        missionRewardSum += def.rewardPoints;
      }
      // claimed_at: pertahankan nilai lama jika sudah diklaim sebelumnya;
      // isi now jika baru saja selesai; null jika masih berjalan.
      int? claimedAt;
      if (wasClaimed) {
        claimedAt = stored?['claimed_at'] as int?;
      } else if (status == 'selesai-diklaim') {
        claimedAt = now.millisecondsSinceEpoch;
      }
      batch.set(
        _missions.doc(docId),
        {
          // Field code disimpan karena kode misi mengandung '_' sehingga
          // tidak bisa di-parse andal dari doc ID.
          'code': def.code,
          'progress': computed,
          'status': status,
          'period_start': periodStart,
          'reward_points': def.rewardPoints,
          'claimed_at': claimedAt,
        },
      );
    }

    // ---- Total poin & streak.
    var scanPointsSum = 0;
    String? lastActiveDate;
    for (final e in scans) {
      scanPointsSum += e.pointsEarned;
      final key = dateKey(e.createdAt);
      if (lastActiveDate == null || key.compareTo(lastActiveDate) > 0) {
        lastActiveDate = key;
      }
    }

    final totalPoints = scanPointsSum + badgeRewardSum + missionRewardSum;
    final storedBest = (userData['best_streak'] as int?) ?? 0;
    final bestStreak = storedBest > agg.streak ? storedBest : agg.streak;

    batch.set(
      _userDoc,
      {
        'total_points': totalPoints,
        'current_streak': agg.streak,
        'best_streak': bestStreak,
        'last_active_date': lastActiveDate,
      },
      SetOptions(merge: true),
    );

    await batch.commit();
  }
}
