import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_gamification/src/predict/predict_controller.dart';
import 'package:feat_gamification/src/predict/predict_models.dart';
import 'package:feat_gamification/src/predict/predict_repository.dart';
import 'package:feat_gamification/src/predict/predict_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:test_support/app_font_loader.dart';
import 'package:test_support/predict_fixture_images.dart';
import 'package:test_support/tab_shell_fixture.dart';
import 'predict_controller_test.dart' show Gateway, fixture;

class ScreenController extends PredictController {
  ScreenController(PredictState value) : super(Gateway(), autoLoad: false) {
    state = value;
  }
  int attempts = 0;
  @override
  Future<void> place(PredictFixture fixture, PredictSelection selection) async {
    attempts++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);
  setUp(() async {
    ConnectivityService.setOnlineForTest(true);
    await installPredictFixtureImages();
  });
  tearDown(() {
    ConnectivityService.setOnlineForTest(true);
    debugNetworkImageHttpClientProvider = null;
  });
  final cases = <String, PredictState>{
    'dark': PredictState(
      dashboard: PredictDashboard(
        enabled: true,
        memberSession: true,
        balanceFet: 500,
        fixtures: [fixture()],
      ),
    ),
    'light': PredictState(
      dashboard: PredictDashboard(
        enabled: true,
        memberSession: true,
        balanceFet: 500,
        fixtures: [fixture()],
      ),
    ),
    'large_text': PredictState(
      dashboard: PredictDashboard(
        enabled: true,
        memberSession: true,
        balanceFet: 500,
        fixtures: [fixture()],
      ),
    ),
    for (final name in ['focused', 'pressed'])
      name: PredictState(
        dashboard: PredictDashboard(
          enabled: true,
          memberSession: true,
          balanceFet: 500,
          fixtures: [fixture()],
        ),
      ),
    'loading': const PredictState(loading: true),
    'empty': const PredictState(
      dashboard: PredictDashboard(
        enabled: true,
        memberSession: true,
        balanceFet: 500,
      ),
    ),
    'disabled': const PredictState(dashboard: PredictDashboard()),
    'error': const PredictState(
      failure: PredictFailure.unavailable,
      needsReconciliation: true,
    ),
    'offline': PredictState(
      dashboard: PredictDashboard(
        enabled: true,
        memberSession: true,
        balanceFet: 500,
        fixtures: [fixture()],
      ),
    ),
    'selected': PredictState(
      dashboard: PredictDashboard(
        enabled: true,
        memberSession: true,
        balanceFet: 400,
        fixtures: [fixture(selection: PredictSelection.home)],
      ),
    ),
    'syncing': PredictState(
      pendingFixture: 'fixture',
      pendingSelection: PredictSelection.home,
      dashboard: PredictDashboard(
        enabled: true,
        memberSession: true,
        balanceFet: 500,
        fixtures: [fixture()],
      ),
    ),
    'conflict': PredictState(
      failure: PredictFailure.alreadyEntered,
      needsReconciliation: true,
      dashboard: PredictDashboard(
        enabled: true,
        memberSession: true,
        balanceFet: 500,
        fixtures: [fixture()],
      ),
    ),
    'security_timeout': PredictState(
      failure: PredictFailure.uncertain,
      needsReconciliation: true,
      dashboard: PredictDashboard(
        enabled: true,
        memberSession: true,
        balanceFet: 500,
        fixtures: [fixture()],
      ),
    ),
    'permission_denied': const PredictState(failure: PredictFailure.signIn),
    'guest': PredictState(
      dashboard: PredictDashboard(enabled: true, fixtures: [fixture()]),
    ),
    'reduced_motion': PredictState(
      dashboard: PredictDashboard(
        enabled: true,
        memberSession: true,
        balanceFet: 500,
        fixtures: [fixture()],
      ),
    ),
    'history': PredictState(
      dashboard: PredictDashboard(
        enabled: true,
        memberSession: true,
        balanceFet: 400,
        history: [fixture(selection: PredictSelection.draw)],
      ),
    ),
    'wallet': PredictState(
      dashboard: PredictDashboard(
        enabled: true,
        memberSession: true,
        balanceFet: 400,
        ledger: [
          PredictLedgerEntry(
            id: 'welcome',
            createdAt: DateTime.utc(2026, 9, 6),
            deltaFet: 500,
            type: 'predict_welcome',
          ),
          PredictLedgerEntry(
            id: 'entry',
            createdAt: DateTime.utc(2026, 9, 6),
            deltaFet: -100,
            type: 'predict_entry',
          ),
        ],
      ),
    ),
  };
  for (final entry in cases.entries) {
    testWidgets('Predict ${entry.key} state', (tester) async {
      final large = entry.key == 'large_text';
      final size = large ? const Size(320, 720) : const Size(390, 844);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      TypographyTokens.debugUseFallbackFonts = true;
      addTearDown(() => TypographyTokens.debugUseFallbackFonts = false);
      ColorTokens.setBrightness(
        entry.key == 'light' ? Brightness.light : Brightness.dark,
      );
      addTearDown(() => ColorTokens.setBrightness(Brightness.dark));
      ConnectivityService.setOnlineForTest(entry.key != 'offline');
      final c = ScreenController(entry.value);
      final router = GoRouter(
        initialLocation: '/predict',
        routes: [
          GoRoute(
            path: '/predict',
            builder: (_, __) => const RepaintBoundary(
              key: ValueKey('predict-golden'),
              child: TabShellFixture(
                index: 2,
                child: PredictScreen(embedded: true),
              ),
            ),
          ),
          GoRoute(
            path: '/auth/phone',
            builder: (_, state) =>
                Text('Phone entry: ${state.uri.queryParameters['from']}'),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [predictControllerProvider.overrideWith((ref) => c)],
          child: MaterialApp.router(
            theme: ClubTheme.from(
              ClubConfig.fallback(),
              brightness: entry.key == 'light'
                  ? Brightness.light
                  : Brightness.dark,
            ),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(large ? 2 : 1),
                disableAnimations: entry.key == 'reduced_motion',
              ),
              child: child!,
            ),
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();
      await tester.runAsync(() async {
        final context = tester.element(find.byType(PredictScreen));
        await Future.wait([
          precacheImage(
            const NetworkImage('https://example.com/home.png'),
            context,
          ),
          precacheImage(
            const NetworkImage('https://example.com/away.png'),
            context,
          ),
        ]);
      });
      await tester.pump(const Duration(milliseconds: 300));
      if (entry.key == 'history') await tester.tap(find.text('My picks'));
      if (entry.key == 'wallet') {
        await tester.tap(find.text('FET activity').first);
      }
      final pick = find.byKey(const ValueKey('predict-fixture-home'));
      TestGesture? heldPress;
      if (entry.key == 'pressed') {
        heldPress = await tester.startGesture(tester.getCenter(pick));
      }
      if (entry.key == 'focused') {
        final focus = Focus.of(
          tester.element(
            find
                .descendant(of: pick, matching: find.byType(GestureDetector))
                .first,
          ),
        );
        FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.alwaysTraditional;
        addTearDown(
          () => FocusManager.instance.highlightStrategy =
              FocusHighlightStrategy.automatic,
        );
        focus.requestFocus();
      }
      if (entry.key == 'dark') {
        final semantics = tester.ensureSemantics();
        expect(
          tester
              .getSemantics(pick)
              .getSemanticsData()
              .hasAction(SemanticsAction.tap),
          isTrue,
        );
        semantics.dispose();
      }
      await tester.pump(const Duration(milliseconds: 300));
      tester
          .renderObject(find.byKey(const ValueKey('predict-golden')))
          .markNeedsPaint();
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Create a new'), findsNothing);
      if (pick.evaluate().isNotEmpty) {
        final choices = [
          for (final selection in PredictSelection.values)
            tester.getRect(
              find.byKey(ValueKey('predict-fixture-${selection.name}')),
            ),
        ];
        for (final rect in choices) {
          expect(rect.height, greaterThanOrEqualTo(48));
          expect(rect.height, closeTo(choices.first.height, .01));
          expect(rect.width, closeTo(choices.first.width, .01));
          if (large) {
            expect(rect.left, closeTo(choices.first.left, .01));
          } else {
            expect(rect.top, closeTo(choices.first.top, .01));
          }
        }
        if (large) {
          for (var i = 1; i < choices.length; i++) {
            expect(choices[i].top, greaterThanOrEqualTo(choices[i - 1].bottom));
          }
        }
        expect(find.text('RAY'), findsOneWidget);
        expect(find.text('APR'), findsOneWidget);
        for (final label in ['RAY', 'Draw', 'APR']) {
          final paragraph = tester.renderObject<RenderParagraph>(
            find.text(label),
          );
          expect(
            paragraph.getBoxesForSelection(
              TextSelection(baseOffset: 0, extentOffset: label.length),
            ),
            hasLength(1),
            reason: '$label must stay on one line',
          );
        }
      }
      if (large) {
        // Review the reflowed choices after a real scroll, so all three
        // enlarged targets are visible in the narrow-phone capture.
        await tester.ensureVisible(
          find.byKey(const ValueKey('predict-fixture-away')),
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .getBottomRight(
                find.byKey(const ValueKey('predict-fixture-away')),
              )
              .dy,
          lessThanOrEqualTo(size.height),
        );
      }
      await expectLater(
        find.byKey(const ValueKey('predict-golden')),
        matchesGoldenFile(
          'goldens/predict_state_${entry.key}_${entry.key == 'light' ? 'light' : 'dark'}_${size.width.toInt()}x${size.height.toInt()}.png',
        ),
      );
      if (heldPress != null) {
        await heldPress.up();
        await tester.pumpAndSettle();
        expect(c.attempts, 0);
        await tester.tap(find.byKey(const ValueKey('predict-confirm-pick')));
        await tester.pumpAndSettle();
        expect(c.attempts, 1);
      }
      if (entry.key == 'focused') {
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(c.attempts, 0);
        await tester.tap(find.byKey(const ValueKey('predict-confirm-pick')));
        await tester.pumpAndSettle();
        expect(c.attempts, 1);
      }
      if (entry.key == 'guest') {
        await tester.tap(find.byKey(const ValueKey('predict-fixture-home')));
        await tester.pumpAndSettle();
        expect(find.text('Phone entry: /predict'), findsOneWidget);
        expect(c.attempts, 0);
      }
      if ([
        'offline',
        'selected',
        'syncing',
        'conflict',
        'security_timeout',
      ].contains(entry.key)) {
        final control = tester.widget<AfriOutlinedButton>(
          find.byKey(const ValueKey('predict-fixture-home')),
        );
        expect(control.onPressed, isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      debugNetworkImageHttpClientProvider = null;
    });
  }
}
