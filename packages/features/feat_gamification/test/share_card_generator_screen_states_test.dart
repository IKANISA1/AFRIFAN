import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_gamification/src/controllers/share_card_controller.dart';
import 'package:feat_gamification/src/models/prediction_models.dart';
import 'package:feat_gamification/src/predict/predict_share_screen.dart';
import 'package:feat_gamification/src/prediction_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:test_support/app_font_loader.dart';

const _goldens = <String, String>{
  'loading': 'goldens/share_card_state_loading_dark_390x844.png',
  'empty': 'goldens/share_card_state_empty_dark_390x844.png',
  'error': 'goldens/share_card_state_error_dark_390x844.png',
  'offline': 'goldens/share_card_state_offline_dark_390x844.png',
  'permission_denied':
      'goldens/share_card_state_permission_denied_dark_390x844.png',
  'disabled': 'goldens/share_card_state_disabled_dark_390x844.png',
  'focused': 'goldens/share_card_state_focused_dark_390x844.png',
  'pressed': 'goldens/share_card_state_pressed_dark_390x844.png',
  'selected': 'goldens/share_card_state_selected_dark_390x844.png',
  'large_text': 'goldens/share_card_state_large_text_dark_320x720.png',
  'reduced_motion': 'goldens/share_card_state_reduced_motion_dark_390x844.png',
  'dark': 'goldens/share_card_state_dark_dark_390x844.png',
  'light': 'goldens/share_card_state_light_light_390x844.png',
  'syncing': 'goldens/share_card_state_syncing_dark_390x844.png',
  'conflict': 'goldens/share_card_state_conflict_dark_390x844.png',
  'security_timeout':
      'goldens/share_card_state_security_timeout_dark_390x844.png',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);
  setUp(() => ConnectivityService.setOnlineForTest(true));
  tearDown(() => ConnectivityService.setOnlineForTest(true));

  testWidgets('Share card refreshes once after reconnect', (tester) async {
    ConnectivityService.setOnlineForTest(false);
    final controller = _Controller(
      const AsyncData<ShareCardRouteState>(
        ShareCardRouteState(
          history: _history,
          selectedId: 'prediction-1',
          phase: ShareCardPhase.degraded,
          failure: ShareCardFailure(ShareCardFailureKind.offline),
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

  testWidgets('golden Share card loading state', (tester) async {
    await _pumpState(
      tester,
      id: 'loading',
      value: const AsyncLoading<ShareCardRouteState>(),
      settle: false,
    );
  });

  testWidgets('golden Share card empty state', (tester) async {
    await _pumpState(
      tester,
      id: 'empty',
      value: const AsyncData<ShareCardRouteState>(ShareCardRouteState()),
      check: (_) async =>
          expect(find.text('Make a pick first'), findsOneWidget),
    );
  });

  testWidgets('golden Share card error state', (tester) async {
    await _pumpState(
      tester,
      id: 'error',
      value: const AsyncError<ShareCardRouteState>(
        ShareCardFailure(ShareCardFailureKind.unknown),
        StackTrace.empty,
      ),
      check: (_) async =>
          expect(find.text('Share cards unavailable'), findsOneWidget),
    );
  });

  testWidgets('golden Share card offline state', (tester) async {
    await _pumpState(
      tester,
      id: 'offline',
      online: false,
      value: const AsyncData<ShareCardRouteState>(
        ShareCardRouteState(
          history: _history,
          selectedId: 'prediction-1',
          phase: ShareCardPhase.degraded,
          failure: ShareCardFailure(ShareCardFailureKind.offline),
        ),
      ),
      check: (_) async {
        expect(find.text('Showing saved share card'), findsOneWidget);
        expect(find.textContaining('No action is queued'), findsOneWidget);
      },
    );
  });

  testWidgets('golden Share card permission-denied state', (tester) async {
    await _pumpState(
      tester,
      id: 'permission_denied',
      value: const AsyncError<ShareCardRouteState>(
        ShareCardFailure(ShareCardFailureKind.permissionDenied),
        StackTrace.empty,
      ),
      check: (_) async =>
          expect(find.text('Prediction access denied'), findsOneWidget),
    );
  });

  testWidgets('golden Share card disabled state', (tester) async {
    await _pumpState(
      tester,
      id: 'disabled',
      accessEnabled: false,
      value: const AsyncData<ShareCardRouteState>(_readyState),
      check: (_) async =>
          expect(find.text('Share actions unavailable'), findsOneWidget),
    );
  });

  testWidgets('golden Share card focused state', (tester) async {
    final previous = FocusManager.instance.highlightStrategy;
    addTearDown(() => FocusManager.instance.highlightStrategy = previous);
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    final focusNode = FocusNode(debugLabel: 'share-action');
    addTearDown(focusNode.dispose);
    await _pumpState(
      tester,
      id: 'focused',
      shareFocusNode: focusNode,
      value: const AsyncData<ShareCardRouteState>(_readyState),
      check: (tester) async {
        focusNode.requestFocus();
        await tester.pumpAndSettle();
        expect(focusNode.hasFocus, isTrue);
      },
    );
  });

  testWidgets('golden Share card pressed state', (tester) async {
    TestGesture? gesture;
    addTearDown(() async => gesture?.cancel());
    await _pumpState(
      tester,
      id: 'pressed',
      value: const AsyncData<ShareCardRouteState>(_readyState),
      check: (tester) async {
        final selector = find.byKey(
          const ValueKey<String>('share-card-prediction-prediction-2'),
        );
        await tester.ensureVisible(selector);
        await tester.pumpAndSettle();
        final detector = find.descendant(
          of: selector,
          matching: find.byType(GestureDetector),
        );
        expect(detector, findsOneWidget);
        gesture = await tester.startGesture(tester.getCenter(detector));
        await tester.pump(const Duration(milliseconds: 120));
        await tester.pump(const Duration(milliseconds: 40));
        final scales = tester
            .widgetList<ScaleTransition>(
              find.descendant(
                of: selector,
                matching: find.byType(ScaleTransition),
              ),
            )
            .map((transition) => transition.scale.value);
        expect(scales.any((scale) => scale < 1), isTrue);
      },
    );
  });

  testWidgets('golden Share card selected state', (tester) async {
    await _pumpState(
      tester,
      id: 'selected',
      value: const AsyncData<ShareCardRouteState>(
        ShareCardRouteState(history: _history, selectedId: 'prediction-2'),
      ),
      check: (_) async {
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && widget.properties.selected == true,
          ),
          findsOneWidget,
        );
        expect(find.text('POL'), findsWidgets);
        expect(find.text('RAY'), findsWidgets);
      },
    );
  });

  testWidgets('golden Share card large-text state', (tester) async {
    await _pumpState(
      tester,
      id: 'large_text',
      size: const Size(320, 720),
      textScale: 2,
      value: const AsyncData<ShareCardRouteState>(_readyState),
      check: (tester) async {
        final share = find.byKey(
          const ValueKey<String>('share-card-share-action'),
        );
        final copy = find.byKey(
          const ValueKey<String>('share-card-copy-action'),
        );
        await tester.scrollUntilVisible(
          copy,
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(tester.getRect(share).width, tester.getRect(copy).width);
        expect(
          tester.getRect(share).bottom,
          lessThan(tester.getRect(copy).top),
        );
        await tester.drag(find.byType(Scrollable).first, const Offset(0, 120));
        await tester.pumpAndSettle();
      },
    );
  });

  testWidgets('golden Share card reduced-motion state', (tester) async {
    await _pumpState(
      tester,
      id: 'reduced_motion',
      reducedMotion: true,
      value: const AsyncData<ShareCardRouteState>(_readyState),
      check: (tester) async => expect(
        MediaQuery.disableAnimationsOf(
          tester.element(find.byType(PredictShareScreen)),
        ),
        isTrue,
      ),
    );
  });

  testWidgets('golden Share card dark state', (tester) async {
    await _pumpState(
      tester,
      id: 'dark',
      value: const AsyncData<ShareCardRouteState>(_readyState),
    );
  });

  testWidgets('golden Share card light state', (tester) async {
    await _pumpState(
      tester,
      id: 'light',
      brightness: Brightness.light,
      value: const AsyncData<ShareCardRouteState>(_readyState),
    );
  });

  testWidgets('golden Share card syncing state', (tester) async {
    await _pumpState(
      tester,
      id: 'syncing',
      settle: false,
      value: const AsyncData<ShareCardRouteState>(
        ShareCardRouteState(
          history: _history,
          selectedId: 'prediction-1',
          phase: ShareCardPhase.syncing,
          mutation: ShareCardMutation.sharing,
        ),
      ),
      check: (_) async =>
          expect(find.text('Opening share options'), findsOneWidget),
    );
  });

  testWidgets('golden Share card conflict state', (tester) async {
    await _pumpState(
      tester,
      id: 'conflict',
      value: const AsyncData<ShareCardRouteState>(
        ShareCardRouteState(
          history: _history,
          selectedId: 'prediction-1',
          phase: ShareCardPhase.degraded,
          failure: ShareCardFailure(ShareCardFailureKind.conflict),
        ),
      ),
      check: (_) async =>
          expect(find.text('Share action paused'), findsOneWidget),
    );
  });

  testWidgets('golden Share card security-timeout state', (tester) async {
    await _pumpState(
      tester,
      id: 'security_timeout',
      value: const AsyncData<ShareCardRouteState>(
        ShareCardRouteState(
          history: _history,
          selectedId: 'prediction-1',
          phase: ShareCardPhase.degraded,
          failure: ShareCardFailure(ShareCardFailureKind.securityTimeout),
          uncertainMutation: true,
        ),
      ),
      check: (_) async =>
          expect(find.text('Share confirmation uncertain'), findsOneWidget),
    );
  });
}

Future<void> _pumpState(
  WidgetTester tester, {
  required String id,
  required AsyncValue<ShareCardRouteState> value,
  bool online = true,
  bool accessEnabled = true,
  Brightness brightness = Brightness.dark,
  Size size = const Size(390, 844),
  double textScale = 1,
  bool reducedMotion = false,
  bool settle = true,
  FocusNode? shareFocusNode,
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
    shareFocusNode: shareFocusNode,
  );
  await check?.call(tester);
  expect(tester.takeException(), isNull);
  await expectLater(
    find.byKey(const ValueKey<String>('share-card-state-golden')),
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
  FocusNode? shareFocusNode,
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
    initialLocation: '/predict/share',
    routes: [
      GoRoute(
        path: '/predict/share',
        builder: (_, _) => RepaintBoundary(
          key: const ValueKey<String>('share-card-state-golden'),
          child: PredictShareScreen(shareFocusNode: shareFocusNode),
        ),
      ),
      GoRoute(path: '/predict', builder: (_, _) => const SizedBox.shrink()),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        shareCardControllerProvider.overrideWith((ref) => controller),
        shareCardActionsEnabledProvider.overrideWithValue(accessEnabled),
      ],
      child: MaterialApp.router(
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
    expect(find.byType(PredictShareScreen), findsOneWidget);
  }
}

class _Controller extends ShareCardController {
  _Controller(AsyncValue<ShareCardRouteState> value)
    : super(_Gateway(), autoLoad: false) {
    state = value;
  }

  int restoredCalls = 0;

  @override
  Future<void> connectionRestored() async {
    restoredCalls += 1;
  }
}

class _Gateway implements ShareCardGateway {
  @override
  Future<List<UserPrediction>> loadHistory({required int limit}) async =>
      _history;

  @override
  Future<void> share(UserPrediction prediction) async {}

  @override
  Future<void> copy(UserPrediction prediction) async {}
}

const _readyState = ShareCardRouteState(
  history: _history,
  selectedId: 'prediction-1',
);

const _history = <UserPrediction>[
  UserPrediction(
    id: 'prediction-1',
    fixtureId: 'fixture-1',
    marketSlug: '1x2',
    marketName: 'Match Result',
    marketGroup: MarketGroup.matchResult,
    homeTeam: 'Rayon Sports',
    homeTeamShort: 'RAY',
    awayTeam: 'APR FC',
    awayTeamShort: 'APR',
    kickoffAt: null,
    fixtureStatus: 'finished',
    competitionName: 'Rwanda Premier League',
    selectedOutcome: 'Rayon Sports',
    status: PredictionStatus.won,
    fetPotential: 100,
    fetEarned: 100,
    placedAt: null,
    homeScore: 2,
    awayScore: 1,
  ),
  UserPrediction(
    id: 'prediction-2',
    fixtureId: 'fixture-2',
    marketSlug: 'goals',
    marketName: 'Total Goals',
    marketGroup: MarketGroup.goals,
    homeTeam: 'Police FC',
    homeTeamShort: 'POL',
    awayTeam: 'Rayon Sports',
    awayTeamShort: 'RAY',
    kickoffAt: null,
    fixtureStatus: 'scheduled',
    competitionName: 'Rwanda Premier League',
    selectedOutcome: 'Over 2.5',
    status: PredictionStatus.pending,
    fetPotential: 140,
    fetEarned: 0,
    placedAt: null,
  ),
];
