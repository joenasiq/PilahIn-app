/// Alasan pemberian poin dari sebuah pemindaian.
enum ScanPointReason {
  /// Sub-kategori ini pertama kali dipindai hari ini.
  newSubcategory,

  /// Sub-kategori ini sudah pernah dipindai hari ini.
  repeatSubcategory,

  /// Hasil pemindaian belum cukup yakin.
  uncertain,

  /// Batas poin harian sudah tercapai.
  dailyLimitReached,

  /// Fitur poin sedang dimatikan.
  disabled,
}

/// Hasil perhitungan poin untuk satu pemindaian.
class ScanPointResult {
  final int points;
  final ScanPointReason reason;
  final int pointsEarnedToday;
  final int dailyLimit;

  const ScanPointResult({
    required this.points,
    required this.reason,
    required this.pointsEarnedToday,
    required this.dailyLimit,
  });

  /// Pesan singkat untuk ditampilkan di layar hasil.
  String get message {
    switch (reason) {
      case ScanPointReason.newSubcategory:
        return '+$points Poin • Sub-kategori baru hari ini';
      case ScanPointReason.repeatSubcategory:
        return '+$points Poin • Sudah pernah dipindai hari ini';
      case ScanPointReason.uncertain:
        return '+$points Poin • Hasil belum yakin';
      case ScanPointReason.dailyLimitReached:
        return '0 Poin • Batas harian $dailyLimit poin tercapai';
      case ScanPointReason.disabled:
        return 'Poin pemindaian sedang tidak aktif';
    }
  }
}

/// Aturan perolehan poin pemindaian.
///
/// - Sub-kategori baru hari ini: 10 poin
/// - Sub-kategori sama diulang di hari yang sama: 5 poin
/// - Hasil belum yakin: 3 poin
/// - Total poin (scan + badge/misi) maksimal 150 per hari
class PointsPolicy {
  static const int pointsNewSubcategory = 10;
  static const int pointsRepeatSubcategory = 5;
  static const int pointsUncertain = 3;
  static const int dailyLimit = 150;

  const PointsPolicy._();

  static ScanPointResult compute({
    required bool isUncertain,
    required bool alreadyScannedToday,
    required int pointsEarnedToday,
    bool enabled = true,
  }) {
    if (!enabled) {
      return ScanPointResult(
        points: 0,
        reason: ScanPointReason.disabled,
        pointsEarnedToday: pointsEarnedToday,
        dailyLimit: dailyLimit,
      );
    }

    final int base;
    final ScanPointReason reason;
    if (isUncertain) {
      base = pointsUncertain;
      reason = ScanPointReason.uncertain;
    } else if (alreadyScannedToday) {
      base = pointsRepeatSubcategory;
      reason = ScanPointReason.repeatSubcategory;
    } else {
      base = pointsNewSubcategory;
      reason = ScanPointReason.newSubcategory;
    }

    final rawRemaining = dailyLimit - pointsEarnedToday;
    final int remaining = rawRemaining < 0 ? 0 : rawRemaining;
    final int awarded = base < remaining ? base : remaining;

    if (awarded <= 0) {
      return ScanPointResult(
        points: 0,
        reason: ScanPointReason.dailyLimitReached,
        pointsEarnedToday: pointsEarnedToday,
        dailyLimit: dailyLimit,
      );
    }

    return ScanPointResult(
      points: awarded,
      reason: reason,
      pointsEarnedToday: pointsEarnedToday,
      dailyLimit: dailyLimit,
    );
  }
}
