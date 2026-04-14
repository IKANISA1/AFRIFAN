import 'package:core_router/core_router.dart';
import 'package:go_router/go_router.dart';

import 'screens/badges_screen.dart';
import 'screens/challenges_screen.dart';
import 'screens/club_fan_zone_screen.dart';
import 'screens/fet_wallet_screen.dart';
import 'screens/friend_challenge_screen.dart';
import 'screens/friends_list_screen.dart';
import 'screens/jackpot_challenge_screen.dart';
import 'screens/leaderboard_screen.dart';
import 'screens/rewards_store_screen.dart';
import 'screens/share_card_generator_screen.dart';
import 'screens/streak_calendar_screen.dart';
import 'screens/token_history_screen.dart';
import 'screens/xp_dashboard_screen.dart';

/// Gamification module — FET, wallet, rewards progress, and challenge surfaces.
///
/// Prediction browsing and market placement live in `feat_prediction`.
/// This module owns the reward and retention layer on top.
class GamificationModule extends FeatureModule {
  @override
  String get featureKey => 'gamification';

  @override
  bool isEnabled(Map<String, bool> featureFlags) {
    if (featureFlags.containsKey('gamification')) {
      return featureFlags['gamification'] ?? true;
    }

    if (featureFlags.containsKey('fanzone')) {
      return featureFlags['fanzone'] ?? true;
    }

    return true;
  }

  @override
  List<RouteBase> get routes => <RouteBase>[
    GoRoute(
      path: '/fet',
      name: 'fet-dashboard',
      builder: (context, state) => const XpDashboardScreen(),
      routes: <RouteBase>[
        GoRoute(
          path: 'leaderboard',
          name: 'fet-leaderboard',
          builder: (context, state) => const LeaderboardScreen(),
        ),
        GoRoute(
          path: 'wallet',
          name: 'fet-wallet',
          builder: (context, state) => const FetWalletScreen(),
        ),
        GoRoute(
          path: 'rewards',
          name: 'fet-rewards',
          builder: (context, state) => const RewardsStoreScreen(),
        ),
        GoRoute(
          path: 'history',
          name: 'fet-history',
          builder: (context, state) => const TokenHistoryScreen(),
        ),
        GoRoute(
          path: 'challenges',
          name: 'fet-challenges',
          builder: (context, state) => const ChallengesScreen(),
        ),
        GoRoute(
          path: 'badges',
          name: 'fet-badges',
          builder: (context, state) => const BadgesScreen(),
        ),
        GoRoute(
          path: 'streak',
          name: 'fet-streak',
          builder: (context, state) => const StreakCalendarScreen(),
        ),
        GoRoute(
          path: 'jackpot',
          name: 'fet-jackpot',
          builder: (context, state) => const JackpotChallengeScreen(),
        ),
        GoRoute(
          path: 'share',
          name: 'fet-share',
          builder: (context, state) => const ShareCardGeneratorScreen(),
        ),
        GoRoute(
          path: 'friends',
          name: 'fet-friends',
          builder: (context, state) => const FriendsListScreen(),
        ),
        GoRoute(
          path: 'challenge',
          name: 'fet-friend-challenge',
          builder: (context, state) => const FriendChallengeScreen(),
        ),
        GoRoute(
          path: 'club-zone',
          name: 'fet-club-zone',
          builder: (context, state) => const ClubFanZoneScreen(),
        ),
      ],
    ),
  ];

  @override
  List<RouteBase> get standaloneRoutes => <RouteBase>[
    GoRoute(path: '/fanzone/wallet', redirect: (_, __) => '/fet/wallet'),
    GoRoute(
      path: '/fanzone/leaderboard',
      redirect: (_, __) => '/fet/leaderboard',
    ),
    GoRoute(path: '/fanzone/rewards', redirect: (_, __) => '/fet/rewards'),
    GoRoute(path: '/fanzone/history', redirect: (_, __) => '/fet/history'),
    GoRoute(
      path: '/fanzone/challenges',
      redirect: (_, __) => '/fet/challenges',
    ),
    GoRoute(path: '/fanzone/badges', redirect: (_, __) => '/fet/badges'),
    GoRoute(path: '/fanzone/streak', redirect: (_, __) => '/fet/streak'),
    GoRoute(path: '/fanzone/jackpot', redirect: (_, __) => '/fet/jackpot'),
    GoRoute(path: '/fanzone/share', redirect: (_, __) => '/fet/share'),
    GoRoute(path: '/fanzone/friends', redirect: (_, __) => '/fet/friends'),
    GoRoute(path: '/fanzone/challenge', redirect: (_, __) => '/fet/challenge'),
    GoRoute(path: '/fanzone/club-zone', redirect: (_, __) => '/fet/club-zone'),
  ];
}
