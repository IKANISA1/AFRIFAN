import 'package:core_router/core_router.dart';
import 'package:go_router/go_router.dart';

import 'screens/live_match_screen.dart';
import 'screens/news_article_screen.dart';

class LiveModule extends FeatureModule {
  @override
  String get featureKey => 'live';

  @override
  TabRoute? get tabRoute => null;

  @override
  List<RouteBase> get routes => [
    GoRoute(
      path: '/live-match',
      builder: (context, state) => const LiveMatchScreen(),
    ),
    GoRoute(
      path: '/news/:articleId',
      builder: (context, state) => NewsArticleScreen(
        articleId: state.pathParameters['articleId'] ?? 'transfer-window',
      ),
    ),
  ];
}
