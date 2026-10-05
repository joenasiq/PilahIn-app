import 'daily_mission.dart';

class HomeSummary {
  final String userName;
  final String levelName;
  final int level;
  final int points;
  final int pointsToNextLevel;
  final int streakDays;
  final List<DailyMission> dailyMissions;

  HomeSummary({
    required this.userName,
    required this.levelName,
    required this.level,
    required this.points,
    required this.pointsToNextLevel,
    required this.streakDays,
    required this.dailyMissions,
  });
}
