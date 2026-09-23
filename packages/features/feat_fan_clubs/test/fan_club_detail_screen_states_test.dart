import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_fan_clubs/src/providers/fan_club_detail_provider.dart';
import 'package:feat_fan_clubs/src/screens/fan_club_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:test_support/app_font_loader.dart';

const _goldens = <String, String>{
  'loading': 'goldens/fan_club_detail_state_loading_dark_390x844.png',
  'empty': 'goldens/fan_club_detail_state_empty_dark_390x844.png',
  'error': 'goldens/fan_club_detail_state_error_dark_390x844.png',
  'offline': 'goldens/fan_club_detail_state_offline_dark_390x844.png',
  'permission_denied':
      'goldens/fan_club_detail_state_permission_denied_dark_390x844.png',
  'disabled': 'goldens/fan_club_detail_state_disabled_dark_390x844.png',
  'focused': 'goldens/fan_club_detail_state_focused_dark_390x844.png',
  'pressed': 'goldens/fan_club_detail_state_pressed_dark_390x844.png',
  'selected': 'goldens/fan_club_detail_state_selected_dark_390x844.png',
  'large_text': 'goldens/fan_club_detail_state_large_text_dark_320x720.png',
  'reduced_motion':
      'goldens/fan_club_detail_state_reduced_motion_dark_390x844.png',
  'dark': 'goldens/fan_club_detail_state_dark_dark_390x844.png',
  'light': 'goldens/fan_club_detail_state_light_light_390x844.png',
  'syncing': 'goldens/fan_club_detail_state_syncing_dark_390x844.png',
  'conflict': 'goldens/fan_club_detail_state_conflict_dark_390x844.png',
  'security_timeout':
      'goldens/fan_club_detail_state_security_timeout_dark_390x844.png',
};

void main() {
  setUpAll(loadAppFonts);
  setUp(() => ConnectivityService.setOnlineForTest(true));
  tearDown(() => ConnectivityService.setOnlineForTest(true));

  testWidgets('Fan club detail refreshes after reconnect', (tester) async {
    ConnectivityService.setOnlineForTest(false);
    final controller = _Controller(AsyncData<FanClubDetailState>(_ready()));
    await _pumpRoute(tester, controller: controller, capture: false);

    ConnectivityService.setOnlineForTest(true);
    await tester.pump();
    await tester.pump();

    expect(controller.refreshCalls, 1);
  });

  testWidgets('golden Fan club detail loading state', (tester) async {
    await _pumpState(
      tester,
      id: 'loading',
      value: const AsyncLoading<FanClubDetailState>(),
      settle: false,
    );
  });

  testWidgets('golden Fan club detail empty state', (tester) async {
    await _pumpState(
      tester,
      id: 'empty',
      value: const AsyncData<FanClubDetailState>(FanClubDetailState()),
      check: (_) async =>
          expect(find.text('Fan club unavailable'), findsOneWidget),
    );
  });

  testWidgets('golden Fan club detail error state', (tester) async {
    await _pumpState(
      tester,
      id: 'error',
      value: const AsyncError<FanClubDetailState>(
        FanClubDetailFailure(FanClubDetailFailureKind.unknown),
        StackTrace.empty,
      ),
      check: (_) async =>
          expect(find.text('Unable to load fan club'), findsOneWidget),
    );
  });

  testWidgets('golden Fan club detail offline state', (tester) async {
    await _pumpState(
      tester,
      id: 'offline',
      value: AsyncData<FanClubDetailState>(_ready()),
      online: false,
      check: (_) async =>
          expect(find.text('Showing saved fan club'), findsOneWidget),
    );
  });

  testWidgets('golden Fan club detail permission-denied state', (tester) async {
    await _pumpState(
      tester,
      id: 'permission_denied',
      value: const AsyncError<FanClubDetailState>(
        FanClubDetailFailure(FanClubDetailFailureKind.permissionDenied),
        StackTrace.empty,
      ),
      check: (_) async {
        expect(find.text('Fan club access denied'), findsOneWidget);
        expect(find.text('Try again'), findsNothing);
      },
    );
  });

  testWidgets('golden Fan club detail disabled state', (tester) async {
    await _pumpState(
      tester,
      id: 'disabled',
      value: AsyncData<FanClubDetailState>(_ready()),
      accessEnabled: false,
      check: (_) async =>
          expect(find.text('Fan club preview unavailable'), findsOneWidget),
    );
  });

  testWidgets('golden Fan club detail focused state', (tester) async {
    final previous = FocusManager.instance.highlightStrategy;
    addTearDown(() => FocusManager.instance.highlightStrategy = previous);
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    await _pumpState(
      tester,
      id: 'focused',
      value: AsyncData<FanClubDetailState>(_ready()),
      check: (tester) async {
        final back = find.byKey(const ValueKey<String>('fan-club-detail-back'));
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

  testWidgets('golden Fan club detail pressed state', (tester) async {
    TestGesture? gesture;
    addTearDown(() async => gesture?.cancel());
    await _pumpState(
      tester,
      id: 'pressed',
      value: AsyncData<FanClubDetailState>(
        _ready(
          phase: FanClubDetailPhase.degraded,
          failure: const FanClubDetailFailure(
            FanClubDetailFailureKind.conflict,
          ),
        ),
      ),
      check: (tester) async {
        gesture = await tester.startGesture(
          tester.getCenter(find.text('Refresh club')),
        );
        await tester.pump(const Duration(milliseconds: 120));
        await tester.pump(const Duration(milliseconds: 40));
      },
    );
  });

  testWidgets('golden Fan club detail selected state', (tester) async {
    await _pumpState(
      tester,
      id: 'selected',
      value: AsyncData<FanClubDetailState>(_ready()),
      check: (_) async {
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

  testWidgets('golden Fan club detail large-text state', (tester) async {
    await _pumpState(
      tester,
      id: 'large_text',
      value: AsyncData<FanClubDetailState>(_ready()),
      size: const Size(320, 720),
      textScale: 2,
      check: (tester) async {
        final action = find.text('Copy link');
        await tester.ensureVisible(action);
        await tester.pumpAndSettle();
        final actionRect = tester.getRect(action);
        expect(actionRect.top, greaterThanOrEqualTo(0));
        expect(actionRect.bottom, lessThanOrEqualTo(720));
        expect(find.text('Copy link'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });

  testWidgets('golden Fan club detail reduced-motion state', (tester) async {
    await _pumpState(
      tester,
      id: 'reduced_motion',
      value: AsyncData<FanClubDetailState>(_ready()),
      reducedMotion: true,
      check: (tester) async => expect(
        MediaQuery.disableAnimationsOf(
          tester.element(find.byType(FanClubDetailScreen)),
        ),
        isTrue,
      ),
    );
  });

  testWidgets('golden Fan club detail dark state', (tester) async {
    await _pumpState(
      tester,
      id: 'dark',
      value: AsyncData<FanClubDetailState>(_ready()),
      check: (_) async {
        expect(
          find.text(
            'A verified public community for Rayon Sports supporters in Kigali.',
          ),
          findsOneWidget,
        );
        expect(find.text('Status'), findsNothing);
        expect(find.text('Active'), findsNothing);
        expect(find.text('Joining options'), findsNothing);
      },
    );
  });

  testWidgets('golden Fan club detail light state', (tester) async {
    await _pumpState(
      tester,
      id: 'light',
      value: AsyncData<FanClubDetailState>(_ready()),
      brightness: Brightness.light,
    );
  });

  testWidgets('golden Fan club detail syncing state', (tester) async {
    await _pumpState(
      tester,
      id: 'syncing',
      value: AsyncData<FanClubDetailState>(
        _ready(phase: FanClubDetailPhase.syncing),
      ),
      check: (_) async =>
          expect(find.text('Refreshing fan club'), findsOneWidget),
    );
  });

  testWidgets('golden Fan club detail conflict state', (tester) async {
    await _pumpState(
      tester,
      id: 'conflict',
      value: AsyncData<FanClubDetailState>(
        _ready(
          phase: FanClubDetailPhase.degraded,
          failure: const FanClubDetailFailure(
            FanClubDetailFailureKind.conflict,
          ),
        ),
      ),
      check: (_) async {
        expect(find.text('Fan club details changed'), findsOneWidget);
        expect(find.text('Refresh club'), findsOneWidget);
      },
    );
  });

  testWidgets('golden Fan club detail security-timeout state', (tester) async {
    await _pumpState(
      tester,
      id: 'security_timeout',
      value: const AsyncError<FanClubDetailState>(
        FanClubDetailFailure(FanClubDetailFailureKind.securityTimeout),
        StackTrace.empty,
      ),
      check: (_) async => expect(
        find.text('Fan club security check timed out'),
        findsOneWidget,
      ),
    );
  });
}

Future<void> _pumpState(
  WidgetTester tester, {
  required String id,
  required AsyncValue<FanClubDetailState> value,
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
    initialLocation: '/fan-clubs/blue-family',
    routes: [
      GoRoute(
        path: '/predict',
        builder: (context, state) =>
            const Scaffold(body: Text('Fan clubs directory')),
      ),
      GoRoute(
        path: '/fan-clubs/:clubId',
        builder: (context, state) =>
            FanClubDetailScreen(clubId: state.pathParameters['clubId']!),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        fanClubDetailProvider.overrideWith((ref, clubId) => controller),
        fanClubDetailAccessEnabledProvider.overrideWithValue(accessEnabled),
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

class _Controller extends FanClubDetailController {
  _Controller(AsyncValue<FanClubDetailState> value)
    : super(_Gateway(), 'blue-family', autoLoad: false) {
    state = value;
  }

  int refreshCalls = 0;

  @override
  Future<void> refresh() async {
    refreshCalls += 1;
  }
}

class _Gateway implements FanClubDetailGateway {
  @override
  Future<FanClubDetailData?> load(String routeId) async => _data();
}

FanClubDetailState _ready({
  FanClubDetailPhase phase = FanClubDetailPhase.ready,
  FanClubDetailFailure? failure,
}) {
  return FanClubDetailState(data: _data(), phase: phase, failure: failure);
}

FanClubDetailData _data() => const FanClubDetailData(
  club: {
    'id': 'club-1',
    'slug': 'blue-family',
    'name': 'Blue Family Kigali',
    'description':
        'A verified public community for Rayon Sports supporters in Kigali.',
    'region': 'Kigali',
    'member_count': 42,
    'is_active': true,
    'approval_status': 'approved',
    'source_label': 'Approved public supporter register',
  },
  upcomingMatch: {
    'home_team': 'Rayon Sports',
    'away_team': 'APR FC',
    'competition': 'Rwanda Premier League',
    'venue': 'Amahoro Stadium',
    'match_date': '2026-08-02',
    'kickoff_time': '17:00',
  },
);
