import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_admin/feat_admin.dart';
import 'package:feat_admin/src/screens/challenge_ops_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:test_support/app_font_loader.dart';

const _goldenViewport = Size(390, 844);
const _goldenViewportId = '390x844';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);

  setUp(() {
    ConnectivityService.setOnlineForTest(true);
    TypographyTokens.debugUseFallbackFonts = true;
  });
  tearDown(() {
    ConnectivityService.setOnlineForTest(true);
    TypographyTokens.debugUseFallbackFonts = false;
    ColorTokens.setBrightness(Brightness.dark);
  });

  testWidgets('renders a truthful loading state', (tester) async {
    final pending = Completer<List<AdminChallengeItem>>();
    await _pumpChallenges(
      tester,
      gateway: _Gateway(loadOutcomes: <Object>[pending.future]),
      settle: false,
    );

    expect(find.text('Loading challenge operations'), findsOneWidget);
    expect(find.text('2400 FET'), findsNothing);
    await _expectStateGolden(tester, 'loading');
    pending.complete(_lockedItems);
    await tester.pumpAndSettle();
  });

  testWidgets('renders a confirmed empty queue', (tester) async {
    await _pumpChallenges(
      tester,
      gateway: _Gateway(loadOutcomes: const <Object>[<AdminChallengeItem>[]]),
    );

    expect(find.text('No challenge operations'), findsOneWidget);
    expect(find.textContaining('currently queued'), findsOneWidget);
    await _expectStateGolden(tester, 'empty');
  });

  testWidgets('renders a privacy-safe unknown error', (tester) async {
    await _pumpChallenges(
      tester,
      gateway: _Gateway(
        loadOutcomes: <Object>[
          StateError('provider row private-account-991 failed'),
        ],
      ),
    );

    expect(find.text('Challenge operations unavailable'), findsOneWidget);
    expect(find.textContaining('private-account-991'), findsNothing);
    expect(find.text('2400 FET'), findsNothing);
    await _expectStateGolden(tester, 'error');
  });

  testWidgets('renders offline without private challenge data', (tester) async {
    await _pumpChallenges(
      tester,
      gateway: _Gateway(loadOutcomes: <Object>[_lockedItems]),
      online: false,
    );

    expect(find.text('Challenge operations offline'), findsOneWidget);
    expect(find.text('2400 FET'), findsNothing);
    await _expectStateGolden(tester, 'offline');
  });

  testWidgets('permission denial clears all challenge data and actions', (
    tester,
  ) async {
    await _pumpChallenges(
      tester,
      gateway: _Gateway(
        loadOutcomes: const <Object>[
          AdminChallengesFailure(AdminChallengesFailureKind.permissionDenied),
        ],
      ),
    );

    expect(find.text('Challenge access unavailable'), findsOneWidget);
    expect(find.text('2400 FET'), findsNothing);
    expect(find.text('RETRY SETTLEMENT'), findsNothing);
    await _expectStateGolden(tester, 'permission_denied');
  });

  testWidgets('renders the feature-disabled state', (tester) async {
    await _pumpChallenges(
      tester,
      gateway: _Gateway(loadOutcomes: <Object>[_lockedItems]),
      enabled: false,
    );

    expect(find.text('Challenge operations unavailable'), findsOneWidget);
    expect(
      find.textContaining('disabled for this controlled build'),
      findsOneWidget,
    );
    expect(find.text('2400 FET'), findsNothing);
    await _expectStateGolden(tester, 'disabled');
  });

  testWidgets('renders confirmed challenge operations and retry control', (
    tester,
  ) async {
    await _pumpChallenges(
      tester,
      gateway: _Gateway(loadOutcomes: <Object>[_lockedItems]),
    );

    expect(find.text('Rayon vs Police'), findsOneWidget);
    expect(find.textContaining('2400 FET'), findsOneWidget);
    expect(find.text('RETRY SETTLEMENT'), findsOneWidget);
  });

  testWidgets('syncing retains confirmed items and pauses actions', (
    tester,
  ) async {
    final pending = Completer<List<AdminChallengeItem>>();
    final gateway = _Gateway(
      loadOutcomes: <Object>[_lockedItems, pending.future],
    );
    final container = await _pumpChallenges(tester, gateway: gateway);

    unawaited(container.read(adminChallengesProvider.notifier).refresh());
    await tester.pump();

    expect(find.text('Refreshing challenge operations'), findsOneWidget);
    expect(find.textContaining('2400 FET'), findsOneWidget);
    final button = tester.widget<AfriButton>(
      find.byKey(
        const ValueKey<String>(
          'admin-challenges-retry-11111111-1111-4111-8111-111111111111',
        ),
      ),
    );
    expect(button.enabled, isFalse);
    await _expectStateGolden(tester, 'syncing');
    pending.complete(_lockedItems);
    await tester.pumpAndSettle();
  });

  testWidgets('conflict retains confirmed items and recovery consequence', (
    tester,
  ) async {
    final gateway = _Gateway(
      loadOutcomes: <Object>[
        _lockedItems,
        const AdminChallengesFailure(AdminChallengesFailureKind.conflict),
      ],
    );
    final container = await _pumpChallenges(tester, gateway: gateway);

    await container.read(adminChallengesProvider.notifier).refresh();
    await tester.pump();

    expect(find.text('Challenge status changed'), findsOneWidget);
    expect(find.textContaining('2400 FET'), findsOneWidget);
    expect(find.textContaining('Actions are paused'), findsOneWidget);
    await _expectStateGolden(tester, 'conflict');
  });

  testWidgets('security timeout retains items and hides diagnostics', (
    tester,
  ) async {
    final gateway = _Gateway(
      loadOutcomes: <Object>[
        _lockedItems,
        TimeoutException('private-account-991 timed out'),
      ],
    );
    final container = await _pumpChallenges(tester, gateway: gateway);

    await container.read(adminChallengesProvider.notifier).refresh();
    await tester.pump();

    expect(find.text('Security check timed out'), findsOneWidget);
    expect(find.textContaining('2400 FET'), findsOneWidget);
    expect(find.textContaining('private-account-991'), findsNothing);
    await _expectStateGolden(tester, 'security_timeout');
  });

  testWidgets('selected filter exposes current selection semantics', (
    tester,
  ) async {
    final gateway = _Gateway(
      loadOutcomes: <Object>[_lockedItems, _settledItems],
    );
    final container = await _pumpChallenges(tester, gateway: gateway);

    await container
        .read(adminChallengesProvider.notifier)
        .selectFilter(AdminChallengeFilter.settled);
    await tester.pumpAndSettle();

    expect(find.text('SETTLED'), findsWidgets);
    final selectedChip = tester.widget<AfriChoiceChip>(
      find.widgetWithText(AfriChoiceChip, 'SETTLED'),
    );
    expect(selectedChip.selected, isTrue);
    await _expectStateGolden(tester, 'selected');
  });

  testWidgets('retry supports focus, held press, and keyboard activation', (
    tester,
  ) async {
    final focusNode = FocusNode(debugLabel: 'admin-challenge-retry');
    addTearDown(focusNode.dispose);
    final previousStrategy = FocusManager.instance.highlightStrategy;
    addTearDown(
      () => FocusManager.instance.highlightStrategy = previousStrategy,
    );
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    await _pumpChallenges(
      tester,
      gateway: _Gateway(loadOutcomes: <Object>[_lockedItems]),
      firstRetryFocusNode: focusNode,
    );
    final actionKey = find.byKey(
      const ValueKey<String>(
        'admin-challenges-retry-11111111-1111-4111-8111-111111111111',
      ),
    );
    final pressTarget = find.descendant(
      of: actionKey,
      matching: find.byType(AfriPressFeedback),
    );
    expect(pressTarget, findsOneWidget);
    expect(tester.widget<AfriButton>(actionKey).enabled, isTrue);
    expect(
      tester.widget<AfriPressFeedback>(pressTarget).semanticsLabel,
      'RETRY SETTLEMENT',
    );
    expect(tester.widget<AfriPressFeedback>(pressTarget).enabled, isTrue);

    final gestureTarget = find.descendant(
      of: pressTarget,
      matching: find.byType(GestureDetector),
    );
    expect(gestureTarget, findsOneWidget);
    final gesture = await tester.startGesture(tester.getCenter(gestureTarget));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 100));
    final scales = tester
        .widgetList<ScaleTransition>(
          find.descendant(
            of: actionKey,
            matching: find.byType(ScaleTransition),
          ),
        )
        .map((transition) => transition.scale.value);
    expect(scales.any((scale) => scale < 1), isTrue);
    await _expectStateGolden(tester, 'pressed');
    await gesture.cancel();
    await tester.pumpAndSettle();

    focusNode.requestFocus();
    await tester.pumpAndSettle();
    expect(focusNode.hasFocus, isTrue);
    await _expectStateGolden(tester, 'focused');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Retry settlement?'), findsOneWidget);
    await tester.tap(find.text('CANCEL'));
    await tester.pumpAndSettle();
  });

  testWidgets('supports 200 percent text without horizontal overflow', (
    tester,
  ) async {
    await _pumpChallenges(
      tester,
      gateway: _Gateway(loadOutcomes: <Object>[_lockedItems]),
      textScale: 2,
    );

    expect(tester.takeException(), isNull);
    final scrollable = tester.widget<Scrollable>(find.byType(Scrollable).first);
    expect(
      scrollable.axisDirection,
      anyOf(AxisDirection.down, AxisDirection.up),
    );
    await _expectStateGolden(tester, 'large_text');
  });

  testWidgets('respects reduced motion', (tester) async {
    await _pumpChallenges(
      tester,
      gateway: _Gateway(loadOutcomes: <Object>[_lockedItems]),
      reduceMotion: true,
    );

    final context = tester.element(find.byType(ChallengeOpsScreen));
    expect(AfriMotion.reduceMotion(context), isTrue);
    expect(tester.takeException(), isNull);
    await _expectStateGolden(tester, 'reduced_motion');
  });

  for (final brightness in <Brightness>[Brightness.dark, Brightness.light]) {
    testWidgets('renders the ${brightness.name} theme', (tester) async {
      await _pumpChallenges(
        tester,
        gateway: _Gateway(loadOutcomes: <Object>[_lockedItems]),
        brightness: brightness,
      );

      expect(find.text('CHALLENGE OPS'), findsOneWidget);
      expect(
        Theme.of(tester.element(find.byType(ChallengeOpsScreen))).brightness,
        brightness,
      );
      expect(tester.takeException(), isNull);
      await _expectStateGolden(tester, brightness.name);
    });
  }
}

Future<ProviderContainer> _pumpChallenges(
  WidgetTester tester, {
  required AdminChallengesGateway gateway,
  bool enabled = true,
  bool online = true,
  bool settle = true,
  bool reduceMotion = false,
  double textScale = 1,
  Brightness brightness = Brightness.dark,
  FocusNode? firstRetryFocusNode,
}) async {
  tester.view.physicalSize = _goldenViewport;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      FakeAccessibilityFeatures(
        disableAnimations: reduceMotion,
        accessibleNavigation: reduceMotion,
      );
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  ConnectivityService.setOnlineForTest(online);
  ColorTokens.setBrightness(brightness);

  final router = GoRouter(
    initialLocation: '/admin/challenges',
    routes: <RouteBase>[
      GoRoute(
        path: '/admin/challenges',
        builder: (_, _) =>
            ChallengeOpsScreen(firstRetryFocusNode: firstRetryFocusNode),
      ),
    ],
  );
  addTearDown(router.dispose);

  late ProviderContainer container;
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        adminChallengesGatewayProvider.overrideWithValue(gateway),
        adminChallengesEnabledProvider.overrideWithValue(enabled),
      ],
      child: Consumer(
        builder: (context, ref, child) {
          container = ProviderScope.containerOf(context);
          return ClubConfigScope(
            config: ClubConfig.fallback(),
            child: MaterialApp.router(
              debugShowCheckedModeBanner: false,
              builder: (context, child) {
                final mediaQuery = MediaQuery.of(context);
                return MediaQuery(
                  data: mediaQuery.copyWith(
                    disableAnimations: reduceMotion,
                    accessibleNavigation: reduceMotion,
                  ),
                  child: child!,
                );
              },
              theme: ClubTheme.from(
                ClubConfig.fallback(),
                brightness: brightness,
              ),
              routerConfig: router,
            ),
          );
        },
      ),
    ),
  );
  await tester.pump();
  if (settle) await tester.pumpAndSettle();
  return container;
}

Future<void> _expectStateGolden(WidgetTester tester, String id) async {
  final suffix = id == 'light' ? 'light' : 'dark';
  expect(tester.view.physicalSize, _goldenViewport);
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile(
      'goldens/admin_challenges_state_${id}_${suffix}_$_goldenViewportId.png',
    ),
  );
}

const _challengeId = '11111111-1111-4111-8111-111111111111';

const _lockedItems = <AdminChallengeItem>[
  AdminChallengeItem(
    id: _challengeId,
    competitionName: 'National League',
    homeTeam: 'Rayon',
    awayTeam: 'Police',
    creatorName: 'Synthetic operator',
    totalPoolFet: 2400,
    totalParticipants: 8,
    status: 'locked',
    settlementMode: 'Pending',
    settlementState: 'Pending',
    canRetrySettlement: true,
    hasVoidReason: false,
  ),
];

const _settledItems = <AdminChallengeItem>[
  AdminChallengeItem(
    id: '22222222-2222-4222-8222-222222222222',
    competitionName: 'National League',
    homeTeam: 'Rayon',
    awayTeam: 'Police',
    creatorName: 'Synthetic operator',
    totalPoolFet: 2400,
    totalParticipants: 8,
    status: 'settled',
    settlementMode: 'Exact score',
    settlementState: 'Recorded',
    canRetrySettlement: false,
    hasVoidReason: false,
  ),
];

class _Gateway implements AdminChallengesGateway {
  _Gateway({required this.loadOutcomes});

  final List<Object> loadOutcomes;
  int loadCount = 0;

  @override
  Future<List<AdminChallengeItem>> load(AdminChallengeFilter filter) async {
    final index = loadCount++;
    final outcome = loadOutcomes[index.clamp(0, loadOutcomes.length - 1)];
    if (outcome is Future<List<AdminChallengeItem>>) return outcome;
    if (outcome is List<AdminChallengeItem>) return outcome;
    throw outcome;
  }

  @override
  Future<AdminChallengeRetryResult> retrySettlement(String challengeId) async =>
      const AdminChallengeRetryResult(status: 'settled');
}
