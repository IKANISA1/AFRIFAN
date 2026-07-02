import 'package:core_router/core_router.dart';
import 'package:go_router/go_router.dart';

import 'screens/fan_club_detail_screen.dart';
import 'screens/fan_clubs_list_screen.dart';

class FanClubsModule extends FeatureModule {
  @override
  String get featureKey => 'fan_clubs';

  @override
  TabRoute? get tabRoute => null;

  @override
  List<RouteBase> get routes => [
    GoRoute(
      path: '/fan-clubs',
      redirect: (_, state) =>
          state.uri.path == '/fan-clubs' ? '/fanzone?section=supporters' : null,
      pageBuilder: (context, state) =>
          afriSheetPage(state, const FanClubsListScreen(), fullHeight: true),
      routes: [
        GoRoute(
          path: ':clubId',
          pageBuilder: (context, state) => afriSheetPage(
            state,
            FanClubDetailScreen(
              clubId: state.pathParameters['clubId'] ?? 'kigali-blue-army',
            ),
            fullHeight: true,
          ),
        ),
      ],
    ),
  ];

  @override
  List<RoutePresentationDecision> get routePresentationDecisions => const [
    RoutePresentationDecision(
      path: '/fan-clubs',
      presentation: RoutePresentation.redirect,
      recommendation: 'consolidate',
      targetPath: '/fanzone?section=supporters',
      rationale: 'Fan clubs belong in the Fan Zone supporters area.',
    ),
    RoutePresentationDecision(
      path: '/fan-clubs/:clubId',
      presentation: RoutePresentation.fullHeightSheet,
      recommendation: 'convert to sheet',
      targetPath: '/fan-clubs',
      rationale: 'Fan club detail is preview/join context.',
    ),
  ];
}
