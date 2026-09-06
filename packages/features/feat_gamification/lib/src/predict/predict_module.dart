import 'package:core_router/core_router.dart';
import 'package:go_router/go_router.dart';
import 'predict_screen.dart';

class PredictModule extends FeatureModule {
  @override
  String get featureKey => 'predict';
  @override
  bool isEnabled(Map<String, bool> featureFlags) =>
      featureFlags[featureKey] == true;
  @override
  List<RouteBase> get routes => [
    GoRoute(path: '/predict', builder: (_, __) => const PredictScreen()),
  ];
  @override
  List<RoutePresentationDecision> get routePresentationDecisions => const [
    RoutePresentationDecision(
      path: '/predict',
      presentation: RoutePresentation.fullScreen,
      recommendation: 'keep',
      rationale:
          'Simple fixture picks, personal history and FET activity. Feature and store authorization remain required.',
    ),
  ];
}
