import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_admin/feat_admin.dart';
import 'package:feat_admin/src/screens/feature_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:test_support/app_font_loader.dart';

const _goldenViewport = Size(390, 844);
const _goldenViewportId = '390x844';
const _featureKey = 'predictions';

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
    final pending = Completer<AdminFeatureDetailSnapshot>();
    await _pumpDetail(
      tester,
      gateway: _Gateway(<Object>[pending.future]),
      settle: false,
    );

    expect(find.text('Loading feature settings'), findsOneWidget);
    expect(find.text('GLOBAL STATE'), findsNothing);
    await _expectStateGolden(tester, 'loading');
    pending.complete(_detail);
    await tester.pumpAndSettle();
  });

  testWidgets('renders a confirmed missing feature', (tester) async {
    await _pumpDetail(
      tester,
      gateway: _Gateway(const <Object>[
        AdminFeatureDetailSnapshot(feature: null),
      ]),
    );

    expect(find.text('Feature not found'), findsOneWidget);
    await _expectStateGolden(tester, 'empty');
  });

  testWidgets('renders a privacy-safe unknown error', (tester) async {
    await _pumpDetail(
      tester,
      gateway: _Gateway(<Object>[StateError('private-rollout-rule failed')]),
    );

    expect(find.text('Feature settings unavailable'), findsOneWidget);
    expect(find.textContaining('private-rollout-rule'), findsNothing);
    await _expectStateGolden(tester, 'error');
  });

  testWidgets('renders offline without private settings', (tester) async {
    await _pumpDetail(
      tester,
      gateway: _Gateway(<Object>[_detail]),
      online: false,
    );

    expect(find.text('Feature settings offline'), findsOneWidget);
    expect(find.text('GLOBAL STATE'), findsNothing);
    await _expectStateGolden(tester, 'offline');
  });

  testWidgets('permission denial clears retained feature settings', (
    tester,
  ) async {
    await _pumpDetail(
      tester,
      gateway: _Gateway(const <Object>[
        AdminFeaturesFailure(AdminFeaturesFailureKind.permissionDenied),
      ]),
    );

    expect(find.text('Feature access unavailable'), findsOneWidget);
    expect(find.text('GLOBAL STATE'), findsNothing);
    await _expectStateGolden(tester, 'permission_denied');
  });

  testWidgets('renders the detail-disabled state', (tester) async {
    await _pumpDetail(
      tester,
      gateway: _Gateway(<Object>[_detail]),
      enabled: false,
    );

    expect(find.text('Feature settings unavailable'), findsOneWidget);
    expect(
      find.textContaining('disabled for this controlled build'),
      findsOneWidget,
    );
    await _expectStateGolden(tester, 'disabled');
  });

  testWidgets('visibility mutation confirms the selected state', (
    tester,
  ) async {
    final gateway = _Gateway(<Object>[_detail, _hiddenDetail]);
    await _pumpDetail(tester, gateway: gateway);

    await tester.tap(
      find.byKey(
        const ValueKey<String>('admin-feature-detail-visibility-hidden'),
      ),
    );
    await tester.pumpAndSettle();

    final selected = tester.widget<AfriChoiceChip>(
      find.widgetWithText(AfriChoiceChip, 'HIDDEN'),
    );
    expect(selected.selected, isTrue);
    expect(gateway.mutationCount, 1);
    await _expectStateGolden(tester, 'selected');
  });

  testWidgets('global state supports held press and keyboard focus', (
    tester,
  ) async {
    final focusNode = FocusNode(debugLabel: 'feature-detail-global');
    addTearDown(focusNode.dispose);
    final previousStrategy = FocusManager.instance.highlightStrategy;
    addTearDown(
      () => FocusManager.instance.highlightStrategy = previousStrategy,
    );
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    await _pumpDetail(
      tester,
      gateway: _Gateway(<Object>[_detail]),
      firstActionFocusNode: focusNode,
    );
    final action = find.byKey(
      const ValueKey<String>('admin-feature-detail-global-toggle'),
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

  testWidgets('supports 200 percent text with vertical reachability', (
    tester,
  ) async {
    await _pumpDetail(
      tester,
      gateway: _Gateway(<Object>[_detail]),
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
    await _pumpDetail(
      tester,
      gateway: _Gateway(<Object>[_detail]),
      reduceMotion: true,
    );

    final context = tester.element(find.byType(FeatureDetailScreen));
    expect(AfriMotion.reduceMotion(context), isTrue);
    expect(tester.takeException(), isNull);
    await _expectStateGolden(tester, 'reduced_motion');
  });

  for (final brightness in <Brightness>[Brightness.dark, Brightness.light]) {
    testWidgets('renders the ${brightness.name} theme', (tester) async {
      await _pumpDetail(
        tester,
        gateway: _Gateway(<Object>[_detail]),
        brightness: brightness,
      );

      expect(find.text('PREDICTIONS'), findsOneWidget);
      expect(
        Theme.of(tester.element(find.byType(FeatureDetailScreen))).brightness,
        brightness,
      );
      expect(tester.takeException(), isNull);
      await _expectStateGolden(tester, brightness.name);
    });
  }

  testWidgets('syncing retains the last confirmed feature settings', (
    tester,
  ) async {
    final pending = Completer<AdminFeatureDetailSnapshot>();
    final gateway = _Gateway(<Object>[_detail, pending.future]);
    final container = await _pumpDetail(tester, gateway: gateway);

    unawaited(
      container
          .read(adminFeatureDetailProvider(_featureKey).notifier)
          .refresh(),
    );
    await tester.pump();

    expect(find.text('Checking feature settings'), findsOneWidget);
    expect(find.text('GLOBAL STATE'), findsOneWidget);
    await _expectStateGolden(tester, 'syncing');
    pending.complete(_detail);
    await tester.pumpAndSettle();
  });

  testWidgets('conflict retains settings and explains recovery', (
    tester,
  ) async {
    final gateway = _Gateway(<Object>[
      _detail,
      const AdminFeaturesFailure(AdminFeaturesFailureKind.conflict),
    ]);
    final container = await _pumpDetail(tester, gateway: gateway);

    await container
        .read(adminFeatureDetailProvider(_featureKey).notifier)
        .refresh();
    await tester.pump();

    expect(find.text('Feature settings changed'), findsOneWidget);
    expect(find.text('GLOBAL STATE'), findsOneWidget);
    expect(find.textContaining('Controls are paused'), findsOneWidget);
    await _expectStateGolden(tester, 'conflict');
  });

  testWidgets('security timeout retains settings and hides diagnostics', (
    tester,
  ) async {
    final gateway = _Gateway(<Object>[
      _detail,
      TimeoutException('private-rollout-rule timed out'),
    ]);
    final container = await _pumpDetail(tester, gateway: gateway);

    await container
        .read(adminFeatureDetailProvider(_featureKey).notifier)
        .refresh();
    await tester.pump();

    expect(find.text('Security check timed out'), findsOneWidget);
    expect(find.text('GLOBAL STATE'), findsOneWidget);
    expect(find.textContaining('private-rollout-rule'), findsNothing);
    await _expectStateGolden(tester, 'security_timeout');
  });
}

Future<ProviderContainer> _pumpDetail(
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
    initialLocation: '/admin/features/$_featureKey',
    routes: <RouteBase>[
      GoRoute(
        path: '/admin/features/:featureKey',
        builder: (_, state) => FeatureDetailScreen(
          featureKey: state.pathParameters['featureKey'] ?? '',
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
        adminFeaturesGatewayProvider.overrideWithValue(gateway),
        adminFeaturesEnabledProvider.overrideWithValue(enabled),
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
      'goldens/admin_feature_detail_state_${state}_$_goldenViewportId.png',
    ),
  );
}

final _detail = AdminFeatureDetailSnapshot(
  feature: AdminFeaturesSnapshot.fromRaw(<Map<String, dynamic>>[
    _featureRow(),
  ]).features.single,
);

final _hiddenDetail = AdminFeatureDetailSnapshot(
  feature: AdminFeaturesSnapshot.fromRaw(<Map<String, dynamic>>[
    _featureRow(visibility: 'hidden'),
  ]).features.single,
);

Map<String, dynamic> _featureRow({String visibility = 'visible'}) {
  return <String, dynamic>{
    'id': 'feature-1',
    'feature_key': _featureKey,
    'display_name': 'Predictions',
    'description': 'Supporter match prediction controls.',
    'category': 'Engagement',
    'is_enabled': true,
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
      <String, dynamic>{
        'channel': 'web',
        'is_enabled': true,
        'is_visible': true,
        'show_in_navigation': false,
        'show_on_home': true,
        'sort_order': 4,
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
  int mutationCount = 0;

  @override
  Future<AdminFeatureDetailSnapshot> loadOne(String featureKey) async {
    final index = loadCount++;
    final outcome = outcomes[index.clamp(0, outcomes.length - 1)];
    if (outcome is Future<AdminFeatureDetailSnapshot>) return outcome;
    if (outcome is AdminFeatureDetailSnapshot) return outcome;
    throw outcome;
  }

  @override
  Future<AdminFeaturesSnapshot> loadAll() async {
    final detail = await loadOne(_featureKey);
    return AdminFeaturesSnapshot(
      features: detail.feature == null
          ? const <AdminManagedFeature>[]
          : <AdminManagedFeature>[detail.feature!],
    );
  }

  Future<void> _mutate() async {
    mutationCount += 1;
  }

  @override
  Future<void> setGlobalEnabled(String featureId, bool enabled) => _mutate();

  @override
  Future<void> setVisibility(String featureId, String visibility) => _mutate();

  @override
  Future<void> updateChannel(
    String featureId,
    String channel,
    Map<String, dynamic> updates,
  ) => _mutate();

  @override
  Future<void> updateRules(String featureId, Map<String, dynamic> updates) =>
      _mutate();
}
