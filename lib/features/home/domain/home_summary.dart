import 'daily_mission.dart';

class HomeSummary {
  final String userName;
  final String levelName;
  final int level;
  final int points;
  final int pointsToNextLevel;
  final int streakDays;
  final int unlockedBadges;
  final int totalBadges;
  final List<DailyMission> dailyMissions;

  HomeSummary({
    required this.userName,
    required this.levelName,
    required this.level,
    required this.points,
    required this.pointsToNextLevel,
    required this.streakDays,
    required this.unlockedBadges,
    required this.totalBadges,
    required this.dailyMissions,
  });

  HomeSummary copyWith({
    String? userName,
    String? levelName,
    int? level,
    int? points,
    int? pointsToNextLevel,
    int? streakDays,
    int? unlockedBadges,
    int? totalBadges,
    List<DailyMission>? dailyMissions,
  }) {
    return HomeSummary(
      userName: userName ?? this.userName,
      levelName: levelName ?? this.levelName,
      level: level ?? this.level,
      points: points ?? this.points,
      pointsToNextLevel: pointsToNextLevel ?? this.pointsToNextLevel,
      streakDays: streakDays ?? this.streakDays,
      unlockedBadges: unlockedBadges ?? this.unlockedBadges,
      totalBadges: totalBadges ?? this.totalBadges,
      dailyMissions: dailyMissions ?? this.dailyMissions,
    );
  }
}
