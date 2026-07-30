import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_admin/feat_admin.dart';
import 'package:feat_admin/src/screens/sms_sync_monitor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:test_support/app_font_loader.dart';

const _size = Size(390, 844);

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

  testWidgets('loading', (tester) async {
    final pending = Completer<AdminSmsMonitorSnapshot>();
    await _pump(tester, _Gateway(<Object>[pending.future]), settle: false);
    expect(find.text('Loading SMS operations'), findsOneWidget);
    await _golden(tester, 'loading');
    pending.complete(_workspace);
    await tester.pumpAndSettle();
  });

  testWidgets('empty', (tester) async {
    await _pump(
      tester,
      _Gateway(const <Object>[AdminSmsMonitorSnapshot.empty()]),
    );
    expect(find.text('No SMS operations history'), findsOneWidget);
    await _golden(tester, 'empty');
  });

  testWidgets('error is private', (tester) async {
    await _pump(tester, _Gateway(<Object>[StateError('private-id')]));
    expect(find.text('SMS operations unavailable'), findsOneWidget);
    expect(find.textContaining('private-id'), findsNothing);
    await _golden(tester, 'error');
  });

  testWidgets('offline', (tester) async {
    await _pump(tester, _Gateway(<Object>[_workspace]), online: false);
    expect(find.text('SMS operations offline'), findsOneWidget);
    await _golden(tester, 'offline');
  });

  testWidgets('permission denied', (tester) async {
    await _pump(
      tester,
      _Gateway(const <Object>[
        AdminSmsMonitorFailure(AdminSmsMonitorFailureKind.permissionDenied),
      ]),
    );
    expect(find.text('SMS operations access unavailable'), findsOneWidget);
    await _golden(tester, 'permission_denied');
  });

  testWidgets('disabled', (tester) async {
    await _pump(tester, _Gateway(<Object>[_workspace]), enabled: false);
    expect(find.text('SMS operations unavailable'), findsOneWidget);
    await _golden(tester, 'disabled');
  });

  testWidgets('selected metric', (tester) async {
    await _pump(tester, _Gateway(<Object>[_workspace]));
    final metric = find.byKey(
      const ValueKey<String>('admin-sms-metric-device_sync'),
    );
    await tester.tap(metric);
    await tester.pumpAndSettle();
    expect(
      find.text('Four successful synchronizations were reported.'),
      findsOneWidget,
    );
    await _golden(tester, 'selected');
  });

  testWidgets('press and focus', (tester) async {
    final node = FocusNode();
    addTearDown(node.dispose);
    final previousStrategy = FocusManager.instance.highlightStrategy;
    addTearDown(
      () => FocusManager.instance.highlightStrategy = previousStrategy,
    );
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    await _pump(tester, _Gateway(<Object>[_workspace]), focusNode: node);
    final metric = find.byKey(
      const ValueKey<String>('admin-sms-metric-device_sync'),
    );
    final gesture = await tester.startGesture(tester.getCenter(metric));
    await tester.pump(const Duration(milliseconds: 300));
    await _golden(tester, 'pressed');
    await gesture.cancel();
    node.requestFocus();
    await tester.pumpAndSettle();
    expect(node.hasFocus, isTrue);
    await _golden(tester, 'focused');
  });

  testWidgets('large text', (tester) async {
    await _pump(tester, _Gateway(<Object>[_workspace]), scale: 2);
    expect(tester.takeException(), isNull);
    await _golden(tester, 'large_text');
  });

  testWidgets('reduced motion', (tester) async {
    await _pump(tester, _Gateway(<Object>[_workspace]), reduced: true);
    expect(
      AfriMotion.reduceMotion(
        tester.element(find.byType(SmsSyncMonitorScreen)),
      ),
      isTrue,
    );
    await _golden(tester, 'reduced_motion');
  });

  for (final brightness in <Brightness>[Brightness.dark, Brightness.light]) {
    testWidgets(brightness.name, (tester) async {
      await _pump(
        tester,
        _Gateway(<Object>[_workspace]),
        brightness: brightness,
      );
      expect(tester.takeException(), isNull);
      await _golden(tester, brightness.name);
    });
  }

  testWidgets('syncing retains operational information', (tester) async {
    final pending = Completer<AdminSmsMonitorSnapshot>();
    final container = await _pump(
      tester,
      _Gateway(<Object>[_workspace, pending.future]),
    );
    unawaited(container.read(adminSmsMonitorProvider.notifier).refresh());
    await tester.pump();
    expect(find.text('Checking SMS operations'), findsOneWidget);
    expect(
      container.read(adminSmsMonitorProvider).requireValue.metrics,
      hasLength(2),
    );
    await _golden(tester, 'syncing');
    pending.complete(_workspace);
    await tester.pumpAndSettle();
  });

  testWidgets('conflict retains operational information', (tester) async {
    final container = await _pump(
      tester,
      _Gateway(<Object>[
        _workspace,
        const AdminSmsMonitorFailure(AdminSmsMonitorFailureKind.conflict),
      ]),
    );
    await container.read(adminSmsMonitorProvider.notifier).refresh();
    await tester.pump();
    expect(find.text('SMS operations changed'), findsOneWidget);
    expect(
      container.read(adminSmsMonitorProvider).requireValue.metrics,
      hasLength(2),
    );
    await _golden(tester, 'conflict');
  });

  testWidgets('timeout retains operational information', (tester) async {
    final container = await _pump(
      tester,
      _Gateway(<Object>[_workspace, TimeoutException('private-id')]),
    );
    await container.read(adminSmsMonitorProvider.notifier).refresh();
    await tester.pump();
    expect(find.text('Security check timed out'), findsOneWidget);
    expect(find.textContaining('private-id'), findsNothing);
    expect(
      container.read(adminSmsMonitorProvider).requireValue.runs,
      hasLength(1),
    );
    await _golden(tester, 'security_timeout');
  });
}

Future<ProviderContainer> _pump(
  WidgetTester tester,
  AdminSmsMonitorGateway gateway, {
  bool enabled = true,
  bool online = true,
  bool settle = true,
  bool reduced = false,
  double scale = 1,
  Brightness brightness = Brightness.dark,
  FocusNode? focusNode,
}) async {
  tester.view.physicalSize = _size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      FakeAccessibilityFeatures(
        disableAnimations: reduced,
        accessibleNavigation: reduced,
      );
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  ConnectivityService.setOnlineForTest(online);
  ColorTokens.setBrightness(brightness);
  final router = GoRouter(
    initialLocation: '/admin/sms-monitor',
    routes: <RouteBase>[
      GoRoute(
        path: '/admin/sms-monitor',
        builder: (_, _) =>
            SmsSyncMonitorScreen(firstActionFocusNode: focusNode),
      ),
    ],
  );
  addTearDown(router.dispose);
  late ProviderContainer container;
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        adminSmsMonitorGatewayProvider.overrideWithValue(gateway),
        adminSmsMonitorEnabledProvider.overrideWithValue(enabled),
      ],
      child: Consumer(
        builder: (context, ref, _) {
          container = ProviderScope.containerOf(context);
          return ClubConfigScope(
            config: ClubConfig.fallback(),
            child: MaterialApp.router(
              theme: ClubTheme.from(
                ClubConfig.fallback(),
                brightness: brightness,
              ),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  disableAnimations: reduced,
                  accessibleNavigation: reduced,
                ),
                child: child!,
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

Future<void> _golden(WidgetTester tester, String state) => expectLater(
  find.byType(MaterialApp),
  matchesGoldenFile('goldens/admin_sms_state_${state}_390x844.png'),
);

final _workspace = AdminSmsMonitorSnapshot.fromRaw(<String, dynamic>{
  'metrics': <Map<String, dynamic>>[
    _metric(),
    _metric(
      key: 'parsing',
      label: 'Parsing',
      status: 'degraded',
      summary: 'Two messages are waiting for controlled review.',
    ),
  ],
  'runs': <Map<String, dynamic>>[_run()],
});

Map<String, dynamic> _metric({
  String key = 'device_sync',
  String label = 'Device Sync',
  String status = 'healthy',
  String summary = 'Four successful synchronizations were reported.',
}) {
  return <String, dynamic>{
    'metric_key': key,
    'label': label,
    'health_status': status,
    'summary': summary,
    'primary_label': '24h Success',
    'primary_value': 4,
    'secondary_label': '24h Fail',
    'secondary_value': 0,
    'tertiary_label': 'Duplicates',
    'tertiary_value': 2,
    'last_signal_at': '2026-07-30T08:00:00Z',
  };
}

Map<String, dynamic> _run() {
  return <String, dynamic>{
    'id': '11111111-1111-4111-8111-111111111111',
    'status': 'succeeded',
    'trigger': 'manual',
    'scanned_messages': 24,
    'uploaded_messages': 20,
    'duplicate_messages': 4,
    'scan_started_at': '2026-07-30T08:00:00Z',
    'scan_completed_at': '2026-07-30T08:01:00Z',
  };
}

class _Gateway implements AdminSmsMonitorGateway {
  _Gateway(this.outcomes);

  final List<Object> outcomes;
  var loadCount = 0;

  @override
  Future<AdminSmsMonitorSnapshot> load() async {
    final outcome = outcomes[loadCount.clamp(0, outcomes.length - 1)];
    loadCount += 1;
    if (outcome is Future<AdminSmsMonitorSnapshot>) return outcome;
    if (outcome is AdminSmsMonitorSnapshot) return outcome;
    throw outcome;
  }
}
