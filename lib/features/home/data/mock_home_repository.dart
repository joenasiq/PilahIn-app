import '../domain/home_summary.dart';
import 'home_repository.dart';
import '../../gamification/domain/gamification_repository.dart';

class MockHomeRepository implements HomeRepository {
  final GamificationRepository gamificationRepo;

  MockHomeRepository(this.gamificationRepo);

  @override
  Future<HomeSummary> getHomeSummary({
    required String userName,
    required bool isDemoOrGuest,
  }) async {
    // Delay simulasi jaringan
    await Future.delayed(const Duration(milliseconds: 500));

    final badges = await gamificationRepo.getBadges();
    final unlocked = badges.where((b) => b.isOpen).length;
    final total = badges.length;

    // Data level, streak, dan misi masih dummy. Poin dasar 850 hanya untuk
    // akun demo/tamu; akun baru mulai dari 0.
    return HomeSummary(
      userName: userName,
      levelName: isDemoOrGuest ? 'Penyelamat Bumi' : 'Pemilah Pemula',
      level: isDemoOrGuest ? 3 : 1,
      points: isDemoOrGuest ? 850 : 0,
      pointsToNextLevel: isDemoOrGuest ? 150 : 100,
      streakDays: isDemoOrGuest ? 7 : 0,
      unlockedBadges: unlocked,
      totalBadges: total,
      // Misi kini dihitung dinamis dari riwayat (lihat mission_provider).
      dailyMissions: const [],
    );
  }
}
