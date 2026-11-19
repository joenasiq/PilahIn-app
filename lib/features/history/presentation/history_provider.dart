import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/ml_config.dart';
import '../../../core/guest/guest_progress_store.dart';
import '../../../core/waste/waste_types.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../gamification/data/points_ledger_service.dart';
import '../../gamification/domain/points_policy.dart';
import '../../gamification/domain/progress_calculator.dart';
import '../../gamification/domain/streak_update.dart';
import '../../gamification/presentation/gamification_provider.dart';
import '../../scan/domain/classification_result.dart';
import '../../scan/domain/waste_category.dart';
import '../data/firebase_history_repository.dart';
import '../data/guest_history_repository.dart';
import '../domain/history_entry.dart';
import '../domain/history_repository.dart';
import '../domain/history_stats.dart';

/// Repository riwayat sesuai sesi aktif (routing Fase 2):
/// - tamu / belum login  -> [GuestHistoryRepository] (GuestProgressStore lokal)
/// - akun login          -> [FirebaseHistoryRepository] (Firestore users/{uid}/scans)
///
/// `sharedPreferencesProvider` diambil dari re-export [auth_controller].
final historyRepositoryProvider = Provider<HistoryRepository>((ref) {
  final user = ref.watch(authControllerProvider).value;
  if (user == null || user.isGuest) {
    return GuestHistoryRepository(ref.watch(guestProgressStoreProvider));
  }
  return FirebaseHistoryRepository(FirebaseFirestore.instance, uid: user.id);
});

class HistoryState {
  final List<HistoryEntry> entries;
  final bool isLoading;
  final String? error;
  final WasteCategory? filterCategory;
  final WasteType? filterWasteType;
  final String searchQuery;

  HistoryState({
    this.entries = const [],
    this.isLoading = true,
    this.error,
    this.filterCategory,
    this.filterWasteType,
    this.searchQuery = '',
  });

  HistoryState copyWith({
    List<HistoryEntry>? entries,
    bool? isLoading,
    String? error,
    WasteCategory? filterCategory,
    WasteType? filterWasteType,
    String? searchQuery,
    bool clearError = false,
  }) {
    return HistoryState(
      entries: entries ?? this.entries,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      filterCategory: filterCategory ?? this.filterCategory,
      filterWasteType: filterWasteType ?? this.filterWasteType,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  // Helper method to clear filterCategory
  HistoryState clearCategoryFilter() {
    return HistoryState(
      entries: entries,
      isLoading: isLoading,
      error: error,
      filterCategory: null,
      filterWasteType: filterWasteType,
      searchQuery: searchQuery,
    );
  }

  // Helper method to clear filterWasteType
  HistoryState clearWasteTypeFilter() {
    return HistoryState(
      entries: entries,
      isLoading: isLoading,
      error: error,
      filterCategory: filterCategory,
      filterWasteType: null,
      searchQuery: searchQuery,
    );
  }
}

/// Hasil penyimpanan satu sesi pemindaian.
///
/// Selain poin, membawa perubahan streak agar layar Hasil bisa menampilkan
/// popup perayaan ketika streak bertambah.
class ScanSaveResult {
  const ScanSaveResult({required this.points, required this.streak});

  final ScanPointResult points;
  final StreakUpdate streak;
}

class HistoryNotifier extends Notifier<HistoryState> {
  late HistoryRepository _repository;
  late String _userId;

  @override
  HistoryState build() {
    _repository = ref.watch(historyRepositoryProvider);
    _userId = ref.watch(currentUserIdProvider);
    Future.microtask(() => _init());
    return HistoryState();
  }

  Future<void> _init() async {
    try {
      if (AppConstants.seedDemoHistory) {
        final count = await _repository.count(userId: _userId);
        if (count == 0) {
          // Demo entries dengan variasi jenis sampah
          final now = DateTime.now();
          final demoEntries = [
            HistoryEntry(
              userId: _userId,
              scanKey: 'demo_1',
              wasteType: WasteType.cardboard,
              confidence: 0.942,
              isUncertain: false,
              pointsEarned: 20,
              createdAt: now.subtract(const Duration(days: 1, hours: 2)),
            ),
            HistoryEntry(
              userId: _userId,
              scanKey: 'demo_2',
              wasteType: WasteType.biological,
              confidence: 0.923,
              isUncertain: false,
              pointsEarned: 20,
              createdAt: now.subtract(const Duration(days: 2, hours: 5)),
            ),
            HistoryEntry(
              userId: _userId,
              scanKey: 'demo_3',
              wasteType: WasteType.plastic,
              confidence: 0.917,
              isUncertain: false,
              pointsEarned: 20,
              createdAt: now.subtract(const Duration(days: 3, hours: 1)),
            ),
            HistoryEntry(
              userId: _userId,
              scanKey: 'demo_4',
              wasteType: WasteType.battery,
              confidence: 0.885,
              isUncertain: false,
              pointsEarned: 20,
              createdAt: now.subtract(const Duration(days: 4, hours: 4)),
            ),
          ];
          for (var entry in demoEntries) {
            await _repository.add(entry);
          }
        }
      }
      await refresh();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      // 1. Fetch filtered by category in SQL
      final rawEntries = await _repository.getAll(
        userId: _userId,
        category: state.filterCategory,
      );

      // 2. Filter gabungan kategori & jenis sampah (AND)
      List<HistoryEntry> filteredEntries = rawEntries;

      if (state.filterCategory != null) {
        filteredEntries = filteredEntries
            .where((entry) => entry.category == state.filterCategory)
            .toList();
      }

      if (state.filterWasteType != null) {
        filteredEntries = filteredEntries
            .where((entry) => entry.wasteType == state.filterWasteType)
            .toList();
      }

      // 3. Pencarian mencocokkan judul, kategori, tanggal, nama jenis, dan labelKey
      if (state.searchQuery.isNotEmpty) {
        final query = state.searchQuery.toLowerCase();
        final dateFormat = DateFormat('dd MMM yyyy • HH:mm', 'id_ID');

        filteredEntries = filteredEntries.where((entry) {
          final title =
              entry.wasteType?.displayName ??
              entry.itemName ??
              (entry.category == WasteCategory.organik
                  ? 'Sampah Organik'
                  : 'Sampah Anorganik');
          final categoryLabel = entry.category == WasteCategory.organik
              ? 'Organik'
              : 'Anorganik';
          final wasteTypeName = entry.wasteType?.displayName ?? '';
          final wasteTypeKey = entry.wasteType?.labelKey ?? '';
          final dateStr = dateFormat.format(entry.createdAt);

          return title.toLowerCase().contains(query) ||
              categoryLabel.toLowerCase().contains(query) ||
              wasteTypeName.toLowerCase().contains(query) ||
              wasteTypeKey.toLowerCase().contains(query) ||
              dateStr.toLowerCase().contains(query);
        }).toList();
      }

      state = state.copyWith(entries: filteredEntries, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void setFilterCategory(WasteCategory? category) {
    if (category == null) {
      state = state.clearCategoryFilter();
    } else {
      state = state.copyWith(filterCategory: category);
    }
    refresh();
  }

  void setFilterWasteType(WasteType? wasteType) {
    if (wasteType == null) {
      state = state.clearWasteTypeFilter();
    } else {
      state = state.copyWith(filterWasteType: wasteType);
    }
    refresh();
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
    refresh();
  }

  Future<void> deleteEntry(HistoryEntry entry) async {
    if (entry.id == null) return;
    try {
      await _repository.delete(entry.id!);
      await refresh();
    } catch (e) {
      developer.log('Failed to delete history: $e');
    }
  }

  Future<void> restoreEntry(HistoryEntry entry) async {
    try {
      await _repository.restore(entry);
      await refresh();
    } catch (e) {
      developer.log('Failed to restore history: $e');
    }
  }

  /// Menyimpan hasil pemindaian ke riwayat.
  ///
  /// Multi-objek: setiap objek valid (`!isUncertain`) disimpan sebagai
  /// baris riwayat terpisah, dan poin dihitung per item. Bila tidak ada objek
  /// yang valid, hasil utama (tidak yakin) tetap disimpan satu kali seperti
  /// perilaku sebelumnya.
  ///
  /// Hasilnya juga memuat perubahan streak scan, dipakai layar Hasil untuk
  /// memunculkan popup "streak bertambah".
  Future<ScanSaveResult> saveScanToHistory(ClassificationResult result) async {
    try {
      final progression = ref.read(progressionServiceProvider);

      // Tamu tidak punya cloud, jadi streak dihitung lokal: ambil nilai
      // sebelum simpan supaya bisa dibandingkan dengan nilai sesudahnya.
      final previousStreak = progression == null
          ? await _currentStreakDays()
          : 0;

      final valid = result.detections.where((d) => !d.isUncertain).toList();
      final items = valid.isEmpty ? [result] : valid;

      ScanPointResult? first;
      var totalPoints = 0;
      for (var i = 0; i < items.length; i++) {
        final item = items[i];
        // Idempotent key: item pertama memakai format lama agar tidak
        // menduplikasi riwayat lama; item berikutnya diberi sufiks indeks.
        final baseKey =
            '${item.imagePath}_${item.timestamp.millisecondsSinceEpoch}';
        final scanKey = i == 0 ? baseKey : '${baseKey}_$i';
        final pointResult = await _saveItem(item, scanKey);
        first ??= pointResult;
        totalPoints += pointResult.points;
      }

      var streak = const StreakUpdate.unknown();
      if (progression != null) {
        try {
          streak = await progression.recomputeAll();
        } catch (e) {
          developer.log('Recompute gamifikasi gagal: $e');
        }
      } else {
        streak = StreakUpdate(
          previous: previousStreak,
          current: await _currentStreakDays(),
        );
      }

      await refresh();
      return ScanSaveResult(
        points: ScanPointResult(
          points: totalPoints,
          reason: first!.reason,
          pointsEarnedToday: first.pointsEarnedToday,
          dailyLimit: first.dailyLimit,
        ),
        streak: streak,
      );
    } catch (e) {
      // Kegagalan menyimpan tidak boleh mengganggu layar Hasil
      developer.log('Riwayat gagal disimpan: $e');
      throw Exception('Riwayat gagal disimpan');
    }
  }

  /// Streak hari beruntun saat ini (dihitung dari seluruh riwayat akun).
  Future<int> _currentStreakDays() async {
    final entries = await _repository.getAll(userId: _userId);
    return computeStreak(entries);
  }

  Future<ScanPointResult> _saveItem(
    ClassificationResult item,
    String scanKey,
  ) async {
    final ledger = PointsLedgerService(ref.read(sharedPreferencesProvider));
    final alreadyScannedToday = await _repository.hasScannedWasteTypeOn(
      userId: _userId,
      wasteType: item.wasteType,
      day: item.timestamp,
    );
    final pointsEarnedToday = await ledger.getDailyPoints(
      _userId,
      date: item.timestamp,
    );

    final pointResult = PointsPolicy.compute(
      isUncertain: item.isUncertain,
      alreadyScannedToday: alreadyScannedToday,
      pointsEarnedToday: pointsEarnedToday,
      enabled: MlConfig.showScanPoints,
    );

    final entry = HistoryEntry(
      scanKey: scanKey,
      userId: _userId,
      wasteType: item.wasteType,
      confidence: item.confidence,
      isUncertain: item.isUncertain,
      pointsEarned: pointResult.points,
      imagePath: item.croppedImagePath ?? item.imagePath,
      createdAt: item.timestamp,
    );

    await _repository.add(entry);
    await ledger.addDailyPoints(
      _userId,
      pointResult.points,
      date: item.timestamp,
    );
    return pointResult;
  }
}
final historyNotifierProvider = NotifierProvider<HistoryNotifier, HistoryState>(
  HistoryNotifier.new,
);

/// Statistik pemindaian (kategori, jenis sampah, dan total poin).
/// Ikut dihitung ulang setiap riwayat berubah, misalnya setelah scan baru.
final historyStatsProvider = FutureProvider.autoDispose<HistoryStats>((
  ref,
) async {
  ref.watch(historyNotifierProvider);
  final repository = ref.watch(historyRepositoryProvider);
  final userId = ref.watch(currentUserIdProvider);

  final byCategory = await repository.countByCategory(userId: userId);
  final byWasteType = await repository.countByWasteType(userId: userId);
  final totalPoints = await repository.sumPointsEarned(userId: userId);

  return HistoryStats(
    byCategory: byCategory,
    byWasteType: byWasteType,
    totalPoints: totalPoints,
  );
});
