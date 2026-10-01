import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_contributions/src/controllers/statement_controller.dart';
import 'package:feat_contributions/src/screens/statement_download_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:test_support/app_font_loader.dart';

import '../../../testing/test_support/test/fixtures/local_route_state_assertions.dart';

const _groupId = 'initiative-statement-1';

const _goldenPaths = <String, String>{
  'loading': 'goldens/statement_state_loading_dark_390x844.png',
  'empty': 'goldens/statement_state_empty_dark_390x844.png',
  'error': 'goldens/statement_state_error_dark_390x844.png',
  'offline': 'goldens/statement_state_offline_dark_390x844.png',
  'permission_denied':
      'goldens/statement_state_permission_denied_dark_390x844.png',
  'disabled': 'goldens/statement_state_disabled_dark_390x844.png',
  'focused': 'goldens/statement_state_focused_dark_390x844.png',
  'pressed': 'goldens/statement_state_pressed_dark_390x844.png',
  'selected': 'goldens/statement_state_selected_dark_390x844.png',
  'large_text': 'goldens/statement_state_large_text_dark_320x720.png',
  'reduced_motion': 'goldens/statement_state_reduced_motion_dark_390x844.png',
  'dark': 'goldens/statement_state_dark_dark_390x844.png',
  'light': 'goldens/statement_state_light_light_390x844.png',
  'syncing': 'goldens/statement_state_syncing_dark_390x844.png',
  'conflict': 'goldens/statement_state_conflict_dark_390x844.png',
  'security_timeout':
      'goldens/statement_state_security_timeout_dark_390x844.png',
};

class _NoopStatementGateway implements StatementGateway {
  @override
  Future<StatementSnapshot?> load(
    String groupId, {
    DateTime? from,
    DateTime? to,
  }) async => _snapshot();
}

class _ControlledStatementController extends StatementController {
  _ControlledStatementController(AsyncValue<StatementState> value)
    : super(_NoopStatementGateway(), groupId: _groupId, autoLoad: false) {
    state = value;
  }

  int refreshCount = 0;

  @override
  Future<void> refresh() async {
    refreshCount++;
  }
}

StatementSnapshot _snapshot({bool empty = false}) {
  return StatementSnapshot(
    groupName: 'Rayon Sports Supporters Away Day Travel Initiative',
    entries: empty
        ? const <StatementEntry>[]
        : <StatementEntry>[
            StatementEntry(
              publicAlias: '#FAN2048',
              amount: 25000,
              status: StatementEntryStatus.confirmed,
              createdAt: DateTime.utc(2026, 7, 18),
            ),
            StatementEntry(
              publicAlias: '#BLUEARMY',
              amount: 10000,
              status: StatementEntryStatus.processing,
              createdAt: DateTime.utc(2026, 7, 17),
            ),
          ],
  );
}

StatementState _populatedState({
  StatementPhase phase = StatementPhase.ready,
  StatementFailure? failure,
  StatementSort sort = StatementSort.date,
  bool empty = false,
}) {
  return StatementState(
    snapshot: _snapshot(empty: empty),
    phase: phase,
    failure: failure,
    sort: sort,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);
  setUp(() => ConnectivityService.setOnlineForTest(true));

  testWidgets('statement refreshes automatically after reconnect', (
    tester,
  ) async {
    ConnectivityService.setOnlineForTest(false);
    addTearDown(() => ConnectivityService.setOnlineForTest(true));
    final controller = _ControlledStatementController(
      const AsyncError<StatementState>(
        StatementFailure(StatementFailureKind.offline),
        StackTrace.empty,
      ),
    );
    final router = _router(stateKey: 'reconnect');
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          statementProvider(_groupId).overrideWith((ref) => controller),
        ],
        child: MaterialApp.router(
          theme: ClubTheme.from(
            localRouteConfigOrFallback(),
            brightness: Brightness.dark,
          ),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Statement offline'), findsOneWidget);

    ConnectivityService.setOnlineForTest(true);
    await tester.pumpAndSettle();

    expect(controller.refreshCount, 1);
    expect(find.text('Connection restored'), findsOneWidget);
  });

  testWidgets('golden statement loading state', (tester) async {
    await _pumpState(
      tester,
      id: 'loading',
      value: const AsyncLoading<StatementState>(),
      settle: false,
      beforeCapture: (tester) async {
        expect(find.text('Loading public statement'), findsOneWidget);
      },
    );
  });

  testWidgets('golden statement empty state', (tester) async {
    await _pumpState(
      tester,
      id: 'empty',
      value: AsyncData<StatementState>(_populatedState(empty: true)),
      beforeCapture: (tester) async {
        expect(find.text('No statement entries'), findsOneWidget);
        expect(find.text('Copy CSV statement'), findsOneWidget);
      },
    );
  });

  testWidgets('golden statement error state', (tester) async {
    await _pumpState(
      tester,
      id: 'error',
      value: const AsyncError<StatementState>(
        StatementFailure(StatementFailureKind.unknown),
        StackTrace.empty,
      ),
      beforeCapture: (tester) async {
        expect(find.text('Statement unavailable'), findsOneWidget);
        expect(find.textContaining('supporter-991'), findsNothing);
      },
    );
  });

  testWidgets('golden statement offline state', (tester) async {
    await _pumpState(
      tester,
      id: 'offline',
      value: AsyncData<StatementState>(_populatedState()),
      online: false,
      beforeCapture: (tester) async {
        expect(find.text('Showing saved statement data'), findsOneWidget);
        expect(
          tester
              .widget<AfriButton>(
                find.byKey(const ValueKey<String>('statement-export-action')),
              )
              .enabled,
          isFalse,
        );
      },
    );
  });

  testWidgets('golden statement permission-denied state', (tester) async {
    await _pumpState(
      tester,
      id: 'permission_denied',
      value: const AsyncError<StatementState>(
        StatementFailure(StatementFailureKind.permissionDenied),
        StackTrace.empty,
      ),
      beforeCapture: (tester) async {
        expect(find.text('Statement unavailable'), findsOneWidget);
        expect(find.text('Refresh'), findsNothing);
      },
    );
  });

  testWidgets('golden statement disabled state', (tester) async {
    await _pumpState(
      tester,
      id: 'disabled',
      value: AsyncData<StatementState>(_populatedState()),
      exportEnabled: false,
      beforeCapture: (tester) async {
        expect(find.text('Statement export is read-only'), findsOneWidget);
        expect(find.text('Export disabled'), findsOneWidget);
      },
    );
  });

  testWidgets('golden statement focused state', (tester) async {
    final focusNode = FocusNode(debugLabel: 'statement-export-focus');
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
      value: AsyncData<StatementState>(_populatedState()),
      exportActionFocusNode: focusNode,
      beforeCapture: (tester) async {
        final action = find.byKey(
          const ValueKey<String>('statement-export-action'),
        );
        await tester.ensureVisible(action);
        focusNode.requestFocus();
        await tester.pumpAndSettle();
        expect(focusNode.hasFocus, isTrue);
      },
      afterCapture: (tester) async {
        focusNode.unfocus();
        await tester.pumpAndSettle();
      },
    );
  });

  testWidgets('golden statement pressed state', (tester) async {
    TestGesture? heldGesture;
    await _pumpState(
      tester,
      id: 'pressed',
      value: AsyncData<StatementState>(_populatedState()),
      beforeCapture: (tester) async {
        final action = find.byKey(
          const ValueKey<String>('statement-export-action'),
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
        await heldGesture?.cancel();
        await tester.pump(const Duration(milliseconds: 300));
      },
    );
  });

  testWidgets('golden statement selected sort state', (tester) async {
    await _pumpState(
      tester,
      id: 'selected',
      value: AsyncData<StatementState>(_populatedState()),
      beforeCapture: (tester) async {
        final amountSort = find.byKey(
          const ValueKey<String>('statement-sort-amount'),
        );
        await tester.ensureVisible(amountSort);
        await tester.tap(amountSort);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<ChoiceChip>(
                find.descendant(
                  of: amountSort,
                  matching: find.byType(ChoiceChip),
                ),
              )
              .selected,
          isTrue,
        );
      },
    );
  });

  testWidgets('golden statement large-text state', (tester) async {
    await _pumpState(
      tester,
      id: 'large_text',
      value: AsyncData<StatementState>(_populatedState()),
      size: const Size(320, 720),
      textScale: 2,
      beforeCapture: (tester) async {
        expect(
          find.text('Rayon Sports Supporters Away Day Travel Initiative'),
          findsOneWidget,
        );
        final action = find.byKey(
          const ValueKey<String>('statement-export-action'),
        );
        for (
          var attempt = 0;
          action.evaluate().isEmpty && attempt < 6;
          attempt++
        ) {
          await tester.drag(
            find.byKey(const ValueKey<String>('statement-scroll-view')),
            const Offset(0, -260),
          );
          await tester.pumpAndSettle();
        }
        await tester.ensureVisible(action);
        await tester.pumpAndSettle();
        expect(find.text('Copy CSV statement'), findsOneWidget);
      },
    );
  });

  testWidgets('golden statement reduced-motion state', (tester) async {
    await _pumpState(
      tester,
      id: 'reduced_motion',
      value: AsyncData<StatementState>(_populatedState()),
      reducedMotion: true,
      beforeCapture: (tester) async {
        expect(
          MediaQuery.disableAnimationsOf(
            tester.element(find.byType(StatementDownloadScreen)),
          ),
          isTrue,
        );
      },
    );
  });

  testWidgets('golden statement dark state', (tester) async {
    await _pumpState(
      tester,
      id: 'dark',
      value: AsyncData<StatementState>(_populatedState()),
    );
  });

  testWidgets('golden statement light state', (tester) async {
    await _pumpState(
      tester,
      id: 'light',
      value: AsyncData<StatementState>(_populatedState()),
      brightness: Brightness.light,
    );
  });

  testWidgets('golden statement syncing state', (tester) async {
    await _pumpState(
      tester,
      id: 'syncing',
      value: AsyncData<StatementState>(
        _populatedState(phase: StatementPhase.syncing),
      ),
      beforeCapture: (tester) async {
        expect(find.text('Refreshing statement'), findsOneWidget);
        expect(find.text('Checking latest entries'), findsOneWidget);
      },
    );
  });

  testWidgets('golden statement conflict state', (tester) async {
    await _pumpState(
      tester,
      id: 'conflict',
      value: AsyncData<StatementState>(
        _populatedState(
          phase: StatementPhase.degraded,
          failure: const StatementFailure(StatementFailureKind.conflict),
        ),
      ),
      beforeCapture: (tester) async {
        expect(find.text('Statement changed'), findsOneWidget);
        expect(find.text('Refresh statement'), findsOneWidget);
      },
    );
  });

  testWidgets('golden statement security-timeout state', (tester) async {
    await _pumpState(
      tester,
      id: 'security_timeout',
      value: AsyncData<StatementState>(
        _populatedState(
          phase: StatementPhase.degraded,
          failure: const StatementFailure(StatementFailureKind.securityTimeout),
        ),
      ),
      beforeCapture: (tester) async {
        expect(find.text('Statement check timed out'), findsOneWidget);
        expect(find.text('Refresh before exporting'), findsOneWidget);
      },
    );
  });
}

GoRouter _router({FocusNode? exportActionFocusNode, required String stateKey}) {
  return GoRouter(
    initialLocation: '/contribute/group/$_groupId/statement',
    routes: <RouteBase>[
      GoRoute(
        path: '/contribute/group/:groupId/statement',
        builder: (context, state) => RepaintBoundary(
          key: const ValueKey<String>('statement-state-golden'),
          child: StatementDownloadScreen(
            key: ValueKey<String>('statement-screen-$stateKey'),
            groupId: state.pathParameters['groupId']!,
            exportActionFocusNode: exportActionFocusNode,
          ),
        ),
      ),
      GoRoute(
        path: '/contribute/group/:groupId',
        builder: (context, state) => const SizedBox.shrink(),
      ),
    ],
  );
}

Future<void> _pumpState(
  WidgetTester tester, {
  required String id,
  required AsyncValue<StatementState> value,
  Size size = const Size(390, 844),
  double textScale = 1,
  Brightness brightness = Brightness.dark,
  bool reducedMotion = false,
  bool online = true,
  bool exportEnabled = true,
  bool settle = true,
  FocusNode? exportActionFocusNode,
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

  final controller = _ControlledStatementController(value);
  final router = _router(
    exportActionFocusNode: exportActionFocusNode,
    stateKey: id,
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        statementProvider(_groupId).overrideWith((ref) => controller),
        statementExportEnabledProvider.overrideWithValue(exportEnabled),
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
        theme: ClubTheme.from(
          localRouteConfigOrFallback(),
          brightness: brightness,
        ),
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
    const ValueKey<String>('statement-state-golden'),
  );
  _markSubtreeNeedsPaint(tester.renderObject(goldenBoundary));
  await tester.pump();
  expect(tester.takeException(), isNull);
  final goldenPath = _goldenPaths[id];
  expect(goldenPath, isNotNull, reason: 'Missing statement golden for $id.');
  await expectGoldenOrClubAssertions(
    tester,
    goldenBoundary,
    goldenPath!,
    route: '/contribute/group/:groupId/statement',
    kind: 'route',
  );
  await afterCapture?.call(tester);
}

void _markSubtreeNeedsPaint(RenderObject object) {
  object.markNeedsPaint();
  object.visitChildren(_markSubtreeNeedsPaint);
}
