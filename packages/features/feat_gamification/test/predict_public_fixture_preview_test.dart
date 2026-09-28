import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_club/feat_club.dart';
import 'package:feat_gamification/src/predict/predict_controller.dart';
import 'package:feat_gamification/src/predict/predict_models.dart';
import 'package:feat_gamification/src/predict/predict_repository.dart';
import 'package:feat_gamification/src/predict/predict_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _DisabledGateway implements PredictGateway {
  @override
  Future<PredictDashboard> load() async => const PredictDashboard();

  @override
  Future<PredictConfirmation> place(
    String fixtureId,
    PredictSelection selection,
  ) async => throw PredictFailure.unavailable;
}

class _DisabledController extends PredictController {
  _DisabledController() : super(_DisabledGateway(), autoLoad: false) {
    state = const PredictState(dashboard: PredictDashboard());
  }
}

void main() {
  testWidgets('Predict shows sourced fixtures without pick controls', (
    tester,
  ) async {
    ConnectivityService.setOnlineForTest(true);
    final router = GoRouter(
      initialLocation: '/predict',
      routes: [
        GoRoute(path: '/predict', builder: (_, __) => const PredictScreen()),
      ],
    );
    addTearDown(router.dispose);
    final match = ClubFixtureItem(
      id: 'gikundiro-verified-fixture',
      homeTeam: 'Rayon Sports FC',
      awayTeam: 'APR FC',
      competition: 'Rwanda Premier League',
      venue: 'Amahoro Stadium',
      matchDate: DateTime.now().add(const Duration(days: 7)),
      kickoffTime: '18:00',
      status: 'scheduled',
      homeScore: 0,
      awayScore: 0,
      isOnSale: false,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          predictControllerProvider.overrideWith(
            (ref) => _DisabledController(),
          ),
          predictPublicFixturePreviewEnabledProvider.overrideWithValue(true),
          clubMatchesProvider.overrideWith((ref) async => [match]),
        ],
        child: MaterialApp.router(
          theme: ClubTheme.from(ClubConfig.fallback()),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Upcoming Rayon Sports fixtures'), findsOneWidget);
    expect(find.text('Rayon Sports FC vs APR FC'), findsOneWidget);
    expect(
      find.textContaining('Predictions are unavailable here'),
      findsOneWidget,
    );
    expect(find.byType(PredictFixtureCard), findsNothing);
  });
}
