import 'package:core_auth/core_auth.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_club/feat_club.dart';
import 'package:feat_ticketing/src/providers/ticket_detail_provider.dart';
import 'package:feat_ticketing/src/screens/interactive_seat_map_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:test_support/app_font_loader.dart';

const _goldens = <String, String>{
  'loading': 'goldens/seat_map_state_loading_dark_390x844.png',
  'empty': 'goldens/seat_map_state_empty_dark_390x844.png',
  'error': 'goldens/seat_map_state_error_dark_390x844.png',
  'offline': 'goldens/seat_map_state_offline_dark_390x844.png',
  'permission_denied':
      'goldens/seat_map_state_permission_denied_dark_390x844.png',
  'disabled': 'goldens/seat_map_state_disabled_dark_390x844.png',
  'focused': 'goldens/seat_map_state_focused_dark_390x844.png',
  'pressed': 'goldens/seat_map_state_pressed_dark_390x844.png',
  'selected': 'goldens/seat_map_state_selected_dark_390x844.png',
  'large_text': 'goldens/seat_map_state_large_text_dark_320x720.png',
  'reduced_motion': 'goldens/seat_map_state_reduced_motion_dark_390x844.png',
  'dark': 'goldens/seat_map_state_dark_dark_390x844.png',
  'light': 'goldens/seat_map_state_light_light_390x844.png',
  'syncing': 'goldens/seat_map_state_syncing_dark_390x844.png',
  'conflict': 'goldens/seat_map_state_conflict_dark_390x844.png',
  'security_timeout':
      'goldens/seat_map_state_security_timeout_dark_390x844.png',
};

void main() {
  setUpAll(loadAppFonts);
  setUp(() => ConnectivityService.setOnlineForTest(true));
  tearDown(() => ConnectivityService.setOnlineForTest(true));

  testWidgets('Seat map refreshes after reconnect', (tester) async {
    ConnectivityService.setOnlineForTest(false);
    final controller = _Controller(AsyncData<TicketDetailState>(_ready()));
    await _pumpRoute(tester, controller: controller, capture: false);

    ConnectivityService.setOnlineForTest(true);
    await tester.pump();
    await tester.pump();

    expect(controller.refreshCalls, 1);
  });

  testWidgets('golden Seat map loading state', (tester) async {
    await _pumpState(
      tester,
      id: 'loading',
      value: const AsyncLoading<TicketDetailState>(),
      settle: false,
    );
  });

  testWidgets('golden Seat map empty state', (tester) async {
    await _pumpState(
      tester,
      id: 'empty',
      value: const AsyncData<TicketDetailState>(TicketDetailState()),
      check: (_) async =>
          expect(find.text('Seat map unavailable'), findsOneWidget),
    );
  });

  testWidgets('golden Seat map error state', (tester) async {
    await _pumpState(
      tester,
      id: 'error',
      value: const AsyncError<TicketDetailState>(
        TicketDetailFailure(TicketDetailFailureKind.unknown),
        StackTrace.empty,
      ),
      check: (_) async =>
          expect(find.text('Unable to load seat map'), findsOneWidget),
    );
  });

  testWidgets('golden Seat map offline state', (tester) async {
    await _pumpState(
      tester,
      id: 'offline',
      value: AsyncData<TicketDetailState>(_ready()),
      online: false,
      check: (_) async =>
          expect(find.text('Showing saved seat map'), findsOneWidget),
    );
  });

  testWidgets('golden Seat map permission-denied state', (tester) async {
    await _pumpState(
      tester,
      id: 'permission_denied',
      value: const AsyncError<TicketDetailState>(
        TicketDetailFailure(TicketDetailFailureKind.permissionDenied),
        StackTrace.empty,
      ),
      check: (_) async {
        expect(find.text('Seat map access denied'), findsOneWidget);
        expect(find.text('TRY AGAIN'), findsNothing);
      },
    );
  });

  testWidgets('golden Seat map disabled state', (tester) async {
    await _pumpState(
      tester,
      id: 'disabled',
      value: AsyncData<TicketDetailState>(_ready()),
      accessEnabled: false,
      check: (_) async =>
          expect(find.text('Seat selection unavailable'), findsOneWidget),
    );
  });

  testWidgets('golden Seat map focused state', (tester) async {
    final previous = FocusManager.instance.highlightStrategy;
    addTearDown(() => FocusManager.instance.highlightStrategy = previous);
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    await _pumpState(
      tester,
      id: 'focused',
      value: AsyncData<TicketDetailState>(_ready()),
      check: (tester) async {
        final back = find.byKey(const ValueKey<String>('seat-map-back'));
        final focusable = find
            .descendant(
              of: back,
              matching: find.byType(FocusableActionDetector),
            )
            .first;
        final gestureDetector = find
            .descendant(
              of: focusable,
              matching: find.byType(GestureDetector),
            )
            .first;
        Focus.of(tester.element(gestureDetector)).requestFocus();
        await tester.pumpAndSettle();
        expect(Focus.of(tester.element(gestureDetector)).hasFocus, isTrue);
      },
    );
  });

  testWidgets('golden Seat map pressed state', (tester) async {
    TestGesture? gesture;
    addTearDown(() async => gesture?.cancel());
    await _pumpState(
      tester,
      id: 'pressed',
      value: AsyncData<TicketDetailState>(
        _ready(
          phase: TicketDetailPhase.degraded,
          failure: const TicketDetailFailure(
            TicketDetailFailureKind.conflict,
          ),
        ),
      ),
      check: (tester) async {
        gesture = await tester.startGesture(
          tester.getCenter(find.text('REFRESH SEAT MAP')),
        );
        await tester.pump(const Duration(milliseconds: 120));
        await tester.pump(const Duration(milliseconds: 40));
      },
    );
  });

  testWidgets('golden Seat map selected state', (tester) async {
    await _pumpState(
      tester,
      id: 'selected',
      value: AsyncData<TicketDetailState>(_ready()),
      check: (tester) async {
        await tester.tap(find.text('East Stand'));
        await tester.pumpAndSettle();
        expect(find.text('East Stand, Seat 1'), findsOneWidget);
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

  testWidgets('golden Seat map large-text state', (tester) async {
    await _pumpState(
      tester,
      id: 'large_text',
      value: AsyncData<TicketDetailState>(_ready()),
      size: const Size(320, 720),
      textScale: 2,
      check: (tester) async {
        await tester.tap(find.text('East Stand'));
        await tester.pumpAndSettle();
        expect(find.text('Confirm'), findsOneWidget);
        final actionRect = tester.getRect(find.text('Confirm'));
        expect(actionRect.top, greaterThanOrEqualTo(0));
        expect(
          actionRect.bottom,
          lessThanOrEqualTo(720),
          reason: 'The large-text primary action must remain on-screen.',
        );
        expect(tester.takeException(), isNull);
      },
    );
  });

  testWidgets('golden Seat map reduced-motion state', (tester) async {
    await _pumpState(
      tester,
      id: 'reduced_motion',
      value: AsyncData<TicketDetailState>(_ready()),
      reducedMotion: true,
      check: (tester) async => expect(
        MediaQuery.disableAnimationsOf(
          tester.element(find.byType(InteractiveSeatMapScreen)),
        ),
        isTrue,
      ),
    );
  });

  testWidgets('golden Seat map dark state', (tester) async {
    await _pumpState(
      tester,
      id: 'dark',
      value: AsyncData<TicketDetailState>(_ready()),
    );
  });

  testWidgets('golden Seat map light state', (tester) async {
    await _pumpState(
      tester,
      id: 'light',
      value: AsyncData<TicketDetailState>(_ready()),
      brightness: Brightness.light,
    );
  });

  testWidgets('golden Seat map syncing state', (tester) async {
    await _pumpState(
      tester,
      id: 'syncing',
      value: AsyncData<TicketDetailState>(
        _ready(phase: TicketDetailPhase.syncing),
      ),
      check: (_) async =>
          expect(find.text('Refreshing seat map'), findsOneWidget),
    );
  });

  testWidgets('golden Seat map conflict state', (tester) async {
    await _pumpState(
      tester,
      id: 'conflict',
      value: AsyncData<TicketDetailState>(
        _ready(
          phase: TicketDetailPhase.degraded,
          failure: const TicketDetailFailure(
            TicketDetailFailureKind.conflict,
          ),
        ),
      ),
      check: (_) async {
        expect(find.text('Seat map changed'), findsOneWidget);
        expect(find.text('REFRESH SEAT MAP'), findsOneWidget);
      },
    );
  });

  testWidgets('golden Seat map security-timeout state', (tester) async {
    await _pumpState(
      tester,
      id: 'security_timeout',
      value: const AsyncError<TicketDetailState>(
        TicketDetailFailure(TicketDetailFailureKind.securityTimeout),
        StackTrace.empty,
      ),
      check: (_) async => expect(
        find.text('Seat map security check timed out'),
        findsOneWidget,
      ),
    );
  });
}

Future<void> _pumpState(
  WidgetTester tester, {
  required String id,
  required AsyncValue<TicketDetailState> value,
  bool online = true,
  bool accessEnabled = true,
  Brightness brightness = Brightness.dark,
  Size size = const Size(390, 844),
  double textScale = 1,
  bool reducedMotion = false,
  bool settle = true,
  Future<void> Function(WidgetTester tester)? check,
}) async {
  ConnectivityService.setOnlineForTest(online);
  await _pumpRoute(
    tester,
    controller: _Controller(value),
    accessEnabled: accessEnabled,
    brightness: brightness,
    size: size,
    textScale: textScale,
    reducedMotion: reducedMotion,
    settle: settle,
    check: check,
    goldenPath: _goldens[id]!,
  );
}

Future<void> _pumpRoute(
  WidgetTester tester, {
  required _Controller controller,
  bool capture = true,
  bool accessEnabled = true,
  Brightness brightness = Brightness.dark,
  Size size = const Size(390, 844),
  double textScale = 1,
  bool reducedMotion = false,
  bool settle = true,
  Future<void> Function(WidgetTester tester)? check,
  String? goldenPath,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  TypographyTokens.debugUseFallbackFonts = true;
  addTearDown(() => TypographyTokens.debugUseFallbackFonts = false);
  ColorTokens.setBrightness(brightness);
  addTearDown(() => ColorTokens.setBrightness(Brightness.dark));

  final router = GoRouter(
    initialLocation: '/tickets/map/match-1',
    routes: [
      GoRoute(
        path: '/tickets',
        builder: (context, state) => const Scaffold(body: Text('Tickets')),
        routes: [
          GoRoute(
            path: 'detail/:id',
            builder: (context, state) =>
                const Scaffold(body: Text('Ticket detail')),
          ),
          GoRoute(
            path: 'map/:id',
            builder: (context, state) => InteractiveSeatMapScreen(
              matchId: state.pathParameters['id']!,
            ),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserProvider.overrideWithValue(null),
        ticketDetailProvider.overrideWith((ref, matchId) => controller),
        seatMapAccessEnabledProvider.overrideWithValue(accessEnabled),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: ClubTheme.from(ClubConfig.fallback(), brightness: brightness),
        builder: (context, child) {
          final media = MediaQuery.of(context);
          return MediaQuery(
            data: media.copyWith(
              textScaler: TextScaler.linear(textScale),
              disableAnimations: reducedMotion,
            ),
            child: ClubConfigScope(
              config: ClubConfig.fallback(),
              child: child!,
            ),
          );
        },
        routerConfig: router,
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  await check?.call(tester);
  if (capture) {
    await expectLater(find.byType(MaterialApp), matchesGoldenFile(goldenPath!));
  }
}

class _Controller extends TicketDetailController {
  _Controller(AsyncValue<TicketDetailState> value)
      : super(_Gateway(), 'match-1', autoLoad: false) {
    state = value;
  }

  int refreshCalls = 0;

  @override
  Future<void> refresh() async {
    refreshCalls += 1;
  }
}

class _Gateway implements TicketDetailGateway {
  @override
  Future<ClubMatch?> load(String matchId) async => _match();
}

TicketDetailState _ready({
  TicketDetailPhase phase = TicketDetailPhase.ready,
  TicketDetailFailure? failure,
}) {
  return TicketDetailState(match: _match(), phase: phase, failure: failure);
}

ClubMatch _match() => ClubMatch(
      id: 'match-1',
      homeTeam: 'Rayon Sports',
      awayTeam: 'APR FC',
      competition: 'Rwanda Premier League',
      venue: 'Amahoro Stadium',
      matchDate: DateTime.utc(2026, 8, 2, 15),
      kickoffTime: '17:00',
      isOnSale: true,
      ticketGeneralPrice: 5000,
      ticketVipPrice: 15000,
      saleStartsAt: DateTime.utc(2026, 7, 20, 9),
      capacity: 45000,
    );
