import 'package:core_router/core_router.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'screens/fixtures_browser_screen.dart';
import 'screens/league_hub_screen.dart';
import 'screens/league_standings_screen.dart';
import 'screens/match_detail_screen.dart';
import 'screens/my_predictions_screen.dart';
import 'screens/prediction_detail_screen.dart';
import 'screens/prediction_leaderboard_screen.dart';
import 'screens/prediction_notifications_screen.dart';
import 'screens/prediction_settlement_screen.dart';
import 'screens/team_profile_screen.dart';

/// Prediction feature module — match predictions, markets, and FET earn.
class PredictionModule extends FeatureModule {
  @override
  String get featureKey => 'prediction';

  @override
  bool isEnabled(Map<String, bool> featureFlags) {
    if (featureFlags.containsKey('prediction')) {
      return featureFlags['prediction'] ?? true;
    }

    if (featureFlags.containsKey('fanzone')) {
      return featureFlags['fanzone'] ?? true;
    }

    return true;
  }

  @override
  TabRoute get tabRoute => TabRoute(
    path: '/predictions',
    label: 'PREDICT',
    icon: Icons.sports_soccer_outlined,
    activeIcon: Icons.sports_soccer_rounded,
    builder: (context, state) => const FixturesBrowserScreen(),
  );

  @override
  List<RouteBase> get routes => <RouteBase>[
    GoRoute(
      path: 'my',
      name: 'my-predictions',
      builder: (context, state) => const MyPredictionsScreen(),
      routes: <RouteBase>[
        GoRoute(
          path: ':predictionId',
          name: 'prediction-detail',
          builder: (context, state) => PredictionDetailScreen(
            predictionId: state.pathParameters['predictionId'] ?? '',
          ),
          routes: <RouteBase>[
            GoRoute(
              path: 'settlement',
              name: 'prediction-settlement',
              builder: (context, state) => PredictionSettlementScreen(
                predictionId: state.pathParameters['predictionId'] ?? '',
              ),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: 'leaderboard',
      name: 'prediction-leaderboard',
      builder: (context, state) => const PredictionLeaderboardScreen(),
    ),
    GoRoute(
      path: 'notifications',
      name: 'prediction-notifications',
      builder: (context, state) => const PredictionNotificationsScreen(),
    ),
    GoRoute(
      path: 'league',
      name: 'prediction-league-root',
      builder: (context, state) => const LeagueHubScreen(),
    ),
    GoRoute(
      path: 'league/:competitionSlug',
      name: 'prediction-league-hub',
      builder: (context, state) => LeagueHubScreen(
        competitionSlug: state.pathParameters['competitionSlug'],
      ),
      routes: <RouteBase>[
        GoRoute(
          path: 'standings',
          name: 'prediction-league-standings',
          builder: (context, state) => LeagueStandingsScreen(
            competitionSlug: state.pathParameters['competitionSlug'] ?? '',
          ),
        ),
      ],
    ),
    GoRoute(
      path: 'team/:teamSlug',
      name: 'prediction-team-profile',
      builder: (context, state) =>
          TeamProfileScreen(teamSlug: state.pathParameters['teamSlug'] ?? ''),
    ),
    GoRoute(
      path: 'match/:fixtureId',
      name: 'match-detail',
      builder: (context, state) =>
          MatchDetailScreen(fixtureId: state.pathParameters['fixtureId'] ?? ''),
    ),
  ];

  @override
  List<RouteBase> get standaloneRoutes => <RouteBase>[
    GoRoute(path: '/fanzone', redirect: (_, __) => '/predictions'),
    GoRoute(path: '/fanzone/fixtures', redirect: (_, __) => '/predictions'),
    GoRoute(path: '/fanzone/live', redirect: (_, __) => '/live'),
    GoRoute(
      path: '/fanzone/leaderboard',
      redirect: (_, __) => '/predictions/leaderboard',
    ),
    GoRoute(path: '/fanzone/my', redirect: (_, __) => '/predictions/my'),
    GoRoute(
      path: '/fanzone/my/:predictionId/settlement',
      redirect: (_, state) =>
          '/predictions/my/'
          '${state.pathParameters['predictionId'] ?? ''}/settlement',
    ),
    GoRoute(
      path: '/fanzone/league',
      redirect: (_, __) => '/predictions/league',
    ),
    GoRoute(
      path: '/fanzone/notifications',
      redirect: (_, __) => '/predictions/notifications',
    ),
    GoRoute(
      path: '/fanzone/league/:competitionSlug',
      redirect: (_, state) =>
          '/predictions/league/'
          '${state.pathParameters['competitionSlug'] ?? ''}',
    ),
    GoRoute(
      path: '/fanzone/standings/:competitionSlug',
      redirect: (_, state) =>
          '/predictions/league/'
          '${state.pathParameters['competitionSlug'] ?? ''}/standings',
    ),
    GoRoute(
      path: '/fanzone/team/:teamSlug',
      redirect: (_, state) =>
          '/predictions/team/${state.pathParameters['teamSlug'] ?? ''}',
    ),
    GoRoute(
      path: '/fanzone/match/:fixtureId',
      redirect: (_, state) =>
          '/predictions/match/${state.pathParameters['fixtureId'] ?? ''}',
    ),
    GoRoute(
      path: '/fanzone/predictions',
      redirect: (_, __) => '/predictions/my',
    ),
  ];
}
