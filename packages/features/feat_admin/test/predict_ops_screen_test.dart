import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_admin/src/admin_predict_controller.dart';
import 'package:feat_admin/src/screens/predict_ops_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:test_support/app_font_loader.dart';

import '../../../testing/test_support/test/fixtures/local_route_state_assertions.dart';
import 'admin_predict_controller_test.dart' show Gateway;

class Controller extends AdminPredictController {
  Controller(
    AdminPredictState value, {
    AdminPredictGateway? gateway,
    Duration timeout = const Duration(seconds: 12),
    this.realCommands = false,
  }) : super(gateway ?? Gateway(), timeout: timeout, autoLoad: false) {
    state = value;
  }
  PredictAdminAction? submitted;
  Map<String, Object?>? parameters;
  final bool realCommands;
  @override
  Future<void> command(
    PredictAdminAction action,
    Map<String, Object?> params,
  ) async {
    if (realCommands) return super.command(action, params);
    submitted = action;
    parameters = params;
  }
}

AdminPredictData data({bool finalScore = true, bool legacy = false}) =>
    AdminPredictData(
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
          'staked_fet': legacy ? 300 : 0,
          'paid_fet': 0,
          'stake_fet': legacy ? 100 : 0,
          'economics_version': legacy ? 'legacy_paid_v1' : 'free_v1',
          'home_score': finalScore ? 2 : null,
          'away_score': finalScore ? 1 : null,
          'result_confirmed': false,
        }),
      ],
    );
void main({bool localStateCoverage = false}) {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);
  Future<void> pumpOperations(
    WidgetTester tester,
    Controller controller,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    ConnectivityService.setOnlineForTest(true);
    addTearDown(() => ConnectivityService.setOnlineForTest(true));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [adminPredictProvider.overrideWith((ref) => controller)],
        child: MaterialApp(
          theme: ClubTheme.from(localRouteConfigOrFallback()),
          home: const PredictOpsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'free operations settings send fixed zero entry without a price field',
    (tester) async {
      final controller = Controller(AdminPredictState(data: data()));
      await pumpOperations(tester, controller);
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.widgetWithText(AfriTextButton, 'Save settings'));
      await tester.pumpAndSettle();
      expect(controller.submitted, PredictAdminAction.settings);
      expect(controller.parameters, {'p_enabled': true, 'p_entry_fet': 0});
    },
  );

  testWidgets('free operations confirm the authoritative score with a source', (
    tester,
  ) async {
    final controller = Controller(AdminPredictState(data: data()));
    await pumpOperations(tester, controller);
    await tester.ensureVisible(find.text('Confirm final result'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm final result'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(
      find.byType(TextField),
      'https://results.invalid/fixture',
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(AfriTextButton, 'Confirm final result'),
    );
    await tester.pumpAndSettle();
    expect(controller.submitted, PredictAdminAction.confirmResult);
    expect(controller.parameters, {
      'p_pool_id': 'pool',
      'p_home_score': 2,
      'p_away_score': 1,
      'p_source_url': 'https://results.invalid/fixture',
    });
  });

  testWidgets(
    'historical paid operations remain visible without client settlement actions',
    (tester) async {
      final controller = Controller(
        AdminPredictState(data: data(legacy: true)),
      );
      await pumpOperations(tester, controller);
      expect(find.textContaining('Historical paid pool.'), findsOneWidget);
      expect(find.text('Confirm final result'), findsNothing);
      expect(find.text('Void free entries'), findsNothing);
      expect(controller.submitted, isNull);
    },
  );
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
    if (localStateCoverage) ...[
      'disabled',
      'focused',
      'pressed',
      'selected',
      'reduced_motion',
      'conflict',
      'security_timeout',
    ],
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
      final gateway = Gateway();
      if (name == 'conflict') {
        gateway.error = const PostgrestException(
          message: 'private revision conflict',
          code: '40001',
        );
      }
      if (name == 'security_timeout') gateway.pending = Completer<void>();
      final c = Controller(
        switch (name) {
          'loading' => const AdminPredictState(loading: true),
          'empty' => const AdminPredictState(data: AdminPredictData()),
          'error' => AdminPredictState(data: data(), failed: true),
          'permission_denied' => const AdminPredictState(
            denied: true,
            failed: true,
          ),
          'awaiting_result' => AdminPredictState(data: data(finalScore: false)),
          'syncing' => AdminPredictState(data: data(), busy: true),
          'disabled' => AdminPredictState(data: data(), busy: true),
          _ => AdminPredictState(data: data()),
        },
        gateway: gateway,
        timeout: const Duration(milliseconds: 100),
        realCommands: name == 'security_timeout',
      );
      if (name == 'conflict') {
        await c.refresh();
        expect(c.state.failed, isTrue);
        expect(c.state.data, isNotNull);
        expect(c.state.canAct, isFalse);
      }
      if (name == 'security_timeout') {
        final pending = c.command(PredictAdminAction.settings, {
          'synthetic': true,
        });
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 101));
        await pending;
        expect(c.state.failed, isTrue);
        expect(gateway.mutations, 1);
        await c.command(PredictAdminAction.settings, {});
        expect(gateway.mutations, 1);
        gateway.pending!.complete();
      }
      await tester.pumpWidget(
        ProviderScope(
          overrides: [adminPredictProvider.overrideWith((ref) => c)],
          child: MaterialApp(
            theme: ClubTheme.from(
              localRouteConfigOrFallback(),
              brightness: name == 'light' ? Brightness.light : Brightness.dark,
            ),
            builder: (context, child) => RepaintBoundary(
              key: const ValueKey('admin-predict-golden'),
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(name == 'large_text' ? 2 : 1),
                  disableAnimations: name == 'reduced_motion',
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
      if (name != 'loading' && name != 'syncing' && name != 'disabled') {
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
            'Review the verified final score and record its source before settling free entries.',
          ),
          findsOneWidget,
        );
        expect(find.byType(TextField), findsNothing);
        expect(c.submitted, isNull);
      }
      if (name == 'large_text') {
        for (final label in ['Confirm final result', 'Void free entries']) {
          final action = find.widgetWithText(AfriButton, label);
          await tester.ensureVisible(action);
          await tester.pumpAndSettle();
          expect(action.hitTestable(), findsOneWidget);
        }
        await tester.ensureVisible(find.byType(AfriFixtureTeams));
        await tester.pumpAndSettle();
      }
      if (name == 'settings') {
        await tester.tap(find.text('Settings'));
        await tester.pumpAndSettle();
      }
      if (name == 'disabled') {
        expect(
          tester
              .widget<AfriButton>(find.widgetWithText(AfriButton, 'Settings'))
              .enabled,
          isFalse,
        );
      }
      if (name == 'focused') {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(FocusManager.instance.primaryFocus?.context, isNotNull);
      }
      if (name == 'selected') {
        await tester.tap(find.widgetWithText(AfriChoiceChip, 'Settled'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<AfriChoiceChip>(
                find.widgetWithText(AfriChoiceChip, 'Settled'),
              )
              .selected,
          isTrue,
        );
      }
      TestGesture? held;
      if (name == 'pressed') {
        held = await tester.startGesture(
          tester.getCenter(find.widgetWithText(AfriButton, 'Settings')),
        );
        await tester.pump(const Duration(milliseconds: 120));
        await tester.pump(AfriMotion.press);
      }
      if (name == 'refund') {
        await tester.ensureVisible(find.text('Void free entries'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Void free entries'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Fixture cancelled');
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
      expect(find.text('Lock'), findsNothing);
      await expectGoldenOrClubAssertions(
        tester,
        find.byKey(const ValueKey('admin-predict-golden')),

        'goldens/admin_predict_state_${name}_${name == 'light' ? 'light' : 'dark'}_${name == 'large_text' ? '320x720' : '390x844'}.png',
        route: '/admin/predict',
        kind: 'route',
        surface: 'mobile_internal_admin',
      );
      await held?.cancel();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }
}
