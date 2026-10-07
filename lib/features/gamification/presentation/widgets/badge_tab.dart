import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gamification_provider.dart';
import 'badge_tile.dart';
import 'badge_detail_sheet.dart';

class BadgeTab extends ConsumerStatefulWidget {
  const BadgeTab({super.key});

  @override
  ConsumerState<BadgeTab> createState() => _BadgeTabState();
}

class _BadgeTabState extends ConsumerState<BadgeTab> {
  String _selectedFilter = 'Semua';
  final List<String> _filters = ['Semua', 'Terbuka', 'Terkunci', 'Organik', 'Anorganik', 'Streak'];

  @override
  Widget build(BuildContext context) {
    final badgesAsync = ref.watch(badgesProvider);

    return badgesAsync.when(
      data: (badges) {
        final unlockedCount = badges.where((b) => b.isOpen).length;
        final totalCount = badges.length;
        final progressRatio = totalCount > 0 ? unlockedCount / totalCount : 0.0;

        var filteredBadges = badges.where((b) {
          if (_selectedFilter == 'Semua') return true;
          if (_selectedFilter == 'Terbuka') return b.isOpen;
          if (_selectedFilter == 'Terkunci') return !b.isOpen;
          if (_selectedFilter == 'Organik') return b.kategori == 'organik';
          if (_selectedFilter == 'Anorganik') return b.kategori == 'anorganik';
          if (_selectedFilter == 'Streak') return b.kategori == 'streak';
          return true;
        }).toList();

        return Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Koleksi Anda', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('$unlockedCount dari $totalCount badge terbuka', style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: progressRatio,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _filters.length,
                itemBuilder: (context, index) {
                  final filter = _filters[index];
                  final isSelected = _selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(filter, style: TextStyle(color: isSelected ? Colors.white : Colors.black87)),
                      selected: isSelected,
                      selectedColor: Colors.blue,
                      onSelected: (selected) {
                        if (selected) setState(() => _selectedFilter = filter);
                      },
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: filteredBadges.map((badge) {
                    return SizedBox(
                      width: (MediaQuery.of(context).size.width - 48) / 2, // 2 columns minus paddings
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => BadgeDetailSheet.show(context, badge),
                        child: BadgeTile(badge: badge),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Gagal memuat lencana'),
            TextButton(
              onPressed: () => ref.refresh(badgesProvider),
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }
}
