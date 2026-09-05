import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_gamification/src/controllers/challenge_controller.dart';
import 'package:feat_gamification/src/models/challenge_models.dart';
import 'package:feat_gamification/src/screens/challenge_feed_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:test_support/app_font_loader.dart';

import 'challenge_test_helpers.dart';

const _goldenPaths = <String, String>{
  'loading': 'goldens/challenge_state_loading_dark_390x844.png',
  'empty': 'goldens/challenge_state_empty_dark_390x844.png',
  'error': 'goldens/challenge_state_error_dark_390x844.png',
  'offline': 'goldens/challenge_state_offline_dark_390x844.png',
  'permission_denied':
      'goldens/challenge_state_permission_denied_dark_390x844.png',
  'disabled': 'goldens/challenge_state_disabled_dark_390x844.png',
  'focused': 'goldens/challenge_state_focused_dark_390x844.png',
  'pressed': 'goldens/challenge_state_pressed_dark_390x844.png',
  'selected': 'goldens/challenge_state_selected_dark_390x844.png',
  'large_text': 'goldens/challenge_state_large_text_dark_320x720.png',
  'reduced_motion': 'goldens/challenge_state_reduced_motion_dark_390x844.png',
  'dark': 'goldens/challenge_state_dark_dark_390x844.png',
  'light': 'goldens/challenge_state_light_light_390x844.png',
  'syncing': 'goldens/challenge_state_syncing_dark_390x844.png',
  'conflict': 'goldens/challenge_state_conflict_dark_390x844.png',
  'security_timeout':
      'goldens/challenge_state_security_timeout_dark_390x844.png',
};

class _ControlledChallengeFeedController extends ChallengeFeedController {
  _ControlledChallengeFeedController(AsyncValue<ChallengeFeedState> value)
    : super(FakeChallengeRepository(), autoLoad: false) {
    state = value;
  }

  int refreshCount = 0;

  @override
  Future<void> refresh() async {
    refreshCount++;
  }
}

ChallengeFeedState _populatedFeed() {
  return ChallengeFeedState(
    featured: <Challenge>[
      buildChallenge(
        id: 'featured-challenge',
        fixture: buildFixture(
          id: 'featured-fixture',
          homeTeamShort: 'RAY',
          awayTeamShort: 'APR',
        ),
        totalParticipants: 18,
        totalPoolFet: 54000,
      ),
    ],
    open: <Challenge>[
      buildChallenge(
        id: 'open-challenge',
        fixture: buildFixture(
          id: 'open-fixture',
          homeTeamShort: 'KIY',
          awayTeamShort: 'MUS',
        ),
        totalParticipants: 7,
        totalPoolFet: 21000,
      ),
    ],
    mine: <Challenge>[
      buildChallenge(
        id: 'joined-challenge',
        fixture: buildFixture(
          id: 'joined-fixture',
          homeTeamShort: 'GAS',
          awayTeamShort: 'ETO',
        ),
        permissions: const ChallengePermissions(hasJoined: true),
        myEntry: buildEntry(
          challengeId: 'joined-challenge',
          userName: 'Current supporter',
        ),
      ),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);
  setUp(() => ConnectivityService.setOnlineForTest(true));

  testWidgets('golden Challenge route loading state', (tester) async {
    await _pumpState(
      tester,
      id: 'loading',
      value: const AsyncLoading<ChallengeFeedState>(),
      settle: false,
      beforeCapture: (tester) async {
        expect(find.text('Opening challenges'), findsOneWidget);
      },
    );
  });

  testWidgets('golden Challenge route empty state', (tester) async {
    await _pumpState(
      tester,
      id: 'empty',
      value: const AsyncData<ChallengeFeedState>(ChallengeFeedState()),
      beforeCapture: (tester) async {
        expect(find.text('No challenges available'), findsOneWidget);
      },
    );
  });

  testWidgets('golden Challenge route error state', (tester) async {
    await _pumpState(
      tester,
      id: 'error',
      value: const AsyncError<ChallengeFeedState>(
        ChallengeFeedFailure(ChallengeFeedFailureKind.unknown),
        StackTrace.empty,
      ),
      beforeCapture: (tester) async {
        expect(find.text('Challenge feed unavailable'), findsOneWidget);
        expect(find.textContaining('supporter-991'), findsNothing);
      },
    );
  });

  testWidgets('golden Challenge route offline state', (tester) async {
    await _pumpState(
      tester,
      id: 'offline',
      value: AsyncData<ChallengeFeedState>(_populatedFeed()),
      online: false,
      beforeCapture: (tester) async {
        expect(find.text('Showing saved challenges'), findsOneWidget);
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

  testWidgets('golden Challenge route permission-denied state', (tester) async {
    await _pumpState(
      tester,
      id: 'permission_denied',
      value: const AsyncError<ChallengeFeedState>(
        ChallengeFeedFailure(ChallengeFeedFailureKind.permissionDenied),
        StackTrace.empty,
      ),
      beforeCapture: (tester) async {
        expect(find.text('Challenge access unavailable'), findsOneWidget);
        expect(find.text('Retry'), findsNothing);
      },
    );
  });

  testWidgets('golden Challenge route disabled state', (tester) async {
    await _pumpState(
      tester,
      id: 'disabled',
      value: AsyncData<ChallengeFeedState>(_populatedFeed()),
      actionsEnabled: false,
      beforeCapture: (tester) async {
        expect(find.text('Challenge actions unavailable'), findsOneWidget);
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

  testWidgets('golden Challenge route focused state', (tester) async {
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
      value: AsyncData<ChallengeFeedState>(_populatedFeed()),
      createFocusNode: focusNode,
      beforeCapture: (tester) async {
        focusNode.requestFocus();
        await tester.pumpAndSettle();
        expect(focusNode.hasFocus, isTrue);
      },
    );
  });

  testWidgets('golden Challenge route pressed state', (tester) async {
    TestGesture? heldGesture;
    await _pumpState(
      tester,
      id: 'pressed',
      value: AsyncData<ChallengeFeedState>(_populatedFeed()),
      beforeCapture: (tester) async {
        final action = find.byKey(
          const ValueKey<String>('challenge-create-action'),
        );
        heldGesture = await tester.press(
          find.bySemanticsLabel('Create a new challenge'),
        );
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

  testWidgets('golden Challenge route selected state', (tester) async {
    await _pumpState(
      tester,
      id: 'selected',
      value: AsyncData<ChallengeFeedState>(_populatedFeed()),
      beforeCapture: (tester) async {
        await tester.tap(find.text('Open').first);
        await tester.pumpAndSettle();
        final selected = tester.widget<AfriChoiceChip>(
          find.ancestor(
            of: find.text('Open').first,
            matching: find.byType(AfriChoiceChip),
          ),
        );
        expect(selected.selected, isTrue);
        expect(
          tester
              .getSemantics(find.byType(ChoiceChip).at(1))
              .flagsCollection
              .isSelected
              .toBoolOrNull(),
          isTrue,
        );
      },
    );
  });

  testWidgets('golden Challenge route large-text state', (tester) async {
    await _pumpState(
      tester,
      id: 'large_text',
      value: AsyncData<ChallengeFeedState>(_populatedFeed()),
      size: const Size(320, 720),
      textScale: 2,
      beforeCapture: (tester) async {
        expect(
          find.text('Create a new challenge', findRichText: true),
          findsOneWidget,
        );
      },
    );
  });

  testWidgets('golden Challenge route reduced-motion state', (tester) async {
    await _pumpState(
      tester,
      id: 'reduced_motion',
      value: AsyncData<ChallengeFeedState>(_populatedFeed()),
      reducedMotion: true,
      beforeCapture: (tester) async {
        expect(
          MediaQuery.disableAnimationsOf(
            tester.element(find.byType(ChallengeFeedScreen)),
          ),
          isTrue,
        );
      },
    );
  });

  testWidgets('golden Challenge route dark state', (tester) async {
    await _pumpState(
      tester,
      id: 'dark',
      value: AsyncData<ChallengeFeedState>(_populatedFeed()),
    );
  });

  testWidgets('golden Challenge route light state', (tester) async {
    await _pumpState(
      tester,
      id: 'light',
      value: AsyncData<ChallengeFeedState>(_populatedFeed()),
      brightness: Brightness.light,
    );
  });

  testWidgets('golden Challenge route syncing state', (tester) async {
    final previous = AsyncData<ChallengeFeedState>(_populatedFeed());
    final refreshing = const AsyncLoading<ChallengeFeedState>()
        .copyWithPrevious(previous);
    await _pumpState(
      tester,
      id: 'syncing',
      value: refreshing,
      beforeCapture: (tester) async {
        expect(find.text('Refreshing challenges'), findsOneWidget);
        expect(find.text('RAY'), findsOneWidget);
      },
    );
  });

  testWidgets('golden Challenge route conflict state', (tester) async {
    await _pumpState(
      tester,
      id: 'conflict',
      value: const AsyncError<ChallengeFeedState>(
        ChallengeFeedFailure(ChallengeFeedFailureKind.conflict),
        StackTrace.empty,
      ),
      beforeCapture: (tester) async {
        expect(find.text('Challenge data changed'), findsOneWidget);
        expect(find.text('Refresh'), findsOneWidget);
      },
    );
  });

  testWidgets('golden Challenge route security-timeout state', (tester) async {
    await _pumpState(
      tester,
      id: 'security_timeout',
      value: const AsyncError<ChallengeFeedState>(
        ChallengeFeedFailure(ChallengeFeedFailureKind.securityTimeout),
        StackTrace.empty,
      ),
      beforeCapture: (tester) async {
        expect(find.text('Challenge security check timed out'), findsOneWidget);
        expect(find.text('Refresh'), findsOneWidget);
      },
    );
  });
}

Future<void> _pumpState(
  WidgetTester tester, {
  required String id,
  required AsyncValue<ChallengeFeedState> value,
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

  final controller = _ControlledChallengeFeedController(value);
  final router = GoRouter(
    initialLocation: '/challenge',
    routes: <RouteBase>[
      GoRoute(
        path: '/challenge',
        builder: (context, state) => RepaintBoundary(
          key: const ValueKey<String>('challenge-state-golden'),
          child: ChallengeFeedScreen(createFocusNode: createFocusNode),
        ),
      ),
      GoRoute(
        path: '/challenge/create',
        builder: (context, state) => const SizedBox.shrink(),
      ),
      GoRoute(
        path: '/challenge/my',
        builder: (context, state) => const SizedBox.shrink(),
      ),
      GoRoute(
        path: '/challenge/:id',
        builder: (context, state) => const SizedBox.shrink(),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        challengeFeedProvider.overrideWith((ref) => controller),
        challengeFeedActionsEnabledProvider.overrideWithValue(actionsEnabled),
      ],
      child: MaterialApp.router(
        builder: (context, child) {
          final mediaQuery = MediaQuery.of(context);
          return MediaQuery(
            data: mediaQuery.copyWith(disableAnimations: reducedMotion),
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

  final routeScrollable = find
      .descendant(
        of: find.byType(ChallengeFeedScreen),
        matching: find.byType(Scrollable),
      )
      .first;
  if (routeScrollable.evaluate().isNotEmpty) {
    tester.state<ScrollableState>(routeScrollable).position.jumpTo(0);
    await tester.pump();
  }

  await beforeCapture?.call(tester);

  expect(tester.takeException(), isNull);
  final goldenPath = _goldenPaths[id];
  expect(goldenPath, isNotNull, reason: 'Missing Challenge golden for $id.');
  await expectLater(
    find.byKey(const ValueKey<String>('challenge-state-golden')),
    matchesGoldenFile(goldenPath!),
  );
  await afterCapture?.call(tester);
}
