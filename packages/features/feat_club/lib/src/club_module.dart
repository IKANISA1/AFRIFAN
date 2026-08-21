import 'package:core_router/core_router.dart';
import 'package:core_theme/core_theme.dart';
import 'package:go_router/go_router.dart';

import 'screens/club_collection_screens.dart';
import 'screens/club_hub_screen.dart';

/// Official club information module.
///
/// Owns the canonical Club tab and its football-information route family.
class ClubModule extends FeatureModule {
  static const String _moduleName = 'Club';

  @override
  String get featureKey => 'club';

  @override
  bool isEnabled(Map<String, bool> featureFlags) => true;

  @override
  bool isEnabledForConfig({
    Map<String, bool> featureFlags = const <String, bool>{},
    Map<String, dynamic>? configSnapshot,
  }) => true;

  @override
  TabRoute get tabRoute => TabRoute(
    path: '/club',
    label: _moduleName,
    icon: AfriIcons.stadium,
    activeIcon: AfriIcons.stadium,
    builder: (context, state) => const ClubHubScreen(),
  );

  @override
  List<RouteBase> get routes => <RouteBase>[
    GoRoute(
      path: 'team',
      name: 'club-team',
      builder: (context, state) => const ClubTeamScreen(),
    ),
    GoRoute(
      path: 'news',
      name: 'club-news',
      builder: (context, state) => const ClubNewsScreen(),
      routes: <RouteBase>[
        GoRoute(
          path: ':articleId',
          name: 'club-news-detail',
          builder: (context, state) => ClubNewsDetailScreen(
            articleId: state.pathParameters['articleId'] ?? '',
          ),
        ),
      ],
    ),
    GoRoute(
      path: 'fixtures',
      name: 'club-fixtures',
      builder: (context, state) => const ClubFixturesScreen(),
      routes: <RouteBase>[
        GoRoute(
          path: ':matchId',
          name: 'club-fixture-detail',
          builder: (context, state) => ClubFixtureDetailScreen(
            matchId: state.pathParameters['matchId'] ?? '',
          ),
        ),
      ],
    ),
    GoRoute(
      path: 'results',
      name: 'club-results',
      builder: (context, state) => const ClubResultsScreen(),
    ),
    GoRoute(
      path: 'standings',
      name: 'club-standings',
      builder: (context, state) => const ClubStandingsScreen(),
    ),
    GoRoute(
      path: 'history',
      name: 'club-history',
      builder: (context, state) => const ClubHistoryScreen(),
    ),
    GoRoute(
      path: 'projects',
      name: 'club-projects',
      builder: (context, state) => const ClubProjectsScreen(),
      routes: <RouteBase>[
        GoRoute(
          path: ':projectId',
          name: 'club-project-detail',
          builder: (context, state) => ClubProjectDetailScreen(
            projectId: state.pathParameters['projectId'] ?? '',
          ),
        ),
      ],
    ),
  ];

  @override
  List<RoutePresentationDecision> get routePresentationDecisions => const [
    RoutePresentationDecision(
      path: '/club',
      presentation: RoutePresentation.fullScreen,
      recommendation: 'keep as the official club hub',
      rationale:
          'Club identity and football information require one canonical consumer branch.',
      renderedStateContract: 'controlled_club_hub_surface',
    ),
    RoutePresentationDecision(
      path: '/club/team',
      presentation: RoutePresentation.fullScreen,
      recommendation: 'keep',
      targetPath: '/club',
      rationale: 'The published first-team squad is core club information.',
      renderedStateContract: 'controlled_club_information_surface',
    ),
    RoutePresentationDecision(
      path: '/club/news',
      presentation: RoutePresentation.fullScreen,
      recommendation: 'keep',
      targetPath: '/club',
      rationale:
          'Published club reporting belongs in the official club branch.',
      renderedStateContract: 'controlled_club_information_surface',
    ),
    RoutePresentationDecision(
      path: '/club/news/:articleId',
      presentation: RoutePresentation.fullScreen,
      recommendation: 'keep',
      targetPath: '/club/news',
      rationale:
          'Canonical article deep links must restore the same club record.',
      renderedStateContract: 'controlled_club_information_surface',
    ),
    RoutePresentationDecision(
      path: '/club/fixtures',
      presentation: RoutePresentation.fullScreen,
      recommendation: 'keep',
      targetPath: '/club',
      rationale: 'Upcoming fixtures are a primary football task.',
      renderedStateContract: 'controlled_club_information_surface',
    ),
    RoutePresentationDecision(
      path: '/club/fixtures/:matchId',
      presentation: RoutePresentation.fullScreen,
      recommendation: 'keep',
      targetPath: '/club/fixtures',
      rationale:
          'Fixture deep links must preserve club scope and truthful ticket availability.',
      renderedStateContract: 'controlled_club_information_surface',
    ),
    RoutePresentationDecision(
      path: '/club/results',
      presentation: RoutePresentation.fullScreen,
      recommendation: 'keep',
      targetPath: '/club',
      rationale: 'Published results are a primary football record.',
      renderedStateContract: 'controlled_club_information_surface',
    ),
    RoutePresentationDecision(
      path: '/club/standings',
      presentation: RoutePresentation.fullScreen,
      recommendation: 'keep',
      targetPath: '/club',
      rationale: 'Standings belong beside fixtures and results.',
      renderedStateContract: 'controlled_club_information_surface',
    ),
    RoutePresentationDecision(
      path: '/club/history',
      presentation: RoutePresentation.fullScreen,
      recommendation: 'keep',
      targetPath: '/club',
      rationale: 'Reviewed club history belongs in the official club record.',
      renderedStateContract: 'controlled_club_information_surface',
    ),
    RoutePresentationDecision(
      path: '/club/projects',
      presentation: RoutePresentation.fullScreen,
      recommendation: 'keep',
      targetPath: '/club',
      rationale:
          'Approved club projects require a first-class discovery route.',
      renderedStateContract: 'controlled_club_information_surface',
    ),
    RoutePresentationDecision(
      path: '/club/projects/:projectId',
      presentation: RoutePresentation.fullScreen,
      recommendation: 'keep',
      targetPath: '/club/projects',
      rationale:
          'Project detail explains governed progress before contribution actions.',
      renderedStateContract: 'controlled_club_information_surface',
    ),
  ];
}
