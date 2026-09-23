import 'package:core_router/core_router.dart';
import 'package:core_theme/core_theme.dart';
import 'package:go_router/go_router.dart';

import 'predict_match_screen.dart';
import 'predict_pick_screen.dart';
import 'predict_screen.dart';
import 'predict_share_screen.dart';

class PredictModule extends FeatureModule {
  @override
  String get featureKey => 'predict';

  @override
  TabRoute get tabRoute => TabRoute(
    path: '/predict',
    label: 'Predict',
    icon: AfriIcons.predict,
    activeIcon: AfriIcons.predict,
    builder: (context, state) => const PredictScreen(embedded: true),
  );

  @override
  List<RouteBase> get routes => const [];

  @override
  List<RouteBase> get standaloneRoutes => [
    GoRoute(
      path: '/predict/match/:fixtureId',
      pageBuilder: (context, state) => afriRoutePage(
        state,
        PredictMatchScreen(fixtureId: state.pathParameters['fixtureId'] ?? ''),
      ),
    ),
    GoRoute(
      path: '/predict/picks/:predictionId',
      pageBuilder: (context, state) => afriSheetPage(
        state,
        PredictPickScreen(
          predictionId: state.pathParameters['predictionId'] ?? '',
        ),
        fullHeight: true,
      ),
    ),
    GoRoute(
      path: '/predict/share',
      pageBuilder: (context, state) =>
          afriSheetPage(state, const PredictShareScreen(), heightFactor: 0.68),
    ),
  ];

  @override
  List<RoutePresentationDecision> get routePresentationDecisions => const [
    RoutePresentationDecision(
      path: '/predict',
      presentation: RoutePresentation.fullScreen,
      recommendation: 'keep',
      rationale: 'Fixtures, picks and FET activity in one Predict destination.',
    ),
    RoutePresentationDecision(
      path: '/predict/match/:fixtureId',
      presentation: RoutePresentation.fullScreen,
      recommendation: 'keep',
      rationale: 'Match context and available prediction pools.',
    ),
    RoutePresentationDecision(
      path: '/predict/picks/:predictionId',
      presentation: RoutePresentation.fullHeightSheet,
      recommendation: 'keep',
      rationale: 'Pick details and settlement status.',
    ),
    RoutePresentationDecision(
      path: '/predict/share',
      presentation: RoutePresentation.modalSheet,
      recommendation: 'keep',
      rationale: 'Share a prediction without leaving Predict.',
    ),
  ];
}
