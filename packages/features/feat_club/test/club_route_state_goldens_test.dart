import 'dart:async';

import 'package:core_l10n/core_l10n.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_club/feat_club.dart';
import 'package:feat_club/src/screens/club_partners_screen.dart';
import 'package:feat_club/src/screens/club_public_link_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:test_support/app_font_loader.dart';

const _goldenKey = ValueKey<String>('club-route-state-golden');

// Golden viewport contract: 390x844 standard and 320x720 at 200% text.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);
  setUp(() {
    ConnectivityService.setOnlineForTest(true);
    FocusManager.instance.primaryFocus?.unfocus(
      disposition: UnfocusDisposition.scope,
    );
  });
  tearDown(() => ConnectivityService.setOnlineForTest(true));

  for (final route in _clubRoutes) {
    for (final state in _clubStates) {
      if (state == 'empty' && !route.hasEmptyState) continue;
      testWidgets('golden ${route.pattern} $state state', (tester) async {
        await _pumpClubRouteState(tester, route: route, state: state);
      });
    }
  }
}

const _clubStates = <String>[
  'loading',
  'empty',
  'error',
  'offline',
  'permission_denied',
  'focused',
  'pressed',
  'large_text',
  'reduced_motion',
  'dark',
  'light',
  'syncing',
  'conflict',
  'security_timeout',
];

const _clubRoutes = <_ClubRouteSpec>[
  _ClubRouteSpec('/club', '/club', 'hub', hasEmptyState: false),
  _ClubRouteSpec('/club/team', '/club/team', 'team'),
  _ClubRouteSpec('/club/team/:playerId', '/club/team/player-1', 'player'),
  _ClubRouteSpec('/club/partners', '/club/partners', 'partners'),
  _ClubRouteSpec(
    '/club/partners/:partnerId',
    '/club/partners/partner-1',
    'partner_detail',
  ),
  _ClubRouteSpec(
    '/club/open-web',
    '/club/open-web?path=%2Fnews%2Fpublished-story',
    'public_link',
  ),
  _ClubRouteSpec('/club/news', '/club/news', 'news'),
  _ClubRouteSpec(
    '/club/news/:articleId',
    '/club/news/article-1',
    'news_detail',
  ),
  _ClubRouteSpec('/club/fixtures', '/club/fixtures', 'fixtures'),
  _ClubRouteSpec(
    '/club/fixtures/:matchId',
    '/club/fixtures/fixture-1',
    'fixture_detail',
  ),
  _ClubRouteSpec('/club/results', '/club/results', 'results'),
  _ClubRouteSpec('/club/standings', '/club/standings', 'standings'),
  _ClubRouteSpec('/club/history', '/club/history', 'history'),
  _ClubRouteSpec('/club/projects', '/club/projects', 'projects'),
  _ClubRouteSpec(
    '/club/projects/:projectId',
    '/club/projects/project-1',
    'project_detail',
  ),
];

Future<void> _pumpClubRouteState(
  WidgetTester tester, {
  required _ClubRouteSpec route,
  required String state,
}) async {
  final size = state == 'large_text'
      ? const Size(320, 720)
      : const Size(390, 844);
  final brightness = state == 'light' ? Brightness.light : Brightness.dark;
  final reducedMotion = state == 'reduced_motion';
  final gateway = _ClubStateGateway(_modeFor(state));
  TestGesture? heldGesture;

  _setGoldenSurface(tester, size, reducedMotion: reducedMotion);
  tester.platformDispatcher.textScaleFactorTestValue = state == 'large_text'
      ? 2
      : 1;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  TypographyTokens.debugUseFallbackFonts = true;
  addTearDown(() => TypographyTokens.debugUseFallbackFonts = false);
  ColorTokens.setBrightness(brightness);
  addTearDown(() => ColorTokens.setBrightness(Brightness.dark));
  ConnectivityService.setOnlineForTest(state != 'offline');
  addTearDown(() => ConnectivityService.setOnlineForTest(true));
  addTearDown(gateway.completePending);

  await tester.pumpWidget(
    _buildClubApp(
      initialLocation: route.location,
      gateway: gateway,
      brightness: brightness,
      reducedMotion: reducedMotion,
    ),
  );

  if (state == 'loading') {
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
  } else {
    await tester.pumpAndSettle();
    // Initial nested GoRouter locations construct the Club hub and destination
    // stack together. Advance one bounded frame after settling so captures
    // cannot retain partially entered route chrome when a provider completes
    // or fails in the same microtask turn.
    await tester.pump(const Duration(milliseconds: 500));
  }

  if (state == 'syncing') {
    await tester.tap(find.byKey(const ValueKey<String>('club-refresh-action')));
    await tester.pump();
    final l10n = lookupAfriLocalizations(const Locale('en'));
    expect(find.text(l10n.clubRefreshingTitle), findsOneWidget);
  }

  if (state == 'focused') {
    final previousHighlightStrategy = FocusManager.instance.highlightStrategy;
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    addTearDown(
      () => FocusManager.instance.highlightStrategy = previousHighlightStrategy,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus, isNotNull);
  }

  if (state == 'pressed') {
    heldGesture = await tester.startGesture(
      tester.getCenter(
        find.byKey(const ValueKey<String>('club-refresh-action')),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }

  if (state == 'offline') {
    final l10n = lookupAfriLocalizations(const Locale('en'));
    expect(find.text(l10n.clubOfflineTitle), findsOneWidget);
  }
  if (state == 'permission_denied') {
    final l10n = lookupAfriLocalizations(const Locale('en'));
    expect(find.text(l10n.clubAccessDeniedTitle), findsOneWidget);
    expect(find.textContaining('private-club-record-4482'), findsNothing);
  }
  if (state == 'conflict') {
    final l10n = lookupAfriLocalizations(const Locale('en'));
    expect(find.text(l10n.clubChangedTitle), findsOneWidget);
    expect(find.textContaining('private-club-record-4482'), findsNothing);
  }
  if (state == 'security_timeout') {
    final l10n = lookupAfriLocalizations(const Locale('en'));
    expect(find.text(l10n.clubSecurityTimeoutTitle), findsOneWidget);
  }
  if (state == 'reduced_motion') {
    final context = tester.element(find.byKey(_goldenKey));
    expect(AfriMotion.reduceMotion(context), isTrue);
  }
  expect(tester.takeException(), isNull);

  final themeName = brightness == Brightness.light ? 'light' : 'dark';
  final dimensions = '${size.width.toInt()}x${size.height.toInt()}';
  await expectLater(
    find.byKey(_goldenKey),
    matchesGoldenFile(
      'goldens/club_${route.slug}_state_${state}_${themeName}_$dimensions.png',
    ),
  );

  await heldGesture?.up();
  gateway.completePending();
  await tester.pump();
}

_ClubGatewayMode _modeFor(String state) {
  return switch (state) {
    'loading' => _ClubGatewayMode.loading,
    'empty' => _ClubGatewayMode.empty,
    'error' => _ClubGatewayMode.error,
    'permission_denied' => _ClubGatewayMode.permissionDenied,
    'syncing' => _ClubGatewayMode.syncing,
    'conflict' => _ClubGatewayMode.conflict,
    'security_timeout' => _ClubGatewayMode.securityTimeout,
    _ => _ClubGatewayMode.data,
  };
}

Widget _buildClubApp({
  required String initialLocation,
  required _ClubStateGateway gateway,
  required Brightness brightness,
  required bool reducedMotion,
}) {
  final module = ClubModule();
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      GoRoute(
        path: '/club',
        builder: (_, __) => const ClubHubScreen(),
        routes: module.routes,
      ),
      GoRoute(path: '/tickets', builder: (_, __) => const SizedBox.shrink()),
      GoRoute(
        path: '/tickets/:matchId',
        builder: (_, __) => const SizedBox.shrink(),
      ),
      GoRoute(
        path: '/contribute/group/:projectId',
        builder: (_, __) => const SizedBox.shrink(),
      ),
    ],
  );
  final config = ClubConfig.fallback();

  return ProviderScope(
    overrides: <Override>[
      clubContentGatewayProvider.overrideWithValue(gateway),
      clubPublicWebsiteProvider.overrideWithValue(
        Uri.parse('https://club.example'),
      ),
      clubPartnersProvider.overrideWith((ref, id) => gateway.loadPartners(id)),
      clubPublicLinkProvider.overrideWith(
        (ref, path) => gateway.loadPublicLink(path),
      ),
      clubContentLoadTimeoutProvider.overrideWithValue(
        const Duration(seconds: 12),
      ),
    ],
    child: AfriLocalizationsScope(
      locale: const Locale('en'),
      child: MaterialApp.router(
        theme: ClubTheme.from(config, brightness: brightness),
        routerConfig: router,
        builder: (context, child) {
          final mediaQuery = MediaQuery.of(context);
          return MediaQuery(
            data: mediaQuery.copyWith(
              disableAnimations: reducedMotion,
              accessibleNavigation: reducedMotion,
            ),
            child: ClubConfigScope(
              config: config,
              child: RepaintBoundary(
                key: _goldenKey,
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          );
        },
      ),
    ),
  );
}

void _setGoldenSurface(
  WidgetTester tester,
  Size size, {
  required bool reducedMotion,
}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      FakeAccessibilityFeatures(
        disableAnimations: reducedMotion,
        accessibleNavigation: reducedMotion,
      );
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

class _ClubRouteSpec {
  const _ClubRouteSpec(
    this.pattern,
    this.location,
    this.slug, {
    this.hasEmptyState = true,
  });

  final String pattern;
  final String location;
  final String slug;
  final bool hasEmptyState;
}

enum _ClubGatewayMode {
  data,
  loading,
  empty,
  error,
  permissionDenied,
  syncing,
  conflict,
  securityTimeout,
}

class _ClubStateGateway implements ClubContentGateway {
  _ClubStateGateway(this.mode);

  final _ClubGatewayMode mode;
  final Map<String, int> _calls = <String, int>{};
  final List<void Function()> _pendingCompletions = <void Function()>[];

  void completePending() {
    for (final complete in List<void Function()>.of(_pendingCompletions)) {
      complete();
    }
    _pendingCompletions.clear();
  }

  Future<T> _load<T>({required String key, required T data, required T empty}) {
    _calls[key] = (_calls[key] ?? 0) + 1;
    return switch (mode) {
      _ClubGatewayMode.loading => _pending(empty),
      _ClubGatewayMode.empty => Future<T>.value(empty),
      _ClubGatewayMode.error => Future<T>.error(
        StateError('private-club-record-4482 failed'),
      ),
      _ClubGatewayMode.permissionDenied => Future<T>.error(
        StateError('RLS permission denied private-club-record-4482'),
      ),
      _ClubGatewayMode.syncing when _calls[key]! > 1 => _pending(data),
      _ClubGatewayMode.conflict => Future<T>.error(
        StateError('stale revision conflict private-club-record-4482'),
      ),
      _ClubGatewayMode.securityTimeout => Future<T>.error(
        TimeoutException('private-club-record-4482 security timeout'),
      ),
      _ => Future<T>.value(data),
    };
  }

  Future<T> _pending<T>(T completionValue) {
    final completer = Completer<T>();
    _pendingCompletions.add(() {
      if (!completer.isCompleted) completer.complete(completionValue);
    });
    return completer.future;
  }

  Future<List<Map<String, dynamic>>> loadPartners(String? id) => _load(
    key: 'partners-${id ?? 'all'}',
    data: [
      {
        'id': 'partner-1',
        'name': 'Synthetic Community Partner',
        'category': 'Community partner',
        'description':
            'Published recognition for a synthetic club partner. No redemption or financial benefit is implied.',
        'website_url': 'https://example.test/club-partner',
        'image_rights_approved': false,
      },
    ],
    empty: <Map<String, dynamic>>[],
  );

  Future<String?> loadPublicLink(String path) =>
      _load<String?>(key: 'public-link', data: null, empty: null);

  @override
  Future<ClubOverview?> loadOverview() =>
      _load<ClubOverview?>(key: 'overview', data: _overview, empty: null);

  @override
  Future<List<ClubHistoryItem>> loadHistory() =>
      _load(key: 'history', data: _history, empty: const <ClubHistoryItem>[]);

  @override
  Future<List<ClubFixtureItem>> loadMatches() =>
      _load(key: 'matches', data: _matches, empty: const <ClubFixtureItem>[]);

  @override
  Future<List<ClubNewsItem>> loadNews() =>
      _load(key: 'news', data: _news, empty: const <ClubNewsItem>[]);

  @override
  Future<List<ClubProjectItem>> loadProjects() =>
      _load(key: 'projects', data: _projects, empty: const <ClubProjectItem>[]);

  @override
  Future<List<ClubSquadMember>> loadSquad() =>
      _load(key: 'squad', data: _squad, empty: const <ClubSquadMember>[]);

  @override
  Future<List<ClubStandingItem>> loadStandings() => _load(
    key: 'standings',
    data: _standings,
    empty: const <ClubStandingItem>[],
  );
}

const _overview = ClubOverview(
  id: 24,
  name: 'Rayon Sports FC',
  country: 'Rwanda',
  league: 'Rwanda Premier League',
  slug: 'rayon_sports_rw',
  nickname: 'Gikundiro',
  fullName: 'Rayon Sports Football Club',
  origin: 'Nyanza, Southern Province, Rwanda',
  currentBase: 'Kigali, Rwanda',
  colours: 'Blue and white',
  identityNote:
      'Gikundiro is the supporter identity carried by Rayon Sports FC across its official social presence.',
);

final _news = <ClubNewsItem>[
  ClubNewsItem(
    id: 'article-1',
    title: 'Gikundiro prepare for the next league fixture',
    subtitle: 'The first team completed its final training session in Kigali.',
    body:
        'The coaching staff confirmed the match squad after a focused week of preparation. Supporters are encouraged to follow official club channels for final matchday guidance.',
    category: 'First team',
    author: 'Rayon Sports FC',
    publishedAt: DateTime.utc(2026, 8, 1),
  ),
];

const _squad = <ClubSquadMember>[
  ClubSquadMember(
    id: 'player-1',
    name: 'Claude Niyonzima',
    position: 'Midfielder',
    shirtNumber: 8,
    nationality: 'Rwanda',
    bio: 'First-team midfielder.',
  ),
  ClubSquadMember(
    id: 'player-2',
    name: 'Eric Ngendahimana',
    position: 'Defender',
    shirtNumber: 4,
    nationality: 'Rwanda',
    bio: 'First-team defender.',
  ),
];

final _matches = <ClubFixtureItem>[
  ClubFixtureItem(
    id: 'fixture-1',
    homeTeam: 'Rayon Sports FC',
    awayTeam: 'APR FC',
    competition: 'Rwanda Premier League',
    venue: 'Kigali Pele Stadium',
    matchDate: DateTime.utc(2026, 8, 8, 15),
    kickoffTime: '17:00',
    status: 'scheduled',
    homeScore: 0,
    awayScore: 0,
    isOnSale: true,
  ),
  ClubFixtureItem(
    id: 'result-1',
    homeTeam: 'Rayon Sports FC',
    awayTeam: 'Police FC',
    competition: 'Rwanda Premier League',
    venue: 'Kigali Pele Stadium',
    matchDate: DateTime.utc(2026, 7, 28, 15),
    kickoffTime: '15:00',
    status: 'finished',
    homeScore: 2,
    awayScore: 1,
    isOnSale: false,
  ),
];

const _standings = <ClubStandingItem>[
  ClubStandingItem(
    id: 'standing-1',
    position: 1,
    clubName: 'Rayon Sports FC',
    played: 6,
    goalDifference: 9,
    points: 16,
    clubSlug: 'rayon_sports_rw',
  ),
  ClubStandingItem(
    id: 'standing-2',
    position: 2,
    clubName: 'APR FC',
    played: 6,
    goalDifference: 7,
    points: 14,
    clubSlug: 'apr_fc',
  ),
];

const _history = <ClubHistoryItem>[
  ClubHistoryItem(
    id: 'history-nyanza',
    title: 'Roots in Nyanza',
    subtitle: 'Nyanza, Southern Province',
    body:
        "Rayon Sports FC traces its roots to Nyanza in Rwanda's Southern Province.",
    sortOrder: 10,
  ),
  ClubHistoryItem(
    id: 'history-kigali',
    title: 'Based in Kigali',
    subtitle: 'Kigali, Rwanda',
    body:
        'The club is now based in Kigali while retaining its historic connection to Nyanza.',
    sortOrder: 20,
  ),
  ClubHistoryItem(
    id: 'identity-gikundiro',
    title: 'Gikundiro',
    subtitle: 'Supporter identity',
    body:
        'Gikundiro is the supporter identity carried by Rayon Sports FC across its official social presence.',
    sortOrder: 30,
  ),
];

const _projects = <ClubProjectItem>[
  ClubProjectItem(
    id: 'project-1',
    name: 'Gikundiro youth training ground',
    description:
        'A governed club project to improve safe training facilities for the next generation.',
    currentTotal: 6400000,
    targetAmount: 10000000,
    memberCount: 486,
  ),
];
