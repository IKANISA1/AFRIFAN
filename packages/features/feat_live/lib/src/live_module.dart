import 'package:core_router/core_router.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'screens/live_match_screen.dart';
import 'screens/news_article_screen.dart';

class LiveModule extends FeatureModule {
  @override
  String get featureKey => 'live';

  @override
  TabRoute get tabRoute => TabRoute(
    path: '/live',
    label: 'LIVE',
    icon: Icons.live_tv_outlined,
    activeIcon: Icons.live_tv_rounded,
    builder: (context, state) => const LiveMatchScreen(),
  );

  @override
  List<RouteBase> get routes => [
    GoRoute(
      path: 'news/:articleId',
      builder: (context, state) => NewsArticleScreen(
        articleId: state.pathParameters['articleId'] ?? 'transfer-window',
      ),
    ),
  ];

  @override
  List<RouteBase> get standaloneRoutes => <RouteBase>[
    GoRoute(path: '/live-match', redirect: (_, __) => '/live'),
  ];
}
