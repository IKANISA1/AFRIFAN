import 'package:core_l10n/core_l10n.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_gamification/src/controllers/venue_checkin_controller.dart';
import 'package:feat_gamification/src/screens/venue_checkin_screen.dart';
import 'package:feat_gamification/src/venue_checkin_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:test_support/app_font_loader.dart';

const _goldens = <String, String>{
  'loading': 'goldens/venue_checkin_state_loading_dark_390x844.png',
  'empty': 'goldens/venue_checkin_state_empty_dark_390x844.png',
  'error': 'goldens/venue_checkin_state_error_dark_390x844.png',
  'offline': 'goldens/venue_checkin_state_offline_dark_390x844.png',
  'permission_denied':
      'goldens/venue_checkin_state_permission_denied_dark_390x844.png',
  'disabled': 'goldens/venue_checkin_state_disabled_dark_390x844.png',
  'focused': 'goldens/venue_checkin_state_focused_dark_390x844.png',
  'pressed': 'goldens/venue_checkin_state_pressed_dark_390x844.png',
  'selected': 'goldens/venue_checkin_state_selected_dark_390x844.png',
  'large_text': 'goldens/venue_checkin_state_large_text_dark_320x720.png',
  'reduced_motion':
      'goldens/venue_checkin_state_reduced_motion_dark_390x844.png',
  'dark': 'goldens/venue_checkin_state_dark_dark_390x844.png',
  'light': 'goldens/venue_checkin_state_light_light_390x844.png',
  'syncing': 'goldens/venue_checkin_state_syncing_dark_390x844.png',
  'conflict': 'goldens/venue_checkin_state_conflict_dark_390x844.png',
  'security_timeout':
      'goldens/venue_checkin_state_security_timeout_dark_390x844.png',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);
  setUp(() => ConnectivityService.setOnlineForTest(true));
  tearDown(() => ConnectivityService.setOnlineForTest(true));

  testWidgets('Venue check-in clears offline state after reconnect', (
    tester,
  ) async {
    ConnectivityService.setOnlineForTest(false);
    final controller = _Controller(
      const AsyncData(
        VenueCheckinRouteState(
          phase: VenueCheckinPhase.degraded,
          failure: VenueCheckinFailure(VenueCheckinFailureKind.offline),
        ),
      ),
    );
    await _pumpRoute(
      tester,
      controller: controller,
      online: false,
      capture: false,
    );

    ConnectivityService.setOnlineForTest(true);
    await tester.pump();
    await tester.pump();
    expect(controller.restoredCalls, 1);
  });

  testWidgets('golden Venue check-in loading state', (tester) async {
    await _pumpState(
      tester,
      id: 'loading',
      value: const AsyncLoading<VenueCheckinRouteState>(),
      settle: false,
    );
  });

  testWidgets('golden Venue check-in empty state', (tester) async {
    await _pumpState(
      tester,
      id: 'empty',
      value: const AsyncData(VenueCheckinRouteState()),
      check: (_) async =>
          expect(find.text('Ready for venue check-in'), findsOneWidget),
    );
  });

  testWidgets('golden Venue check-in error state', (tester) async {
    await _pumpState(
      tester,
      id: 'error',
      value: const AsyncError(
        VenueCheckinFailure(VenueCheckinFailureKind.unknown),
        StackTrace.empty,
      ),
      check: (_) async =>
          expect(find.text('Venue check-in unavailable'), findsOneWidget),
    );
  });

  testWidgets('golden Venue check-in offline state', (tester) async {
    await _pumpState(
      tester,
      id: 'offline',
      online: false,
      value: const AsyncData(
        VenueCheckinRouteState(
          phase: VenueCheckinPhase.degraded,
          failure: VenueCheckinFailure(VenueCheckinFailureKind.offline),
        ),
      ),
      check: (_) async =>
          expect(find.text('Check-in paused offline'), findsOneWidget),
    );
  });

  testWidgets('golden Venue check-in permission-denied state', (tester) async {
    await _pumpState(
      tester,
      id: 'permission_denied',
      value: const AsyncError(
        VenueCheckinFailure(VenueCheckinFailureKind.permissionDenied),
        StackTrace.empty,
      ),
      check: (_) async =>
          expect(find.text('Check-in access denied'), findsOneWidget),
    );
  });

  testWidgets('golden Venue check-in disabled state', (tester) async {
    await _pumpState(
      tester,
      id: 'disabled',
      accessEnabled: false,
      value: const AsyncData(VenueCheckinRouteState()),
      check: (_) async =>
          expect(find.text('Venue check-in unavailable'), findsOneWidget),
    );
  });

  testWidgets('golden Venue check-in focused state', (tester) async {
    final previous = FocusManager.instance.highlightStrategy;
    addTearDown(() => FocusManager.instance.highlightStrategy = previous);
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    final focusNode = FocusNode(debugLabel: 'venue-checkin-submit');
    addTearDown(focusNode.dispose);
    await _pumpState(
      tester,
      id: 'focused',
      focusNode: focusNode,
      value: const AsyncData(VenueCheckinRouteState()),
      check: (tester) async {
        focusNode.requestFocus();
        await tester.pumpAndSettle();
        expect(focusNode.hasFocus, isTrue);
      },
    );
  });

  testWidgets('golden Venue check-in pressed state', (tester) async {
    TestGesture? gesture;
    addTearDown(() async => gesture?.cancel());
    await _pumpState(
      tester,
      id: 'pressed',
      value: const AsyncData(VenueCheckinRouteState()),
      check: (tester) async {
        final button = find.byKey(
          const ValueKey<String>('venue-checkin-submit'),
        );
        final detector = find.descendant(
          of: button,
          matching: find.byType(GestureDetector),
        );
        gesture = await tester.startGesture(tester.getCenter(detector.first));
        await tester.pump(const Duration(milliseconds: 120));
        await tester.pump(const Duration(milliseconds: 40));
        expect(
          tester
              .widgetList<ScaleTransition>(
                find.descendant(
                  of: button,
                  matching: find.byType(ScaleTransition),
                ),
              )
              .any((transition) => transition.scale.value < 1),
          isTrue,
        );
      },
    );
  });

  testWidgets('golden Venue check-in selected state', (tester) async {
    await _pumpState(
      tester,
      id: 'selected',
      value: const AsyncData(VenueCheckinRouteState(locationConsent: true)),
      check: (tester) async {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
        await tester.pumpAndSettle();
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && widget.properties.selected == true,
          ),
          findsOneWidget,
        );
      },
    );
  });

  testWidgets('golden Venue check-in large-text state', (tester) async {
    await _pumpState(
      tester,
      id: 'large_text',
      size: const Size(320, 720),
      textScale: 2,
      value: const AsyncData(VenueCheckinRouteState()),
      check: (tester) async {
        await tester.scrollUntilVisible(
          find.text('Venue code'),
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -32));
        await tester.pumpAndSettle();
      },
    );
  });

  for (final localeCase
      in const <({Locale locale, String title, String action})>[
        (locale: Locale('en'), title: 'Venue check-in', action: 'Check in'),
        (locale: Locale('en'), title: 'Venue check-in', action: 'Check in'),
      ]) {
    testWidgets(
      'Venue check-in ${localeCase.locale.languageCode} reflows at 200 percent',
      (tester) async {
        await _pumpRoute(
          tester,
          controller: _Controller(
            const AsyncData<VenueCheckinRouteState>(VenueCheckinRouteState()),
          ),
          size: const Size(320, 760),
          textScale: 2,
          locale: localeCase.locale,
          capture: false,
        );

        expect(find.text(localeCase.title), findsOneWidget);
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -600));
        await tester.pumpAndSettle();
        final action = find.byKey(
          const ValueKey<String>('venue-checkin-submit'),
        );
        await tester.ensureVisible(action);
        await tester.pump();
        expect(find.text(localeCase.action), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('golden Venue check-in reduced-motion state', (tester) async {
    await _pumpState(
      tester,
      id: 'reduced_motion',
      reducedMotion: true,
      value: const AsyncData(VenueCheckinRouteState()),
      check: (tester) async => expect(
        MediaQuery.disableAnimationsOf(
          tester.element(find.byType(VenueCheckinScreen)),
        ),
        isTrue,
      ),
    );
  });

  testWidgets('golden Venue check-in dark state', (tester) async {
    await _pumpState(
      tester,
      id: 'dark',
      value: const AsyncData(
        VenueCheckinRouteState(
          phase: VenueCheckinPhase.confirmed,
          result: VenueCheckinResult(
            status: 'confirmed',
            code: 'ok',
            fetAwarded: 25,
          ),
        ),
      ),
    );
  });

  testWidgets('golden Venue check-in light state', (tester) async {
    await _pumpState(
      tester,
      id: 'light',
      brightness: Brightness.light,
      value: const AsyncData(VenueCheckinRouteState()),
    );
  });

  testWidgets('golden Venue check-in syncing state', (tester) async {
    await _pumpState(
      tester,
      id: 'syncing',
      settle: false,
      value: const AsyncData(
        VenueCheckinRouteState(phase: VenueCheckinPhase.syncing),
      ),
      check: (_) async =>
          expect(find.text('Checking venue code'), findsOneWidget),
    );
  });

  testWidgets('golden Venue check-in conflict state', (tester) async {
    await _pumpState(
      tester,
      id: 'conflict',
      value: const AsyncData(
        VenueCheckinRouteState(
          phase: VenueCheckinPhase.degraded,
          failure: VenueCheckinFailure(VenueCheckinFailureKind.conflict),
        ),
      ),
      check: (_) async =>
          expect(find.text('Check-in conflict'), findsOneWidget),
    );
  });

  testWidgets('golden Venue check-in security-timeout state', (tester) async {
    await _pumpState(
      tester,
      id: 'security_timeout',
      value: const AsyncData(
        VenueCheckinRouteState(
          phase: VenueCheckinPhase.degraded,
          failure: VenueCheckinFailure(VenueCheckinFailureKind.securityTimeout),
          uncertainMutation: true,
        ),
      ),
      check: (_) async =>
          expect(find.text('Check-in confirmation uncertain'), findsOneWidget),
    );
  });
}

Future<void> _pumpState(
  WidgetTester tester, {
  required String id,
  required AsyncValue<VenueCheckinRouteState> value,
  bool online = true,
  bool accessEnabled = true,
  Brightness brightness = Brightness.dark,
  Size size = const Size(390, 844),
  double textScale = 1,
  bool reducedMotion = false,
  Locale locale = const Locale('en'),
  bool settle = true,
  FocusNode? focusNode,
  Future<void> Function(WidgetTester tester)? check,
}) async {
  final controller = _Controller(value);
  await _pumpRoute(
    tester,
    controller: controller,
    online: online,
    accessEnabled: accessEnabled,
    brightness: brightness,
    size: size,
    textScale: textScale,
    reducedMotion: reducedMotion,
    locale: locale,
    settle: settle,
    focusNode: focusNode,
  );
  await check?.call(tester);
  expect(tester.takeException(), isNull);
  await expectLater(
    find.byKey(const ValueKey<String>('venue-checkin-state-golden')),
    matchesGoldenFile(_goldens[id]!),
  );
}

Future<void> _pumpRoute(
  WidgetTester tester, {
  required _Controller controller,
  bool online = true,
  bool accessEnabled = true,
  Brightness brightness = Brightness.dark,
  Size size = const Size(390, 844),
  double textScale = 1,
  bool reducedMotion = false,
  Locale locale = const Locale('en'),
  bool settle = true,
  bool capture = true,
  FocusNode? focusNode,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  TypographyTokens.debugUseFallbackFonts = true;
  addTearDown(() => TypographyTokens.debugUseFallbackFonts = false);
  ColorTokens.setBrightness(brightness);
  addTearDown(() => ColorTokens.setBrightness(Brightness.dark));
  ConnectivityService.setOnlineForTest(online);
  addTearDown(() => ConnectivityService.setOnlineForTest(true));

  final router = GoRouter(
    initialLocation: '/fanzone/venue',
    routes: [
      GoRoute(
        path: '/fanzone/venue',
        builder: (_, _) => RepaintBoundary(
          key: const ValueKey<String>('venue-checkin-state-golden'),
          child: VenueCheckinScreen(checkinFocusNode: focusNode),
        ),
      ),
      GoRoute(path: '/fanzone', builder: (_, _) => const SizedBox.shrink()),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        venueCheckinControllerProvider.overrideWith((ref) => controller),
        venueCheckinAccessEnabledProvider.overrideWithValue(accessEnabled),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        builder: (context, child) {
          final media = MediaQuery.of(context);
          return AfriLocalizationsScope(
            locale: locale,
            child: MediaQuery(
              data: media.copyWith(
                disableAnimations: reducedMotion,
                accessibleNavigation: reducedMotion,
              ),
              child: child ?? const SizedBox.shrink(),
            ),
          );
        },
        theme: ClubTheme.from(ClubConfig.fallback(), brightness: brightness),
        routerConfig: router,
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  if (capture) {
    expect(find.byType(VenueCheckinScreen), findsOneWidget);
  }
}

class _Controller extends VenueCheckinController {
  _Controller(AsyncValue<VenueCheckinRouteState> value) : super(_Gateway()) {
    state = value;
  }

  int restoredCalls = 0;

  @override
  Future<void> connectionRestored() async {
    restoredCalls += 1;
  }
}

class _Gateway implements VenueCheckinGateway {
  @override
  Future<VenueCheckinResult> submit({
    required String rawCode,
    required String idempotencyKey,
  }) async => const VenueCheckinResult(status: 'confirmed', code: 'ok');
}
