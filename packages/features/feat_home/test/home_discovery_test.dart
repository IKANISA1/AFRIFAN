import 'dart:convert';

import 'package:core_feature_config/core_feature_config.dart';
import 'package:core_l10n/core_l10n.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_home/src/repositories/home_content_repository.dart';
import 'package:feat_home/src/repositories/home_discovery_repository.dart';
import 'package:feat_home/src/widgets/home_discovery_section.dart';
import 'package:feat_home/src/widgets/latest_intel_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _Scope extends ClubScopeResolver {
  _Scope(SupabaseClient client, this.clubId) : super(client: client);
  final int clubId;
  @override
  Future<ClubScope> requireResolved([String? hint]) async =>
      ClubScope(partnerId: '', clubId: clubId);
}

class _Discovery implements HomeDiscoveryRepository {
  bool failed = false;
  int predictionReads = 0;
  DateTime? expires;

  @override
  Future<List<Map<String, dynamic>>> load(HomeDiscoveryKind kind) async {
    if (kind == HomeDiscoveryKind.partners && failed) {
      throw StateError('Isolated partner outage');
    }
    if (kind == HomeDiscoveryKind.predictions) {
      predictionReads++;
      if (expires != null && predictionReads > 1) return [];
      return [
        {
          'id': 'match-1',
          'home_team': 'Rayon Sports FC',
          'away_team': 'APR FC',
          'competition': 'League',
          'kickoff_at': '2030-08-08T16:00:00Z',
          if (expires != null) 'locks_at': expires!.toIso8601String(),
        },
      ];
    }
    return [
      {
        'id': 'record-1',
        'name': kind == HomeDiscoveryKind.partners
            ? 'Community partnership'
            : 'City supporters',
        'region': 'Kigali',
        'member_count': 42,
      },
    ];
  }
}

void main() {
  for (final clubId in [6, 24, 26, 44]) {
    test('Home discovery is tenant-scoped and read-only for $clubId', () async {
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'https://home-discovery.invalid',
        'synthetic',
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response(
            '[]',
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      final repository = SupabaseHomeDiscoveryRepository(
        client,
        const StoreReleasePolicy.unenforced(),
        scopeResolver: _Scope(client, clubId),
      );
      for (final kind in HomeDiscoveryKind.values) {
        await repository.load(kind);
      }
      expect(requests, hasLength(3));
      expect(requests.first.url.path, '/rest/v1/rpc/predict_public_preview');
      expect(jsonDecode(requests.first.body), {'p_club_id': clubId});
      for (final request in requests.skip(1)) {
        expect(request.method, 'GET');
        expect(request.url.queryParameters['club_id'], 'eq.$clubId');
        expect(request.url.queryParameters['limit'], '3');
      }
      requests.clear();
      final restricted = SupabaseHomeDiscoveryRepository(
        client,
        const StoreReleasePolicy(isEnforced: true),
        scopeResolver: _Scope(client, clubId),
      );
      expect(await restricted.load(HomeDiscoveryKind.predictions), isEmpty);
      expect(requests, isEmpty);
    });
  }

  for (final kind in HomeDiscoveryKind.values) {
    for (final showAll in [false, true]) {
      testWidgets(
        '$kind opens its full page from ${showAll ? 'header' : 'card'}',
        (tester) async {
          final repository = _Discovery();
          final route = switch (kind) {
            HomeDiscoveryKind.predictions => '/predict',
            HomeDiscoveryKind.partners => '/club/partners',
            HomeDiscoveryKind.fanClubs => '/fan-clubs',
          };
          final router = GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (_, __) => Scaffold(
                  body: SingleChildScrollView(
                    child: HomeDiscoverySection(kind: kind),
                  ),
                ),
              ),
              GoRoute(
                path: route,
                builder: (_, state) =>
                    Scaffold(body: Text('Opened ${state.uri}')),
              ),
            ],
          );
          addTearDown(router.dispose);
          await tester.pumpWidget(_app(repository, router: router));
          await tester.pumpAndSettle();
          final target = showAll
              ? find.text('Show all')
              : find.byType(AfriEditorialCard);
          await tester.tap(target);
          await tester.pumpAndSettle();
          final suffix = showAll || kind == HomeDiscoveryKind.predictions
              ? ''
              : '?${kind == HomeDiscoveryKind.partners ? 'partner' : 'club'}=record-1';
          expect(find.text('Opened $route$suffix'), findsOneWidget);
        },
      );
    }
  }

  for (final showAll in [false, true]) {
    testWidgets('news opens its ${showAll ? 'directory' : 'article'} page', (
      tester,
    ) async {
      final route = showAll ? '/club/news' : '/club/news/story-1';
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const Scaffold(body: LatestIntelSection()),
          ),
          GoRoute(
            path: route,
            builder: (_, __) =>
                const Scaffold(body: Text('Published club news')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [latestIntelRepositoryProvider.overrideWithValue(_News())],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AfriLocalizations.localizationsDelegates,
            supportedLocales: AfriLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(showAll ? 'Show all' : 'Inside training'));
      await tester.pumpAndSettle();
      expect(find.text('Published club news'), findsOneWidget);
    });
  }

  testWidgets('a failed section retries without hiding other discovery', (
    tester,
  ) async {
    final repository = _Discovery()..failed = true;
    await tester.pumpWidget(
      _app(
        repository,
        child: const Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                HomeDiscoverySection(kind: HomeDiscoveryKind.partners),
                HomeDiscoverySection(kind: HomeDiscoveryKind.fanClubs),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('City supporters'), findsOneWidget);
    expect(find.text('Could not refresh this section'), findsOneWidget);
    repository.failed = false;
    await tester.tap(find.text('Could not refresh this section'));
    await tester.pumpAndSettle();
    expect(find.text('Community partnership'), findsOneWidget);
    expect(find.text('City supporters'), findsOneWidget);
  });

  testWidgets('locked predictions leave the Home preview without a refresh', (
    tester,
  ) async {
    final repository = _Discovery()
      ..expires = DateTime.now().add(const Duration(seconds: 1));
    await tester.pumpWidget(
      _app(
        repository,
        child: const Scaffold(
          body: HomeDiscoverySection(kind: HomeDiscoveryKind.predictions),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AfriFixtureCard), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.byType(AfriFixtureCard), findsNothing);
    expect(find.text('New predictions will appear here'), findsNothing);
    expect(find.text('Active predictions'), findsNothing);
  });
}

Widget _app(_Discovery repository, {GoRouter? router, Widget? child}) =>
    ProviderScope(
      overrides: [
        homeDiscoveryRepositoryProvider.overrideWithValue(repository),
        featureConfigServiceProvider.overrideWithValue(
          const FeatureConfigService(
            PlatformConfigSnapshot(
              features: [
                PlatformFeature(featureKey: 'predict', displayName: 'Predict'),
              ],
            ),
            storeReleasePolicy: StoreReleasePolicy.unenforced(),
          ),
        ),
      ],
      child: router != null
          ? MaterialApp.router(
              routerConfig: router,
              localizationsDelegates: AfriLocalizations.localizationsDelegates,
              supportedLocales: AfriLocalizations.supportedLocales,
            )
          : MaterialApp(
              home: child,
              localizationsDelegates: AfriLocalizations.localizationsDelegates,
              supportedLocales: AfriLocalizations.supportedLocales,
            ),
    );

class _News implements LatestIntelRepository {
  @override
  Future<LatestIntelSnapshot> loadPublishedArticles() async =>
      const LatestIntelSnapshot(
        status: LatestIntelStatus.ready,
        articles: [
          {'id': 'story-1', 'title': 'Inside training'},
        ],
      );
}
