import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_admin/feat_admin.dart';
import 'package:feat_admin/src/screens/feature_manager_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:test_support/app_font_loader.dart';

import '../../../testing/test_support/test/fixtures/local_route_state_assertions.dart';

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
    final pending = Completer<AdminFeaturesSnapshot>();
    await _pumpFeatures(
      tester,
      gateway: _Gateway(<Object>[pending.future]),
      settle: false,
    );

    expect(find.text('Loading feature registry'), findsOneWidget);
    expect(find.text('PREDICTIONS'), findsNothing);
    await _expectStateGolden(tester, 'loading');
    pending.complete(_registry);
    await tester.pumpAndSettle();
  });

  testWidgets('renders a confirmed empty registry', (tester) async {
    await _pumpFeatures(
      tester,
      gateway: _Gateway(const <Object>[AdminFeaturesSnapshot.empty()]),
    );

    expect(find.text('No features configured'), findsOneWidget);
    await _expectStateGolden(tester, 'empty');
  });

  testWidgets('renders a privacy-safe unknown error', (tester) async {
    await _pumpFeatures(
      tester,
      gateway: _Gateway(<Object>[StateError('private-admin-id failed')]),
    );

    expect(find.text('Feature registry unavailable'), findsOneWidget);
    expect(find.textContaining('private-admin-id'), findsNothing);
    await _expectStateGolden(tester, 'error');
  });

  testWidgets('renders offline without private configuration', (tester) async {
    await _pumpFeatures(
      tester,
      gateway: _Gateway(<Object>[_registry]),
      online: false,
    );

    expect(find.text('Feature registry offline'), findsOneWidget);
    expect(find.text('Predictions'), findsNothing);
    await _expectStateGolden(tester, 'offline');
  });

  testWidgets('permission denial clears feature configuration', (tester) async {
    await _pumpFeatures(
      tester,
      gateway: _Gateway(const <Object>[
        AdminFeaturesFailure(AdminFeaturesFailureKind.permissionDenied),
      ]),
    );

    expect(find.text('Feature access unavailable'), findsOneWidget);
    expect(find.text('Predictions'), findsNothing);
    await _expectStateGolden(tester, 'permission_denied');
  });

  testWidgets('renders the feature-disabled state', (tester) async {
    await _pumpFeatures(
      tester,
      gateway: _Gateway(<Object>[_registry]),
      enabled: false,
    );

    expect(find.text('Feature management unavailable'), findsOneWidget);
    expect(
      find.textContaining('disabled for this controlled build'),
      findsOneWidget,
    );
    await _expectStateGolden(tester, 'disabled');
  });

  testWidgets('selected filter exposes current selection', (tester) async {
    await _pumpFeatures(tester, gateway: _Gateway(<Object>[_registry]));

    await tester.tap(find.text('Disabled'));
    await tester.pumpAndSettle();

    final selected = tester.widget<AfriChoiceChip>(
      find.widgetWithText(AfriChoiceChip, 'Disabled'),
    );
    expect(selected.selected, isTrue);
    expect(find.text('Tickets'), findsOneWidget);
    expect(find.text('Predictions'), findsNothing);
    await _expectStateGolden(tester, 'selected');
  });

  testWidgets('feature card supports held press and keyboard focus', (
    tester,
  ) async {
    final focusNode = FocusNode(debugLabel: 'feature-card');
    addTearDown(focusNode.dispose);
    final previousStrategy = FocusManager.instance.highlightStrategy;
    addTearDown(
      () => FocusManager.instance.highlightStrategy = previousStrategy,
    );
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    await _pumpFeatures(
      tester,
      gateway: _Gateway(<Object>[_registry]),
      firstActionFocusNode: focusNode,
    );
    final action = find.byKey(const ValueKey<String>('admin-feature-tickets'));

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
    await _pumpFeatures(
      tester,
      gateway: _Gateway(<Object>[_registry]),
      textScale: 2,
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(Scrollable), findsWidgets);
    await _expectStateGolden(tester, 'large_text');
  });

  testWidgets('respects reduced motion', (tester) async {
    await _pumpFeatures(
      tester,
      gateway: _Gateway(<Object>[_registry]),
      reduceMotion: true,
    );

    final context = tester.element(find.byType(FeatureManagerScreen));
    expect(AfriMotion.reduceMotion(context), isTrue);
    expect(tester.takeException(), isNull);
    await _expectStateGolden(tester, 'reduced_motion');
  });

  for (final brightness in <Brightness>[Brightness.dark, Brightness.light]) {
    testWidgets('renders the ${brightness.name} theme', (tester) async {
      await _pumpFeatures(
        tester,
        gateway: _Gateway(<Object>[_registry]),
        brightness: brightness,
      );

      expect(find.text('Feature manager'), findsOneWidget);
      expect(
        Theme.of(tester.element(find.byType(FeatureManagerScreen))).brightness,
        brightness,
      );
      expect(tester.takeException(), isNull);
      await _expectStateGolden(tester, brightness.name);
    });
  }

  testWidgets('syncing retains confirmed feature configuration', (
    tester,
  ) async {
    final pending = Completer<AdminFeaturesSnapshot>();
    final gateway = _Gateway(<Object>[_registry, pending.future]);
    final container = await _pumpFeatures(tester, gateway: gateway);

    unawaited(container.read(adminFeaturesProvider.notifier).refresh());
    await tester.pump();

    expect(find.text('Checking feature configuration'), findsOneWidget);
    expect(find.text('Predictions'), findsOneWidget);
    await _expectStateGolden(tester, 'syncing');
    pending.complete(_registry);
    await tester.pumpAndSettle();
  });

  testWidgets('conflict retains configuration and explains recovery', (
    tester,
  ) async {
    final gateway = _Gateway(<Object>[
      _registry,
      const AdminFeaturesFailure(AdminFeaturesFailureKind.conflict),
    ]);
    final container = await _pumpFeatures(tester, gateway: gateway);

    await container.read(adminFeaturesProvider.notifier).refresh();
    await tester.pump();

    expect(find.text('Feature configuration changed'), findsOneWidget);
    expect(find.text('Predictions'), findsOneWidget);
    expect(find.textContaining('Controls are paused'), findsOneWidget);
    await _expectStateGolden(tester, 'conflict');
  });

  testWidgets('security timeout retains configuration and hides diagnostics', (
    tester,
  ) async {
    final gateway = _Gateway(<Object>[
      _registry,
      TimeoutException('private-admin-id timed out'),
    ]);
    final container = await _pumpFeatures(tester, gateway: gateway);

    await container.read(adminFeaturesProvider.notifier).refresh();
    await tester.pump();

    expect(find.text('Security check timed out'), findsOneWidget);
    expect(find.text('Predictions'), findsOneWidget);
    expect(find.textContaining('private-admin-id'), findsNothing);
    await _expectStateGolden(tester, 'security_timeout');
  });
}

Future<ProviderContainer> _pumpFeatures(
  WidgetTester tester, {
  required AdminFeaturesGateway gateway,
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
    initialLocation: '/admin/features',
    routes: <RouteBase>[
      GoRoute(
        path: '/admin/features',
        builder: (_, _) =>
            FeatureManagerScreen(firstActionFocusNode: firstActionFocusNode),
      ),
      GoRoute(
        path: '/admin/features/:featureKey',
        builder: (_, state) => FeatureManagerScreen(
          key: ValueKey<String>(state.pathParameters['featureKey'] ?? ''),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);

  late ProviderContainer container;
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        adminFeaturesGatewayProvider.overrideWithValue(gateway),
        adminFeaturesEnabledProvider.overrideWithValue(enabled),
      ],
      child: Consumer(
        builder: (context, ref, child) {
          container = ProviderScope.containerOf(context);
          return ClubConfigScope(
            config: localRouteConfigOrFallback(),
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
                localRouteConfigOrFallback(),
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
  await expectGoldenOrClubAssertions(
    tester,
    find.byType(MaterialApp),
    'goldens/admin_features_state_${state}_$_goldenViewportId.png',
    route: '/admin/features',
    kind: 'route',
    surface: 'mobile_internal_admin',
  );
}

final _registry = AdminFeaturesSnapshot.fromRaw(<Map<String, dynamic>>[
  _featureRow(),
  _featureRow(
    id: 'feature-2',
    featureKey: 'tickets',
    displayName: 'Tickets',
    category: 'Commerce',
    isEnabled: false,
    visibility: 'maintenance',
  ),
]);

Map<String, dynamic> _featureRow({
  String id = 'feature-1',
  String featureKey = 'predictions',
  String displayName = 'Predictions',
  String category = 'Engagement',
  bool isEnabled = true,
  String visibility = 'visible',
}) {
  return <String, dynamic>{
    'id': id,
    'feature_key': featureKey,
    'display_name': displayName,
    'description': 'Supporter match prediction controls.',
    'category': category,
    'is_enabled': isEnabled,
    'visibility_state': visibility,
    'channels': <Map<String, dynamic>>[
      <String, dynamic>{
        'channel': 'mobile',
        'is_enabled': true,
        'is_visible': true,
        'show_in_navigation': true,
        'show_on_home': false,
        'sort_order': 2,
      },
    ],
    'rules': <Map<String, dynamic>>[
      <String, dynamic>{
        'auth_required': true,
        'schedule_start_at': '2026-08-01T08:00:00Z',
        'schedule_end_at': '2026-08-31T20:00:00Z',
      },
    ],
  };
}

class _Gateway implements AdminFeaturesGateway {
  _Gateway(this.outcomes);

  final List<Object> outcomes;
  int loadCount = 0;

  @override
  Future<AdminFeaturesSnapshot> loadAll() async {
    final index = loadCount++;
    final outcome = outcomes[index.clamp(0, outcomes.length - 1)];
    if (outcome is Future<AdminFeaturesSnapshot>) return outcome;
    if (outcome is AdminFeaturesSnapshot) return outcome;
    throw outcome;
  }

  @override
  Future<AdminFeatureDetailSnapshot> loadOne(String featureKey) async {
    final snapshot = await loadAll();
    for (final feature in snapshot.features) {
      if (feature.featureKey == featureKey) {
        return AdminFeatureDetailSnapshot(feature: feature);
      }
    }
    return const AdminFeatureDetailSnapshot(feature: null);
  }

  @override
  Future<void> setGlobalEnabled(String featureId, bool enabled) async {}

  @override
  Future<void> setVisibility(String featureId, String visibility) async {}

  @override
  Future<void> updateChannel(
    String featureId,
    String channel,
    Map<String, dynamic> updates,
  ) async {}

  @override
  Future<void> updateRules(
    String featureId,
    Map<String, dynamic> updates,
  ) async {}
}
