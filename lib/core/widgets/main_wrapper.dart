import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class CurrentBottomNavIndex extends Notifier<int> {
  @override
  int build() => 0;

  void setIndex(int index) {
    state = index;
  }
}

final currentBottomNavIndexProvider =
    NotifierProvider<CurrentBottomNavIndex, int>(CurrentBottomNavIndex.new);

class MainWrapper extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const MainWrapper({super.key, required this.navigationShell});

  @override
  ConsumerState<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends ConsumerState<MainWrapper> {
  DateTime? _lastPressedAt;

  void _onTabSelected(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = widget.navigationShell.currentIndex;

    // Update provider when navigationShell.currentIndex changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(currentBottomNavIndexProvider) != currentIndex) {
        ref.read(currentBottomNavIndexProvider.notifier).setIndex(currentIndex);
      }
    });

    final isScanActive = currentIndex == 1;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        if (currentIndex != 0) {
          widget.navigationShell.goBranch(0);
          return;
        }

        final now = DateTime.now();
        if (_lastPressedAt == null ||
            now.difference(_lastPressedAt!) > const Duration(seconds: 2)) {
          _lastPressedAt = now;
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tekan sekali lagi untuk keluar'),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }

        SystemNavigator.pop();
      },
      child: Scaffold(
        body: widget.navigationShell,
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        floatingActionButton: Container(
          width: 58,
          height: 58,
          margin: const EdgeInsets.only(top: 8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: isScanActive
                    ? const Color(0xFF047857).withValues(alpha: 0.5)
                    : const Color(0xFF10B981).withValues(alpha: 0.38),
                blurRadius: 14,
                spreadRadius: isScanActive ? 3 : 1,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: FloatingActionButton(
            heroTag: 'mainDockedScanFab',
            onPressed: () => _onTabSelected(1),
            elevation: 0,
            highlightElevation: 0,
            backgroundColor: Colors.transparent,
            shape: const CircleBorder(),
            child: Ink(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isScanActive
                      ? [const Color(0xFF047857), const Color(0xFF065F46)]
                      : [const Color(0xFF10B981), const Color(0xFF059669)],
                ),
                border: Border.all(
                  color: Colors.white,
                  width: 2.5,
                ),
              ),
              child: const Icon(
                Icons.crop_free,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        ),
        bottomNavigationBar: BottomAppBar(
          shape: const CircularNotchedRectangle(),
          notchMargin: 8.0,
          color: Colors.white,
          elevation: 12,
          shadowColor: Colors.black.withValues(alpha: 0.15),
          padding: EdgeInsets.zero,
          child: BottomNavigationBar(
            currentIndex: currentIndex,
            selectedItemColor: const Color(0xFF059669),
            unselectedItemColor: Colors.grey.shade500,
            backgroundColor: Colors.transparent,
            elevation: 0,
            type: BottomNavigationBarType.fixed,
            onTap: _onTabSelected,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home),
                label: 'Beranda',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.crop_free, color: Colors.transparent),
                activeIcon: Icon(Icons.crop_free, color: Colors.transparent),
                label: 'Pindai',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                activeIcon: Icon(Icons.person),
                label: 'Profil',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
