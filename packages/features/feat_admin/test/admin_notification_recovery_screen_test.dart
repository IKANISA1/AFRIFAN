import 'dart:io';
import 'dart:ui' as ui;

import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_admin/feat_admin.dart';
import 'package:feat_admin/src/screens/push_notifications_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_support/app_font_loader.dart';

import '../../../testing/test_support/test/fixtures/local_route_state_assertions.dart';
import 'notification_command_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);
  setUp(() {
    ConnectivityService.setOnlineForTest(true);
    TypographyTokens.debugUseFallbackFonts = true;
  });
  tearDown(() {
    TypographyTokens.debugUseFallbackFonts = false;
    ColorTokens.setBrightness(Brightness.dark);
  });

  testWidgets(
    'relaunch retains original; status unknown never shows retry or a success toast',
    (tester) async {
      final journal = MemoryNotificationJournal();
      final original = _attempt();
      await journal.save(original.scope, null, original.encode());
      final gateway = _Gateway('unknown');
      await _pump(tester, journal, gateway);
      expect(find.text('Original notification request'), findsOneWidget);
      expect(find.text('Matchday alert'), findsOneWidget);
      expect(find.textContaining(original.operationId), findsOneWidget);
      final action = find.byKey(const ValueKey('admin-notification-recover'));
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(gateway.submissions, 0);
      expect(gateway.statusReads, 1);
      expect(journal.values.values.single, original.encode());
      expect(
        find.textContaining('Those delivery attempts will not be sent again.'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('admin-notification-resume')),
        findsNothing,
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('admin-notifications-send')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      final send = tester.widget<AfriButton>(
        find.byKey(const ValueKey('admin-notifications-send')),
      );
      expect(send.enabled, isFalse);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('Original notification request'),
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await _capture(tester, 'notification-original-unknown-390x844.png');
    },
  );

  testWidgets(
    'narrow large-text recovery reviews the retained content and retries only not-admitted identity',
    (tester) async {
      final journal = MemoryNotificationJournal();
      final original = _attempt();
      await journal.save(original.scope, null, original.encode());
      final gateway = _Gateway('not_admitted');
      await _pump(
        tester,
        journal,
        gateway,
        size: const Size(320, 760),
        scale: 2,
      );
      final check = find.byKey(const ValueKey('admin-notification-recover'));
      await tester.scrollUntilVisible(
        check,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(check);
      await tester.pumpAndSettle();
      expect(gateway.submissions, 0);
      final resume = find.byKey(const ValueKey('admin-notification-resume'));
      await tester.scrollUntilVisible(
        resume,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(tester.getRect(resume).height, greaterThanOrEqualTo(48));
      expect(find.text('Retry original request'), findsOneWidget);
      final label = tester.renderObject<RenderParagraph>(
        find.descendant(
          of: resume,
          matching: find.text('Retry original request'),
        ),
      );
      expect(label.didExceedMaxLines, isFalse);
      expect(tester.takeException(), isNull);
      await _capture(
        tester,
        'notification-original-review-320x760-large-text.png',
      );
      await tester.tap(resume);
      await tester.pumpAndSettle();
      expect(gateway.submissions, 1);
      expect(gateway.operations.toSet(), {original.operationId});
      expect(journal.values, isEmpty);
      expect(
        find.byKey(const ValueKey('admin-notification-original-request')),
        findsNothing,
      );
    },
  );
}

AdminNotificationAttempt _attempt() => AdminNotificationAttempt(
  userId: notificationTestUser,
  clubId: 24,
  operationId: notificationTestOperation,
  arguments: {
    'title': 'Matchday alert',
    'body': 'Kickoff soon.',
    'audience': 'all_fans',
    'delivery_mode': 'send_now',
  },
);

class _Gateway implements AdminNotificationsGateway {
  _Gateway(this.state);
  final String state;
  int submissions = 0, statusReads = 0;
  final operations = <String>[];
  @override
  AdminNotificationOwner captureOwner() => notificationTestOwner();
  @override
  Future<AdminNotificationsSnapshot> load() async =>
      const AdminNotificationsSnapshot.empty();
  @override
  Future<Map<String, dynamic>> command(
    AdminNotificationAttempt attempt,
    bool submit,
  ) async {
    operations.add(attempt.operationId);
    if (submit) {
      submissions++;
    } else {
      statusReads++;
    }
    return notificationTestReceipt(
      attempt,
      state: submit ? 'completed' : state,
      status: state == 'unknown' && !submit ? 'unknown' : 'sent',
      unknown: state == 'unknown' && !submit ? 1 : 0,
      sent: state == 'unknown' && !submit ? 0 : 1,
    );
  }
}

Future<void> _pump(
  WidgetTester tester,
  MemoryNotificationJournal journal,
  _Gateway gateway, {
  Size size = const Size(390, 844),
  double scale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final config = localRouteConfigOrFallback();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        adminNotificationJournalProvider.overrideWithValue(journal),
        adminNotificationsGatewayProvider.overrideWithValue(gateway),
      ],
      child: ClubConfigScope(
        config: config,
        child: MaterialApp(
          theme: ClubTheme.from(config, brightness: Brightness.dark),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const RepaintBoundary(
            key: ValueKey('notification-capture'),
            child: PushNotificationsScreen(),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _capture(WidgetTester tester, String name) async {
  const captureDirectory = String.fromEnvironment(
    'NOTIFICATION_CAPTURE_DIRECTORY',
  );
  if (captureDirectory.isEmpty) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('notification-capture')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final directory = Directory(captureDirectory);
    if (directory.existsSync()) {
      await File(
        '${directory.path}/$name',
      ).writeAsBytes(data!.buffer.asUint8List());
    }
  });
}
