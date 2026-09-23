import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_admin/feat_admin.dart';
import 'package:feat_admin/src/screens/push_notifications_screen.dart';
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
    final pending = Completer<AdminNotificationsSnapshot>();
    await _pump(tester, _Gateway(<Object>[pending.future]), settle: false);
    expect(find.text('Loading notification workspace'), findsOneWidget);
    await _golden(tester, 'loading');
    pending.complete(_workspace);
    await tester.pumpAndSettle();
  });
  testWidgets('empty', (tester) async {
    await _pump(
      tester,
      _Gateway(const <Object>[AdminNotificationsSnapshot.empty()]),
    );
    await _scrollTo(
      tester,
      find.byKey(const ValueKey<String>('admin-notifications-state-empty')),
    );
    expect(find.text('No notification history'), findsOneWidget);
    await _golden(tester, 'empty');
  });
  testWidgets('error is private', (tester) async {
    await _pump(tester, _Gateway(<Object>[StateError('private-id')]));
    expect(find.text('Notification workspace unavailable'), findsOneWidget);
    expect(find.textContaining('private-id'), findsNothing);
    await _golden(tester, 'error');
  });
  testWidgets('offline', (tester) async {
    await _pump(tester, _Gateway(<Object>[_workspace]), online: false);
    expect(find.text('Notification workspace offline'), findsOneWidget);
    await _golden(tester, 'offline');
  });
  testWidgets('permission denied', (tester) async {
    await _pump(
      tester,
      _Gateway(const <Object>[
        AdminNotificationsFailure(
          AdminNotificationsFailureKind.permissionDenied,
        ),
      ]),
    );
    expect(find.text('Notification access unavailable'), findsOneWidget);
    await _golden(tester, 'permission_denied');
  });
  testWidgets('disabled', (tester) async {
    await _pump(tester, _Gateway(<Object>[_workspace]), enabled: false);
    expect(find.text('Notification management unavailable'), findsOneWidget);
    await _golden(tester, 'disabled');
  });
  testWidgets('selected audience', (tester) async {
    await _pump(tester, _Gateway(<Object>[_workspace]));
    await tester.tap(find.widgetWithText(AfriChoiceChip, 'By tier'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(AfriChoiceChip, 'Gold'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<AfriChoiceChip>(find.widgetWithText(AfriChoiceChip, 'Gold'))
          .selected,
      isTrue,
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
    final action = find.byKey(
      const ValueKey<String>('admin-notifications-send'),
    );
    await _scrollTo(tester, action);
    final gesture = await tester.startGesture(tester.getCenter(action));
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
        tester.element(find.byType(PushNotificationsScreen)),
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
  testWidgets('syncing retains history', (tester) async {
    final pending = Completer<AdminNotificationsSnapshot>();
    final container = await _pump(
      tester,
      _Gateway(<Object>[_workspace, pending.future]),
    );
    unawaited(container.read(adminNotificationsProvider.notifier).refresh());
    await tester.pump();
    expect(find.text('Checking delivery information'), findsOneWidget);
    expect(
      container.read(adminNotificationsProvider).requireValue.history,
      hasLength(1),
    );
    await _golden(tester, 'syncing');
    pending.complete(_workspace);
    await tester.pumpAndSettle();
  });
  testWidgets('conflict retains history', (tester) async {
    final container = await _pump(
      tester,
      _Gateway(<Object>[
        _workspace,
        const AdminNotificationsFailure(AdminNotificationsFailureKind.conflict),
      ]),
    );
    await container.read(adminNotificationsProvider.notifier).refresh();
    await tester.pump();
    expect(find.text('Delivery information changed'), findsOneWidget);
    expect(
      container.read(adminNotificationsProvider).requireValue.history,
      hasLength(1),
    );
    await _golden(tester, 'conflict');
  });
  testWidgets('timeout retains history', (tester) async {
    final container = await _pump(
      tester,
      _Gateway(<Object>[_workspace, TimeoutException('private-id')]),
    );
    await container.read(adminNotificationsProvider.notifier).refresh();
    await tester.pump();
    expect(find.text('Security check timed out'), findsOneWidget);
    expect(find.textContaining('private-id'), findsNothing);
    expect(
      container.read(adminNotificationsProvider).requireValue.history,
      hasLength(1),
    );
    await _golden(tester, 'security_timeout');
  });
}

Future<ProviderContainer> _pump(
  WidgetTester tester,
  AdminNotificationsGateway gateway, {
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
    initialLocation: '/admin/notifications',
    routes: <RouteBase>[
      GoRoute(
        path: '/admin/notifications',
        builder: (_, _) =>
            PushNotificationsScreen(firstActionFocusNode: focusNode),
      ),
    ],
  );
  addTearDown(router.dispose);
  late ProviderContainer container;
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        adminNotificationsGatewayProvider.overrideWithValue(gateway),
        adminNotificationsEnabledProvider.overrideWithValue(enabled),
      ],
      child: Consumer(
        builder: (context, ref, _) {
          container = ProviderScope.containerOf(context);
          return ClubConfigScope(
            config: ClubConfig.fallback(),
            child: MaterialApp.router(
              debugShowCheckedModeBanner: false,
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
  matchesGoldenFile('goldens/admin_notifications_state_${state}_390x844.png'),
);

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    320,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

final _workspace = AdminNotificationsSnapshot.fromRaw(<String, dynamic>{
  'groups': <Map<String, dynamic>>[
    <String, dynamic>{'id': 'group-1', 'name': 'Blue Family'},
  ],
  'history': <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 'notification-1',
      'title': 'Match day',
      'body': 'Gates open at 16:00.',
      'audience_type': 'all_fans',
      'audience_tier': null,
      'audience_group_name': null,
      'delivery_mode': 'send_now',
      'status': 'sent',
      'scheduled_at': null,
      'sent_at': '2026-07-30T08:00:00Z',
      'requested_recipient_count': 1200,
      'sent_count': 1180,
      'failed_count': 20,
      'created_at': '2026-07-30T07:58:00Z',
    },
  ],
});

class _Gateway implements AdminNotificationsGateway {
  _Gateway(this.outcomes);
  final List<Object> outcomes;
  int count = 0;
  @override
  Future<AdminNotificationsSnapshot> load() async {
    final index = count++;
    final value = outcomes[index.clamp(0, outcomes.length - 1)];
    if (value is Future<AdminNotificationsSnapshot>) return value;
    if (value is AdminNotificationsSnapshot) return value;
    throw value;
  }

  @override
  Future<AdminNotificationDelivery> send(AdminNotificationDraft draft) async {
    return const AdminNotificationDelivery(
      status: 'sent',
      requestedCount: 1,
      sentCount: 1,
      failedCount: 0,
    );
  }
}
