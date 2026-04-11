import 'package:core_router/core_router.dart';
import 'package:go_router/go_router.dart';

import 'screens/fantasy_competition_detail_screen.dart';
import 'screens/fantasy_create_entry_screen.dart';
import 'screens/fantasy_hub_screen.dart';
import 'screens/fantasy_leaderboard_screen.dart';
import 'screens/fantasy_rules_screen.dart';
import 'screens/fantasy_squad_builder_screen.dart';

class FantasyModule extends FeatureModule {
  @override
  String get featureKey => 'fantasy';

  @override
  List<RouteBase> get routes => [
    GoRoute(
      path: '/fantasy',
      builder: (context, state) => const FantasyHubScreen(),
      routes: [
        GoRoute(
          path: 'competition/:slug',
          builder: (context, state) => FantasyCompetitionDetailScreen(
            slug: state.pathParameters['slug'] ?? '',
          ),
          routes: [
            GoRoute(
              path: 'rules',
              builder: (context, state) =>
                  FantasyRulesScreen(slug: state.pathParameters['slug'] ?? ''),
            ),
            GoRoute(
              path: 'leaderboard',
              builder: (context, state) => FantasyLeaderboardScreen(
                slug: state.pathParameters['slug'] ?? '',
              ),
            ),
            GoRoute(
              path: 'entry',
              builder: (context, state) => FantasyCreateEntryScreen(
                slug: state.pathParameters['slug'] ?? '',
              ),
            ),
            GoRoute(
              path: 'squad',
              builder: (context, state) => FantasySquadBuilderScreen(
                slug: state.pathParameters['slug'] ?? '',
              ),
            ),
          ],
        ),
      ],
    ),
  ];
}
