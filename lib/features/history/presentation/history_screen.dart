import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import 'history_provider.dart';
import '../domain/history_entry.dart';
import '../../scan/domain/waste_category.dart';
import '../../scan/domain/classification_result.dart';
import '../../result/data/guidance_content.dart';
import '../../../core/waste/waste_types.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(historyNotifierProvider.notifier).setSearchQuery(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(historyNotifierProvider);
    final notifier = ref.read(historyNotifierProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Pemindaian', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        leading: IconButton(
          tooltip: 'Kembali',
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
      ),
      body: Column(
        children: [
          _buildSearchAndFilter(state, notifier),
          Expanded(
            child: _buildBody(state, notifier),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter(HistoryState state, HistoryNotifier notifier) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Search Field
          TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Cari',
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      tooltip: 'Hapus pencarian',
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                        setState(() {});
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.grey[200],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
            ),
          ),
          const SizedBox(height: 16),
          // Filters
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('Semua', null, state, notifier),
                const SizedBox(width: 8),
                _buildFilterChip('Organik', WasteCategory.organik, state, notifier),
                const SizedBox(width: 8),
                _buildFilterChip('Anorganik', WasteCategory.anorganik, state, notifier),
                const SizedBox(width: 8),
                _buildWasteTypeFilterChip(context, state, notifier),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWasteTypeFilterChip(BuildContext context, HistoryState state, HistoryNotifier notifier) {
    final isSelected = state.filterWasteType != null;
    return InputChip(
      avatar: isSelected ? null : const Icon(Icons.arrow_drop_down, size: 18, color: Colors.black54),
      label: Text(
        isSelected ? 'Jenis: ${state.filterWasteType!.displayName}' : 'Jenis',
      ),
      selected: isSelected,
      onSelected: (_) {
        _showWasteTypeFilterSheet(context, state, notifier);
      },
      onDeleted: isSelected ? () => notifier.setFilterWasteType(null) : null,
      deleteIcon: isSelected ? const Icon(Icons.close, size: 16, color: Colors.white) : null,
      deleteButtonTooltipMessage: 'Hapus filter jenis',
      selectedColor: Colors.blue,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      backgroundColor: Colors.grey[200],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Colors.transparent),
      ),
      showCheckmark: false,
    );
  }

  void _showWasteTypeFilterSheet(BuildContext context, HistoryState state, HistoryNotifier notifier) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Pilih Jenis Sampah',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.all_inclusive, color: Colors.grey),
                      title: const Text('Semua jenis'),
                      selected: state.filterWasteType == null,
                      trailing: state.filterWasteType == null ? const Icon(Icons.check, color: Colors.blue) : null,
                      onTap: () {
                        notifier.setFilterWasteType(null);
                        Navigator.pop(ctx);
                      },
                    ),
                    ...WasteType.values.map((type) {
                      final isSelected = state.filterWasteType == type;
                      return ListTile(
                        leading: Icon(
                          type.icon,
                          color: type.category == WasteCategory.organik ? Colors.green : Colors.blue,
                        ),
                        title: Text(type.displayName),
                        subtitle: Text(
                          type.category == WasteCategory.organik ? 'Organik' : (type.isHazardous ? 'Anorganik (B3)' : 'Anorganik'),
                          style: const TextStyle(fontSize: 12),
                        ),
                        selected: isSelected,
                        trailing: isSelected ? const Icon(Icons.check, color: Colors.blue) : null,
                        onTap: () {
                          notifier.setFilterWasteType(type);
                          Navigator.pop(ctx);
                        },
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(String label, WasteCategory? category, HistoryState state, HistoryNotifier notifier) {
    final isSelected = state.filterCategory == category;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        notifier.setFilterCategory(category);
      },
      selectedColor: Colors.blue,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      backgroundColor: Colors.grey[200],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Colors.transparent),
      ),
      showCheckmark: false,
    );
  }

  Widget _buildBody(HistoryState state, HistoryNotifier notifier) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Terjadi kesalahan:\n${state.error}', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => notifier.refresh(),
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }

    if (state.entries.isEmpty) {
      if (state.searchQuery.isNotEmpty || state.filterCategory != null || state.filterWasteType != null) {
        // Not found
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off, size: 80, color: Colors.grey),
              SizedBox(height: 16),
              Text('Tidak ditemukan', style: TextStyle(fontSize: 16, color: Colors.grey)),
            ],
          ),
        );
      } else {
        // Empty state
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.history, size: 80, color: Colors.grey[400]),
              const SizedBox(height: 16),
              const Text('Belum ada riwayat pemindaian', style: TextStyle(fontSize: 16, color: Colors.grey)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go('/scan'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: const Text('Mulai Pindai'),
              ),
            ],
          ),
        );
      }
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: state.entries.length,
      itemBuilder: (context, index) {
        final entry = state.entries[index];
        return _buildHistoryCard(entry, notifier);
      },
    );
  }

  Widget _buildHistoryCard(HistoryEntry entry, HistoryNotifier notifier) {
    final isOrganic = entry.category == WasteCategory.organik;
    final color = isOrganic ? Colors.green : Colors.blue;
    final icon = entry.wasteType?.icon ?? (isOrganic ? Icons.eco : Icons.recycling);
    final title = entry.wasteType?.displayName ?? (isOrganic ? 'Sampah Organik' : 'Sampah Anorganik');
    final categoryLabel = isOrganic ? 'Organik' : 'Anorganik';
    
    final dateFormat = DateFormat('dd MMM yyyy • HH:mm', 'id_ID');
    final dateStr = dateFormat.format(entry.createdAt);

    final numFormat = NumberFormat('#,##0.0', 'id_ID');
    final confPercent = numFormat.format(entry.confidence * 100);

    return Dismissible(
      key: ValueKey(entry.id ?? entry.scanKey),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (direction) async {
        await notifier.deleteEntry(entry);
        if (!mounted) return;
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Riwayat dihapus'),
            action: SnackBarAction(
              label: 'Urungkan',
              onPressed: () {
                notifier.restoreEntry(entry);
              },
            ),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
        color: Colors.white,
        child: InkWell(
          onTap: () => _showEntryDetail(context, entry),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Icon Box
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: 16),
                
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateStr,
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 4,
                        children: [
                          Text(
                            categoryLabel,
                            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          if (entry.isHazardous)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.deepOrange.shade50,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.deepOrange.shade300, width: 0.8),
                              ),
                              child: Text(
                                'B3',
                                style: TextStyle(
                                  color: Colors.deepOrange.shade800,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          if (entry.pointsEarned > 0)
                            Text(
                              ' • ${entry.pointsEarned} Poin',
                              style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          if (entry.isUncertain)
                            const Text(
                              ' • Tidak yakin',
                              style: TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Right part
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$confPercent%',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Akurasi',
                      style: TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Lihat',
                            style: TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.bold),
                          ),
                          Icon(Icons.chevron_right, size: 14, color: Colors.blue),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEntryDetail(BuildContext context, HistoryEntry entry) {
    final isOrganic = entry.category == WasteCategory.organik;
    final color = isOrganic ? Colors.green : Colors.blue;
    final title = entry.wasteType?.displayName ?? (isOrganic ? 'Sampah Organik' : 'Sampah Anorganik');
    final icon = entry.wasteType?.icon ?? (isOrganic ? Icons.eco : Icons.recycling);
    final dateFormat = DateFormat('EEEE, dd MMMM yyyy • HH:mm', 'id_ID');
    final dateStr = dateFormat.format(entry.createdAt);
    final numFormat = NumberFormat('#,##0.0', 'id_ID');
    final confPercent = numFormat.format(entry.confidence * 100);
    final wasteType = entry.wasteType ?? (isOrganic ? WasteType.biological : WasteType.cardboard);
    final guidance = GuidanceContent.getGuidance(wasteType);

    final hasImage = entry.imagePath != null &&
        entry.imagePath!.isNotEmpty &&
        File(entry.imagePath!).existsSync();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    if (hasImage) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.file(
                          File(entry.imagePath!),
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ] else ...[
                      Container(
                        height: 120,
                        decoration: BoxDecoration(
                          color: color.withAlpha(25),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: color.withAlpha(50)),
                        ),
                        child: Center(
                          child: Icon(
                            icon,
                            size: 64,
                            color: color,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Wrap(
                          spacing: 6,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: color.withAlpha(30),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: color),
                              ),
                              child: Text(
                                isOrganic ? 'Organik' : 'Anorganik',
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            if (entry.isHazardous)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.deepOrange.shade50,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.deepOrange.shade300),
                                ),
                                child: Text(
                                  'B3',
                                  style: TextStyle(
                                    color: Colors.deepOrange.shade800,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      dateStr,
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              Text(
                                '$confPercent%',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Akurasi Deteksi',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                          Container(width: 1, height: 36, color: Colors.grey[300]),
                          Column(
                            children: [
                              Text(
                                '+${entry.pointsEarned}',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Poin Didapat',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Rekomendasi Penanganan',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 10),
                    ...guidance.summaryPoints.map((point) => Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 6, right: 10),
                                child: CircleAvatar(
                                  radius: 4,
                                  backgroundColor: color,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  point,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        )),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        final classificationResult = ClassificationResult(
                          wasteType: entry.wasteType ?? (isOrganic ? WasteType.biological : WasteType.cardboard),
                          confidence: entry.confidence,
                          imagePath: entry.imagePath ?? '',
                          isUncertain: entry.isUncertain,
                          timestamp: entry.createdAt,
                        );
                        context.push('/scan/panduan', extra: classificationResult);
                      },
                      icon: const Icon(Icons.menu_book),
                      label: const Text('Lihat Panduan Lengkap'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(100),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Tutup'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
