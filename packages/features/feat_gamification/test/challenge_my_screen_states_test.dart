import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_gamification/src/controllers/challenge_my_controller.dart';
import 'package:feat_gamification/src/models/challenge_models.dart';
import 'package:feat_gamification/src/screens/my_challenges_screen.dart';
import 'package:feat_gamification/src/widgets/challenge_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:test_support/app_font_loader.dart';

import 'challenge_test_helpers.dart';

const _goldenPaths = <String, String>{
  'loading': 'goldens/challenge_my_state_loading_dark_390x844.png',
  'empty': 'goldens/challenge_my_state_empty_dark_390x844.png',
  'error': 'goldens/challenge_my_state_error_dark_390x844.png',
  'offline': 'goldens/challenge_my_state_offline_dark_390x844.png',
  'permission_denied':
      'goldens/challenge_my_state_permission_denied_dark_390x844.png',
  'disabled': 'goldens/challenge_my_state_disabled_dark_390x844.png',
  'focused': 'goldens/challenge_my_state_focused_dark_390x844.png',
  'pressed': 'goldens/challenge_my_state_pressed_dark_390x844.png',
  'selected': 'goldens/challenge_my_state_selected_dark_390x844.png',
  'large_text': 'goldens/challenge_my_state_large_text_dark_320x720.png',
  'reduced_motion':
      'goldens/challenge_my_state_reduced_motion_dark_390x844.png',
  'dark': 'goldens/challenge_my_state_dark_dark_390x844.png',
  'light': 'goldens/challenge_my_state_light_light_390x844.png',
  'syncing': 'goldens/challenge_my_state_syncing_dark_390x844.png',
  'conflict': 'goldens/challenge_my_state_conflict_dark_390x844.png',
  'security_timeout':
      'goldens/challenge_my_state_security_timeout_dark_390x844.png',
};

class _ControlledMyChallengesController extends MyChallengesController {
  _ControlledMyChallengesController(AsyncValue<MyChallengesState> value)
    : super(FakeChallengeRepository(), autoLoad: false) {
    state = value;
  }

  int refreshCount = 0;
  final List<MyChallengeFilter> selectedFilters = <MyChallengeFilter>[];

  @override
  Future<void> refresh() async {
    refreshCount++;
  }

  @override
  Future<void> select(MyChallengeFilter filter) async {
    selectedFilters.add(filter);
    if (filter == MyChallengeFilter.settled) {
      state = AsyncData<MyChallengesState>(
        MyChallengesState(
          filter: filter,
          items: <Challenge>[_settledChallenge()],
        ),
      );
    }
  }
}

Challenge _openChallenge() {
  return buildChallenge(
    id: 'my-open',
    fixture: buildFixture(
      id: 'my-open-fixture',
      homeTeamName: 'Rayon Sports Football Club',
      homeTeamShort: 'RAY',
      awayTeamName: 'Armée Patriotique Rwandaise FC',
      awayTeamShort: 'APR',
    ),
    permissions: const ChallengePermissions(hasJoined: true),
    myEntry: buildEntry(challengeId: 'my-open', homeScore: 2, awayScore: 1),
    totalParticipants: 8,
    totalPoolFet: 24000,
  );
}

Challenge _settledChallenge() {
  return buildChallenge(
    id: 'my-settled',
    fixture: buildFixture(
      id: 'my-settled-fixture',
      homeTeamName: 'Kiyovu Sports Association',
      homeTeamShort: 'KIY',
      awayTeamName: 'Musanze Football Club',
      awayTeamShort: 'MUS',
      status: 'finished',
      homeScore: 2,
      awayScore: 1,
    ),
    status: ChallengeStatus.settled,
    permissions: const ChallengePermissions(hasJoined: true),
    myEntry: buildEntry(
      challengeId: 'my-settled',
      status: ChallengeEntryStatus.winner,
      payoutFet: 9000,
    ),
  );
}

MyChallengesState _populatedState({
  MyChallengesPhase phase = MyChallengesPhase.ready,
  MyChallengesFailure? failure,
}) {
  return MyChallengesState(
    items: <Challenge>[_openChallenge()],
    phase: phase,
    failure: failure,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);
  setUp(() => ConnectivityService.setOnlineForTest(true));

  testWidgets('My challenges refreshes automatically after reconnect', (
    tester,
  ) async {
    ConnectivityService.setOnlineForTest(false);
    addTearDown(() => ConnectivityService.setOnlineForTest(true));
    final controller = _ControlledMyChallengesController(
      const AsyncError<MyChallengesState>(
        MyChallengesFailure(MyChallengesFailureKind.offline),
        StackTrace.empty,
      ),
    );
    final router = _router(stateKey: 'reconnect');
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          myChallengesProvider.overrideWith((ref) => controller),
        ],
        child: MaterialApp.router(
          theme: ClubTheme.from(
            ClubConfig.fallback(),
            brightness: Brightness.dark,
          ),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Challenge history offline'), findsOneWidget);

    ConnectivityService.setOnlineForTest(true);
    await tester.pumpAndSettle();

    expect(controller.refreshCount, 1);
    expect(find.text('Connection restored'), findsOneWidget);
  });

  testWidgets('golden My challenges loading state', (tester) async {
    await _pumpState(
      tester,
      id: 'loading',
      value: const AsyncLoading<MyChallengesState>(),
      settle: false,
      beforeCapture: (tester) async {
        expect(find.text('Loading your challenges'), findsOneWidget);
      },
    );
  });

  testWidgets('golden My challenges empty state', (tester) async {
    await _pumpState(
      tester,
      id: 'empty',
      value: const AsyncData<MyChallengesState>(MyChallengesState()),
      beforeCapture: (tester) async {
        expect(find.text('No open challenges'), findsOneWidget);
        expect(find.text('Create challenge'), findsOneWidget);
      },
    );
  });

  testWidgets('golden My challenges error state', (tester) async {
    await _pumpState(
      tester,
      id: 'error',
      value: const AsyncError<MyChallengesState>(
        MyChallengesFailure(MyChallengesFailureKind.unknown),
        StackTrace.empty,
      ),
      beforeCapture: (tester) async {
        expect(find.text('Challenge history unavailable'), findsOneWidget);
        expect(find.textContaining('supporter-991'), findsNothing);
      },
    );
  });

  testWidgets('golden My challenges offline state', (tester) async {
    await _pumpState(
      tester,
      id: 'offline',
      value: AsyncData<MyChallengesState>(_populatedState()),
      online: false,
      beforeCapture: (tester) async {
        expect(find.text('Showing saved challenge history'), findsOneWidget);
        expect(
          tester.widget<ChallengeCard>(find.byType(ChallengeCard)).enabled,
          isFalse,
        );
      },
    );
  });

  testWidgets('golden My challenges permission-denied state', (tester) async {
    await _pumpState(
      tester,
      id: 'permission_denied',
      value: const AsyncError<MyChallengesState>(
        MyChallengesFailure(MyChallengesFailureKind.permissionDenied),
        StackTrace.empty,
      ),
      beforeCapture: (tester) async {
        expect(find.text('Challenge history unavailable'), findsOneWidget);
        expect(find.text('Refresh'), findsNothing);
      },
    );
  });

  testWidgets('golden My challenges disabled state', (tester) async {
    await _pumpState(
      tester,
      id: 'disabled',
      value: AsyncData<MyChallengesState>(_populatedState()),
      actionsEnabled: false,
      beforeCapture: (tester) async {
        expect(find.text('Challenge history is read-only'), findsOneWidget);
        expect(
          tester.widget<ChallengeCard>(find.byType(ChallengeCard)).enabled,
          isFalse,
        );
      },
    );
  });

  testWidgets('golden My challenges focused state', (tester) async {
    final focusNode = FocusNode(debugLabel: 'my-challenge-card-focus');
    addTearDown(focusNode.dispose);
    final previousHighlightStrategy = FocusManager.instance.highlightStrategy;
    addTearDown(
      () => FocusManager.instance.highlightStrategy = previousHighlightStrategy,
    );
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;

    await _pumpState(
      tester,
      id: 'focused',
      value: AsyncData<MyChallengesState>(_populatedState()),
      cardFocusNode: focusNode,
      beforeCapture: (tester) async {
        focusNode.requestFocus();
        await tester.pumpAndSettle();
        final scrollable = tester.state<ScrollableState>(
          find
              .descendant(
                of: find.byKey(
                  const ValueKey<String>('my-challenges-scroll-view'),
                ),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        scrollable.position.jumpTo(0);
        await tester.pumpAndSettle();
        expect(focusNode.hasFocus, isTrue);
      },
      afterCapture: (tester) async {
        focusNode.unfocus();
        await tester.pumpAndSettle();
      },
    );
  });

  testWidgets('golden My challenges pressed state', (tester) async {
    TestGesture? heldGesture;
    await _pumpState(
      tester,
      id: 'pressed',
      value: AsyncData<MyChallengesState>(_populatedState()),
      beforeCapture: (tester) async {
        final card = find.byType(ChallengeCard);
        final pressFeedback = find.descendant(
          of: card,
          matching: find.byType(AfriPressFeedback),
        );
        heldGesture = await tester.press(pressFeedback);
        await tester.pump(const Duration(milliseconds: 120));
        await tester.pump(const Duration(milliseconds: 100));
        final scales = tester
            .widgetList<ScaleTransition>(
              find.descendant(of: card, matching: find.byType(ScaleTransition)),
            )
            .map((transition) => transition.scale.value);
        expect(scales.any((scale) => scale < 1), isTrue);
      },
      afterCapture: (tester) async {
        await heldGesture?.up();
        await tester.pumpAndSettle();
      },
    );
  });

  testWidgets('golden My challenges selected tab state', (tester) async {
    await _pumpState(
      tester,
      id: 'selected',
      value: AsyncData<MyChallengesState>(_populatedState()),
      beforeCapture: (tester) async {
        await tester.tap(find.text('Settled'));
        await tester.pumpAndSettle();
        expect(find.text('KIY'), findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && widget.properties.selected == true,
          ),
          findsWidgets,
        );
      },
    );
  });

  testWidgets('golden My challenges large-text state', (tester) async {
    await _pumpState(
      tester,
      id: 'large_text',
      value: AsyncData<MyChallengesState>(_populatedState()),
      size: const Size(320, 720),
      textScale: 2,
      beforeCapture: (tester) async {
        expect(
          find.textContaining('Rayon Sports Football Club'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Armée Patriotique Rwandaise FC'),
          findsOneWidget,
        );
      },
    );
  });

  testWidgets('golden My challenges reduced-motion state', (tester) async {
    await _pumpState(
      tester,
      id: 'reduced_motion',
      value: AsyncData<MyChallengesState>(_populatedState()),
      reducedMotion: true,
      beforeCapture: (tester) async {
        expect(
          MediaQuery.disableAnimationsOf(
            tester.element(find.byType(MyChallengesScreen)),
          ),
          isTrue,
        );
      },
    );
  });

  testWidgets('golden My challenges dark state', (tester) async {
    await _pumpState(
      tester,
      id: 'dark',
      value: AsyncData<MyChallengesState>(_populatedState()),
    );
  });

  testWidgets('golden My challenges light state', (tester) async {
    await _pumpState(
      tester,
      id: 'light',
      value: AsyncData<MyChallengesState>(_populatedState()),
      brightness: Brightness.light,
    );
  });

  testWidgets('golden My challenges syncing state', (tester) async {
    await _pumpState(
      tester,
      id: 'syncing',
      value: AsyncData<MyChallengesState>(
        _populatedState(phase: MyChallengesPhase.syncing),
      ),
      beforeCapture: (tester) async {
        expect(find.text('Refreshing challenge history'), findsOneWidget);
        expect(
          tester.widget<ChallengeCard>(find.byType(ChallengeCard)).enabled,
          isFalse,
        );
      },
    );
  });

  testWidgets('golden My challenges conflict state', (tester) async {
    await _pumpState(
      tester,
      id: 'conflict',
      value: AsyncData<MyChallengesState>(
        _populatedState(
          phase: MyChallengesPhase.degraded,
          failure: const MyChallengesFailure(MyChallengesFailureKind.conflict),
        ),
      ),
      beforeCapture: (tester) async {
        expect(find.text('Challenge history changed'), findsOneWidget);
        expect(find.text('Refresh history'), findsOneWidget);
      },
    );
  });

  testWidgets('golden My challenges security-timeout state', (tester) async {
    await _pumpState(
      tester,
      id: 'security_timeout',
      value: AsyncData<MyChallengesState>(
        _populatedState(
          phase: MyChallengesPhase.degraded,
          failure: const MyChallengesFailure(
            MyChallengesFailureKind.securityTimeout,
          ),
        ),
      ),
      beforeCapture: (tester) async {
        expect(find.text('Challenge history check timed out'), findsOneWidget);
        expect(
          find.text(
            'No status was confirmed. Refresh before opening a challenge.',
          ),
          findsOneWidget,
        );
      },
    );
  });
}

GoRouter _router({FocusNode? cardFocusNode, required String stateKey}) {
  return GoRouter(
    initialLocation: '/challenge/my',
    routes: <RouteBase>[
      GoRoute(
        path: '/challenge/my',
        builder: (context, state) => RepaintBoundary(
          key: const ValueKey<String>('challenge-my-state-golden'),
          child: MyChallengesScreen(
            key: ValueKey<String>('my-challenges-screen-$stateKey'),
            cardFocusNode: cardFocusNode,
          ),
        ),
      ),
      GoRoute(
        path: '/challenge/create',
        builder: (context, state) => const SizedBox.shrink(),
      ),
      GoRoute(
        path: '/challenge/:id',
        builder: (context, state) => const SizedBox.shrink(),
      ),
    ],
  );
}

Future<void> _pumpState(
  WidgetTester tester, {
  required String id,
  required AsyncValue<MyChallengesState> value,
  Size size = const Size(390, 844),
  double textScale = 1,
  Brightness brightness = Brightness.dark,
  bool reducedMotion = false,
  bool online = true,
  bool actionsEnabled = true,
  bool settle = true,
  FocusNode? cardFocusNode,
  Future<void> Function(WidgetTester tester)? beforeCapture,
  Future<void> Function(WidgetTester tester)? afterCapture,
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

  final controller = _ControlledMyChallengesController(value);
  final router = _router(cardFocusNode: cardFocusNode, stateKey: id);
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        myChallengesProvider.overrideWith((ref) => controller),
        myChallengesActionsEnabledProvider.overrideWithValue(actionsEnabled),
      ],
      child: MaterialApp.router(
        builder: (context, child) {
          final mediaQuery = MediaQuery.of(context);
          return MediaQuery(
            data: mediaQuery.copyWith(
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

  await beforeCapture?.call(tester);
  final goldenBoundary = find.byKey(
    const ValueKey<String>('challenge-my-state-golden'),
  );
  tester.renderObject(goldenBoundary).markNeedsPaint();
  await tester.pump();
  expect(tester.takeException(), isNull);
  final goldenPath = _goldenPaths[id];
  expect(
    goldenPath,
    isNotNull,
    reason: 'Missing My challenges golden for $id.',
  );
  await expectLater(goldenBoundary, matchesGoldenFile(goldenPath!));
  await afterCapture?.call(tester);
}
