import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import 'widgets/mission_tab.dart';
import 'widgets/badge_tab.dart';

class MissionScreen extends StatefulWidget {
  const MissionScreen({super.key});

  @override
  State<MissionScreen> createState() => _MissionScreenState();
}

class _MissionScreenState extends State<MissionScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    // Redirect if gamification is disabled
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!AppConstants.gamificationEnabled && mounted) {
        context.go('/profile');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!AppConstants.gamificationEnabled) {
      return const Scaffold(); // Return empty while redirecting
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Misi & Lencana',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/profile');
            }
          },
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          _buildSegmentControl(),
          const SizedBox(height: 16),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: const [MissionTab(), BadgeTab()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentControl() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _selectedIndex = 0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _selectedIndex == 0
                      ? AppColors.primaryGreen
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  'Misi Aktif',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _selectedIndex == 0
                        ? Colors.white
                        : Colors.grey.shade600,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _selectedIndex = 1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _selectedIndex == 1
                      ? AppColors.primaryGreen
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  'Koleksi Badge',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _selectedIndex == 1
                        ? Colors.white
                        : Colors.grey.shade600,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
