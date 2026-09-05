import 'package:club_data/club_data.dart';
import 'package:core_auth/core_auth.dart';
import 'package:core_feature_config/core_feature_config.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_ticketing/src/providers/ticket_detail_provider.dart';
import 'package:feat_ticketing/src/screens/match_detail_screen.dart';
import 'package:feat_ticketing/src/widgets/ticket_configure_step.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:test_support/app_font_loader.dart';

const _goldens = <String, String>{
  'loading': 'goldens/ticket_detail_state_loading_dark_390x844.png',
  'empty': 'goldens/ticket_detail_state_empty_dark_390x844.png',
  'error': 'goldens/ticket_detail_state_error_dark_390x844.png',
  'offline': 'goldens/ticket_detail_state_offline_dark_390x844.png',
  'permission_denied':
      'goldens/ticket_detail_state_permission_denied_dark_390x844.png',
  'disabled': 'goldens/ticket_detail_state_disabled_dark_390x844.png',
  'focused': 'goldens/ticket_detail_state_focused_dark_390x844.png',
  'pressed': 'goldens/ticket_detail_state_pressed_dark_390x844.png',
  'selected': 'goldens/ticket_detail_state_selected_dark_390x844.png',
  'large_text': 'goldens/ticket_detail_state_large_text_dark_320x720.png',
  'reduced_motion':
      'goldens/ticket_detail_state_reduced_motion_dark_390x844.png',
  'dark': 'goldens/ticket_detail_state_dark_dark_390x844.png',
  'light': 'goldens/ticket_detail_state_light_light_390x844.png',
  'syncing': 'goldens/ticket_detail_state_syncing_dark_390x844.png',
  'conflict': 'goldens/ticket_detail_state_conflict_dark_390x844.png',
  'security_timeout':
      'goldens/ticket_detail_state_security_timeout_dark_390x844.png',
};

void main() {
  setUpAll(loadAppFonts);
  setUp(() => ConnectivityService.setOnlineForTest(true));
  tearDown(() => ConnectivityService.setOnlineForTest(true));

  testWidgets('Ticket detail refreshes after reconnect', (tester) async {
    ConnectivityService.setOnlineForTest(false);
    final controller = _Controller(AsyncData<TicketDetailState>(_ready()));
    await _pumpRoute(tester, controller: controller, capture: false);

    ConnectivityService.setOnlineForTest(true);
    await tester.pump();
    await tester.pump();

    expect(controller.refreshCalls, 1);
  });

  testWidgets('golden Ticket detail loading state', (tester) async {
    await _pumpState(
      tester,
      id: 'loading',
      value: const AsyncLoading<TicketDetailState>(),
      settle: false,
    );
  });

  testWidgets('golden Ticket detail empty state', (tester) async {
    await _pumpState(
      tester,
      id: 'empty',
      value: const AsyncData<TicketDetailState>(TicketDetailState()),
      check: (_) async =>
          expect(find.text('Fixture not found'), findsOneWidget),
    );
  });

  testWidgets('golden Ticket detail error state', (tester) async {
    await _pumpState(
      tester,
      id: 'error',
      value: const AsyncError<TicketDetailState>(
        TicketDetailFailure(TicketDetailFailureKind.unknown),
        StackTrace.empty,
      ),
      check: (_) async =>
          expect(find.text('Unable to load this fixture'), findsOneWidget),
    );
  });

  testWidgets('golden Ticket detail offline state', (tester) async {
    await _pumpState(
      tester,
      id: 'offline',
      value: AsyncData<TicketDetailState>(_ready()),
      online: false,
      check: (_) async =>
          expect(find.text('Showing saved fixture'), findsOneWidget),
    );
  });

  testWidgets('golden Ticket detail permission-denied state', (tester) async {
    await _pumpState(
      tester,
      id: 'permission_denied',
      value: const AsyncError<TicketDetailState>(
        TicketDetailFailure(TicketDetailFailureKind.permissionDenied),
        StackTrace.empty,
      ),
      check: (_) async {
        expect(find.text('Ticket access denied'), findsOneWidget);
        expect(find.text('TRY AGAIN'), findsNothing);
      },
    );
  });

  testWidgets('golden Ticket detail disabled state', (tester) async {
    await _pumpState(
      tester,
      id: 'disabled',
      value: AsyncData<TicketDetailState>(_ready()),
      accessEnabled: false,
      check: (_) async =>
          expect(find.text('Ticket sales unavailable'), findsOneWidget),
    );
  });

  testWidgets('golden Ticket detail focused state', (tester) async {
    final previous = FocusManager.instance.highlightStrategy;
    addTearDown(() => FocusManager.instance.highlightStrategy = previous);
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    await _pumpState(
      tester,
      id: 'focused',
      value: AsyncData<TicketDetailState>(_ready()),
      check: (tester) async {
        final back = find.byKey(const ValueKey<String>('ticket-detail-back'));
        final focusable = find
            .descendant(
              of: back,
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

  testWidgets('golden Ticket detail pressed state', (tester) async {
    TestGesture? gesture;
    addTearDown(() async => gesture?.cancel());
    await _pumpState(
      tester,
      id: 'pressed',
      value: AsyncData<TicketDetailState>(
        _ready(
          phase: TicketDetailPhase.degraded,
          failure: const TicketDetailFailure(TicketDetailFailureKind.conflict),
        ),
      ),
      check: (tester) async {
        gesture = await tester.startGesture(
          tester.getCenter(find.text('REFRESH FIXTURE')),
        );
        await tester.pump(const Duration(milliseconds: 120));
        await tester.pump(const Duration(milliseconds: 40));
      },
    );
  });

  testWidgets('golden Ticket detail selected state', (tester) async {
    await _pumpState(
      tester,
      id: 'selected',
      value: AsyncData<TicketDetailState>(_ready()),
      check: (_) async {
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.selected == true &&
                widget.properties.label == 'Selected ticket access GENERAL',
          ),
          findsOneWidget,
        );
      },
    );
  });

  testWidgets('golden Ticket detail large-text state', (tester) async {
    await _pumpState(
      tester,
      id: 'large_text',
      value: AsyncData<TicketDetailState>(_ready()),
      size: const Size(320, 720),
      textScale: 2,
      check: (tester) async {
        await tester.ensureVisible(find.text('Review'));
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );
  });

  testWidgets('golden Ticket detail reduced-motion state', (tester) async {
    await _pumpState(
      tester,
      id: 'reduced_motion',
      value: AsyncData<TicketDetailState>(_ready()),
      reducedMotion: true,
      check: (tester) async {
        expect(
          MediaQuery.disableAnimationsOf(
            tester.element(find.byType(TicketConfigureStep)),
          ),
          isTrue,
        );
      },
    );
  });

  testWidgets('golden Ticket detail dark state', (tester) async {
    await _pumpState(
      tester,
      id: 'dark',
      value: AsyncData<TicketDetailState>(_ready()),
    );
  });

  testWidgets('golden Ticket detail light state', (tester) async {
    await _pumpState(
      tester,
      id: 'light',
      value: AsyncData<TicketDetailState>(_ready()),
      brightness: Brightness.light,
    );
  });

  testWidgets('golden Ticket detail syncing state', (tester) async {
    await _pumpState(
      tester,
      id: 'syncing',
      value: AsyncData<TicketDetailState>(
        _ready(phase: TicketDetailPhase.syncing),
      ),
      check: (_) async =>
          expect(find.text('Refreshing fixture'), findsOneWidget),
    );
  });

  testWidgets('golden Ticket detail conflict state', (tester) async {
    await _pumpState(
      tester,
      id: 'conflict',
      value: AsyncData<TicketDetailState>(
        _ready(
          phase: TicketDetailPhase.degraded,
          failure: const TicketDetailFailure(TicketDetailFailureKind.conflict),
        ),
      ),
      check: (_) async {
        expect(find.text('Fixture changed'), findsOneWidget);
        expect(find.text('REFRESH FIXTURE'), findsOneWidget);
      },
    );
  });

  testWidgets('golden Ticket detail security-timeout state', (tester) async {
    await _pumpState(
      tester,
      id: 'security_timeout',
      value: const AsyncError<TicketDetailState>(
        TicketDetailFailure(TicketDetailFailureKind.securityTimeout),
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
    initialLocation: '/tickets/detail/match-1',
    routes: [
      GoRoute(
        path: '/tickets',
        builder: (context, state) => const Scaffold(body: Text('Tickets')),
        routes: [
          GoRoute(
            path: 'detail/:id',
            builder: (context, state) =>
                MatchDetailScreen(matchId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: 'map/:id',
            builder: (context, state) => const Scaffold(body: Text('Seat map')),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        storeReleasePolicyProvider.overrideWithValue(
          const StoreReleasePolicy.unenforced(),
        ),
        currentUserProvider.overrideWithValue(null),
        ticketDetailProvider.overrideWith((ref, matchId) => controller),
        ticketDetailAccessEnabledProvider.overrideWithValue(accessEnabled),
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
