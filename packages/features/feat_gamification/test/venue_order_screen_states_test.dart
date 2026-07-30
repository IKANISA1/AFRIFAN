import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_gamification/src/controllers/venue_order_controller.dart';
import 'package:feat_gamification/src/screens/venue_order_screen.dart';
import 'package:feat_gamification/src/venue_order_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:test_support/app_font_loader.dart';

const _goldens = <String, String>{
  'loading': 'goldens/venue_order_state_loading_dark_390x844.png',
  'empty': 'goldens/venue_order_state_empty_dark_390x844.png',
  'error': 'goldens/venue_order_state_error_dark_390x844.png',
  'offline': 'goldens/venue_order_state_offline_dark_390x844.png',
  'permission_denied':
      'goldens/venue_order_state_permission_denied_dark_390x844.png',
  'disabled': 'goldens/venue_order_state_disabled_dark_390x844.png',
  'focused': 'goldens/venue_order_state_focused_dark_390x844.png',
  'pressed': 'goldens/venue_order_state_pressed_dark_390x844.png',
  'selected': 'goldens/venue_order_state_selected_dark_390x844.png',
  'large_text': 'goldens/venue_order_state_large_text_dark_320x720.png',
  'reduced_motion': 'goldens/venue_order_state_reduced_motion_dark_390x844.png',
  'dark': 'goldens/venue_order_state_dark_dark_390x844.png',
  'light': 'goldens/venue_order_state_light_light_390x844.png',
  'syncing': 'goldens/venue_order_state_syncing_dark_390x844.png',
  'conflict': 'goldens/venue_order_state_conflict_dark_390x844.png',
  'security_timeout':
      'goldens/venue_order_state_security_timeout_dark_390x844.png',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);
  setUp(() => ConnectivityService.setOnlineForTest(true));
  tearDown(() => ConnectivityService.setOnlineForTest(true));

  testWidgets('Venue order refreshes once after reconnect', (tester) async {
    ConnectivityService.setOnlineForTest(false);
    final controller = _Controller(
      const AsyncData<VenueOrderRouteState>(
        VenueOrderRouteState(
          context: _context,
          quantities: <String, int>{'water': 1},
          phase: VenueOrderPhase.degraded,
          failure: VenueOrderFailure(VenueOrderFailureKind.offline),
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

  testWidgets('golden Venue order loading state', (tester) async {
    await _pumpState(
      tester,
      id: 'loading',
      value: const AsyncLoading<VenueOrderRouteState>(),
      settle: false,
    );
  });

  testWidgets('golden Venue order empty state', (tester) async {
    await _pumpState(
      tester,
      id: 'empty',
      value: const AsyncData<VenueOrderRouteState>(VenueOrderRouteState()),
      check: (_) async =>
          expect(find.text('Check in before ordering'), findsOneWidget),
    );
  });

  testWidgets('golden Venue order error state', (tester) async {
    await _pumpState(
      tester,
      id: 'error',
      value: const AsyncError<VenueOrderRouteState>(
        VenueOrderFailure(VenueOrderFailureKind.unknown),
        StackTrace.empty,
      ),
      check: (_) async =>
          expect(find.text('Venue ordering unavailable'), findsOneWidget),
    );
  });

  testWidgets('golden Venue order offline state', (tester) async {
    await _pumpState(
      tester,
      id: 'offline',
      online: false,
      value: const AsyncData<VenueOrderRouteState>(
        VenueOrderRouteState(
          context: _context,
          quantities: <String, int>{'water': 1},
          phase: VenueOrderPhase.degraded,
          failure: VenueOrderFailure(VenueOrderFailureKind.offline),
        ),
      ),
      check: (_) async {
        expect(find.text('Showing saved venue menu'), findsOneWidget);
        expect(find.textContaining('Nothing is queued'), findsOneWidget);
      },
    );
  });

  testWidgets('golden Venue order permission-denied state', (tester) async {
    await _pumpState(
      tester,
      id: 'permission_denied',
      value: const AsyncError<VenueOrderRouteState>(
        VenueOrderFailure(VenueOrderFailureKind.permissionDenied),
        StackTrace.empty,
      ),
      check: (_) async =>
          expect(find.text('Venue order access denied'), findsOneWidget),
    );
  });

  testWidgets('golden Venue order disabled state', (tester) async {
    await _pumpState(
      tester,
      id: 'disabled',
      accessEnabled: false,
      value: const AsyncData<VenueOrderRouteState>(_selectedState),
      check: (_) async =>
          expect(find.text('Venue ordering unavailable'), findsOneWidget),
    );
  });

  testWidgets('golden Venue order focused state', (tester) async {
    final previous = FocusManager.instance.highlightStrategy;
    addTearDown(() => FocusManager.instance.highlightStrategy = previous);
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    final focusNode = FocusNode(debugLabel: 'venue-order-submit');
    addTearDown(focusNode.dispose);
    await _pumpState(
      tester,
      id: 'focused',
      submitFocusNode: focusNode,
      value: const AsyncData<VenueOrderRouteState>(_selectedState),
      check: (tester) async {
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey<String>('venue-order-submit')),
          220,
          scrollable: find.byType(Scrollable).first,
        );
        focusNode.requestFocus();
        await tester.pumpAndSettle();
        expect(focusNode.hasFocus, isTrue);
      },
    );
  });

  testWidgets('golden Venue order pressed state', (tester) async {
    TestGesture? gesture;
    addTearDown(() async => gesture?.cancel());
    await _pumpState(
      tester,
      id: 'pressed',
      value: const AsyncData<VenueOrderRouteState>(_readyState),
      check: (tester) async {
        final add = find.byKey(const ValueKey<String>('venue-order-add-water'));
        final detector = find.descendant(
          of: add,
          matching: find.byType(GestureDetector),
        );
        expect(detector, findsOneWidget);
        gesture = await tester.startGesture(tester.getCenter(detector));
        await tester.pump(const Duration(milliseconds: 120));
        await tester.pump(const Duration(milliseconds: 40));
        expect(
          tester
              .widgetList<ScaleTransition>(
                find.descendant(
                  of: add,
                  matching: find.byType(ScaleTransition),
                ),
              )
              .any((transition) => transition.scale.value < 1),
          isTrue,
        );
      },
    );
  });

  testWidgets('golden Venue order selected state', (tester) async {
    await _pumpState(
      tester,
      id: 'selected',
      value: const AsyncData<VenueOrderRouteState>(_selectedState),
      check: (_) async {
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && widget.properties.selected == true,
          ),
          findsOneWidget,
        );
        expect(find.text('RWF 1,500'), findsWidgets);
      },
    );
  });

  testWidgets('golden Venue order large-text state', (tester) async {
    await _pumpState(
      tester,
      id: 'large_text',
      size: const Size(320, 720),
      textScale: 2,
      value: const AsyncData<VenueOrderRouteState>(_selectedState),
      check: (tester) async {
        await tester.scrollUntilVisible(
          find.text('Approved drinks'),
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
      },
    );
  });

  testWidgets('golden Venue order reduced-motion state', (tester) async {
    await _pumpState(
      tester,
      id: 'reduced_motion',
      reducedMotion: true,
      value: const AsyncData<VenueOrderRouteState>(_selectedState),
      check: (tester) async => expect(
        MediaQuery.disableAnimationsOf(
          tester.element(find.byType(VenueOrderScreen)),
        ),
        isTrue,
      ),
    );
  });

  testWidgets('golden Venue order dark state', (tester) async {
    await _pumpState(
      tester,
      id: 'dark',
      value: const AsyncData<VenueOrderRouteState>(
        VenueOrderRouteState(
          context: _context,
          quantities: <String, int>{'water': 1},
          phase: VenueOrderPhase.confirmed,
          result: VenueOrderResult(
            status: 'created',
            code: 'ok',
            orderId: 'order-2',
            totalAmount: 1500,
          ),
        ),
      ),
    );
  });

  testWidgets('golden Venue order light state', (tester) async {
    await _pumpState(
      tester,
      id: 'light',
      brightness: Brightness.light,
      value: const AsyncData<VenueOrderRouteState>(_selectedState),
    );
  });

  testWidgets('golden Venue order syncing state', (tester) async {
    await _pumpState(
      tester,
      id: 'syncing',
      settle: false,
      value: const AsyncData<VenueOrderRouteState>(
        VenueOrderRouteState(
          context: _context,
          quantities: <String, int>{'water': 1},
          phase: VenueOrderPhase.syncing,
        ),
      ),
      check: (_) async =>
          expect(find.text('Creating venue order'), findsOneWidget),
    );
  });

  testWidgets('golden Venue order conflict state', (tester) async {
    await _pumpState(
      tester,
      id: 'conflict',
      value: const AsyncData<VenueOrderRouteState>(
        VenueOrderRouteState(
          context: _context,
          quantities: <String, int>{'water': 1},
          phase: VenueOrderPhase.degraded,
          failure: VenueOrderFailure(VenueOrderFailureKind.conflict),
        ),
      ),
      check: (_) async =>
          expect(find.text('Order attempt paused'), findsOneWidget),
    );
  });

  testWidgets('golden Venue order security-timeout state', (tester) async {
    await _pumpState(
      tester,
      id: 'security_timeout',
      value: const AsyncData<VenueOrderRouteState>(
        VenueOrderRouteState(
          context: _context,
          quantities: <String, int>{'water': 1},
          phase: VenueOrderPhase.degraded,
          failure: VenueOrderFailure(VenueOrderFailureKind.securityTimeout),
          uncertainMutation: true,
        ),
      ),
      check: (_) async =>
          expect(find.text('Order confirmation uncertain'), findsOneWidget),
    );
  });
}

Future<void> _pumpState(
  WidgetTester tester, {
  required String id,
  required AsyncValue<VenueOrderRouteState> value,
  bool online = true,
  bool accessEnabled = true,
  Brightness brightness = Brightness.dark,
  Size size = const Size(390, 844),
  double textScale = 1,
  bool reducedMotion = false,
  bool settle = true,
  FocusNode? submitFocusNode,
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
    settle: settle,
    submitFocusNode: submitFocusNode,
  );
  await check?.call(tester);
  expect(tester.takeException(), isNull);
  await expectLater(
    find.byKey(const ValueKey<String>('venue-order-state-golden')),
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
  bool settle = true,
  bool capture = true,
  FocusNode? submitFocusNode,
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
    initialLocation: '/fanzone/venue/order',
    routes: [
      GoRoute(
        path: '/fanzone/venue/order',
        builder: (_, _) => RepaintBoundary(
          key: const ValueKey<String>('venue-order-state-golden'),
          child: VenueOrderScreen(submitFocusNode: submitFocusNode),
        ),
      ),
      GoRoute(
        path: '/fanzone/venue',
        builder: (_, _) => const SizedBox.shrink(),
      ),
      GoRoute(path: '/fanzone', builder: (_, _) => const SizedBox.shrink()),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        venueOrderControllerProvider.overrideWith((ref) => controller),
        venueOrderAccessEnabledProvider.overrideWithValue(accessEnabled),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        builder: (context, child) {
          final media = MediaQuery.of(context);
          return MediaQuery(
            data: media.copyWith(
              disableAnimations: reducedMotion,
              accessibleNavigation: reducedMotion,
            ),
            child: child ?? const SizedBox.shrink(),
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
    expect(find.byType(VenueOrderScreen), findsOneWidget);
  }
}

const _menu = <VenueDrinkItem>[
  VenueDrinkItem(
    id: 'water',
    venueId: 'venue-1',
    name: 'Water',
    description: 'Cold still water',
    priceAmount: 1500,
    currencyCode: 'RWF',
  ),
  VenueDrinkItem(
    id: 'juice',
    venueId: 'venue-1',
    name: 'Passion juice',
    description: 'Fresh non-alcoholic juice',
    priceAmount: 2500,
    currencyCode: 'RWF',
  ),
];

const _context = VenueOrderContext(
  checkinId: 'checkin-1',
  venueId: 'venue-1',
  menu: _menu,
  latestOrder: VenueOrderResult(
    status: 'preparing',
    code: 'loaded',
    orderId: 'order-1',
    totalAmount: 1500,
  ),
);

const _readyState = VenueOrderRouteState(context: _context);

const _selectedState = VenueOrderRouteState(
  context: _context,
  quantities: <String, int>{'water': 1},
);

class _Controller extends VenueOrderController {
  _Controller(AsyncValue<VenueOrderRouteState> value)
    : super(_Gateway(), autoLoad: false) {
    state = value;
  }

  int restoredCalls = 0;

  @override
  Future<void> connectionRestored() async {
    restoredCalls += 1;
  }
}

class _Gateway implements VenueOrderGateway {
  @override
  Future<VenueOrderContext> load() async => _context;

  @override
  Future<VenueOrderResult> create({
    required VenueOrderContext context,
    required Map<String, int> quantities,
    required bool ageGateConfirmed,
    required String idempotencyKey,
  }) async => const VenueOrderResult(
    status: 'created',
    code: 'ok',
    orderId: 'order-2',
    totalAmount: 1500,
  );
}
