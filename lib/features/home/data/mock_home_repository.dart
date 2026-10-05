import '../domain/daily_mission.dart';
import '../domain/home_summary.dart';
import 'home_repository.dart';

class MockHomeRepository implements HomeRepository {
  @override
  Future<HomeSummary> getHomeSummary({required String userName}) async {
    // Delay simulasi jaringan
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Data ini sementara sesuai dengan desain UI
    return HomeSummary(
      userName: userName,
      levelName: 'Penyelamat Bumi',
      level: 3,
      points: 850,
      pointsToNextLevel: 150,
      streakDays: 7,
      dailyMissions: [
        DailyMission(
          title: 'Pilah 3 Sampah Organik',
          currentProgress: 2,
          targetProgress: 3,
          rewardPoints: 30,
          status: 'Berjalan',
        ),
      ],
    );
  }
}
