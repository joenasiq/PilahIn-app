class Mission {
  final String id;
  final String judul;
  final int progres;
  final int target;
  final String satuan;
  final int hadiahPoin;
  final String periode; // 'harian' / 'mingguan'
  final String status; // 'berjalan' / 'selesai' / 'selesai-diklaim'

  /// Kunci unik periode klaim, mis. `daily_scan_5:2026-11-03`.
  final String periodKey;

  Mission({
    required this.id,
    required this.judul,
    required this.progres,
    required this.target,
    required this.satuan,
    required this.hadiahPoin,
    required this.periode,
    required this.status,
    this.periodKey = '',
  });

  bool get isCompleted => progres >= target;
  bool get isClaimed => status == 'selesai-diklaim';
  bool get isClaimable => isCompleted && !isClaimed;

  double get progressRatio {
    if (target <= 0) return 0;
    return (progres / target).clamp(0.0, 1.0);
  }

  Mission copyWith({int? progres, String? status}) {
    return Mission(
      id: id,
      judul: judul,
      progres: progres ?? this.progres,
      target: target,
      satuan: satuan,
      hadiahPoin: hadiahPoin,
      periode: periode,
      status: status ?? this.status,
      periodKey: periodKey,
    );
  }
}
