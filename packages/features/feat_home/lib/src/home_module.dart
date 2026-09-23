import 'package:core_router/core_router.dart';
import 'package:core_theme/core_theme.dart';
import 'package:go_router/go_router.dart';

import 'screens/discovery_search_screen.dart';
import 'screens/home_screen.dart';

/// Home feature module — the main tab with CMS hero, match, quick actions.
class HomeModule extends FeatureModule {
  @override
  String get featureKey => 'home';

  @override
  TabRoute get tabRoute => TabRoute(
    path: '/home',
    label: 'Home',
    icon: AfriIcons.home,
    activeIcon: AfriIcons.home,
    builder: (context, state) => const HomeScreen(),
  );

  @override
  List<RouteBase> get routes => [];

  @override
  List<RouteBase> get standaloneRoutes => <RouteBase>[
    GoRoute(
      path: '/search',
      name: 'discovery-search',
      builder: (context, state) => const DiscoverySearchScreen(),
    ),
  ];

  @override
  List<RoutePresentationDecision> get routePresentationDecisions => const [
    RoutePresentationDecision(
      path: '/home',
      presentation: RoutePresentation.fullScreen,
      recommendation: 'keep',
      rationale: 'Home is the main fan command surface.',
    ),
    RoutePresentationDecision(
      path: '/search',
      presentation: RoutePresentation.fullScreen,
      recommendation: 'keep',
      rationale:
          'Search is a dedicated discovery archetype with bounded results and complete recovery states.',
    ),
  ];
}
