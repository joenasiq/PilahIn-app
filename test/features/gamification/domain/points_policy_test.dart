import 'package:flutter_test/flutter_test.dart';
import 'package:pilahin_app/features/gamification/domain/points_policy.dart';

void main() {
  group('PointsPolicy', () {
    test('sub-kategori baru hari ini mendapat 10 poin', () {
      final result = PointsPolicy.compute(
        isUncertain: false,
        alreadyScannedToday: false,
        pointsEarnedToday: 0,
      );

      expect(result.points, 10);
      expect(result.reason, ScanPointReason.newSubcategory);
    });

    test('sub-kategori yang sama diulang hari ini mendapat 5 poin', () {
      final result = PointsPolicy.compute(
        isUncertain: false,
        alreadyScannedToday: true,
        pointsEarnedToday: 20,
      );

      expect(result.points, 5);
      expect(result.reason, ScanPointReason.repeatSubcategory);
    });

    test('hasil belum yakin mendapat 3 poin', () {
      final result = PointsPolicy.compute(
        isUncertain: true,
        alreadyScannedToday: false,
        pointsEarnedToday: 0,
      );

      expect(result.points, 3);
      expect(result.reason, ScanPointReason.uncertain);
    });

    test('poin dipotong agar tidak melewati batas harian 150', () {
      final result = PointsPolicy.compute(
        isUncertain: false,
        alreadyScannedToday: false,
        pointsEarnedToday: 145,
      );

      expect(result.points, 5);
      expect(result.dailyLimit, 150);
    });

    test('poin 0 ketika batas harian sudah tercapai', () {
      final result = PointsPolicy.compute(
        isUncertain: false,
        alreadyScannedToday: false,
        pointsEarnedToday: 150,
      );

      expect(result.points, 0);
      expect(result.reason, ScanPointReason.dailyLimitReached);
    });

    test('fitur poin nonaktif tidak memberi poin', () {
      final result = PointsPolicy.compute(
        isUncertain: false,
        alreadyScannedToday: false,
        pointsEarnedToday: 0,
        enabled: false,
      );

      expect(result.points, 0);
      expect(result.reason, ScanPointReason.disabled);
    });
  });
}
