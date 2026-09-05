import 'package:club_data/club_data.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:feat_contributions/src/controllers/group_detail_controller.dart';
import 'package:feat_contributions/src/screens/group_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:test_support/app_font_loader.dart';

const _groupId = 'initiative-1';

const _goldenPaths = <String, String>{
  'loading': 'goldens/group_detail_state_loading_dark_390x844.png',
  'empty': 'goldens/group_detail_state_empty_dark_390x844.png',
  'error': 'goldens/group_detail_state_error_dark_390x844.png',
  'offline': 'goldens/group_detail_state_offline_dark_390x844.png',
  'permission_denied':
      'goldens/group_detail_state_permission_denied_dark_390x844.png',
  'disabled': 'goldens/group_detail_state_disabled_dark_390x844.png',
  'focused': 'goldens/group_detail_state_focused_dark_390x844.png',
  'pressed': 'goldens/group_detail_state_pressed_dark_390x844.png',
  'selected': 'goldens/group_detail_state_selected_dark_390x844.png',
  'large_text': 'goldens/group_detail_state_large_text_dark_320x720.png',
  'reduced_motion':
      'goldens/group_detail_state_reduced_motion_dark_390x844.png',
  'dark': 'goldens/group_detail_state_dark_dark_390x844.png',
  'light': 'goldens/group_detail_state_light_light_390x844.png',
  'syncing': 'goldens/group_detail_state_syncing_dark_390x844.png',
  'conflict': 'goldens/group_detail_state_conflict_dark_390x844.png',
  'security_timeout':
      'goldens/group_detail_state_security_timeout_dark_390x844.png',
};

class _NoopGroupDetailGateway implements GroupDetailGateway {
  @override
  Future<GroupDetailSnapshot?> load(String groupId) async => _snapshot();
}

class _ControlledGroupDetailController extends GroupDetailController {
  _ControlledGroupDetailController(AsyncValue<GroupDetailState> value)
    : super(_NoopGroupDetailGateway(), groupId: _groupId, autoLoad: false) {
    state = value;
  }

  int refreshCount = 0;

  @override
  Future<void> refresh() async {
    refreshCount++;
  }
}

ContributionGroup _initiative() {
  return ContributionGroup(
    id: _groupId,
    creatorId: 'club-admin',
    name: 'Rayon Sports Supporters Away Day Travel Initiative',
    description:
        'Help supporters travel safely to the next away fixture while keeping the public ledger transparent.',
    groupType: ContributionGroupType.project,
    targetAmount: 1000000,
    currentTotal: 640000,
    paymentRecipient: '123456',
    memberCount: 86,
    createdAt: DateTime.utc(2026, 7, 1),
  );
}

GroupDetailSnapshot _snapshot() {
  return GroupDetailSnapshot(
    group: _initiative(),
    ledger: <GroupLedgerEntry>[
      GroupLedgerEntry(
        publicAlias: '#FAN2048',
        amount: 25000,
        status: GroupLedgerStatus.confirmed,
        createdAt: DateTime.utc(2026, 7, 18),
      ),
      GroupLedgerEntry(
        publicAlias: '#BLUEARMY',
        amount: 10000,
        status: GroupLedgerStatus.processing,
        createdAt: DateTime.utc(2026, 7, 17),
      ),
    ],
  );
}

GroupDetailState _populatedState({
  GroupDetailPhase phase = GroupDetailPhase.ready,
  GroupDetailFailure? failure,
}) {
  return GroupDetailState(
    snapshot: _snapshot(),
    phase: phase,
    failure: failure,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);
  setUp(() => ConnectivityService.setOnlineForTest(true));

  testWidgets('group detail refreshes automatically after reconnect', (
    tester,
  ) async {
    ConnectivityService.setOnlineForTest(false);
    addTearDown(() => ConnectivityService.setOnlineForTest(true));
    final controller = _ControlledGroupDetailController(
      const AsyncError<GroupDetailState>(
        GroupDetailFailure(GroupDetailFailureKind.offline),
        StackTrace.empty,
      ),
    );
    final router = _router(stateKey: 'reconnect');
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          groupDetailProvider(_groupId).overrideWith((ref) => controller),
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
    expect(find.text('Initiative offline'), findsOneWidget);

    ConnectivityService.setOnlineForTest(true);
    await tester.pumpAndSettle();

    expect(controller.refreshCount, 1);
    expect(find.text('Connection restored'), findsOneWidget);
  });

  testWidgets('golden group detail loading state', (tester) async {
    await _pumpState(
      tester,
      id: 'loading',
      value: const AsyncLoading<GroupDetailState>(),
      settle: false,
      beforeCapture: (tester) async {
        expect(find.text('Loading public initiative'), findsOneWidget);
      },
    );
  });

  testWidgets('golden group detail empty state', (tester) async {
    await _pumpState(
      tester,
      id: 'empty',
      value: const AsyncError<GroupDetailState>(
        GroupDetailFailure(GroupDetailFailureKind.notFound),
        StackTrace.empty,
      ),
      beforeCapture: (tester) async {
        expect(find.text('Initiative not found'), findsOneWidget);
        expect(find.text('Back to communities'), findsOneWidget);
      },
    );
  });

  testWidgets('golden group detail error state', (tester) async {
    await _pumpState(
      tester,
      id: 'error',
      value: const AsyncError<GroupDetailState>(
        GroupDetailFailure(GroupDetailFailureKind.unknown),
        StackTrace.empty,
      ),
      beforeCapture: (tester) async {
        expect(find.text('Initiative unavailable'), findsOneWidget);
        expect(find.textContaining('supporter-991'), findsNothing);
      },
    );
  });

  testWidgets('golden group detail offline state', (tester) async {
    await _pumpState(
      tester,
      id: 'offline',
      value: AsyncData<GroupDetailState>(_populatedState()),
      online: false,
      beforeCapture: (tester) async {
        expect(find.text('Showing saved initiative data'), findsOneWidget);
        expect(
          tester
              .widget<AfriButton>(
                find.byKey(
                  const ValueKey<String>('group-detail-contribute-action'),
                ),
              )
              .enabled,
          isFalse,
        );
      },
    );
  });

  testWidgets('golden group detail permission-denied state', (tester) async {
    await _pumpState(
      tester,
      id: 'permission_denied',
      value: const AsyncError<GroupDetailState>(
        GroupDetailFailure(GroupDetailFailureKind.permissionDenied),
        StackTrace.empty,
      ),
      beforeCapture: (tester) async {
        expect(find.text('Initiative unavailable'), findsOneWidget);
        expect(find.text('Refresh'), findsNothing);
      },
    );
  });

  testWidgets('golden group detail disabled state', (tester) async {
    await _pumpState(
      tester,
      id: 'disabled',
      value: AsyncData<GroupDetailState>(_populatedState()),
      actionsEnabled: false,
      beforeCapture: (tester) async {
        expect(find.text('Contributions are read-only'), findsOneWidget);
        expect(find.text('Contributions disabled'), findsOneWidget);
      },
    );
  });

  testWidgets('golden group detail focused state', (tester) async {
    final focusNode = FocusNode(debugLabel: 'group-detail-contribute-focus');
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
      value: AsyncData<GroupDetailState>(_populatedState()),
      primaryActionFocusNode: focusNode,
      beforeCapture: (tester) async {
        focusNode.requestFocus();
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const ValueKey<String>('group-detail-contribute-action')),
        );
        await tester.pumpAndSettle();
        expect(focusNode.hasFocus, isTrue);
      },
      afterCapture: (tester) async {
        focusNode.unfocus();
        await tester.pumpAndSettle();
      },
    );
  });

  testWidgets('golden group detail pressed state', (tester) async {
    TestGesture? heldGesture;
    await _pumpState(
      tester,
      id: 'pressed',
      value: AsyncData<GroupDetailState>(_populatedState()),
      beforeCapture: (tester) async {
        final action = find.byKey(
          const ValueKey<String>('group-detail-contribute-action'),
        );
        await tester.ensureVisible(action);
        await tester.pumpAndSettle();
        final feedback = find.descendant(
          of: action,
          matching: find.byType(AfriPressFeedback),
        );
        heldGesture = await tester.press(feedback);
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

  testWidgets('golden group detail selected amount state', (tester) async {
    await _pumpState(
      tester,
      id: 'selected',
      value: AsyncData<GroupDetailState>(_populatedState()),
      beforeCapture: (tester) async {
        final action = find.byKey(
          const ValueKey<String>('group-detail-contribute-action'),
        );
        await tester.ensureVisible(action);
        await tester.tap(action);
        await tester.pumpAndSettle();
        await tester.tap(find.text('+10K'));
        await tester.pumpAndSettle();
        expect(find.text('RWF 10,000'), findsWidgets);
        expect(
          tester
              .widgetList<Semantics>(find.byType(Semantics))
              .any((widget) => widget.properties.selected == true),
          isTrue,
        );
      },
      afterCapture: (tester) async {
        Navigator.of(
          tester.element(find.text('HOW MUCH TO CONTRIBUTE?')),
        ).pop();
        await tester.pumpAndSettle();
      },
    );
  });

  testWidgets('golden group detail large-text state', (tester) async {
    await _pumpState(
      tester,
      id: 'large_text',
      value: AsyncData<GroupDetailState>(_populatedState()),
      size: const Size(320, 720),
      textScale: 2,
      beforeCapture: (tester) async {
        expect(
          find.text('Rayon Sports Supporters Away Day Travel Initiative'),
          findsOneWidget,
        );
        final action = find.byKey(
          const ValueKey<String>('group-detail-contribute-action'),
        );
        await tester.ensureVisible(action);
        await tester.pumpAndSettle();
        expect(find.text('Contribute now'), findsOneWidget);
      },
    );
  });

  testWidgets('golden group detail reduced-motion state', (tester) async {
    await _pumpState(
      tester,
      id: 'reduced_motion',
      value: AsyncData<GroupDetailState>(_populatedState()),
      reducedMotion: true,
      beforeCapture: (tester) async {
        expect(
          MediaQuery.disableAnimationsOf(
            tester.element(find.byType(GroupDetailScreen)),
          ),
          isTrue,
        );
      },
    );
  });

  testWidgets('golden group detail dark state', (tester) async {
    await _pumpState(
      tester,
      id: 'dark',
      value: AsyncData<GroupDetailState>(_populatedState()),
    );
  });

  testWidgets('golden group detail light state', (tester) async {
    await _pumpState(
      tester,
      id: 'light',
      value: AsyncData<GroupDetailState>(_populatedState()),
      brightness: Brightness.light,
    );
  });

  testWidgets('golden group detail syncing state', (tester) async {
    await _pumpState(
      tester,
      id: 'syncing',
      value: AsyncData<GroupDetailState>(
        _populatedState(phase: GroupDetailPhase.syncing),
      ),
      beforeCapture: (tester) async {
        expect(find.text('Refreshing initiative'), findsOneWidget);
        expect(find.text('Checking latest total'), findsOneWidget);
      },
    );
  });

  testWidgets('golden group detail conflict state', (tester) async {
    await _pumpState(
      tester,
      id: 'conflict',
      value: AsyncData<GroupDetailState>(
        _populatedState(
          phase: GroupDetailPhase.degraded,
          failure: const GroupDetailFailure(GroupDetailFailureKind.conflict),
        ),
      ),
      beforeCapture: (tester) async {
        expect(find.text('Initiative changed'), findsOneWidget);
        expect(find.text('REFRESH INITIATIVE'), findsOneWidget);
      },
    );
  });

  testWidgets('golden group detail security-timeout state', (tester) async {
    await _pumpState(
      tester,
      id: 'security_timeout',
      value: AsyncData<GroupDetailState>(
        _populatedState(
          phase: GroupDetailPhase.degraded,
          failure: const GroupDetailFailure(
            GroupDetailFailureKind.securityTimeout,
          ),
        ),
      ),
      beforeCapture: (tester) async {
        expect(find.text('Initiative check timed out'), findsOneWidget);
        expect(find.text('Refresh before contributing'), findsOneWidget);
      },
    );
  });
}

GoRouter _router({
  FocusNode? primaryActionFocusNode,
  required String stateKey,
}) {
  return GoRouter(
    initialLocation: '/contribute/group/$_groupId',
    routes: <RouteBase>[
      GoRoute(
        path: '/contribute/group/:groupId',
        builder: (context, state) => RepaintBoundary(
          key: const ValueKey<String>('group-detail-state-golden'),
          child: GroupDetailScreen(
            key: ValueKey<String>('group-detail-screen-$stateKey'),
            groupId: state.pathParameters['groupId']!,
            primaryActionFocusNode: primaryActionFocusNode,
          ),
        ),
      ),
      GoRoute(
        path: '/contribute/groups',
        builder: (context, state) => const SizedBox.shrink(),
      ),
    ],
  );
}

Future<void> _pumpState(
  WidgetTester tester, {
  required String id,
  required AsyncValue<GroupDetailState> value,
  Size size = const Size(390, 844),
  double textScale = 1,
  Brightness brightness = Brightness.dark,
  bool reducedMotion = false,
  bool online = true,
  bool actionsEnabled = true,
  bool settle = true,
  FocusNode? primaryActionFocusNode,
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

  final controller = _ControlledGroupDetailController(value);
  final router = _router(
    primaryActionFocusNode: primaryActionFocusNode,
    stateKey: id,
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        groupDetailProvider(_groupId).overrideWith((ref) => controller),
        groupContributionActionsEnabledProvider.overrideWithValue(
          actionsEnabled,
        ),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
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
  final goldenBoundary = id == 'selected'
      ? find.byType(Overlay).first
      : find.byKey(const ValueKey<String>('group-detail-state-golden'));
  _markSubtreeNeedsPaint(tester.renderObject(goldenBoundary));
  await tester.pump();
  expect(tester.takeException(), isNull);
  final goldenPath = _goldenPaths[id];
  expect(goldenPath, isNotNull, reason: 'Missing group detail golden for $id.');
  await expectLater(goldenBoundary, matchesGoldenFile(goldenPath!));
  await afterCapture?.call(tester);
}

void _markSubtreeNeedsPaint(RenderObject object) {
  object.markNeedsPaint();
  object.visitChildren(_markSubtreeNeedsPaint);
}
