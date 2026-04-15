import 'package:core_router/core_router.dart';
import 'package:go_router/go_router.dart';

import 'screens/live_match_screen.dart';
import 'screens/news_article_screen.dart';

class LiveModule extends FeatureModule {
  @override
  String get featureKey => 'live';

  @override
  List<RouteBase> get routes => [
    GoRoute(
      path: '/live',
      name: 'live',
      builder: (context, state) => const LiveMatchScreen(),
      routes: [
        GoRoute(
          path: 'news/:articleId',
          builder: (context, state) => NewsArticleScreen(
            articleId: state.pathParameters['articleId'] ?? 'transfer-window',
          ),
        ),
      ],
    ),
  ];

  @override
  List<RouteBase> get standaloneRoutes => <RouteBase>[
    GoRoute(path: '/live-match', redirect: (_, __) => '/live'),
  ];
}
