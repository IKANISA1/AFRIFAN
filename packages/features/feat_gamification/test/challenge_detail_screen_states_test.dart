import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_gamification/src/controllers/challenge_detail_controller.dart';
import 'package:feat_gamification/src/models/challenge_models.dart';
import 'package:feat_gamification/src/screens/challenge_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:test_support/app_font_loader.dart';

import 'challenge_test_helpers.dart';

const _goldenPaths = <String, String>{
  'loading': 'goldens/challenge_detail_state_loading_dark_390x844.png',
  'empty': 'goldens/challenge_detail_state_empty_dark_390x844.png',
  'error': 'goldens/challenge_detail_state_error_dark_390x844.png',
  'offline': 'goldens/challenge_detail_state_offline_dark_390x844.png',
  'permission_denied':
      'goldens/challenge_detail_state_permission_denied_dark_390x844.png',
  'disabled': 'goldens/challenge_detail_state_disabled_dark_390x844.png',
  'focused': 'goldens/challenge_detail_state_focused_dark_390x844.png',
  'pressed': 'goldens/challenge_detail_state_pressed_dark_390x844.png',
  'selected': 'goldens/challenge_detail_state_selected_dark_390x844.png',
  'large_text': 'goldens/challenge_detail_state_large_text_dark_320x720.png',
  'reduced_motion':
      'goldens/challenge_detail_state_reduced_motion_dark_390x844.png',
  'dark': 'goldens/challenge_detail_state_dark_dark_390x844.png',
  'light': 'goldens/challenge_detail_state_light_light_390x844.png',
  'syncing': 'goldens/challenge_detail_state_syncing_dark_390x844.png',
  'conflict': 'goldens/challenge_detail_state_conflict_dark_390x844.png',
  'security_timeout':
      'goldens/challenge_detail_state_security_timeout_dark_390x844.png',
};

class _ControlledChallengeDetailController extends ChallengeDetailController {
  _ControlledChallengeDetailController(AsyncValue<ChallengeDetailState> value)
    : super(FakeChallengeRepository(), 'detail-1', autoLoad: false) {
    state = value;
  }

  int refreshCount = 0;

  @override
  Future<void> refresh() async {
    refreshCount++;
  }
}

ChallengeDetailPayload _joinableDetail() {
  final challenge = buildChallenge(
    id: 'detail-1',
    fixture: buildFixture(
      id: 'detail-fixture',
      homeTeamShort: 'RAY',
      awayTeamShort: 'APR',
      competitionName: 'Rwanda Premier League',
    ),
    totalParticipants: 18,
    totalPoolFet: 54000,
    permissions: const ChallengePermissions(canJoin: true),
  );
  return buildDetail(
    challenge: challenge,
    entries: <ChallengeEntry>[
      buildEntry(
        id: 'creator-entry',
        challengeId: challenge.id,
        userId: challenge.creatorUserId,
        userName: challenge.creatorDisplayName,
      ),
      buildEntry(
        id: 'second-entry',
        challengeId: challenge.id,
        userId: 'supporter-2',
        userName: 'Eric Nshimiyimana',
        homeScore: 1,
        awayScore: 1,
      ),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);
  setUp(() => ConnectivityService.setOnlineForTest(true));

  testWidgets('Challenge detail refreshes automatically after reconnect', (
    tester,
  ) async {
    ConnectivityService.setOnlineForTest(false);
    addTearDown(() => ConnectivityService.setOnlineForTest(true));
    final controller = _ControlledChallengeDetailController(
      const AsyncError<ChallengeDetailState>(
        ChallengeDetailFailure(ChallengeDetailFailureKind.offline),
        StackTrace.empty,
      ),
    );
    final router = GoRouter(
      initialLocation: '/challenge/detail-1',
      routes: <RouteBase>[
        GoRoute(
          path: '/challenge/:id',
          builder: (context, state) =>
              const ChallengeDetailScreen(id: 'detail-1'),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          challengeDetailProvider.overrideWith((ref, id) => controller),
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
    expect(find.text('Challenge details offline'), findsOneWidget);

    ConnectivityService.setOnlineForTest(true);
    await tester.pumpAndSettle();

    expect(controller.refreshCount, 1);
    expect(find.text('Connection restored'), findsOneWidget);
  });

  testWidgets('golden Challenge detail loading state', (tester) async {
    await _pumpState(
      tester,
      id: 'loading',
      value: const AsyncLoading<ChallengeDetailState>(),
      settle: false,
      beforeCapture: (tester) async {
        expect(find.text('Opening challenge'), findsOneWidget);
      },
    );
  });

  testWidgets('golden Challenge detail empty state', (tester) async {
    await _pumpState(
      tester,
      id: 'empty',
      value: const AsyncData<ChallengeDetailState>(ChallengeDetailState()),
      beforeCapture: (tester) async {
        expect(find.text('Challenge not found'), findsOneWidget);
        expect(find.text('Back to challenges'), findsOneWidget);
      },
    );
  });

  testWidgets('golden Challenge detail error state', (tester) async {
    await _pumpState(
      tester,
      id: 'error',
      value: const AsyncError<ChallengeDetailState>(
        ChallengeDetailFailure(ChallengeDetailFailureKind.unknown),
        StackTrace.empty,
      ),
      beforeCapture: (tester) async {
        expect(find.text('Challenge unavailable'), findsOneWidget);
        expect(find.textContaining('supporter-991'), findsNothing);
      },
    );
  });

  testWidgets('golden Challenge detail offline state', (tester) async {
    await _pumpState(
      tester,
      id: 'offline',
      value: AsyncData<ChallengeDetailState>(
        ChallengeDetailState(payload: _joinableDetail()),
      ),
      online: false,
      beforeCapture: (tester) async {
        expect(find.text('Showing saved challenge'), findsOneWidget);
        expect(
          tester
              .widget<AfriButton>(
                find.byKey(
                  const ValueKey<String>('challenge-detail-join-action'),
                ),
              )
              .enabled,
          isFalse,
        );
      },
    );
  });

  testWidgets('golden Challenge detail permission-denied state', (
    tester,
  ) async {
    await _pumpState(
      tester,
      id: 'permission_denied',
      value: const AsyncError<ChallengeDetailState>(
        ChallengeDetailFailure(ChallengeDetailFailureKind.permissionDenied),
        StackTrace.empty,
      ),
      beforeCapture: (tester) async {
        expect(find.text('Challenge access unavailable'), findsOneWidget);
        expect(find.text('Refresh'), findsNothing);
      },
    );
  });

  testWidgets('golden Challenge detail disabled state', (tester) async {
    await _pumpState(
      tester,
      id: 'disabled',
      value: AsyncData<ChallengeDetailState>(
        ChallengeDetailState(payload: _joinableDetail()),
      ),
      actionsEnabled: false,
      beforeCapture: (tester) async {
        expect(find.text('Challenge actions unavailable'), findsOneWidget);
        expect(
          tester
              .widget<AfriButton>(
                find.byKey(
                  const ValueKey<String>('challenge-detail-join-action'),
                ),
              )
              .enabled,
          isFalse,
        );
      },
    );
  });

  testWidgets('golden Challenge detail focused state', (tester) async {
    final focusNode = FocusNode(debugLabel: 'challenge-detail-join-focus');
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
      value: AsyncData<ChallengeDetailState>(
        ChallengeDetailState(payload: _joinableDetail()),
      ),
      joinFocusNode: focusNode,
      beforeCapture: (tester) async {
        final action = find.byKey(
          const ValueKey<String>('challenge-detail-join-action'),
        );
        await tester.scrollUntilVisible(
          action,
          220,
          scrollable: _routeScrollable(),
        );
        focusNode.requestFocus();
        await tester.pumpAndSettle();
        expect(focusNode.hasFocus, isTrue);
      },
    );
  });

  testWidgets('golden Challenge detail pressed state', (tester) async {
    TestGesture? heldGesture;
    await _pumpState(
      tester,
      id: 'pressed',
      value: AsyncData<ChallengeDetailState>(
        ChallengeDetailState(payload: _joinableDetail()),
      ),
      beforeCapture: (tester) async {
        final action = find.byKey(
          const ValueKey<String>('challenge-detail-join-action'),
        );
        await tester.scrollUntilVisible(
          action,
          220,
          scrollable: _routeScrollable(),
        );
        heldGesture = await tester.press(
          find.bySemanticsLabel('Join with 3000 pts'),
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

  testWidgets('golden Challenge detail selected score state', (tester) async {
    await _pumpState(
      tester,
      id: 'selected',
      value: AsyncData<ChallengeDetailState>(
        ChallengeDetailState(payload: _joinableDetail()),
      ),
      beforeCapture: (tester) async {
        final increase = find.byTooltip('Increase RAY');
        await tester.scrollUntilVisible(
          increase,
          220,
          scrollable: _routeScrollable(),
        );
        await tester.tap(increase);
        await tester.pumpAndSettle();
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.selected == true &&
                widget.properties.label == 'Selected exact score 2 to 0',
          ),
          findsOneWidget,
        );
      },
    );
  });

  testWidgets('golden Challenge detail large-text state', (tester) async {
    await _pumpState(
      tester,
      id: 'large_text',
      value: AsyncData<ChallengeDetailState>(
        ChallengeDetailState(payload: _joinableDetail()),
      ),
      size: const Size(320, 720),
      textScale: 2,
      beforeCapture: (tester) async {
        final action = find.byKey(
          const ValueKey<String>('challenge-detail-join-action'),
        );
        final scrollable = tester.state<ScrollableState>(_routeScrollable());
        for (
          var attempt = 0;
          attempt < 20 && action.evaluate().isEmpty;
          attempt++
        ) {
          final nextOffset = (scrollable.position.pixels + 300).clamp(
            scrollable.position.minScrollExtent,
            scrollable.position.maxScrollExtent,
          );
          scrollable.position.jumpTo(nextOffset);
          await tester.pump();
          if (nextOffset == scrollable.position.maxScrollExtent) {
            break;
          }
        }
        expect(action, findsOneWidget);
        await Scrollable.ensureVisible(
          tester.element(action),
          alignment: 0.86,
          duration: Duration.zero,
        );
        await tester.pumpAndSettle();
      },
    );
  });

  testWidgets('golden Challenge detail reduced-motion state', (tester) async {
    await _pumpState(
      tester,
      id: 'reduced_motion',
      value: AsyncData<ChallengeDetailState>(
        ChallengeDetailState(payload: _joinableDetail()),
      ),
      reducedMotion: true,
      beforeCapture: (tester) async {
        expect(
          MediaQuery.disableAnimationsOf(
            tester.element(find.byType(ChallengeDetailScreen)),
          ),
          isTrue,
        );
      },
    );
  });

  testWidgets('golden Challenge detail dark state', (tester) async {
    await _pumpState(
      tester,
      id: 'dark',
      value: AsyncData<ChallengeDetailState>(
        ChallengeDetailState(payload: _joinableDetail()),
      ),
    );
  });

  testWidgets('golden Challenge detail light state', (tester) async {
    await _pumpState(
      tester,
      id: 'light',
      value: AsyncData<ChallengeDetailState>(
        ChallengeDetailState(payload: _joinableDetail()),
      ),
      brightness: Brightness.light,
    );
  });

  testWidgets('golden Challenge detail syncing state', (tester) async {
    await _pumpState(
      tester,
      id: 'syncing',
      value: AsyncData<ChallengeDetailState>(
        ChallengeDetailState(
          payload: _joinableDetail(),
          phase: ChallengeDetailPhase.syncing,
          mutation: ChallengeDetailMutation.joining,
        ),
      ),
      settle: false,
      beforeCapture: (tester) async {
        expect(find.text('Joining challenge'), findsNWidgets(2));
        expect(find.text('RAY'), findsWidgets);
      },
    );
  });

  testWidgets('golden Challenge detail conflict state', (tester) async {
    await _pumpState(
      tester,
      id: 'conflict',
      value: AsyncData<ChallengeDetailState>(
        ChallengeDetailState(
          payload: _joinableDetail(),
          phase: ChallengeDetailPhase.degraded,
          failure: const ChallengeDetailFailure(
            ChallengeDetailFailureKind.conflict,
          ),
        ),
      ),
      beforeCapture: (tester) async {
        expect(find.text('Challenge data changed'), findsOneWidget);
        expect(find.text('Refresh challenge'), findsOneWidget);
        expect(find.text('RAY'), findsWidgets);
      },
    );
  });

  testWidgets('golden Challenge detail security-timeout state', (tester) async {
    await _pumpState(
      tester,
      id: 'security_timeout',
      value: AsyncData<ChallengeDetailState>(
        ChallengeDetailState(
          payload: _joinableDetail(),
          phase: ChallengeDetailPhase.degraded,
          failure: const ChallengeDetailFailure(
            ChallengeDetailFailureKind.securityTimeout,
          ),
        ),
      ),
      beforeCapture: (tester) async {
        expect(find.text('Challenge security check timed out'), findsOneWidget);
        expect(
          find.text(
            'No challenge action was confirmed. Refresh before trying again.',
          ),
          findsOneWidget,
        );
      },
    );
  });
}

Finder _routeScrollable() {
  return find
      .descendant(
        of: find.byKey(const ValueKey<String>('challenge-detail-scroll-view')),
        matching: find.byType(Scrollable),
      )
      .first;
}

Future<void> _pumpState(
  WidgetTester tester, {
  required String id,
  required AsyncValue<ChallengeDetailState> value,
  Size size = const Size(390, 844),
  double textScale = 1,
  Brightness brightness = Brightness.dark,
  bool reducedMotion = false,
  bool online = true,
  bool actionsEnabled = true,
  bool settle = true,
  FocusNode? joinFocusNode,
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

  final controller = _ControlledChallengeDetailController(value);
  final router = GoRouter(
    initialLocation: '/challenge/detail-1',
    routes: <RouteBase>[
      GoRoute(
        path: '/challenge',
        builder: (context, state) => const SizedBox.shrink(),
      ),
      GoRoute(
        path: '/challenge/:id',
        builder: (context, state) => RepaintBoundary(
          key: const ValueKey<String>('challenge-detail-state-golden'),
          child: ChallengeDetailScreen(
            id: state.pathParameters['id'] ?? '',
            joinFocusNode: joinFocusNode,
          ),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        challengeDetailProvider.overrideWith((ref, id) => controller),
        challengeDetailActionsEnabledProvider.overrideWithValue(actionsEnabled),
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
    const ValueKey<String>('challenge-detail-scroll-view'),
  );
  if (routeScrollView.evaluate().isNotEmpty) {
    tester.state<ScrollableState>(_routeScrollable()).position.jumpTo(0);
    await tester.pump();
  }

  await beforeCapture?.call(tester);

  expect(tester.takeException(), isNull);
  final goldenPath = _goldenPaths[id];
  expect(goldenPath, isNotNull, reason: 'Missing detail golden for $id.');
  await expectLater(
    find.byKey(const ValueKey<String>('challenge-detail-state-golden')),
    matchesGoldenFile(goldenPath!),
  );
  await afterCapture?.call(tester);
}
