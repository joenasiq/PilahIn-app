import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pilahin_app/core/constants/app_constants.dart';
import 'package:pilahin_app/core/constants/ml_config.dart';
import 'package:pilahin_app/core/waste/waste_types.dart';
import 'package:pilahin_app/features/auth/presentation/auth_controller.dart';
import 'package:pilahin_app/features/gamification/presentation/gamification_provider.dart';
import 'package:pilahin_app/features/history/domain/history_entry.dart';
import 'package:pilahin_app/features/history/presentation/history_provider.dart';
import 'package:pilahin_app/features/scan/domain/classification_result.dart';

import '../../history/helpers/fake_history_repository.dart';

/// `saveScanToHistory` pada jalur tamu (tanpa cloud) harus mengembalikan
/// perubahan streak yang benar supaya popup perayaan tidak salah muncul.
void main() {
  late FakeHistoryRepository repository;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    MlConfig.showScanPoints = true;
    repository = FakeHistoryRepository();

    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        historyRepositoryProvider.overrideWithValue(repository),
        currentUserIdProvider.overrideWithValue(AppConstants.demoUserId),
        progressionServiceProvider.overrideWithValue(null),
      ],
    );
  });

  tearDown(() => container.dispose());

  ClassificationResult scanAt(DateTime time) => ClassificationResult(
    wasteType: WasteType.biological,
    confidence: 0.9,
    imagePath: 'dummy.jpg',
    isUncertain: false,
    timestamp: time,
  );

  Future<void> seedScan(DateTime time) => repository.add(
    HistoryEntry(
      scanKey: 'seed_${time.millisecondsSinceEpoch}',
      userId: AppConstants.demoUserId,
      wasteType: WasteType.plastic,
      confidence: 0.9,
      isUncertain: false,
      pointsEarned: 10,
      createdAt: time,
    ),
  );

  test('scan pertama: streak 0 -> 1 dan bertambah', () async {
    final notifier = container.read(historyNotifierProvider.notifier);
    final result = await notifier.saveScanToHistory(scanAt(DateTime.now()));

    expect(result.streak.previous, 0);
    expect(result.streak.current, 1);
    expect(result.streak.increased, isTrue);
  });

  test('scan kemarin lalu hari ini: streak 1 -> 2', () async {
    final now = DateTime.now();
    await seedScan(now.subtract(const Duration(days: 1)));

    final notifier = container.read(historyNotifierProvider.notifier);
    final result = await notifier.saveScanToHistory(scanAt(now));

    expect(result.streak.previous, 1);
    expect(result.streak.current, 2);
    expect(result.streak.increased, isTrue);
  });

  test('scan kedua di hari yang sama: streak tetap 1', () async {
    final now = DateTime.now();
    await seedScan(now);

    final notifier = container.read(historyNotifierProvider.notifier);
    final result = await notifier.saveScanToHistory(scanAt(now));

    expect(result.streak.previous, 1);
    expect(result.streak.current, 1);
    expect(result.streak.increased, isFalse);
  });

  test('poin tetap dikembalikan bersama streak', () async {
    final notifier = container.read(historyNotifierProvider.notifier);
    final result = await notifier.saveScanToHistory(scanAt(DateTime.now()));

    expect(result.points.points, 10);
  });
}
