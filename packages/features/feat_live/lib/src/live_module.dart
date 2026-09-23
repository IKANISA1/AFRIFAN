import 'package:core_router/core_router.dart';
import 'package:go_router/go_router.dart';

class LiveModule extends FeatureModule {
  @override
  String get featureKey => 'live';

  @override
  List<RouteBase> get routes => [
    GoRoute(
      path: '/live',
      name: 'live',
      redirect: (_, __) => '/predict/match/live',
    ),
    GoRoute(
      path: '/live/news/:articleId',
      redirect: (context, state) =>
          '/club/news/${Uri.encodeComponent(state.pathParameters['articleId'] ?? '')}',
    ),
  ];

  @override
  List<RouteBase> get standaloneRoutes => <RouteBase>[
    GoRoute(path: '/live-match', redirect: (_, __) => '/predict/match/live'),
  ];

  @override
  List<RoutePresentationDecision> get routePresentationDecisions => const [
    RoutePresentationDecision(
      path: '/live',
      presentation: RoutePresentation.redirect,
      recommendation: 'merge',
      targetPath: '/predict/match/live',
      rationale: 'Live match state opens in Match Center.',
    ),
    RoutePresentationDecision(
      path: '/live/news/:articleId',
      presentation: RoutePresentation.redirect,
      recommendation: 'merge',
      targetPath: '/club/news/:articleId',
      rationale: 'All published news uses the canonical Club reader.',
    ),
    RoutePresentationDecision(
      path: '/live-match',
      presentation: RoutePresentation.redirect,
      recommendation: 'deep-link compatibility only',
      targetPath: '/predict/match/live',
      rationale: 'Alias route should never appear as a product surface.',
    ),
  ];
}
