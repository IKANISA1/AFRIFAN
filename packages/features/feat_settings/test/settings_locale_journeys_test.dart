import 'package:core_l10n/core_l10n.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_settings/src/models/user_notification_settings.dart';
import 'package:feat_settings/src/notification_permission_gateway.dart';
import 'package:feat_settings/src/screens/notification_preferences_screen.dart';
import 'package:feat_settings/src/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => ConnectivityService.setOnlineForTest(true));
  tearDown(() => ConnectivityService.setOnlineForTest(true));

  testWidgets('French notification-settings journey uses the FR catalog', (
    tester,
  ) async {
    await _pumpNotificationSettings(tester, const Locale('fr'));

    expect(find.text('NOTIFICATIONS'), findsOneWidget);
    expect(find.text('RÉCEPTION DES NOTIFICATIONS'), findsOneWidget);
    expect(find.text('Alertes activées.'), findsNothing);
    expect(find.text('Enregistrer'), findsOneWidget);
    expect(find.text('NOTIFICATION DELIVERY'), findsNothing);
  });

  testWidgets('Kinyarwanda notification-settings journey uses the RW catalog', (
    tester,
  ) async {
    await _pumpNotificationSettings(tester, const Locale('rw'));

    expect(find.text('AMATANGAZO'), findsOneWidget);
    expect(find.text('KWAKIRA AMATANGAZO'), findsOneWidget);
    expect(find.text('Bika'), findsOneWidget);
    expect(find.text('NOTIFICATION DELIVERY'), findsNothing);
  });
}

Future<void> _pumpNotificationSettings(
  WidgetTester tester,
  Locale appCopyLocale,
) async {
  final router = GoRouter(
    initialLocation: '/settings/notifications',
    routes: <RouteBase>[
      GoRoute(
        path: '/settings/notifications',
        builder: (context, state) => const NotificationPreferencesScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SizedBox.shrink(),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        notificationSettingsProvider.overrideWith((ref) async => _settings),
        notificationPermissionGatewayProvider.overrideWithValue(
          const _AuthorizedNotificationGateway(),
        ),
      ],
      child: ClubConfigScope(
        config: ClubConfig.fallback(),
        child: MaterialApp.router(
          locale: const Locale('en'),
          builder: (context, child) => AfriLocalizationsScope(
            locale: appCopyLocale,
            child: child ?? const SizedBox.shrink(),
          ),
          routerConfig: router,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

const _settings = UserNotificationSettings(
  userId: 'locale-user',
  clubId: '24',
  pushEnabled: false,
  allowAll: false,
  matchAlerts: false,
  contributionReceipts: false,
  fetMilestones: false,
  teamNews: false,
  challenges: false,
  groupChat: false,
  updatedAt: '2026-07-30T09:00:00Z',
);

class _AuthorizedNotificationGateway implements NotificationPermissionGateway {
  const _AuthorizedNotificationGateway();

  @override
  Future<PushPermissionStatus> getPermissionStatus() async {
    return PushPermissionStatus.authorized;
  }

  @override
  Future<PushPermissionStatus> requestPermission() async {
    return PushPermissionStatus.authorized;
  }

  @override
  Future<void> syncToken() async {}

  @override
  Future<void> unregisterCurrentDevice() async {}
}
