import 'mission.dart';
import 'badge.dart';

abstract class GamificationRepository {
  Future<List<Mission>> getMissions();
  Future<List<AppBadge>> getBadges();
}
