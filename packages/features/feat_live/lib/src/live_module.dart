import 'package:core_router/core_router.dart';
import 'package:go_router/go_router.dart';

import 'screens/news_article_screen.dart';

class LiveModule extends FeatureModule {
  @override
  String get featureKey => 'live';

  @override
  List<RouteBase> get routes => [
    GoRoute(
      path: '/live',
      name: 'live',
      redirect: (_, __) => '/fanzone/match/live',
    ),
    GoRoute(
      path: '/live/news/:articleId',
      pageBuilder: (context, state) => afriSheetPage(
        state,
        NewsArticleScreen(
          articleId: state.pathParameters['articleId'] ?? 'transfer-window',
        ),
        fullHeight: true,
      ),
    ),
  ];

  @override
  List<RouteBase> get standaloneRoutes => <RouteBase>[
    GoRoute(path: '/live-match', redirect: (_, __) => '/fanzone/match/live'),
  ];

  @override
  List<RoutePresentationDecision> get routePresentationDecisions => const [
    RoutePresentationDecision(
      path: '/live',
      presentation: RoutePresentation.redirect,
      recommendation: 'merge',
      targetPath: '/fanzone/match/live',
      rationale: 'Live match state opens in Match Center.',
    ),
    RoutePresentationDecision(
      path: '/live/news/:articleId',
      presentation: RoutePresentation.fullHeightSheet,
      recommendation: 'convert to reader sheet',
      targetPath: '/fanzone/match/live',
      rationale: 'Articles are content overlays, not app destinations.',
    ),
    RoutePresentationDecision(
      path: '/live-match',
      presentation: RoutePresentation.redirect,
      recommendation: 'deep-link compatibility only',
      targetPath: '/fanzone/match/live',
      rationale: 'Alias route should never appear as a product surface.',
    ),
  ];
}
