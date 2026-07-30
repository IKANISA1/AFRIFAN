import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_club/feat_club.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows official club identity and canonical destinations', (
    tester,
  ) async {
    await tester.pumpWidget(_testApp(_FakeClubContentGateway()));
    await tester.pumpAndSettle();

    final l10n = lookupAfriLocalizations(const Locale('en'));
    expect(find.text('Rayon Sports FC'), findsOneWidget);
    expect(find.text('Gikundiro'), findsOneWidget);
    expect(find.text(l10n.clubTeamTitle), findsOneWidget);
    expect(find.text(l10n.clubNewsTitle), findsOneWidget);
    expect(find.text(l10n.clubFixturesTitle), findsOneWidget);
    expect(find.text(l10n.clubResultsTitle), findsOneWidget);
    expect(find.text(l10n.clubStandingsTitle), findsOneWidget);
    expect(find.text(l10n.clubHistoryTitle), findsOneWidget);
    expect(find.text(l10n.clubProjectsTitle), findsOneWidget);
    expect(find.text(l10n.clubTicketsTitle), findsOneWidget);
    expect(find.text(l10n.clubShopTitle), findsOneWidget);
  });

  testWidgets('retains verified app identity when live club lookup fails', (
    tester,
  ) async {
    await tester.pumpWidget(_testApp(_FailingClubContentGateway()));
    await tester.pumpAndSettle();

    expect(find.text('AFRICLUB'), findsOneWidget);
    expect(find.text('Live club identity unavailable'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  for (final locale in const <Locale>[
    Locale('fr'),
    Locale('rw'),
  ]) {
    testWidgets(
      'renders the official Club hub in ${locale.languageCode}',
      (tester) async {
        await tester.pumpWidget(
          _testApp(_FakeClubContentGateway(), appLocale: locale),
        );
        await tester.pumpAndSettle();

        final l10n = lookupAfriLocalizations(locale);
        expect(find.text(l10n.clubOfficialSection), findsOneWidget);
        expect(find.text(l10n.clubTeamTitle), findsOneWidget);
        expect(find.text(l10n.clubNewsTitle), findsOneWidget);
        expect(find.text(l10n.clubFixturesTitle), findsOneWidget);
        expect(find.text(l10n.clubProjectsTitle), findsOneWidget);
        expect(find.text(l10n.clubShopTitle), findsOneWidget);
      },
    );
  }
}

Widget _testApp(
  ClubContentGateway gateway, {
  Locale appLocale = const Locale('en'),
}) {
  final config = ClubConfig.fallback();
  return ProviderScope(
    overrides: <Override>[
      clubContentGatewayProvider.overrideWithValue(gateway),
    ],
    child: AfriLocalizationsScope(
      locale: appLocale,
      child: MaterialApp(
        theme: ClubTheme.from(config),
        home: ClubConfigScope(
          config: config,
          child: const ClubHubScreen(),
        ),
      ),
    ),
  );
}

class _FakeClubContentGateway implements ClubContentGateway {
  @override
  Future<ClubOverview?> loadOverview() async => const ClubOverview(
        id: 24,
        name: 'Rayon Sports FC',
        country: 'Rwanda',
        league: 'Rwanda Premier League',
        slug: 'rayon_sports_rw',
        nickname: 'Gikundiro',
      );

  @override
  Future<List<ClubHistoryItem>> loadHistory() async => const [];

  @override
  Future<List<ClubFixtureItem>> loadMatches() async => const [];

  @override
  Future<List<ClubNewsItem>> loadNews() async => const [];

  @override
  Future<List<ClubProjectItem>> loadProjects() async => const [];

  @override
  Future<List<ClubSquadMember>> loadSquad() async => const [];

  @override
  Future<List<ClubStandingItem>> loadStandings() async => const [];
}

class _FailingClubContentGateway extends _FakeClubContentGateway {
  @override
  Future<ClubOverview?> loadOverview() {
    throw StateError('offline');
  }
}
