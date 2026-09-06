import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_club/feat_club.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  Future<void> capture(String name) async {
    await binding.takeScreenshot(name);
    if (const bool.fromEnvironment('AFRICLUB_CAPTURE_SYSTEM')) {
      // ignore: avoid_print
      print('AFRICLUB_CLUB_CAPTURE $name');
      await Future<void>.delayed(const Duration(seconds: 3));
    }
  }

  testWidgets('Club shows sourced identity and opens its history', (
    tester,
  ) async {
    ConnectivityService.setOnlineForTest(true);
    ColorTokens.setBrightness(Brightness.dark);
    final router = GoRouter(
      initialLocation: '/club',
      routes: [
        GoRoute(
          path: '/club',
          builder: (_, __) => const ClubHubScreen(),
          routes: ClubModule().routes,
        ),
        GoRoute(
          path: '/membership',
          builder: (_, __) => const Scaffold(body: Text('Membership')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [clubContentGatewayProvider.overrideWithValue(_Gateway())],
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: ClubTheme.from(
            ClubConfig.fallback(),
            brightness: Brightness.dark,
          ),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Rayon Sports FC'), findsOneWidget);
    expect(find.text('Nyanza, Southern Province, Rwanda'), findsOneWidget);
    expect(find.text('Blue and white'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    await capture('club-native-ready');
    await tester.ensureVisible(find.text('Club history'));
    await tester.pumpAndSettle();
    await capture('club-native-details');
    await tester.tap(find.text('Club history'));
    await tester.pumpAndSettle();
    expect(find.text('Roots in Nyanza'), findsOneWidget);
    expect(find.text('Based in Kigali'), findsOneWidget);
    await capture('club-native-history');
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
  });
}

class _Gateway implements ClubContentGateway {
  @override
  Future<ClubOverview?> loadOverview() async => const ClubOverview(
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
  @override
  Future<List<ClubHistoryItem>> loadHistory() async => const [
    ClubHistoryItem(
      id: 'nyanza',
      title: 'Roots in Nyanza',
      subtitle: 'Nyanza, Southern Province',
      body:
          "Rayon Sports FC traces its roots to Nyanza in Rwanda's Southern Province.",
      sortOrder: 10,
    ),
    ClubHistoryItem(
      id: 'kigali',
      title: 'Based in Kigali',
      subtitle: 'Kigali, Rwanda',
      body:
          'The club is now based in Kigali while retaining its historic connection to Nyanza.',
      sortOrder: 20,
    ),
    ClubHistoryItem(
      id: 'gikundiro',
      title: 'Gikundiro',
      subtitle: 'Supporter identity',
      body:
          'Gikundiro is the supporter identity carried by Rayon Sports FC across its official social presence.',
      sortOrder: 30,
    ),
  ];
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
