import '../domain/daily_mission.dart';
import '../domain/home_summary.dart';
import 'home_repository.dart';
import '../../gamification/domain/gamification_repository.dart';

class MockHomeRepository implements HomeRepository {
  final GamificationRepository gamificationRepo;

  MockHomeRepository(this.gamificationRepo);

  @override
  Future<HomeSummary> getHomeSummary({required String userName}) async {
    // Delay simulasi jaringan
    await Future.delayed(const Duration(milliseconds: 500));
    
    final badges = await gamificationRepo.getBadges();
    final unlocked = badges.where((b) => b.isOpen).length;
    final total = badges.length;

    // Data ini sementara sesuai dengan desain UI
    return HomeSummary(
      userName: userName,
      levelName: 'Penyelamat Bumi',
      level: 3,
      points: 850,
      pointsToNextLevel: 150,
      streakDays: 7,
      unlockedBadges: unlocked,
      totalBadges: total,
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
