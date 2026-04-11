import 'package:core_router/core_router.dart';
import 'package:go_router/go_router.dart';

import 'features/ai_advisor/ai_advisor_sheet.dart';
import 'features/chips/chip_activation_sheet.dart';
import 'features/competitions/competition_browser_screen.dart';
import 'features/competitions/competition_detail_screen.dart';
import 'features/leaderboard/leaderboard_screen.dart';
import 'features/live_gameweek/live_gameweek_screen.dart';
import 'features/player_detail/player_detail_sheet.dart';
import 'features/squad_builder/squad_builder_screen.dart';
import 'features/transfers/transfer_portal_screen.dart';
import 'features/world_cup/wc_bracket_screen.dart';

class AfriclubFantasyModule extends FeatureModule {
  @override
  String get featureKey => 'fantasy';

  @override
  List<RouteBase> get routes => <RouteBase>[
    GoRoute(
      path: '/fantasy',
      builder: (context, state) => const CompetitionBrowserScreen(),
      routes: <RouteBase>[
        GoRoute(
          path: ':slug',
          builder: (context, state) =>
              CompetitionDetailScreen(slug: state.pathParameters['slug']!),
          routes: <RouteBase>[
            GoRoute(
              path: 'build',
              builder: (context, state) =>
                  SquadBuilderScreen(slug: state.pathParameters['slug']!),
            ),
            GoRoute(
              path: 'live',
              builder: (context, state) =>
                  LiveGameweekScreen(slug: state.pathParameters['slug']!),
            ),
            GoRoute(
              path: 'transfers',
              builder: (context, state) =>
                  TransferPortalScreen(slug: state.pathParameters['slug']!),
            ),
            GoRoute(
              path: 'leaderboard',
              builder: (context, state) =>
                  LeaderboardScreen(slug: state.pathParameters['slug']!),
            ),
            GoRoute(
              path: 'wc-bracket',
              builder: (context, state) => const WCBracketScreen(),
            ),
            GoRoute(
              path: 'advisor',
              builder: (context, state) => AIAdvisorSheet.standalone(
                slug: state.pathParameters['slug']!,
              ),
            ),
            GoRoute(
              path: 'chips',
              builder: (context, state) => ChipActivationSheet.standalone(
                slug: state.pathParameters['slug']!,
              ),
            ),
            GoRoute(
              path: 'player/:playerId',
              builder: (context, state) => PlayerDetailSheet.standalone(
                slug: state.pathParameters['slug']!,
                playerId: int.parse(state.pathParameters['playerId']!),
              ),
            ),
          ],
        ),
      ],
    ),
  ];
}
