import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

import '../widgets/main_wrapper.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/scan/presentation/scan_screen.dart';
import '../../features/result/presentation/result_screen.dart';
import '../../features/gamification/presentation/guide_screen.dart';
import '../../features/history/presentation/history_screen.dart';
import '../../features/gamification/presentation/mission_screen.dart';
import '../../features/gamification/presentation/badge_detail_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final GlobalKey<NavigatorState> _homeNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'home');
final GlobalKey<NavigatorState> _scanNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'scan');
final GlobalKey<NavigatorState> _profileNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'profile');

final goRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/login', // Nanti diubah sesuai status auth
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    
    // Rute tanpa bottom nav (layar detail)
    GoRoute(
      path: '/result',
      builder: (context, state) => const ResultScreen(),
    ),
    GoRoute(
      path: '/guide',
      builder: (context, state) => const GuideScreen(),
    ),
    GoRoute(
      path: '/history',
      builder: (context, state) => const HistoryScreen(),
    ),
    GoRoute(
      path: '/mission',
      builder: (context, state) => const MissionScreen(),
    ),
    GoRoute(
      path: '/badge-detail',
      builder: (context, state) => const BadgeDetailScreen(),
    ),

    // Rute dengan bottom nav
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return MainWrapper(navigationShell: navigationShell);
      },
      branches: [
        // Tab 1: Beranda
        StatefulShellBranch(
          navigatorKey: _homeNavigatorKey,
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const HomeScreen(),
            ),
          ],
        ),
        // Tab 2: Pindai
        StatefulShellBranch(
          navigatorKey: _scanNavigatorKey,
          routes: [
            GoRoute(
              path: '/scan',
              builder: (context, state) => const ScanScreen(),
            ),
          ],
        ),
        // Tab 3: Profil
        StatefulShellBranch(
          navigatorKey: _profileNavigatorKey,
          routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);
