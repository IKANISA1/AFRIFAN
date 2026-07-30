import 'package:core_feature_config/core_feature_config.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_gamification/src/controllers/challenge_create_controller.dart';
import 'package:feat_gamification/src/fet_providers.dart';
import 'package:feat_gamification/src/models/prediction_models.dart';
import 'package:feat_gamification/src/screens/create_challenge_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:test_support/app_font_loader.dart';

import 'challenge_test_helpers.dart';

const _goldenPaths = <String, String>{
  'loading': 'goldens/challenge_create_state_loading_dark_390x844.png',
  'empty': 'goldens/challenge_create_state_empty_dark_390x844.png',
  'error': 'goldens/challenge_create_state_error_dark_390x844.png',
  'offline': 'goldens/challenge_create_state_offline_dark_390x844.png',
  'permission_denied':
      'goldens/challenge_create_state_permission_denied_dark_390x844.png',
  'disabled': 'goldens/challenge_create_state_disabled_dark_390x844.png',
  'focused': 'goldens/challenge_create_state_focused_dark_390x844.png',
  'pressed': 'goldens/challenge_create_state_pressed_dark_390x844.png',
  'selected': 'goldens/challenge_create_state_selected_dark_390x844.png',
  'large_text': 'goldens/challenge_create_state_large_text_dark_320x720.png',
  'reduced_motion':
      'goldens/challenge_create_state_reduced_motion_dark_390x844.png',
  'dark': 'goldens/challenge_create_state_dark_dark_390x844.png',
  'light': 'goldens/challenge_create_state_light_light_390x844.png',
  'syncing': 'goldens/challenge_create_state_syncing_dark_390x844.png',
  'conflict': 'goldens/challenge_create_state_conflict_dark_390x844.png',
  'security_timeout':
      'goldens/challenge_create_state_security_timeout_dark_390x844.png',
};

const _stakeConfig = PlatformConfigSnapshot(
  optionSets: <PlatformOptionSet>[
    PlatformOptionSet(
      optionSetKey: 'challenge_stake_fet',
      label: 'Challenge entry options',
      valueType: 'number',
      surface: 'mobile',
      values: <PlatformOptionValue>[
        PlatformOptionValue(
          optionKey: 'stake_1000',
          label: '1,000 points',
          value: 1000,
          sortOrder: 10,
          isDefault: true,
        ),
        PlatformOptionValue(
          optionKey: 'stake_3000',
          label: '3,000 points',
          value: 3000,
          sortOrder: 20,
        ),
      ],
    ),
  ],
);

class _ControlledChallengeCreateController extends ChallengeCreateController {
  _ControlledChallengeCreateController(AsyncValue<ChallengeCreateState> value)
    : super(
        FakeChallengeFixturesGateway(),
        FakeChallengeRepository(),
        autoLoad: false,
      ) {
    state = value;
  }

  int refreshCount = 0;

  @override
  Future<void> refresh() async {
    refreshCount++;
  }
}

List<FixtureSummary> _fixtures() => <FixtureSummary>[
  buildFixture(
    id: 'fixture-create-1',
    homeTeamShort: 'RAY',
    awayTeamShort: 'APR',
    competitionName: 'Rwanda Premier League',
  ),
  buildFixture(
    id: 'fixture-create-2',
    homeTeamShort: 'KIG',
    awayTeamShort: 'MUS',
    competitionName: 'Peace Cup',
  ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);
  setUp(() => ConnectivityService.setOnlineForTest(true));

  testWidgets('Create challenge refreshes automatically after reconnect', (
    tester,
  ) async {
    ConnectivityService.setOnlineForTest(false);
    addTearDown(() => ConnectivityService.setOnlineForTest(true));
    final controller = _ControlledChallengeCreateController(
      const AsyncError<ChallengeCreateState>(
        ChallengeCreateFailure(ChallengeCreateFailureKind.offline),
        StackTrace.empty,
      ),
    );
    final router = _router();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          challengeCreateProvider.overrideWith((ref) => controller),
          fetRepositoryProvider.overrideWithValue(
            FakeFetRepository()..wallet = buildWallet(balance: 8000),
          ),
          initialFeatureConfigSnapshotProvider.overrideWithValue(_stakeConfig),
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
    expect(find.text('Challenge creation offline'), findsOneWidget);

    ConnectivityService.setOnlineForTest(true);
    await tester.pumpAndSettle();

    expect(controller.refreshCount, 1);
    expect(find.text('Connection restored'), findsOneWidget);
  });

  testWidgets('golden Create challenge loading state', (tester) async {
    await _pumpState(
      tester,
      id: 'loading',
      value: const AsyncLoading<ChallengeCreateState>(),
      settle: false,
      beforeCapture: (tester) async {
        expect(find.text('Finding upcoming fixtures'), findsOneWidget);
      },
    );
  });

  testWidgets('golden Create challenge empty state', (tester) async {
    await _pumpState(
      tester,
      id: 'empty',
      value: const AsyncData<ChallengeCreateState>(ChallengeCreateState()),
      beforeCapture: (tester) async {
        expect(find.text('No fixtures available'), findsOneWidget);
      },
    );
  });

  testWidgets('golden Create challenge error state', (tester) async {
    await _pumpState(
      tester,
      id: 'error',
      value: const AsyncError<ChallengeCreateState>(
        ChallengeCreateFailure(ChallengeCreateFailureKind.unknown),
        StackTrace.empty,
      ),
      beforeCapture: (tester) async {
        expect(find.text('Challenge creation unavailable'), findsOneWidget);
        expect(find.textContaining('supporter-991'), findsNothing);
      },
    );
  });

  testWidgets('golden Create challenge offline state', (tester) async {
    await _pumpState(
      tester,
      id: 'offline',
      value: AsyncData<ChallengeCreateState>(
        ChallengeCreateState(fixtures: _fixtures()),
      ),
      online: false,
      beforeCapture: (tester) async {
        expect(find.text('Showing saved fixtures'), findsOneWidget);
        expect(
          tester
              .widget<AfriButton>(
                find.byKey(const ValueKey<String>('challenge-create-action')),
              )
              .enabled,
          isFalse,
        );
      },
    );
  });

  testWidgets('golden Create challenge permission-denied state', (
    tester,
  ) async {
    await _pumpState(
      tester,
      id: 'permission_denied',
      value: const AsyncError<ChallengeCreateState>(
        ChallengeCreateFailure(ChallengeCreateFailureKind.permissionDenied),
        StackTrace.empty,
      ),
      beforeCapture: (tester) async {
        expect(find.text('Challenge creation unavailable'), findsOneWidget);
        expect(find.text('Refresh'), findsNothing);
      },
    );
  });

  testWidgets('golden Create challenge disabled state', (tester) async {
    await _pumpState(
      tester,
      id: 'disabled',
      value: AsyncData<ChallengeCreateState>(
        ChallengeCreateState(fixtures: _fixtures()),
      ),
      actionsEnabled: false,
      beforeCapture: (tester) async {
        expect(find.text('Challenge creation unavailable'), findsOneWidget);
      },
    );
  });

  testWidgets('golden Create challenge focused state', (tester) async {
    final focusNode = FocusNode(debugLabel: 'challenge-create-focus');
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
      value: AsyncData<ChallengeCreateState>(
        ChallengeCreateState(fixtures: _fixtures()),
      ),
      createFocusNode: focusNode,
      beforeCapture: (tester) async {
        final action = find.byKey(
          const ValueKey<String>('challenge-create-action'),
        );
        await _reveal(tester, action);
        focusNode.requestFocus();
        await tester.pumpAndSettle();
        expect(focusNode.hasFocus, isTrue);
      },
    );
  });

  testWidgets('golden Create challenge pressed state', (tester) async {
    TestGesture? heldGesture;
    await _pumpState(
      tester,
      id: 'pressed',
      value: AsyncData<ChallengeCreateState>(
        ChallengeCreateState(fixtures: _fixtures()),
      ),
      beforeCapture: (tester) async {
        final action = find.byKey(
          const ValueKey<String>('challenge-create-action'),
        );
        await _reveal(tester, action);
        heldGesture = await tester.press(action);
        await tester.pump(const Duration(milliseconds: 120));
        await tester.pump(const Duration(milliseconds: 100));
        final scales = tester
            .widgetList<ScaleTransition>(
              find.descendant(
                of: action,
                matching: find.byType(ScaleTransition),
              ),
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

  testWidgets('golden Create challenge selected score state', (tester) async {
    await _pumpState(
      tester,
      id: 'selected',
      value: AsyncData<ChallengeCreateState>(
        ChallengeCreateState(fixtures: _fixtures()),
      ),
      beforeCapture: (tester) async {
        final increase = find.byTooltip('Increase RAY');
        await tester.tap(increase);
        await tester.pumpAndSettle();
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.selected == true &&
                widget.properties.label == 'Selected exact score 3 to 1',
          ),
          findsOneWidget,
        );
      },
    );
  });

  testWidgets('golden Create challenge large-text state', (tester) async {
    await _pumpState(
      tester,
      id: 'large_text',
      value: AsyncData<ChallengeCreateState>(
        ChallengeCreateState(fixtures: _fixtures()),
      ),
      size: const Size(320, 720),
      textScale: 2,
      beforeCapture: (tester) async {
        await _reveal(
          tester,
          find.byKey(const ValueKey<String>('challenge-create-action')),
          alignment: 0.86,
        );
      },
    );
  });

  testWidgets('golden Create challenge reduced-motion state', (tester) async {
    await _pumpState(
      tester,
      id: 'reduced_motion',
      value: AsyncData<ChallengeCreateState>(
        ChallengeCreateState(fixtures: _fixtures()),
      ),
      reducedMotion: true,
      beforeCapture: (tester) async {
        expect(
          MediaQuery.disableAnimationsOf(
            tester.element(find.byType(CreateChallengeScreen)),
          ),
          isTrue,
        );
      },
    );
  });

  testWidgets('golden Create challenge dark state', (tester) async {
    await _pumpState(
      tester,
      id: 'dark',
      value: AsyncData<ChallengeCreateState>(
        ChallengeCreateState(fixtures: _fixtures()),
      ),
    );
  });

  testWidgets('golden Create challenge light state', (tester) async {
    await _pumpState(
      tester,
      id: 'light',
      value: AsyncData<ChallengeCreateState>(
        ChallengeCreateState(fixtures: _fixtures()),
      ),
      brightness: Brightness.light,
    );
  });

  testWidgets('golden Create challenge syncing state', (tester) async {
    await _pumpState(
      tester,
      id: 'syncing',
      value: AsyncData<ChallengeCreateState>(
        ChallengeCreateState(
          fixtures: _fixtures(),
          phase: ChallengeCreatePhase.syncing,
        ),
      ),
      settle: false,
      beforeCapture: (tester) async {
        expect(find.text('Creating challenge'), findsOneWidget);
      },
    );
  });

  testWidgets('golden Create challenge conflict state', (tester) async {
    await _pumpState(
      tester,
      id: 'conflict',
      value: AsyncData<ChallengeCreateState>(
        ChallengeCreateState(
          fixtures: _fixtures(),
          phase: ChallengeCreatePhase.degraded,
          failure: const ChallengeCreateFailure(
            ChallengeCreateFailureKind.conflict,
          ),
        ),
      ),
      beforeCapture: (tester) async {
        expect(find.text('Challenge details changed'), findsOneWidget);
        expect(find.text('REFRESH FIXTURES'), findsOneWidget);
      },
    );
  });

  testWidgets('golden Create challenge security-timeout state', (tester) async {
    await _pumpState(
      tester,
      id: 'security_timeout',
      value: AsyncData<ChallengeCreateState>(
        ChallengeCreateState(
          fixtures: _fixtures(),
          phase: ChallengeCreatePhase.degraded,
          failure: const ChallengeCreateFailure(
            ChallengeCreateFailureKind.securityTimeout,
          ),
        ),
      ),
      beforeCapture: (tester) async {
        expect(find.text('Challenge security check timed out'), findsOneWidget);
        expect(
          find.text('No challenge was confirmed. Refresh before trying again.'),
          findsOneWidget,
        );
      },
    );
  });
}

GoRouter _router({FocusNode? createFocusNode}) {
  return GoRouter(
    initialLocation: '/challenge/create',
    routes: <RouteBase>[
      GoRoute(
        path: '/challenge/create',
        builder: (context, state) => RepaintBoundary(
          key: const ValueKey<String>('challenge-create-state-golden'),
          child: CreateChallengeScreen(createFocusNode: createFocusNode),
        ),
      ),
      GoRoute(
        path: '/challenge/:id',
        builder: (context, state) => const SizedBox.shrink(),
      ),
    ],
  );
}

Finder _routeScrollable() {
  return find
      .descendant(
        of: find.byKey(const ValueKey<String>('challenge-create-scroll-view')),
        matching: find.byType(Scrollable),
      )
      .first;
}

Future<void> _reveal(
  WidgetTester tester,
  Finder target, {
  double alignment = 0.78,
}) async {
  final scrollable = tester.state<ScrollableState>(_routeScrollable());
  for (var attempt = 0; attempt < 20 && target.evaluate().isEmpty; attempt++) {
    final nextOffset = (scrollable.position.pixels + 300).clamp(
      scrollable.position.minScrollExtent,
      scrollable.position.maxScrollExtent,
    );
    scrollable.position.jumpTo(nextOffset);
    await tester.pump();
    if (nextOffset == scrollable.position.maxScrollExtent) break;
  }
  expect(target, findsOneWidget);
  await Scrollable.ensureVisible(
    tester.element(target),
    alignment: alignment,
    duration: Duration.zero,
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpState(
  WidgetTester tester, {
  required String id,
  required AsyncValue<ChallengeCreateState> value,
  Size size = const Size(390, 844),
  double textScale = 1,
  Brightness brightness = Brightness.dark,
  bool reducedMotion = false,
  bool online = true,
  bool actionsEnabled = true,
  bool settle = true,
  FocusNode? createFocusNode,
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

  final controller = _ControlledChallengeCreateController(value);
  final walletRepository = FakeFetRepository()
    ..wallet = buildWallet(balance: 8000);
  final router = _router(createFocusNode: createFocusNode);
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        challengeCreateProvider.overrideWith((ref) => controller),
        challengeCreateActionsEnabledProvider.overrideWithValue(actionsEnabled),
        fetRepositoryProvider.overrideWithValue(walletRepository),
        initialFeatureConfigSnapshotProvider.overrideWithValue(_stakeConfig),
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

  final routeScrollView = find.byKey(
    const ValueKey<String>('challenge-create-scroll-view'),
  );
  if (routeScrollView.evaluate().isNotEmpty) {
    tester.state<ScrollableState>(_routeScrollable()).position.jumpTo(0);
    await tester.pump();
  }

  await beforeCapture?.call(tester);
  expect(tester.takeException(), isNull);
  final goldenPath = _goldenPaths[id];
  expect(goldenPath, isNotNull, reason: 'Missing create golden for $id.');
  await expectLater(
    find.byKey(const ValueKey<String>('challenge-create-state-golden')),
    matchesGoldenFile(goldenPath!),
  );
  await afterCapture?.call(tester);
}
