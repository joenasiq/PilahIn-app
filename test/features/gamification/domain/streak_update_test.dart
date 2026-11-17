import 'package:flutter_test/flutter_test.dart';
import 'package:pilahin_app/features/gamification/domain/streak_update.dart';

void main() {
  group('StreakUpdate', () {
    test('0 -> 1 (scan pertama) dianggap bertambah', () {
      const update = StreakUpdate(previous: 0, current: 1);

      expect(update.increased, isTrue);
    });

    test('1 -> 2 dianggap bertambah', () {
      expect(const StreakUpdate(previous: 1, current: 2).increased, isTrue);
    });

    test('1 -> 1 tidak bertambah', () {
      expect(const StreakUpdate(previous: 1, current: 1).increased, isFalse);
    });

    test('2 -> 1 (streak putus) tidak bertambah', () {
      expect(const StreakUpdate(previous: 2, current: 1).increased, isFalse);
    });

    test('unknown tidak pernah bertambah', () {
      expect(const StreakUpdate.unknown().increased, isFalse);
    });
  });
}
