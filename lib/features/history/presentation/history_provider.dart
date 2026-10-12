import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../domain/history_entry.dart';
import '../domain/history_repository.dart';
import '../data/sqflite_history_repository.dart';
import '../../scan/domain/classification_result.dart';
import '../../scan/domain/waste_category.dart';
import '../../../core/constants/ml_config.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/waste/waste_types.dart';

final historyRepositoryProvider = Provider<HistoryRepository>((ref) {
  return SqfliteHistoryRepository();
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

class HistoryNotifier extends Notifier<HistoryState> {
  late final HistoryRepository _repository;

  @override
  HistoryState build() {
    _repository = ref.watch(historyRepositoryProvider);
    Future.microtask(() => _init());
    return HistoryState();
  }

  Future<void> _init() async {
    try {
      if (AppConstants.seedDemoHistory) {
        final count = await _repository.count();
        if (count == 0) {
          // Demo entries dengan variasi jenis sampah
          final now = DateTime.now();
          final demoEntries = [
            HistoryEntry(
              scanKey: 'demo_1',
              wasteType: WasteType.cardboard,
              confidence: 0.942,
              isUncertain: false,
              pointsEarned: 20,
              createdAt: now.subtract(const Duration(days: 1, hours: 2)),
            ),
            HistoryEntry(
              scanKey: 'demo_2',
              wasteType: WasteType.biological,
              confidence: 0.923,
              isUncertain: false,
              pointsEarned: 20,
              createdAt: now.subtract(const Duration(days: 2, hours: 5)),
            ),
            HistoryEntry(
              scanKey: 'demo_3',
              wasteType: WasteType.plastic,
              confidence: 0.917,
              isUncertain: false,
              pointsEarned: 20,
              createdAt: now.subtract(const Duration(days: 3, hours: 1)),
            ),
            HistoryEntry(
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
      final rawEntries = await _repository.getAll(category: state.filterCategory);
      
      // 2. Filter gabungan kategori & jenis sampah (AND)
      List<HistoryEntry> filteredEntries = rawEntries;

      if (state.filterCategory != null) {
        filteredEntries = filteredEntries.where((entry) => entry.category == state.filterCategory).toList();
      }

      if (state.filterWasteType != null) {
        filteredEntries = filteredEntries.where((entry) => entry.wasteType == state.filterWasteType).toList();
      }

      // 3. Pencarian mencocokkan judul, kategori, tanggal, nama jenis, dan labelKey
      if (state.searchQuery.isNotEmpty) {
        final query = state.searchQuery.toLowerCase();
        final dateFormat = DateFormat('dd MMM yyyy • HH:mm', 'id_ID');
        
        filteredEntries = filteredEntries.where((entry) {
          final title = entry.wasteType?.displayName ?? entry.itemName ?? (entry.category == WasteCategory.organik ? 'Sampah Organik' : 'Sampah Anorganik');
          final categoryLabel = entry.category == WasteCategory.organik ? 'Organik' : 'Anorganik';
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

  Future<void> saveScanToHistory(ClassificationResult result) async {
    try {
      // Idempotent key to avoid duplicate entries for the exact same scan result
      final scanKey = '${result.imagePath}_${result.timestamp.millisecondsSinceEpoch}';
      
      final points = MlConfig.showScanPoints ? MlConfig.scanPointsReward : 0;
      
      final entry = HistoryEntry(
        scanKey: scanKey,
        wasteType: result.wasteType,
        confidence: result.confidence,
        isUncertain: result.isUncertain,
        pointsEarned: points,
        imagePath: result.imagePath,
        createdAt: result.timestamp,
      );
      
      await _repository.add(entry);
      await refresh(); // Refresh list if needed
    } catch (e) {
      // Kegagalan menyimpan tidak boleh mengganggu layar Hasil
      developer.log('Riwayat gagal disimpan: $e');
      throw Exception('Riwayat gagal disimpan');
    }
  }
}

final historyNotifierProvider = NotifierProvider<HistoryNotifier, HistoryState>(
  HistoryNotifier.new
);
