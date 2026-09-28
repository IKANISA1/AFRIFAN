import 'package:core_router/core_router.dart';
import 'package:go_router/go_router.dart';

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
      pageBuilder: (context, state) => afriSheetPage(
        state,
        FanClubsListScreen(clubId: state.uri.queryParameters['club']),
        fullHeight: true,
      ),
      routes: [
        GoRoute(
          path: ':clubId',
          redirect: (_, state) => Uri(
            path: '/fan-clubs',
            queryParameters: {'club': state.pathParameters['clubId']!},
          ).toString(),
        ),
      ],
    ),
  ];

  @override
  List<RoutePresentationDecision> get routePresentationDecisions => const [
    RoutePresentationDecision(
      path: '/fan-clubs',
      presentation: RoutePresentation.fullHeightSheet,
      recommendation: 'keep',
      rationale:
          'Community discovery opens directly from Membership and search.',
    ),
    RoutePresentationDecision(
      path: '/fan-clubs/:clubId',
      presentation: RoutePresentation.redirect,
      recommendation: 'delete duplicate',
      targetPath: '/fan-clubs',
      rationale:
          'One image-led directory contains the published community information.',
    ),
  ];
}
