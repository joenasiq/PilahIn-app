import 'package:flutter_test/flutter_test.dart';
import 'package:pilahin_app/features/profile/presentation/profile_screen.dart';

void main() {
  group('DonutData Unit Tests', () {
    test('calculate zero correctly', () {
      final data = DonutData(organic: 0, anorganic: 0);
      expect(data.total, 0);
      expect(data.organicRatio, 0.0);
      expect(data.anorganicRatio, 0.0);
    });

    test('calculate pure organic', () {
      final data = DonutData(organic: 10, anorganic: 0);
      expect(data.total, 10);
      expect(data.organicRatio, 1.0);
      expect(data.anorganicRatio, 0.0);
    });

    test('calculate pure anorganic', () {
      final data = DonutData(organic: 0, anorganic: 5);
      expect(data.total, 5);
      expect(data.organicRatio, 0.0);
      expect(data.anorganicRatio, 1.0);
    });

    test('calculate mixed correctly', () {
      final data = DonutData(organic: 3, anorganic: 1);
      expect(data.total, 4);
      expect(data.organicRatio, 0.75);
      expect(data.anorganicRatio, 0.25);
    });
  });
}
