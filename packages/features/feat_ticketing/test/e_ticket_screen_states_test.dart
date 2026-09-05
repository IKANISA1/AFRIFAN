import 'package:club_data/club_data.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_ticketing/src/providers/e_ticket_provider.dart';
import 'package:feat_ticketing/src/screens/e_ticket_qr_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:test_support/app_font_loader.dart';

const _goldens = <String, String>{
  'loading': 'goldens/e_ticket_state_loading_dark_390x844.png',
  'empty': 'goldens/e_ticket_state_empty_dark_390x844.png',
  'error': 'goldens/e_ticket_state_error_dark_390x844.png',
  'offline': 'goldens/e_ticket_state_offline_dark_390x844.png',
  'permission_denied':
      'goldens/e_ticket_state_permission_denied_dark_390x844.png',
  'disabled': 'goldens/e_ticket_state_disabled_dark_390x844.png',
  'focused': 'goldens/e_ticket_state_focused_dark_390x844.png',
  'pressed': 'goldens/e_ticket_state_pressed_dark_390x844.png',
  'selected': 'goldens/e_ticket_state_selected_dark_390x844.png',
  'large_text': 'goldens/e_ticket_state_large_text_dark_320x720.png',
  'reduced_motion': 'goldens/e_ticket_state_reduced_motion_dark_390x844.png',
  'dark': 'goldens/e_ticket_state_dark_dark_390x844.png',
  'light': 'goldens/e_ticket_state_light_light_390x844.png',
  'syncing': 'goldens/e_ticket_state_syncing_dark_390x844.png',
  'conflict': 'goldens/e_ticket_state_conflict_dark_390x844.png',
  'security_timeout':
      'goldens/e_ticket_state_security_timeout_dark_390x844.png',
};

void main() {
  setUpAll(loadAppFonts);
  setUp(() => ConnectivityService.setOnlineForTest(true));
  tearDown(() => ConnectivityService.setOnlineForTest(true));

  testWidgets('E-ticket refreshes after reconnect', (tester) async {
    ConnectivityService.setOnlineForTest(false);
    final controller = _Controller(AsyncData<ETicketState>(_ready()));
    await _pumpRoute(tester, controller: controller, capture: false);

    ConnectivityService.setOnlineForTest(true);
    await tester.pump();
    await tester.pump();

    expect(controller.refreshCalls, 1);
  });

  testWidgets('golden E-ticket loading state', (tester) async {
    await _pumpState(
      tester,
      id: 'loading',
      value: const AsyncLoading<ETicketState>(),
      settle: false,
    );
  });

  testWidgets('golden E-ticket empty state', (tester) async {
    await _pumpState(
      tester,
      id: 'empty',
      value: const AsyncData<ETicketState>(ETicketState()),
      check: (_) async => expect(find.text('Ticket not found'), findsOneWidget),
    );
  });

  testWidgets('golden E-ticket error state', (tester) async {
    await _pumpState(
      tester,
      id: 'error',
      value: const AsyncError<ETicketState>(
        ETicketFailure(ETicketFailureKind.unknown),
        StackTrace.empty,
      ),
      check: (_) async =>
          expect(find.text('Ticket unavailable'), findsOneWidget),
    );
  });

  testWidgets('golden E-ticket offline state', (tester) async {
    await _pumpState(
      tester,
      id: 'offline',
      value: AsyncData<ETicketState>(_ready()),
      online: false,
      check: (_) async =>
          expect(find.text('Showing saved entry code'), findsOneWidget),
    );
  });

  testWidgets('golden E-ticket permission-denied state', (tester) async {
    await _pumpState(
      tester,
      id: 'permission_denied',
      value: const AsyncError<ETicketState>(
        ETicketFailure(ETicketFailureKind.permissionDenied),
        StackTrace.empty,
      ),
      check: (_) async {
        expect(find.text('E-ticket access denied'), findsOneWidget);
        expect(find.text('Refresh ticket'), findsNothing);
      },
    );
  });

  testWidgets('golden E-ticket disabled state', (tester) async {
    await _pumpState(
      tester,
      id: 'disabled',
      value: AsyncData<ETicketState>(_ready()),
      accessEnabled: false,
      check: (_) async =>
          expect(find.text('E-ticket access unavailable'), findsOneWidget),
    );
  });

  testWidgets('golden E-ticket focused state', (tester) async {
    final previous = FocusManager.instance.highlightStrategy;
    addTearDown(() => FocusManager.instance.highlightStrategy = previous);
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    await _pumpState(
      tester,
      id: 'focused',
      value: AsyncData<ETicketState>(_ready()),
      check: (tester) async {
        final close = find.byKey(const ValueKey<String>('e-ticket-close'));
        final focusable = find
            .descendant(
              of: close,
              matching: find.byType(FocusableActionDetector),
            )
            .first;
        final gestureDetector = find
            .descendant(of: focusable, matching: find.byType(GestureDetector))
            .first;
        Focus.of(tester.element(gestureDetector)).requestFocus();
        await tester.pumpAndSettle();
        expect(Focus.of(tester.element(gestureDetector)).hasFocus, isTrue);
      },
    );
  });

  testWidgets('golden E-ticket pressed state', (tester) async {
    TestGesture? gesture;
    addTearDown(() async => gesture?.cancel());
    await _pumpState(
      tester,
      id: 'pressed',
      value: AsyncData<ETicketState>(
        _ready(
          phase: ETicketPhase.degraded,
          failure: const ETicketFailure(ETicketFailureKind.conflict),
        ),
      ),
      check: (tester) async {
        gesture = await tester.startGesture(
          tester.getCenter(find.text('Refresh ticket')),
        );
        await tester.pump(const Duration(milliseconds: 120));
        await tester.pump(const Duration(milliseconds: 40));
      },
    );
  });

  testWidgets('golden E-ticket selected state', (tester) async {
    await _pumpState(
      tester,
      id: 'selected',
      value: AsyncData<ETicketState>(_ready()),
      check: (_) async {
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.selected == true &&
                widget.properties.label ==
                    'Selected e-ticket Rayon Sports vs APR FC',
          ),
          findsOneWidget,
        );
      },
    );
  });

  testWidgets('golden E-ticket large-text state', (tester) async {
    await _pumpState(
      tester,
      id: 'large_text',
      value: AsyncData<ETicketState>(_ready()),
      size: const Size(320, 720),
      textScale: 2,
      check: (tester) async {
        await tester.ensureVisible(
          find.text('Wallet export is not available in this release yet.'),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );
  });

  testWidgets('golden E-ticket reduced-motion state', (tester) async {
    await _pumpState(
      tester,
      id: 'reduced_motion',
      value: AsyncData<ETicketState>(_ready()),
      reducedMotion: true,
      check: (_) async {
        expect(find.byKey(const Key('qr_scanner_overlay')), findsNothing);
      },
    );
  });

  testWidgets('golden E-ticket dark state', (tester) async {
    await _pumpState(
      tester,
      id: 'dark',
      value: AsyncData<ETicketState>(_ready()),
    );
  });

  testWidgets('golden E-ticket light state', (tester) async {
    await _pumpState(
      tester,
      id: 'light',
      value: AsyncData<ETicketState>(_ready()),
      brightness: Brightness.light,
    );
  });

  testWidgets('golden E-ticket syncing state', (tester) async {
    await _pumpState(
      tester,
      id: 'syncing',
      value: AsyncData<ETicketState>(_ready(phase: ETicketPhase.syncing)),
      check: (_) async =>
          expect(find.text('Refreshing ticket'), findsOneWidget),
    );
  });

  testWidgets('golden E-ticket conflict state', (tester) async {
    await _pumpState(
      tester,
      id: 'conflict',
      value: AsyncData<ETicketState>(
        _ready(
          phase: ETicketPhase.degraded,
          failure: const ETicketFailure(ETicketFailureKind.conflict),
        ),
      ),
      check: (_) async {
        expect(find.text('Ticket changed'), findsOneWidget);
        expect(find.text('Refresh ticket'), findsOneWidget);
      },
    );
  });

  testWidgets('golden E-ticket security-timeout state', (tester) async {
    await _pumpState(
      tester,
      id: 'security_timeout',
      value: const AsyncError<ETicketState>(
        ETicketFailure(ETicketFailureKind.securityTimeout),
        StackTrace.empty,
      ),
      check: (_) async =>
          expect(find.text('Ticket security check timed out'), findsOneWidget),
    );
  });
}

Future<void> _pumpState(
  WidgetTester tester, {
  required String id,
  required AsyncValue<ETicketState> value,
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
    initialLocation: '/e-ticket/ticket-1',
    routes: [
      GoRoute(
        path: '/e-ticket/:id',
        builder: (context, state) => ETicketQrScreen(
          ticketId: state.pathParameters['id']!,
          scannerAnimationEnabled: false,
        ),
      ),
      GoRoute(
        path: '/tickets',
        builder: (context, state) => const Scaffold(body: Text('Tickets')),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        eTicketProvider.overrideWith((ref, ticketId) => controller),
        eTicketAccessEnabledProvider.overrideWithValue(accessEnabled),
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
            child: child!,
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

class _Controller extends ETicketController {
  _Controller(AsyncValue<ETicketState> value)
    : super(_Gateway(), 'ticket-1', autoLoad: false) {
    state = value;
  }

  int refreshCalls = 0;

  @override
  Future<void> refresh() async {
    refreshCalls += 1;
  }
}

class _Gateway implements ETicketGateway {
  @override
  Future<ClubTicket?> load(String ticketId) async => _ticket();
}

ETicketState _ready({
  ETicketPhase phase = ETicketPhase.ready,
  ETicketFailure? failure,
}) {
  return ETicketState(ticket: _ticket(), phase: phase, failure: failure);
}

ClubTicket _ticket() => ClubTicket.fromJson({
  'id': 'ticket-1',
  'match_id': 'match-1',
  'user_id': 'user-1',
  'seat_type': 'vip',
  'amount_paid': 15000,
  'qr_code': 'AFRICLUB-TICKET-1',
  'momo_reference': 'not-rendered',
  'status': 'active',
  'purchased_at': '2026-07-28T09:00:00Z',
  'match': {
    'id': 'match-1',
    'home_team': 'Rayon Sports',
    'away_team': 'APR FC',
    'competition': 'Rwanda Premier League',
    'venue': 'Amahoro Stadium',
    'match_date': '2026-08-02T15:00:00Z',
    'kickoff_time': '17:00',
    'is_on_sale': true,
    'ticket_general_price': 5000,
    'ticket_vip_price': 15000,
    'sale_starts_at': '2026-07-20T09:00:00Z',
    'capacity': 45000,
  },
});
