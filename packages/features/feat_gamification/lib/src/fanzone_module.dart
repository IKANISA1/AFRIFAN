import 'package:core_router/core_router.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'screens/badges_screen.dart';
import 'screens/challenges_screen.dart';
import 'screens/club_fan_zone_screen.dart';
import 'screens/fanzone_hub_screen.dart';
import 'screens/fet_wallet_screen.dart';
import 'screens/fixtures_browser_screen.dart';
import 'screens/friend_challenge_screen.dart';
import 'screens/friends_list_screen.dart';
import 'screens/jackpot_challenge_screen.dart';
import 'screens/leaderboard_screen.dart';
import 'screens/league_hub_screen.dart';
import 'screens/league_standings_screen.dart';
import 'screens/match_detail_screen.dart';
import 'screens/my_predictions_screen.dart';
import 'screens/prediction_detail_screen.dart';
import 'screens/prediction_notifications_screen.dart';
import 'screens/prediction_settlement_screen.dart';
import 'screens/rewards_store_screen.dart';
import 'screens/share_card_generator_screen.dart';
import 'screens/streak_calendar_screen.dart';
import 'screens/team_profile_screen.dart';
import 'screens/token_history_screen.dart';

class FanzoneModule extends FeatureModule {
  @override
  String get featureKey => 'fanzone';

  @override
  bool isEnabled(Map<String, bool> featureFlags) {
    if (featureFlags.containsKey('fanzone')) {
      return featureFlags['fanzone'] ?? true;
    }

    final predictionEnabled = featureFlags['prediction'];
    final gamificationEnabled = featureFlags['gamification'];

    if (predictionEnabled == false && gamificationEnabled == false) {
      return false;
    }

    return true;
  }

  @override
  TabRoute get tabRoute => TabRoute(
    path: '/fanzone',
    label: 'FANZONE',
    icon: Icons.sports_soccer_outlined,
    activeIcon: Icons.sports_soccer_rounded,
    builder: (context, state) => const FanzoneHubScreen(),
  );

  @override
  List<RouteBase> get routes => [
    GoRoute(
      path: 'fixtures',
      name: 'fanzone-fixtures',
      builder: (context, state) =>
          const FixturesBrowserScreen(title: 'FIXTURES'),
    ),
    GoRoute(
      path: 'live',
      name: 'fanzone-live',
      builder: (context, state) => const FixturesBrowserScreen(
        statusFilter: 'live',
        title: 'LIVE MATCHES',
      ),
    ),
    GoRoute(
      path: 'my',
      name: 'fanzone-my-predictions',
      builder: (context, state) => const MyPredictionsScreen(),
      routes: [
        GoRoute(
          path: ':predictionId',
          name: 'fanzone-prediction-detail',
          builder: (context, state) => PredictionDetailScreen(
            predictionId: state.pathParameters['predictionId'] ?? '',
          ),
          routes: [
            GoRoute(
              path: 'settlement',
              name: 'fanzone-prediction-settlement',
              builder: (context, state) => PredictionSettlementScreen(
                predictionId: state.pathParameters['predictionId'] ?? '',
              ),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: 'match/:fixtureId',
      name: 'fanzone-match-detail',
      builder: (context, state) =>
          MatchDetailScreen(fixtureId: state.pathParameters['fixtureId'] ?? ''),
    ),
    GoRoute(
      path: 'wallet',
      name: 'fanzone-wallet',
      builder: (context, state) => const FetWalletScreen(),
    ),
    GoRoute(
      path: 'rewards',
      name: 'fanzone-rewards-store',
      builder: (context, state) => const RewardsStoreScreen(),
    ),
    GoRoute(
      path: 'history',
      name: 'fanzone-token-history',
      builder: (context, state) => const TokenHistoryScreen(),
    ),
    GoRoute(
      path: 'leaderboard',
      name: 'fanzone-leaderboard',
      builder: (context, state) => const LeaderboardScreen(),
    ),
    GoRoute(
      path: 'notifications',
      name: 'fanzone-notifications',
      builder: (context, state) => const PredictionNotificationsScreen(),
    ),
    GoRoute(
      path: 'challenges',
      name: 'fanzone-challenges',
      builder: (context, state) => const ChallengesScreen(),
    ),
    GoRoute(
      path: 'badges',
      name: 'fanzone-badges',
      builder: (context, state) => const BadgesScreen(),
    ),
    GoRoute(
      path: 'streak',
      name: 'fanzone-streak',
      builder: (context, state) => const StreakCalendarScreen(),
    ),
    GoRoute(
      path: 'jackpot',
      name: 'fanzone-jackpot',
      builder: (context, state) => const JackpotChallengeScreen(),
    ),
    GoRoute(
      path: 'share',
      name: 'fanzone-share',
      builder: (context, state) => const ShareCardGeneratorScreen(),
    ),
    GoRoute(
      path: 'friends',
      name: 'fanzone-friends',
      builder: (context, state) => const FriendsListScreen(),
    ),
    GoRoute(
      path: 'challenge',
      name: 'fanzone-friend-challenge',
      builder: (context, state) => const FriendChallengeScreen(),
    ),
    GoRoute(
      path: 'league',
      name: 'fanzone-league-hub-root',
      builder: (context, state) => const LeagueHubScreen(),
    ),
    GoRoute(
      path: 'league/:competitionSlug',
      name: 'fanzone-league-hub',
      builder: (context, state) => LeagueHubScreen(
        competitionSlug: state.pathParameters['competitionSlug'],
      ),
    ),
    GoRoute(
      path: 'standings/:competitionSlug',
      name: 'fanzone-league-standings',
      builder: (context, state) => LeagueStandingsScreen(
        competitionSlug: state.pathParameters['competitionSlug'] ?? '',
      ),
    ),
    GoRoute(
      path: 'team/:teamSlug',
      name: 'fanzone-team-profile',
      builder: (context, state) =>
          TeamProfileScreen(teamSlug: state.pathParameters['teamSlug'] ?? ''),
    ),
    GoRoute(
      path: 'club-zone',
      name: 'fanzone-club-zone',
      builder: (context, state) => const ClubFanZoneScreen(),
    ),
  ];

  @override
  List<RouteBase> get standaloneRoutes => <RouteBase>[
    GoRoute(path: '/predictions', redirect: (_, __) => '/fanzone/fixtures'),
    GoRoute(
      path: '/predictions/leaderboard',
      redirect: (_, __) => '/fanzone/leaderboard',
    ),
    GoRoute(
      path: '/predictions/notifications',
      redirect: (_, __) => '/fanzone/notifications',
    ),
    GoRoute(path: '/predictions/my', redirect: (_, __) => '/fanzone/my'),
    GoRoute(
      path: '/predictions/league',
      redirect: (_, __) => '/fanzone/league',
    ),
    GoRoute(
      path: '/predictions/my/:predictionId',
      redirect: (_, state) =>
          '/fanzone/my/${state.pathParameters['predictionId'] ?? ''}',
    ),
    GoRoute(
      path: '/predictions/my/:predictionId/settlement',
      redirect: (_, state) =>
          '/fanzone/my/${state.pathParameters['predictionId'] ?? ''}/settlement',
    ),
    GoRoute(
      path: '/predictions/league/:competitionSlug',
      redirect: (_, state) =>
          '/fanzone/league/${state.pathParameters['competitionSlug'] ?? ''}',
    ),
    GoRoute(
      path: '/predictions/league/:competitionSlug/standings',
      redirect: (_, state) =>
          '/fanzone/standings/${state.pathParameters['competitionSlug'] ?? ''}',
    ),
    GoRoute(
      path: '/predictions/team/:teamSlug',
      redirect: (_, state) =>
          '/fanzone/team/${state.pathParameters['teamSlug'] ?? ''}',
    ),
    GoRoute(
      path: '/predictions/match/:fixtureId',
      redirect: (_, state) =>
          '/fanzone/match/${state.pathParameters['fixtureId'] ?? ''}',
    ),
    GoRoute(path: '/fanzone/predictions', redirect: (_, __) => '/fanzone/my'),
    GoRoute(path: '/fet', redirect: (_, __) => '/fanzone'),
    GoRoute(
      path: '/fet/leaderboard',
      redirect: (_, __) => '/fanzone/leaderboard',
    ),
    GoRoute(path: '/fet/wallet', redirect: (_, __) => '/fanzone/wallet'),
    GoRoute(path: '/fet/rewards', redirect: (_, __) => '/fanzone/rewards'),
    GoRoute(path: '/fet/history', redirect: (_, __) => '/fanzone/history'),
    GoRoute(
      path: '/fet/challenges',
      redirect: (_, __) => '/fanzone/challenges',
    ),
    GoRoute(path: '/fet/badges', redirect: (_, __) => '/fanzone/badges'),
    GoRoute(path: '/fet/streak', redirect: (_, __) => '/fanzone/streak'),
    GoRoute(path: '/fet/jackpot', redirect: (_, __) => '/fanzone/jackpot'),
    GoRoute(path: '/fet/share', redirect: (_, __) => '/fanzone/share'),
    GoRoute(path: '/fet/friends', redirect: (_, __) => '/fanzone/friends'),
    GoRoute(path: '/fet/challenge', redirect: (_, __) => '/fanzone/challenge'),
    GoRoute(path: '/fet/club-zone', redirect: (_, __) => '/fanzone/club-zone'),
  ];
}
