import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_admin/src/admin_predict_controller.dart';
import 'package:feat_admin/src/screens/predict_ops_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_support/app_font_loader.dart';
import 'admin_predict_controller_test.dart' show Gateway;

class Controller extends AdminPredictController {
  Controller(AdminPredictState value) : super(Gateway(), autoLoad: false) {
    state = value;
  }
  PredictAdminAction? submitted;
  Map<String, Object?>? parameters;
  @override
  Future<void> command(
    PredictAdminAction action,
    Map<String, Object?> params,
  ) async {
    submitted = action;
    parameters = params;
  }
}

AdminPredictData data({bool finalScore = true}) => AdminPredictData(
  enabled: true,
  fixtures: [
    AdminPredictFixture({
      'id': 'fixture',
      'pool_id': 'pool',
      'home_team': 'Rayon Sports FC',
      'away_team': 'APR FC',
      'competition': 'Rwanda Premier League',
      'status': 'locked',
      'fixture_status': finalScore ? 'finished' : 'scheduled',
      'kickoff_at': '2026-09-05T16:00:00Z',
      'entry_count': 3,
      'staked_fet': 300,
      'paid_fet': 0,
      'stake_fet': 100,
      'home_score': finalScore ? 2 : null,
      'away_score': finalScore ? 1 : null,
      'result_confirmed': false,
    }),
  ],
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);
  for (final name in [
    'dark',
    'light',
    'large_text',
    'loading',
    'empty',
    'offline',
    'error',
    'permission_denied',
    'syncing',
    'automatic_result',
    'awaiting_result',
    'settings',
    'refund',
  ]) {
    testWidgets('Predict operations $name', (tester) async {
      final size = name == 'large_text'
          ? const Size(320, 720)
          : const Size(390, 844);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      TypographyTokens.debugUseFallbackFonts = true;
      addTearDown(() => TypographyTokens.debugUseFallbackFonts = false);
      ColorTokens.setBrightness(
        name == 'light' ? Brightness.light : Brightness.dark,
      );
      addTearDown(() => ColorTokens.setBrightness(Brightness.dark));
      ConnectivityService.setOnlineForTest(name != 'offline');
      addTearDown(() => ConnectivityService.setOnlineForTest(true));
      final c = Controller(switch (name) {
        'loading' => const AdminPredictState(loading: true),
        'empty' => const AdminPredictState(data: AdminPredictData()),
        'error' => AdminPredictState(data: data(), failed: true),
        'permission_denied' => const AdminPredictState(
          denied: true,
          failed: true,
        ),
        'awaiting_result' => AdminPredictState(data: data(finalScore: false)),
        'syncing' => AdminPredictState(data: data(), busy: true),
        _ => AdminPredictState(data: data()),
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [adminPredictProvider.overrideWith((ref) => c)],
          child: MaterialApp(
            theme: ClubTheme.from(
              ClubConfig.fallback(),
              brightness: name == 'light' ? Brightness.light : Brightness.dark,
            ),
            builder: (context, child) => RepaintBoundary(
              key: const ValueKey('admin-predict-golden'),
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(name == 'large_text' ? 2 : 1),
                ),
                child: child!,
              ),
            ),
            home: const PredictOpsScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      if (c.state.data?.fixtures.isNotEmpty ?? false) {
        if (name == 'large_text') {
          await tester.scrollUntilVisible(find.byType(AfriFixtureTeams), 200);
        }
        final context = tester.element(find.byType(AfriFixtureTeams).first);
        await tester.runAsync(() async {
          for (final name in ['Rayon Sports FC', 'APR FC']) {
            await precacheImage(
              AssetImage(teamAssetFor(name)!.asset!),
              context,
            );
          }
        });
        await tester.pump();
        expect(
          tester
              .widgetList<RawImage>(find.byType(RawImage))
              .where((image) => image.image != null),
          hasLength(2),
        );
      }
      if (name != 'loading' && name != 'syncing') {
        await tester.pumpAndSettle();
      }
      expect(find.textContaining('Confirm result'), findsNothing);
      if (name == 'automatic_result' || name == 'awaiting_result') {
        final resultLabel = name == 'automatic_result'
            ? 'Final score · 2–1'
            : 'Waiting for the final result';
        await tester.ensureVisible(find.text(resultLabel));
        expect(find.text(resultLabel), findsOneWidget);
        expect(
          find.text(
            'LiveScore validates and confirms results automatically. No manual confirmation is needed.',
          ),
          findsOneWidget,
        );
        expect(find.byType(TextField), findsNothing);
        expect(c.submitted, isNull);
      }
      if (name == 'settings') {
        await tester.tap(find.text('Settings'));
        await tester.pumpAndSettle();
      }
      if (name == 'refund') {
        await tester.ensureVisible(find.text('Void and refund'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Void and refund'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Fixture cancelled');
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
      expect(find.text('Lock'), findsNothing);
      await expectLater(
        find.byKey(const ValueKey('admin-predict-golden')),
        matchesGoldenFile(
          'goldens/admin_predict_state_${name}_${name == 'light' ? 'light' : 'dark'}_${name == 'large_text' ? '320x720' : '390x844'}.png',
        ),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }
}
