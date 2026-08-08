import 'package:core_router/core_router.dart';
import 'package:go_router/go_router.dart';

import 'screens/game_operations_hub_screen.dart';
import 'screens/live_game_control_screen.dart';
import 'screens/managed_games_screen.dart';
import 'screens/my_tvs_screen.dart';
import 'screens/pair_tv_screen.dart';
import 'screens/session_planner_screen.dart';
import 'screens/tv_detail_screen.dart';

class GameOperationsModule extends FeatureModule {
  @override
  String get featureKey => 'game_operations';

  @override
  List<RouteBase> get routes => <RouteBase>[
    GoRoute(
      path: '/game-operations',
      name: 'game-operations',
      pageBuilder: (context, state) =>
          afriRoutePage(state, const GameOperationsHubScreen()),
      routes: <RouteBase>[
        GoRoute(
          path: 'sessions',
          name: 'managed-games',
          pageBuilder: (context, state) =>
              afriRoutePage(state, const ManagedGamesScreen()),
          routes: <RouteBase>[
            GoRoute(
              path: 'new',
              name: 'managed-game-new',
              pageBuilder: (context, state) =>
                  afriRoutePage(state, const SessionPlannerScreen()),
            ),
            GoRoute(
              path: ':sessionId',
              name: 'managed-game-control',
              pageBuilder: (context, state) => afriRoutePage(
                state,
                LiveGameControlScreen(
                  sessionId: state.pathParameters['sessionId'] ?? '',
                ),
              ),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/my-tvs',
      name: 'my-tvs',
      pageBuilder: (context, state) =>
          afriRoutePage(state, const MyTvsScreen()),
      routes: <RouteBase>[
        GoRoute(
          path: 'pair',
          name: 'my-tvs-pair',
          pageBuilder: (context, state) => afriRoutePage(
            state,
            PairTvScreen(
              initialChallenge: state.uri.queryParameters['challenge'],
              recoverDisplayId: state.uri.queryParameters['recoverDisplayId'],
            ),
          ),
        ),
        GoRoute(
          path: ':displayId',
          name: 'my-tv-detail',
          pageBuilder: (context, state) => afriRoutePage(
            state,
            TvDetailScreen(displayId: state.pathParameters['displayId'] ?? ''),
          ),
        ),
      ],
    ),
  ];

  @override
  List<RoutePresentationDecision> get routePresentationDecisions => const [
    RoutePresentationDecision(
      path: '/game-operations',
      presentation: RoutePresentation.fullScreen,
      recommendation: 'keep',
      rationale:
          'Authenticated owners and assigned organizers need one role-safe operations entry point.',
      renderedStateContract: 'static_game_operations_hub_surface',
    ),
    RoutePresentationDecision(
      path: '/game-operations/sessions',
      presentation: RoutePresentation.fullScreen,
      recommendation: 'keep',
      rationale:
          'Assigned organizer inventory is an operational list, not a supporter tab.',
      renderedStateContract: 'controlled_organizer_inventory_surface',
    ),
    RoutePresentationDecision(
      path: '/game-operations/sessions/new',
      presentation: RoutePresentation.fullScreen,
      recommendation: 'keep',
      rationale:
          'Session planning is a focused multi-field task with governed pack and display choices.',
      renderedStateContract: 'controlled_organizer_planner_surface',
    ),
    RoutePresentationDecision(
      path: '/game-operations/sessions/:sessionId',
      presentation: RoutePresentation.fullScreen,
      recommendation: 'keep',
      rationale:
          'Live control requires persistent synchronized state and explicit transition actions.',
      renderedStateContract: 'controlled_organizer_live_control_surface',
    ),
    RoutePresentationDecision(
      path: '/my-tvs',
      presentation: RoutePresentation.fullScreen,
      recommendation: 'keep',
      rationale:
          'TV ownership is a personal authenticated inventory separate from supporter gameplay.',
      renderedStateContract: 'controlled_tv_inventory_surface',
    ),
    RoutePresentationDecision(
      path: '/my-tvs/pair',
      presentation: RoutePresentation.fullScreen,
      recommendation: 'keep',
      rationale:
          'Pairing supports a QR deep link and a keyboard-accessible manual challenge fallback.',
      renderedStateContract: 'controlled_tv_pairing_surface',
    ),
    RoutePresentationDecision(
      path: '/my-tvs/:displayId',
      presentation: RoutePresentation.fullScreen,
      recommendation: 'keep',
      rationale:
          'Rename, repair, and revocation are security-sensitive owner actions.',
      renderedStateContract: 'controlled_tv_management_surface',
    ),
  ];
}
