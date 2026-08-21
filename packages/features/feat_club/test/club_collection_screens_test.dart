import 'dart:async';

import 'package:core_l10n/core_l10n.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_club/feat_club.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  setUp(() => ConnectivityService.setOnlineForTest(true));
  tearDown(() => ConnectivityService.setOnlineForTest(true));

  testWidgets('announces the Club collection loading state', (tester) async {
    final gateway = _PendingClubContentGateway();

    await tester.pumpWidget(_testApp(gateway));
    await tester.pump();

    final l10n = lookupAfriLocalizations(const Locale('en'));
    expect(
      find.bySemanticsLabel(
        l10n.splashLoadingSemantic(l10n.clubNewsTitle.toUpperCase()),
      ),
      findsOneWidget,
    );

    gateway.completeNews();
    await tester.pumpAndSettle();
  });

  testWidgets('exits loading when Club data exceeds the bounded timeout', (
    tester,
  ) async {
    final gateway = _PendingClubContentGateway();

    await tester.pumpWidget(
      _testApp(gateway, timeout: const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump();

    final l10n = lookupAfriLocalizations(const Locale('en'));
    expect(find.text(l10n.clubSecurityTimeoutTitle), findsOneWidget);
    expect(find.text(l10n.retry), findsOneWidget);
  });

  testWidgets('distinguishes permission denial from a retryable failure', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        _ThrowingClubContentGateway(StateError('RLS permission denied')),
      ),
    );
    await tester.pumpAndSettle();

    final l10n = lookupAfriLocalizations(const Locale('en'));
    expect(find.text(l10n.clubAccessDeniedTitle), findsOneWidget);
    expect(find.text(l10n.retry), findsNothing);
  });

  testWidgets('shows the explicit offline state before an initial load', (
    tester,
  ) async {
    ConnectivityService.setOnlineForTest(false);
    final gateway = _PendingClubContentGateway();

    await tester.pumpWidget(_testApp(gateway));
    await tester.pump();

    final l10n = lookupAfriLocalizations(const Locale('en'));
    expect(find.text(l10n.clubOfflineTitle), findsOneWidget);

    gateway.completeNews();
    await tester.pumpAndSettle();
  });

  testWidgets('identifies conflicting Club projections', (tester) async {
    await tester.pumpWidget(
      _testApp(
        _ThrowingClubContentGateway(StateError('stale version conflict')),
      ),
    );
    await tester.pumpAndSettle();

    final l10n = lookupAfriLocalizations(const Locale('en'));
    expect(find.text(l10n.clubChangedTitle), findsOneWidget);
    expect(find.text(l10n.retry), findsOneWidget);
  });
}

Widget _testApp(
  ClubContentGateway gateway, {
  Duration timeout = const Duration(seconds: 12),
}) {
  final config = ClubConfig.fallback();
  final router = GoRouter(
    initialLocation: '/club/news',
    routes: <RouteBase>[
      GoRoute(path: '/club/news', builder: (_, __) => const ClubNewsScreen()),
    ],
  );

  return ProviderScope(
    overrides: <Override>[
      clubContentGatewayProvider.overrideWithValue(gateway),
      clubContentLoadTimeoutProvider.overrideWithValue(timeout),
    ],
    child: AfriLocalizationsScope(
      locale: const Locale('en'),
      child: ClubConfigScope(
        config: config,
        child: MaterialApp.router(
          theme: ClubTheme.from(config),
          routerConfig: router,
        ),
      ),
    ),
  );
}

class _PendingClubContentGateway implements ClubContentGateway {
  final Completer<List<ClubNewsItem>> _news = Completer<List<ClubNewsItem>>();

  void completeNews() => _news.complete(const <ClubNewsItem>[]);

  @override
  Future<ClubOverview?> loadOverview() async => null;

  @override
  Future<List<ClubHistoryItem>> loadHistory() async => const [];

  @override
  Future<List<ClubFixtureItem>> loadMatches() async => const [];

  @override
  Future<List<ClubNewsItem>> loadNews() => _news.future;

  @override
  Future<List<ClubProjectItem>> loadProjects() async => const [];

  @override
  Future<List<ClubSquadMember>> loadSquad() async => const [];

  @override
  Future<List<ClubStandingItem>> loadStandings() async => const [];
}

class _ThrowingClubContentGateway implements ClubContentGateway {
  const _ThrowingClubContentGateway(this.error);

  final Object error;

  Future<T> _fail<T>() => Future<T>.error(error);

  @override
  Future<ClubOverview?> loadOverview() => _fail<ClubOverview?>();

  @override
  Future<List<ClubHistoryItem>> loadHistory() => _fail<List<ClubHistoryItem>>();

  @override
  Future<List<ClubFixtureItem>> loadMatches() => _fail<List<ClubFixtureItem>>();

  @override
  Future<List<ClubNewsItem>> loadNews() => _fail<List<ClubNewsItem>>();

  @override
  Future<List<ClubProjectItem>> loadProjects() =>
      _fail<List<ClubProjectItem>>();

  @override
  Future<List<ClubSquadMember>> loadSquad() => _fail<List<ClubSquadMember>>();

  @override
  Future<List<ClubStandingItem>> loadStandings() =>
      _fail<List<ClubStandingItem>>();
}
