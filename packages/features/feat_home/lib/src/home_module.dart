import 'package:core_router/core_router.dart';
import 'package:core_theme/core_theme.dart';
import 'package:go_router/go_router.dart';

import 'screens/home_screen.dart';

/// Home feature module — the main tab with CMS hero, match, quick actions.
class HomeModule extends FeatureModule {
  @override
  String get featureKey => 'home';

  @override
  TabRoute get tabRoute => TabRoute(
    path: '/home',
    label: 'Home',
    icon: AfriIcons.stadium,
    activeIcon: AfriIcons.stadium,
    builder: (context, state) => const HomeScreen(),
  );

  @override
  List<RouteBase> get routes => [];

  @override
  List<RoutePresentationDecision> get routePresentationDecisions => const [
    RoutePresentationDecision(
      path: '/home',
      presentation: RoutePresentation.fullScreen,
      recommendation: 'keep',
      rationale: 'Home is the main fan command surface.',
    ),
  ];
}
