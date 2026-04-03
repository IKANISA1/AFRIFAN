import 'package:core_router/core_router.dart';
import 'package:go_router/go_router.dart';

import 'screens/badges_screen.dart';
import 'screens/challenges_screen.dart';
import 'screens/leaderboard_screen.dart';
import 'screens/streak_calendar_screen.dart';
import 'screens/xp_dashboard_screen.dart';

/// Gamification feature module — XP dashboard + leaderboard.
/// Accessed via Home quick actions, NOT a bottom nav tab.
class GamificationModule extends FeatureModule {
  @override
  String get featureKey => 'gamification';

  // No tabRoute — accessed via Home quick actions

  @override
  List<RouteBase> get routes => [
    GoRoute(
      path: '/xp',
      name: 'xp-dashboard',
      builder: (context, state) => const XpDashboardScreen(),
      routes: [
        GoRoute(
          path: 'leaderboard',
          name: 'leaderboard',
          builder: (context, state) => const LeaderboardScreen(),
        ),
        GoRoute(
          path: 'challenges',
          builder: (context, state) => const ChallengesScreen(),
        ),
        GoRoute(
          path: 'badges',
          builder: (context, state) => const BadgesScreen(),
        ),
        GoRoute(
          path: 'streak',
          builder: (context, state) => const StreakCalendarScreen(),
        ),
      ],
    ),
  ];
}
