import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_admin/feat_admin.dart';
import 'package:feat_admin/src/screens/admin_dashboard_screen.dart';
import 'package:flutter/material.dart';
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
    final pending = Completer<AdminDashboardSnapshot>();
    await _pumpDashboard(
      tester,
      gateway: _DashboardGateway(pending.future),
      settle: false,
    );

    expect(find.text('Loading admin workspace'), findsOneWidget);
    expect(find.text('42'), findsNothing);
    await _expectStateGolden(tester, 'loading');
    pending.complete(_snapshot);
    await tester.pumpAndSettle();
  });

  testWidgets('renders confirmed zero metrics as an explicit empty feed', (
    tester,
  ) async {
    await _pumpDashboard(
      tester,
      gateway: const _DashboardGateway(_emptySnapshot),
    );

    expect(find.text('No recent activity'), findsOneWidget);
    expect(
      find.textContaining('Current totals are confirmed.'),
      findsOneWidget,
    );
    expect(find.text('0'), findsNWidgets(4));
    await _expectStateGolden(tester, 'empty');
  });

  testWidgets('renders a privacy-safe unknown error', (tester) async {
    await _pumpDashboard(
      tester,
      gateway: _DashboardGateway(
        StateError('provider row private-account-991 failed'),
      ),
    );

    expect(find.text('Admin workspace unavailable'), findsOneWidget);
    expect(find.textContaining('private-account-991'), findsNothing);
    expect(find.text('42'), findsNothing);
    await _expectStateGolden(tester, 'error');
  });

  testWidgets('renders the offline state without private data', (tester) async {
    await _pumpDashboard(
      tester,
      gateway: const _DashboardGateway(_snapshot),
      online: false,
    );

    expect(find.text('Admin workspace offline'), findsOneWidget);
    expect(find.text('42'), findsNothing);
    await _expectStateGolden(tester, 'offline');
  });

  testWidgets('permission denial clears all dashboard data and actions', (
    tester,
  ) async {
    await _pumpDashboard(
      tester,
      gateway: const _DashboardGateway(
        AdminDashboardFailure(AdminDashboardFailureKind.permissionDenied),
      ),
    );

    expect(find.text('Admin access unavailable'), findsOneWidget);
    expect(find.text('42'), findsNothing);
    expect(find.text('Manage CMS'), findsNothing);
    await _expectStateGolden(tester, 'permission_denied');
  });

  testWidgets('renders the feature-disabled state', (tester) async {
    await _pumpDashboard(
      tester,
      gateway: const _DashboardGateway(_snapshot),
      enabled: false,
    );

    expect(find.text('Admin workspace unavailable'), findsOneWidget);
    expect(
      find.textContaining('disabled for this controlled build'),
      findsOneWidget,
    );
    expect(find.text('42'), findsNothing);
    await _expectStateGolden(tester, 'disabled');
  });

  testWidgets('renders current metrics, activity, and enabled actions', (
    tester,
  ) async {
    await _pumpDashboard(tester, gateway: const _DashboardGateway(_snapshot));

    expect(find.text('42'), findsOneWidget);
    expect(find.text('Season launch'), findsOneWidget);
    expect(find.text('Manage CMS'), findsOneWidget);
    final cms = tester.widget<Semantics>(
      find.byKey(const ValueKey<String>('admin-dashboard-action-/admin/cms')),
    );
    expect(cms.properties.selected, isFalse);
  });

  testWidgets('syncing retains confirmed data and pauses actions', (
    tester,
  ) async {
    final pending = Completer<AdminDashboardSnapshot>();
    final gateway = _SequenceDashboardGateway(<Object>[
      _snapshot,
      pending.future,
    ]);
    final container = await _pumpDashboard(tester, gateway: gateway);

    unawaited(container.read(adminDashboardProvider.notifier).refresh());
    await tester.pump();

    expect(find.text('Refreshing admin workspace'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
    final feedback = tester.widget<AfriPressFeedback>(
      find.descendant(
        of: find.byKey(
          const ValueKey<String>('admin-dashboard-action-/admin/cms'),
        ),
        matching: find.byType(AfriPressFeedback),
      ),
    );
    expect(feedback.enabled, isFalse);
    await _expectStateGolden(tester, 'syncing');
    pending.complete(_snapshot);
    await tester.pumpAndSettle();
  });

  testWidgets('conflict retains confirmed data and shows recovery copy', (
    tester,
  ) async {
    final gateway = _SequenceDashboardGateway(<Object>[
      _snapshot,
      const AdminDashboardFailure(AdminDashboardFailureKind.conflict),
    ]);
    final container = await _pumpDashboard(tester, gateway: gateway);

    await container.read(adminDashboardProvider.notifier).refresh();
    await tester.pump();

    expect(find.text('Admin data changed'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
    expect(find.textContaining('Actions are paused'), findsOneWidget);
    await _expectStateGolden(tester, 'conflict');
  });

  testWidgets('security timeout retains confirmed data and hides diagnostics', (
    tester,
  ) async {
    final gateway = _SequenceDashboardGateway(<Object>[
      _snapshot,
      TimeoutException('private-account-991 timed out'),
    ]);
    final container = await _pumpDashboard(tester, gateway: gateway);

    await container.read(adminDashboardProvider.notifier).refresh();
    await tester.pump();

    expect(find.text('Refresh timed out'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
    expect(find.textContaining('private-account-991'), findsNothing);
    await _expectStateGolden(tester, 'security_timeout');
  });

  testWidgets('selected action exposes selected semantics', (tester) async {
    await _pumpDashboard(
      tester,
      gateway: const _DashboardGateway(_snapshot),
      selectedRoute: '/admin/cms',
    );

    final cms = tester.widget<Semantics>(
      find.byKey(const ValueKey<String>('admin-dashboard-action-/admin/cms')),
    );
    expect(cms.properties.selected, isTrue);
    await _expectStateGolden(tester, 'selected');
  });

  testWidgets('action supports focus, held press, and keyboard activation', (
    tester,
  ) async {
    final focusNode = FocusNode(debugLabel: 'admin-dashboard-cms');
    addTearDown(focusNode.dispose);
    final previousStrategy = FocusManager.instance.highlightStrategy;
    addTearDown(
      () => FocusManager.instance.highlightStrategy = previousStrategy,
    );
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    await _pumpDashboard(
      tester,
      gateway: const _DashboardGateway(_snapshot),
      firstActionFocusNode: focusNode,
    );
    final action = find.bySemanticsLabel('Manage CMS');
    await tester.ensureVisible(action);

    focusNode.requestFocus();
    await tester.pumpAndSettle();
    expect(focusNode.hasFocus, isTrue);
    await _expectStateGolden(tester, 'focused');

    focusNode.unfocus();
    await tester.pumpAndSettle();
    final pressTarget = find.descendant(
      of: find.byKey(
        const ValueKey<String>('admin-dashboard-action-/admin/cms'),
      ),
      matching: find.byType(AfriPressFeedback),
    );
    final gesture = await tester.startGesture(tester.getCenter(pressTarget));
    await tester.pump(const Duration(milliseconds: 250));
    expect(tester.takeException(), isNull);
    await _expectStateGolden(tester, 'pressed');
    await gesture.cancel();
    await tester.pump();

    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(find.text('CMS destination'), findsOneWidget);
  });

  testWidgets('supports 200 percent text without horizontal overflow', (
    tester,
  ) async {
    await _pumpDashboard(
      tester,
      gateway: const _DashboardGateway(_snapshot),
      textScale: 2,
    );

    expect(tester.takeException(), isNull);
    final scrollable = tester.widget<Scrollable>(find.byType(Scrollable).first);
    expect(
      scrollable.axisDirection,
      anyOf(AxisDirection.down, AxisDirection.up),
    );
    final users = find.text('Total users');
    final groups = find.text('Active groups');
    final transactions = find.text('Transactions today');
    expect(
      tester.getTopLeft(groups).dy,
      greaterThan(tester.getBottomLeft(users).dy),
    );
    expect(tester.getSize(transactions).width, greaterThan(280));
    await _expectStateGolden(tester, 'large_text');
    await tester.ensureVisible(find.text('Manage CMS'));
    await tester.tap(find.text('Manage CMS'));
    await tester.pumpAndSettle();
    expect(find.text('CMS destination'), findsOneWidget);
  });

  testWidgets('respects reduced motion', (tester) async {
    await _pumpDashboard(
      tester,
      gateway: const _DashboardGateway(_snapshot),
      reduceMotion: true,
    );

    final context = tester.element(find.byType(AdminDashboardScreen));
    expect(AfriMotion.reduceMotion(context), isTrue);
    expect(tester.takeException(), isNull);
    await _expectStateGolden(tester, 'reduced_motion');
  });

  for (final brightness in <Brightness>[Brightness.dark, Brightness.light]) {
    testWidgets('renders the ${brightness.name} theme', (tester) async {
      await _pumpDashboard(
        tester,
        gateway: const _DashboardGateway(_snapshot),
        brightness: brightness,
      );

      expect(find.text('Command center'), findsOneWidget);
      expect(
        Theme.of(tester.element(find.byType(AdminDashboardScreen))).brightness,
        brightness,
      );
      expect(tester.takeException(), isNull);
      await _expectStateGolden(tester, brightness.name);
    });
  }
}

Future<ProviderContainer> _pumpDashboard(
  WidgetTester tester, {
  required AdminDashboardGateway gateway,
  bool enabled = true,
  bool online = true,
  bool settle = true,
  bool reduceMotion = false,
  double textScale = 1,
  String? selectedRoute,
  Brightness brightness = Brightness.dark,
  FocusNode? firstActionFocusNode,
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
    initialLocation: '/admin',
    routes: <RouteBase>[
      GoRoute(
        path: '/admin',
        builder: (_, _) =>
            AdminDashboardScreen(firstActionFocusNode: firstActionFocusNode),
        routes: <RouteBase>[
          GoRoute(
            path: 'cms',
            builder: (_, _) =>
                const Scaffold(body: Center(child: Text('CMS destination'))),
          ),
        ],
      ),
      GoRoute(
        path: '/settings',
        builder: (_, _) =>
            const Scaffold(body: Center(child: Text('Settings destination'))),
      ),
    ],
  );
  addTearDown(router.dispose);

  late ProviderContainer container;
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        adminDashboardGatewayProvider.overrideWithValue(gateway),
        adminDashboardEnabledProvider.overrideWithValue(enabled),
        if (selectedRoute != null)
          adminDashboardSelectedActionProvider.overrideWith(
            (ref) => selectedRoute,
          ),
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
      'goldens/admin_dashboard_state_${id}_${suffix}_$_goldenViewportId.png',
    ),
  );
}

const _emptySnapshot = AdminDashboardSnapshot(
  metrics: AdminDashboardMetrics(),
  activity: <AdminDashboardActivity>[],
);

const _snapshot = AdminDashboardSnapshot(
  metrics: AdminDashboardMetrics(
    totalUsers: 42,
    activeGroups: 3,
    transactionsToday: 7,
    ticketsSold: 11,
  ),
  activity: <AdminDashboardActivity>[
    AdminDashboardActivity(title: 'Season launch', category: 'CMS'),
  ],
);

class _DashboardGateway implements AdminDashboardGateway {
  const _DashboardGateway(this.outcome);

  final Object outcome;

  @override
  Future<AdminDashboardSnapshot> load() async {
    if (outcome is Future<AdminDashboardSnapshot>) {
      return outcome as Future<AdminDashboardSnapshot>;
    }
    if (outcome is AdminDashboardSnapshot) {
      return outcome as AdminDashboardSnapshot;
    }
    throw outcome;
  }
}

class _SequenceDashboardGateway implements AdminDashboardGateway {
  _SequenceDashboardGateway(this.outcomes);

  final List<Object> outcomes;
  int _index = 0;

  @override
  Future<AdminDashboardSnapshot> load() async {
    final outcome = outcomes[_index.clamp(0, outcomes.length - 1)];
    _index++;
    if (outcome is Future<AdminDashboardSnapshot>) return outcome;
    if (outcome is AdminDashboardSnapshot) return outcome;
    throw outcome;
  }
}
