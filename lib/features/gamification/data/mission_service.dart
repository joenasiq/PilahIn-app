import '../../history/domain/history_repository.dart';
import '../data/points_ledger_service.dart';
import '../domain/mission.dart';
import '../domain/mission_template.dart';
import 'mission_progress_calculator.dart';

/// Hasil klaim hadiah misi.
class MissionClaimResult {
  final bool success;
  final bool alreadyClaimed;
  final int points;

  const MissionClaimResult({
    required this.success,
    required this.alreadyClaimed,
    required this.points,
  });

  static const MissionClaimResult rejected = MissionClaimResult(
    success: false,
    alreadyClaimed: false,
    points: 0,
  );

  static const MissionClaimResult duplicate = MissionClaimResult(
    success: false,
    alreadyClaimed: true,
    points: 0,
  );
}

/// Menghitung progres misi dari riwayat dan menangani klaim hadiah.
class MissionService {
  final HistoryRepository repository;
  final PointsLedgerService ledger;
  final MissionProgressCalculator calculator;

  MissionService({
    required this.repository,
    required this.ledger,
    this.calculator = const MissionProgressCalculator(),
  });

  Future<List<Mission>> dailyMissions({required String userId, DateTime? now}) {
    return _buildMissions(
      templates: MissionTemplates.daily,
      userId: userId,
      now: now,
    );
  }

  Future<List<Mission>> weeklyMissions({
    required String userId,
    DateTime? now,
  }) {
    return _buildMissions(
      templates: MissionTemplates.weekly,
      userId: userId,
      now: now,
    );
  }

  Future<List<Mission>> _buildMissions({
    required List<MissionTemplate> templates,
    required String userId,
    DateTime? now,
  }) async {
    final today = now ?? DateTime.now();
    final range = periodRange(templates.first.period, today);
    final entries = await repository.getBetween(
      userId: userId,
      start: range.start,
      end: range.end,
    );
    final periodKey = periodKeyOf(templates.first.period, today);
    final claimedKeys = await ledger.getClaimedMissionKeys(userId);

    return templates.map((template) {
      final progress = calculator
          .metricValue(template.metric, entries)
          .clamp(0, template.target);
      final claimKey = '${template.id}:$periodKey';
      final claimed = claimedKeys.contains(claimKey);

      return Mission(
        id: template.id,
        judul: template.title,
        progres: progress,
        target: template.target,
        satuan: template.unit,
        hadiahPoin: template.rewardPoints,
        periode: template.period == MissionPeriod.daily ? 'harian' : 'mingguan',
        status: claimed
            ? 'selesai-diklaim'
            : (progress >= template.target ? 'selesai' : 'berjalan'),
        periodKey: claimKey,
      );
    }).toList();
  }

  /// Mengklaim hadiah misi. Hadiah misi tidak terkena batas poin harian.
  Future<MissionClaimResult> claim({
    required String userId,
    required Mission mission,
  }) async {
    if (mission.status != 'selesai') {
      return mission.status == 'selesai-diklaim'
          ? MissionClaimResult.duplicate
          : MissionClaimResult.rejected;
    }

    final key = mission.periodKey.isNotEmpty
        ? mission.periodKey
        : '${mission.id}:${periodKeyOf(MissionPeriod.daily, DateTime.now())}';

    final claimed = await ledger.claimMission(userId, key);
    if (!claimed) return MissionClaimResult.duplicate;

    await ledger.addMissionPoints(userId, mission.hadiahPoin);
    return MissionClaimResult(
      success: true,
      alreadyClaimed: false,
      points: mission.hadiahPoin,
    );
  }

  /// Rentang waktu sebuah periode. Mingguan dimulai hari Senin.
  static ({DateTime start, DateTime end}) periodRange(
    MissionPeriod period,
    DateTime date,
  ) {
    final day = DateTime(date.year, date.month, date.day);
    if (period == MissionPeriod.daily) {
      return (start: day, end: day.add(const Duration(days: 1)));
    }
    final start = day.subtract(Duration(days: day.weekday - 1));
    return (start: start, end: start.add(const Duration(days: 7)));
  }

  /// Kunci periode untuk mencegah klaim ganda pada periode yang sama.
  static String periodKeyOf(MissionPeriod period, DateTime date) {
    final range = periodRange(period, date);
    final start = range.start;
    final y = start.year.toString().padLeft(4, '0');
    final m = start.month.toString().padLeft(2, '0');
    final d = start.day.toString().padLeft(2, '0');
    return period == MissionPeriod.daily ? '$y-$m-$d' : 'W$y-$m-$d';
  }
}
