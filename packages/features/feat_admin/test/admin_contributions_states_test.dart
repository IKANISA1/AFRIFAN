import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_admin/feat_admin.dart';
import 'package:feat_admin/src/screens/contributions_monitor_screen.dart';
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
    final pending = Completer<AdminContributionsSnapshot>();
    await _pumpContributions(
      tester,
      gateway: _Gateway(<Object>[pending.future]),
      settle: false,
    );

    expect(find.text('Loading contributions'), findsOneWidget);
    expect(find.text('STADIUM LIGHTS'), findsNothing);
    await _expectStateGolden(tester, 'loading');
    pending.complete(_workspace);
    await tester.pumpAndSettle();
  });

  testWidgets('renders a confirmed empty monitor', (tester) async {
    await _pumpContributions(
      tester,
      gateway: _Gateway(const <Object>[AdminContributionsSnapshot.empty()]),
    );

    expect(find.text('No contribution groups'), findsOneWidget);
    await _expectStateGolden(tester, 'empty');
  });

  testWidgets('renders a privacy-safe unknown error', (tester) async {
    await _pumpContributions(
      tester,
      gateway: _Gateway(<Object>[
        StateError('private-payment-reference failed'),
      ]),
    );

    expect(find.text('Contribution monitor unavailable'), findsOneWidget);
    expect(find.textContaining('private-payment-reference'), findsNothing);
    await _expectStateGolden(tester, 'error');
  });

  testWidgets('renders offline without private records', (tester) async {
    await _pumpContributions(
      tester,
      gateway: _Gateway(<Object>[_workspace]),
      online: false,
    );

    expect(find.text('Contribution monitor offline'), findsOneWidget);
    expect(find.text('STADIUM LIGHTS'), findsNothing);
    await _expectStateGolden(tester, 'offline');
  });

  testWidgets('permission denial clears records and controls', (tester) async {
    await _pumpContributions(
      tester,
      gateway: _Gateway(const <Object>[
        AdminContributionsFailure(
          AdminContributionsFailureKind.permissionDenied,
        ),
      ]),
    );

    expect(find.text('Contribution access unavailable'), findsOneWidget);
    expect(find.text('STADIUM LIGHTS'), findsNothing);
    expect(find.text('Export privacy-safe report'), findsNothing);
    await _expectStateGolden(tester, 'permission_denied');
  });

  testWidgets('renders the feature-disabled state', (tester) async {
    await _pumpContributions(
      tester,
      gateway: _Gateway(<Object>[_workspace]),
      enabled: false,
    );

    expect(find.text('Contribution monitor unavailable'), findsOneWidget);
    expect(
      find.textContaining('disabled for this controlled build'),
      findsOneWidget,
    );
    expect(find.text('STADIUM LIGHTS'), findsNothing);
    await _expectStateGolden(tester, 'disabled');
  });

  testWidgets('selected filter exposes current selection semantics', (
    tester,
  ) async {
    await _pumpContributions(tester, gateway: _Gateway(<Object>[_workspace]));

    await tester.tap(find.text('COMMUNITY'));
    await tester.pumpAndSettle();

    expect(find.text('No groups match'), findsOneWidget);
    final selected = tester.widget<AfriChoiceChip>(
      find.widgetWithText(AfriChoiceChip, 'COMMUNITY'),
    );
    expect(selected.selected, isTrue);
    await _expectStateGolden(tester, 'selected');
  });

  testWidgets('export action supports held press and keyboard focus', (
    tester,
  ) async {
    final focusNode = FocusNode(debugLabel: 'contribution-export');
    addTearDown(focusNode.dispose);
    final previousStrategy = FocusManager.instance.highlightStrategy;
    addTearDown(
      () => FocusManager.instance.highlightStrategy = previousStrategy,
    );
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    await _pumpContributions(
      tester,
      gateway: _Gateway(<Object>[_workspace]),
      firstActionFocusNode: focusNode,
    );
    final action = find.byKey(
      const ValueKey<String>('admin-contributions-export'),
    );

    await tester.ensureVisible(action);
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(tester.getCenter(action));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 100));
    await _expectStateGolden(tester, 'pressed');
    await gesture.cancel();
    await tester.pumpAndSettle();

    focusNode.requestFocus();
    await tester.pumpAndSettle();
    expect(focusNode.hasFocus, isTrue);
    await _expectStateGolden(tester, 'focused');
  });

  testWidgets('supports 200 percent text without horizontal overflow', (
    tester,
  ) async {
    await _pumpContributions(
      tester,
      gateway: _Gateway(<Object>[_workspace]),
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
    await _pumpContributions(
      tester,
      gateway: _Gateway(<Object>[_workspace]),
      reduceMotion: true,
    );

    final context = tester.element(find.byType(ContributionsMonitorScreen));
    expect(AfriMotion.reduceMotion(context), isTrue);
    expect(tester.takeException(), isNull);
    await _expectStateGolden(tester, 'reduced_motion');
  });

  for (final brightness in <Brightness>[Brightness.dark, Brightness.light]) {
    testWidgets('renders the ${brightness.name} theme', (tester) async {
      await _pumpContributions(
        tester,
        gateway: _Gateway(<Object>[_workspace]),
        brightness: brightness,
      );

      expect(find.text('CONTRIBUTIONS'), findsOneWidget);
      expect(
        Theme.of(
          tester.element(find.byType(ContributionsMonitorScreen)),
        ).brightness,
        brightness,
      );
      expect(tester.takeException(), isNull);
      await _expectStateGolden(tester, brightness.name);
    });
  }

  testWidgets('syncing retains confirmed records and pauses controls', (
    tester,
  ) async {
    final pending = Completer<AdminContributionsSnapshot>();
    final gateway = _Gateway(<Object>[_workspace, pending.future]);
    final container = await _pumpContributions(tester, gateway: gateway);

    unawaited(container.read(adminContributionsProvider.notifier).refresh());
    await tester.pump();

    expect(find.text('Refreshing contributions'), findsOneWidget);
    expect(find.text('STADIUM LIGHTS'), findsOneWidget);
    expect(
      tester
          .widget<AfriChoiceChip>(
            find.widgetWithText(AfriChoiceChip, 'COMMUNITY'),
          )
          .onSelected,
      isNull,
    );
    await _expectStateGolden(tester, 'syncing');
    pending.complete(_workspace);
    await tester.pumpAndSettle();
  });

  testWidgets('conflict retains records and explains recovery', (tester) async {
    final gateway = _Gateway(<Object>[
      _workspace,
      const AdminContributionsFailure(AdminContributionsFailureKind.conflict),
    ]);
    final container = await _pumpContributions(tester, gateway: gateway);

    await container.read(adminContributionsProvider.notifier).refresh();
    await tester.pump();

    expect(find.text('Contribution data changed'), findsOneWidget);
    expect(find.text('STADIUM LIGHTS'), findsOneWidget);
    expect(find.textContaining('Controls are paused'), findsOneWidget);
    await _expectStateGolden(tester, 'conflict');
  });

  testWidgets('security timeout retains records and hides diagnostics', (
    tester,
  ) async {
    final gateway = _Gateway(<Object>[
      _workspace,
      TimeoutException('private-payment-reference timed out'),
    ]);
    final container = await _pumpContributions(tester, gateway: gateway);

    await container.read(adminContributionsProvider.notifier).refresh();
    await tester.pump();

    expect(find.text('Security check timed out'), findsOneWidget);
    expect(find.text('STADIUM LIGHTS'), findsOneWidget);
    expect(find.textContaining('private-payment-reference'), findsNothing);
    await _expectStateGolden(tester, 'security_timeout');
  });
}

Future<ProviderContainer> _pumpContributions(
  WidgetTester tester, {
  required AdminContributionsGateway gateway,
  bool enabled = true,
  bool online = true,
  bool settle = true,
  bool reduceMotion = false,
  double textScale = 1,
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
    initialLocation: '/admin/contributions',
    routes: <RouteBase>[
      GoRoute(
        path: '/admin/contributions',
        builder: (_, _) => ContributionsMonitorScreen(
          firstActionFocusNode: firstActionFocusNode,
        ),
      ),
    ],
  );
  addTearDown(router.dispose);

  late ProviderContainer container;
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        adminContributionsGatewayProvider.overrideWithValue(gateway),
        adminContributionsEnabledProvider.overrideWithValue(enabled),
      ],
      child: Consumer(
        builder: (context, ref, child) {
          container = ProviderScope.containerOf(context);
          return ClubConfigScope(
            config: ClubConfig.fallback(),
            child: MaterialApp.router(
              debugShowCheckedModeBanner: false,
              builder: (context, child) {
                final media = MediaQuery.of(context);
                return MediaQuery(
                  data: media.copyWith(
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
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  return container;
}

Future<void> _expectStateGolden(WidgetTester tester, String state) async {
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile(
      'goldens/admin_contributions_state_${state}_$_goldenViewportId.png',
    ),
  );
}

final _workspace = AdminContributionsSnapshot.fromRawCollections(
  <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 'group-1',
      'name': 'Stadium Lights',
      'group_type': 'project',
      'current_total': 750000,
      'target_amount': 2000000,
      'member_count': 84,
      'is_closed': false,
      'created_at': '2026-07-18T08:00:00Z',
    },
  ],
  <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 'contribution-1',
      'group_id': 'group-1',
      'amount': 15000,
      'status': 'confirmed',
      'created_at': '2026-07-29T10:15:00Z',
    },
  ],
);

class _Gateway implements AdminContributionsGateway {
  _Gateway(this.outcomes);

  final List<Object> outcomes;
  int loadCount = 0;

  @override
  Future<AdminContributionsSnapshot> load() async {
    final index = loadCount++;
    final outcome = outcomes[index.clamp(0, outcomes.length - 1)];
    if (outcome is Future<AdminContributionsSnapshot>) return outcome;
    if (outcome is AdminContributionsSnapshot) return outcome;
    throw outcome;
  }
}
