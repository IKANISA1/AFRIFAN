import 'package:core_auth/core_auth.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_gamification/src/predict/predict_controller.dart';
import 'package:feat_gamification/src/predict/predict_models.dart';
import 'package:feat_gamification/src/predict/predict_repository.dart';
import 'package:feat_gamification/src/predict/predict_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:test_support/predict_fixture_images.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  Future<void> capture(String name) async {
    await binding.takeScreenshot(name);
    if (const bool.fromEnvironment('AFRICLUB_CAPTURE_SYSTEM')) {
      // Host simctl captures avoid the integration plugin's partial repaint frames.
      // ignore: avoid_print
      print('AFRICLUB_PREDICT_CAPTURE $name');
      await Future<void>.delayed(const Duration(seconds: 3));
    }
  }

  testWidgets('native Predict records one result and shows confirmed history', (
    tester,
  ) async {
    ConnectivityService.setOnlineForTest(true);
    ColorTokens.setBrightness(Brightness.dark);
    await installPredictFixtureImages();
    final gateway = _Gateway();
    final router = GoRouter(
      initialLocation: '/predict',
      routes: [
        GoRoute(path: '/predict', builder: (_, __) => const PredictScreen()),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWith(
            (ref) =>
                const UserProfile(id: 'synthetic-predict-user', clubId: '24'),
          ),
          predictGatewayProvider.overrideWithValue(gateway),
        ],
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
    expect(find.text('500 FET'), findsOneWidget);
    expect(find.text('Draw'), findsOneWidget);
    await capture('predict-native-ready');
    await tester.tap(find.byKey(const ValueKey('predict-native-fixture-draw')));
    await tester.tap(
      find.byKey(const ValueKey('predict-native-fixture-draw')),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    expect(gateway.entries, 0);
    await capture('predict-native-review');
    await tester.tap(find.byKey(const ValueKey('predict-confirm-pick')));
    await tester.pumpAndSettle();
    expect(gateway.entries, 1);
    expect(find.text('400 FET'), findsOneWidget);
    expect(find.text('Draw · Picked'), findsOneWidget);
    await capture('predict-native-confirmed');
    await tester.tap(find.text('My picks'));
    await tester.pumpAndSettle();
    expect(find.text('Draw · Picked'), findsOneWidget);
    await capture('predict-native-history');
    await tester.tap(find.text('FET activity').first);
    await tester.pumpAndSettle();
    expect(find.text('-100 FET'), findsOneWidget);
    await capture('predict-native-wallet');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    router.dispose();
    debugNetworkImageHttpClientProvider = null;
  });
}

class _Gateway implements PredictGateway {
  int entries = 0;
  PredictFixture get fixture => PredictFixture(
    id: 'native-fixture',
    poolId: 'native-pool',
    competitionId: 'test-league',
    competition: 'Rwanda Premier League',
    homeTeam: 'Home FC',
    awayTeam: 'Away FC',
    homeCrest: 'https://example.com/home.png',
    awayCrest: 'https://example.com/away.png',
    kickoffAt: DateTime.utc(2030, 9, 17, 16, 30),
    locksAt: DateTime.utc(2030, 9, 17, 16, 30),
    stakeFet: 100,
    selection: entries == 0 ? null : PredictSelection.draw,
  );
  @override
  Future<PredictDashboard> load() async => PredictDashboard(
    enabled: true,
    memberSession: true,
    balanceFet: 500 - entries * 100,
    fixtures: [fixture],
    history: entries == 0 ? [] : [fixture],
    ledger: [
      PredictLedgerEntry(
        id: 'welcome',
        createdAt: DateTime.utc(2026, 9, 6),
        deltaFet: 500,
        type: 'predict_welcome',
      ),
      if (entries > 0)
        PredictLedgerEntry(
          id: 'entry',
          createdAt: DateTime.utc(2026, 9, 6),
          deltaFet: -100,
          type: 'predict_entry',
        ),
    ],
  );
  @override
  Future<PredictConfirmation> place(
    String fixtureId,
    PredictSelection selection,
  ) async {
    entries++;
    return PredictConfirmation(fixture, 400);
  }
}
