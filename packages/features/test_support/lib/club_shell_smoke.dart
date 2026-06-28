// ignore_for_file: implementation_imports

import 'package:app_registry/app_registry.dart';
import 'package:core_app/core_app.dart';
import 'package:core_auth/core_auth.dart';
import 'package:core_router/core_router.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_home/src/repositories/home_content_repository.dart';
import 'package:feat_home/src/widgets/match_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Widget buildClubShellSmokeApp({
  required ClubConfig config,
  String initialLocation = '/home',
}) {
  ColorTokens.init(config.colors);
  final modules = AppModuleRegistry.build(config);
  final router = AppRouter(
    modules: modules,
    initialLocation: initialLocation,
    shellBuilder: (context, shell) =>
        AppShell(shell: shell, config: config, modules: modules),
  );

  return ProviderScope(
    overrides: [
      homeFeedRepositoryProvider.overrideWithValue(
        const _FakeHomeFeedRepository(
          snapshot: HomeFeedSnapshot(
            heroSlides: [
              MatchSlide(
                homeTeam: 'HOME CLUB',
                awayTeam: 'RIVAL FC',
                venue: 'CLUB STADIUM',
                status: 'ON SALE',
                dateInfo: '12 APR • 18:00',
                route: '/tickets',
              ),
            ],
            status: HomeFeedStatus.success,
          ),
        ),
      ),
      latestIntelRepositoryProvider.overrideWithValue(
        const _FakeLatestIntelRepository(
          LatestIntelSnapshot(
            status: LatestIntelStatus.ready,
            articles: [
              {
                'id': 'article-1',
                'title': 'Training ground update',
                'subtitle': 'First-team preparations continue this week.',
              },
            ],
          ),
        ),
      ),
      currentUserProvider.overrideWith(
        (ref) => UserProfile(
          id: 'user-1',
          clubId: config.clubId,
          publicUserId: '483912',
          phone: '0788123456',
          momoNumber: '0788123456',
          momoProvider: 'MoMo',
        ),
      ),
    ],
    child: MaterialApp.router(
      theme: ClubTheme.from(config),
      routerConfig: router.router,
      locale: const Locale('en'),
    ),
  );
}

class _FakeHomeFeedRepository implements HomeFeedRepository {
  const _FakeHomeFeedRepository({required this.snapshot});

  final HomeFeedSnapshot snapshot;

  @override
  Future<HomeFeedSnapshot> load() async => snapshot;
}

class _FakeLatestIntelRepository implements LatestIntelRepository {
  const _FakeLatestIntelRepository(this.snapshot);

  final LatestIntelSnapshot snapshot;

  @override
  Future<LatestIntelSnapshot> loadPublishedArticles() async => snapshot;
}
