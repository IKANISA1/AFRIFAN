import 'dart:async';

import 'package:core_auth/core_auth.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_settings/src/models/user_notification_settings.dart';
import 'package:feat_settings/src/models/user_privacy_settings.dart';
import 'package:feat_settings/src/notification_permission_gateway.dart';
import 'package:feat_settings/src/screens/edit_profile_screen.dart';
import 'package:feat_settings/src/screens/notification_preferences_screen.dart';
import 'package:feat_settings/src/screens/privacy_settings_screen.dart';
import 'package:feat_settings/src/screens/settings_screen.dart';
import 'package:feat_settings/src/settings_providers.dart';
import 'package:feat_settings/src/widgets/settings_overlays.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => ConnectivityService.setOnlineForTest(true));

  testWidgets('sign-out confirmation supports cancellation and confirmation', (
    tester,
  ) async {
    await tester.pumpWidget(const _OverlayHarness());

    await tester.tap(find.text('Open sign-out'));
    await tester.pumpAndSettle();
    expect(find.text('Sign out?'), findsOneWidget);

    await tester.tap(find.text('Stay'));
    await tester.pumpAndSettle();
    expect(find.text('Result: cancelled'), findsOneWidget);

    await tester.tap(find.text('Open sign-out'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Result: confirmed'), findsOneWidget);
  });

  testWidgets('delete account requires typed confirmation and can cancel', (
    tester,
  ) async {
    await tester.pumpWidget(const _OverlayHarness());

    await tester.tap(find.text('Open delete'));
    await tester.pumpAndSettle();
    expect(find.text('DELETE your account?'), findsOneWidget);
    expect(
      tester
          .widget<AfriButton>(
            find.widgetWithText(AfriButton, 'Delete permanently'),
          )
          .enabled,
      isFalse,
    );

    await tester.enterText(find.byType(TextField), 'DELETE');
    await tester.pump();
    expect(
      tester
          .widget<AfriButton>(
            find.widgetWithText(AfriButton, 'Delete permanently'),
          )
          .enabled,
      isTrue,
    );

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Result: cancelled'), findsOneWidget);
  });

  testWidgets(
    '200 percent text keeps sign-out sheet and delete dialog actions reachable',
    (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(const _OverlayHarness());

      await tester.tap(find.text('Open sign-out'));
      await tester.pumpAndSettle();
      final signOut = find.widgetWithText(AfriButton, 'Sign out');
      final stay = find.widgetWithText(AfriButton, 'Stay');
      await tester.ensureVisible(signOut);
      await tester.ensureVisible(stay);
      expect(tester.takeException(), isNull);
      await tester.tap(stay);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open delete'));
      await tester.pumpAndSettle();
      final input = find.byType(TextField);
      final cancel = find.text('Cancel');
      final delete = find.widgetWithText(AfriButton, 'Delete permanently');
      await tester.ensureVisible(input);
      await tester.ensureVisible(cancel);
      await tester.ensureVisible(delete);
      expect(tester.takeException(), isNull);
      await tester.tap(cancel);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open notifications'));
      await tester.pumpAndSettle();
      final enable = find.widgetWithText(AfriButton, 'Enable notifications');
      final later = find.text('Maybe later');
      await tester.ensureVisible(enable);
      await tester.ensureVisible(later);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('support-unavailable state is explicit and recoverable', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildSettingsHarness(
        initialLocation: '/settings',
        supportWhatsApp: null,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Support contact unavailable'), findsOneWidget);
    final supportRow = find.widgetWithText(AfriListRow, 'Help & support');
    await tester.scrollUntilVisible(supportRow, 240);
    await tester.pumpAndSettle();
    expect(tester.widget<AfriListRow>(supportRow).enabled, isFalse);
    expect(find.text('Not configured'), findsOneWidget);
  });

  testWidgets('missing profile offers a deterministic reauthentication path', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildSettingsHarness(
        initialLocation: '/settings/edit-profile',
        profile: null,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('profile-unavailable')), findsOneWidget);
    expect(
      find.text(
        'Your profile is unavailable. Sign in again to recover your account.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Sign in again'));
    await tester.pumpAndSettle();
    expect(find.text('Sign-in recovery'), findsOneWidget);
    expect(find.text('from:/settings/edit-profile'), findsOneWidget);
  });

  testWidgets(
    'profile save failure is announced, retains nickname, and restores field focus',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _buildSettingsHarness(
          initialLocation: '/settings/edit-profile',
          profile: _profile,
          overrides: <Override>[
            authStateProvider.overrideWith(_FailingProfileAuthNotifier.new),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final nicknameField = find.widgetWithText(AfriInputField, 'Nickname');
      await tester.enterText(nicknameField, 'Blue Lion');
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(
        find.descendant(of: nicknameField, matching: find.byType(TextField)),
      );
      expect(textField.controller?.text, 'Blue Lion');
      expect(textField.autofillHints, contains(AutofillHints.nickname));
      expect(
        find.bySemanticsLabel(
          'Nickname. Error: Profile service is temporarily unavailable.',
        ),
        findsOneWidget,
      );
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'Nickname');
      semantics.dispose();
    },
  );

  testWidgets(
    '200 percent text keeps profile error and save recovery reachable',
    (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        _buildSettingsHarness(
          initialLocation: '/settings/edit-profile',
          profile: _profile,
          overrides: <Override>[
            authStateProvider.overrideWith(_FailingProfileAuthNotifier.new),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final nicknameField = find.widgetWithText(AfriInputField, 'Nickname');
      final save = find.widgetWithText(AfriButton, 'Save changes');
      await tester.enterText(nicknameField, 'Blue Lion');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();

      final error = find
          .text('Profile service is temporarily unavailable.')
          .first;
      await tester.ensureVisible(nicknameField);
      await tester.ensureVisible(error);
      await tester.ensureVisible(save);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('profile save blocks duplicates and retains the busy draft', (
    tester,
  ) async {
    final gate = Completer<String?>();
    final notifier = _BlockingProfileAuthNotifier(gate);
    await tester.pumpWidget(
      _buildSettingsHarness(
        initialLocation: '/settings/edit-profile',
        profile: _profile,
        overrides: <Override>[authStateProvider.overrideWith(() => notifier)],
      ),
    );
    await tester.pumpAndSettle();

    final nicknameField = find.widgetWithText(AfriInputField, 'Nickname');
    await tester.enterText(nicknameField, 'Blue Lion');
    await tester.tap(find.text('Save changes'));
    await tester.pump();
    await tester.tap(find.text('Saving…'), warnIfMissed: false);
    await tester.pump();

    expect(notifier.updateCount, 1);
    expect(
      tester
          .widget<TextField>(
            find.descendant(
              of: nicknameField,
              matching: find.byType(TextField),
            ),
          )
          .controller
          ?.text,
      'Blue Lion',
    );
    expect(
      tester
          .widget<AfriButton>(find.widgetWithText(AfriButton, 'Saving…'))
          .enabled,
      isFalse,
    );

    gate.complete('Profile service is temporarily unavailable.');
    await tester.pumpAndSettle();
    expect(notifier.updateCount, 1);
  });

  testWidgets(
    'keyboard-open profile keeps the active field, error, and save reachable',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 320);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(
        _buildSettingsHarness(
          initialLocation: '/settings/edit-profile',
          profile: _profile,
          overrides: <Override>[
            authStateProvider.overrideWith(_FailingProfileAuthNotifier.new),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final nicknameField = find.widgetWithText(AfriInputField, 'Nickname');
      final save = find.widgetWithText(AfriButton, 'Save changes');
      await tester.showKeyboard(nicknameField);
      await tester.enterText(nicknameField, 'Blue Lion');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();

      final error = find
          .descendant(
            of: nicknameField,
            matching: find.text('Profile service is temporarily unavailable.'),
          )
          .first;
      await tester.ensureVisible(nicknameField);
      await tester.pumpAndSettle();
      _expectInKeyboardViewport(tester, nicknameField);
      _expectInKeyboardViewport(tester, error);
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      _expectInKeyboardViewport(tester, save);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('notification denial is announced and remains recoverable', (
    tester,
  ) async {
    final gateway = _FakeNotificationGateway(
      status: PushPermissionStatus.notDetermined,
      requestedStatus: PushPermissionStatus.denied,
    );
    await tester.pumpWidget(
      _buildSettingsHarness(
        initialLocation: '/settings/notifications',
        profile: _profile,
        overrides: <Override>[
          notificationPermissionGatewayProvider.overrideWithValue(gateway),
          notificationSettingsProvider.overrideWith(
            (ref) async => UserNotificationSettings.defaults(
              userId: _profile.id,
              clubId: _profile.clubId,
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Enable alerts'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enable notifications'));
    await tester.pumpAndSettle();

    expect(
      find.text('Notifications blocked. Enable in device settings.'),
      findsOneWidget,
    );
    expect(
      find.text('System notifications are blocked at the device level.'),
      findsOneWidget,
    );
    expect(gateway.requestCount, 1);
  });

  testWidgets('privacy loading and error states expose retry recovery', (
    tester,
  ) async {
    var attempts = 0;
    final pending = Completer<UserPrivacySettings?>();
    await tester.pumpWidget(
      _buildSettingsHarness(
        initialLocation: '/settings/privacy',
        profile: _profile,
        overrides: <Override>[
          privacySettingsProvider.overrideWith((ref) {
            attempts += 1;
            if (attempts == 1) {
              return pending.future;
            }
            return Future<UserPrivacySettings?>.value(
              UserPrivacySettings.defaults(
                userId: _profile.id,
                clubId: _profile.clubId,
              ),
            );
          }),
        ],
      ),
    );
    await tester.pump();
    expect(find.text('Loading privacy settings'), findsOneWidget);

    pending.completeError(StateError('simulated privacy failure'));
    await tester.pumpAndSettle();
    expect(find.text('Could not load privacy settings.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Your data'), findsOneWidget);
    expect(attempts, 2);
  });

  testWidgets('notification repository errors expose retry recovery', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      _buildSettingsHarness(
        initialLocation: '/settings/notifications',
        profile: _profile,
        overrides: <Override>[
          notificationPermissionGatewayProvider.overrideWithValue(
            _FakeNotificationGateway(status: PushPermissionStatus.unavailable),
          ),
          notificationSettingsProvider.overrideWith((ref) async {
            attempts += 1;
            if (attempts == 1) {
              throw StateError('simulated notification failure');
            }
            return UserNotificationSettings.defaults(
              userId: _profile.id,
              clubId: _profile.clubId,
            );
          }),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Could not load notification settings.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Notification delivery'), findsOneWidget);
    expect(attempts, 2);
  });

  testWidgets('privacy keeps the draft visible and blocks saves offline', (
    tester,
  ) async {
    ConnectivityService.setOnlineForTest(false);
    var loads = 0;
    await tester.pumpWidget(
      _buildSettingsHarness(
        initialLocation: '/settings/privacy',
        profile: _profile,
        overrides: <Override>[
          privacySettingsProvider.overrideWith((ref) async {
            loads += 1;
            return UserPrivacySettings.defaults(
              userId: _profile.id,
              clubId: _profile.clubId,
            );
          }),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Saved privacy settings'), findsOneWidget);
    expect(
      find.textContaining('Reconnect before changing or saving'),
      findsOneWidget,
    );
    final save = find.widgetWithText(AfriButton, 'Connection required');
    await tester.ensureVisible(save.first);
    expect(tester.widget<AfriButton>(save.first).enabled, isFalse);

    ConnectivityService.setOnlineForTest(true);
    await tester.pumpAndSettle();

    expect(loads, 2);
    expect(find.text('Saved privacy settings'), findsNothing);
    expect(find.text('No changes to save'), findsOneWidget);
  });

  testWidgets(
    'notifications keep saved values visible and block delivery changes offline',
    (tester) async {
      ConnectivityService.setOnlineForTest(false);
      await tester.pumpWidget(
        _buildSettingsHarness(
          initialLocation: '/settings/notifications',
          profile: _profile,
          overrides: <Override>[
            notificationPermissionGatewayProvider.overrideWithValue(
              _FakeNotificationGateway(status: PushPermissionStatus.authorized),
            ),
            notificationSettingsProvider.overrideWith(
              (ref) async => UserNotificationSettings.defaults(
                userId: _profile.id,
                clubId: _profile.clubId,
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Saved notification settings'), findsOneWidget);
      for (final key in <String>[
        'notifications-delivery-action',
        'notifications-save-action',
      ]) {
        final action = find.byKey(ValueKey<String>(key));
        await tester.ensureVisible(action);
        final button = tester.widget<AfriButton>(action);
        expect(button.label, 'Connection required');
        expect(button.enabled, isFalse, reason: key);
      }
    },
  );
}

const _profile = UserProfile(
  id: 'user-1',
  clubId: '24',
  publicUserId: '483912',
  languageCode: 'en',
);

Widget _buildSettingsHarness({
  required String initialLocation,
  UserProfile? profile,
  String? supportWhatsApp = '250000000000',
  List<Override> overrides = const <Override>[],
}) {
  const config = _FakeClubConfig();
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
        routes: <RouteBase>[
          GoRoute(
            path: 'edit-profile',
            builder: (context, state) => const EditProfileScreen(),
          ),
          GoRoute(
            path: 'notifications',
            builder: (context, state) => const NotificationPreferencesScreen(),
          ),
          GoRoute(
            path: 'privacy',
            builder: (context, state) => const PrivacySettingsScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/auth/phone',
        builder: (context, state) => Scaffold(
          body: Column(
            children: <Widget>[
              const Text('Sign-in recovery'),
              Text('from:${state.uri.queryParameters['from']}'),
            ],
          ),
        ),
      ),
    ],
  );

  return ProviderScope(
    overrides: <Override>[
      currentUserProvider.overrideWith((ref) => profile),
      supportWhatsAppProvider.overrideWith((ref) async => supportWhatsApp),
      ...overrides,
    ],
    child: ClubConfigScope(
      config: config,
      child: MaterialApp.router(
        theme: ClubTheme.from(config),
        routerConfig: router,
      ),
    ),
  );
}

void _expectInKeyboardViewport(WidgetTester tester, Finder finder) {
  final visibleBottom =
      tester.view.physicalSize.height / tester.view.devicePixelRatio -
      tester.view.viewInsets.bottom;
  final rect = tester.getRect(finder);
  expect(rect.top, greaterThanOrEqualTo(0));
  expect(rect.bottom, lessThanOrEqualTo(visibleBottom));
}

class _FakeNotificationGateway implements NotificationPermissionGateway {
  _FakeNotificationGateway({required this.status, this.requestedStatus});

  PushPermissionStatus status;
  final PushPermissionStatus? requestedStatus;
  int requestCount = 0;

  @override
  Future<PushPermissionStatus> getPermissionStatus() async => status;

  @override
  Future<PushPermissionStatus> requestPermission() async {
    requestCount += 1;
    status = requestedStatus ?? status;
    return status;
  }

  @override
  Future<void> syncToken() async {}

  @override
  Future<void> unregisterCurrentDevice() async {}
}

class _OverlayHarness extends StatefulWidget {
  const _OverlayHarness();

  @override
  State<_OverlayHarness> createState() => _OverlayHarnessState();
}

class _OverlayHarnessState extends State<_OverlayHarness> {
  String _result = 'none';

  @override
  Widget build(BuildContext context) {
    const config = _FakeClubConfig();
    return ClubConfigScope(
      config: config,
      child: MaterialApp(
        theme: ClubTheme.from(config),
        home: Builder(
          builder: (context) => Scaffold(
            body: Column(
              children: <Widget>[
                AfriButton(
                  label: 'Open sign-out',
                  onTap: () async {
                    final result = await showSignOutConfirmationSheet(context);
                    if (!mounted) return;
                    setState(
                      () => _result = result ? 'confirmed' : 'cancelled',
                    );
                  },
                ),
                AfriButton(
                  label: 'Open delete',
                  onTap: () async {
                    final result = await showDeleteAccountConfirmDialog(
                      context,
                    );
                    if (!mounted) return;
                    setState(
                      () => _result = result ? 'confirmed' : 'cancelled',
                    );
                  },
                ),
                AfriButton(
                  label: 'Open notifications',
                  onTap: () async {
                    final result = await showNotificationPermissionModal(
                      context,
                    );
                    if (!mounted) return;
                    setState(
                      () => _result = result ? 'confirmed' : 'cancelled',
                    );
                  },
                ),
                Text('Result: $_result'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FailingProfileAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthAuthenticated(
    profile: _profile,
    workspace: AdminWorkspaceAccess.none,
  );

  @override
  Future<String?> updateProfile(UserProfile profile) async {
    return 'Profile service is temporarily unavailable.';
  }
}

class _BlockingProfileAuthNotifier extends AuthNotifier {
  _BlockingProfileAuthNotifier(this.gate);

  final Completer<String?> gate;
  int updateCount = 0;

  @override
  AuthState build() => const AuthAuthenticated(
    profile: _profile,
    workspace: AdminWorkspaceAccess.none,
  );

  @override
  Future<String?> updateProfile(UserProfile profile) {
    updateCount += 1;
    return gate.future;
  }
}

class _FakeClubConfig implements ClubConfig {
  const _FakeClubConfig();

  @override
  String get appName => 'Gikundiro';
  @override
  String get clubId => '24';
  @override
  String get clubName => 'Rayon Sports FC';
  @override
  ClubColors get colors => const ClubColors(
    primary: ColorTokens.referenceAccountBlue,
    secondary: ColorTokens.referenceChromeBlack,
    accent: ColorTokens.referenceRewardsVioletHot,
    gradient: <Color>[
      ColorTokens.referenceChromeBlack,
      ColorTokens.referenceAccountBlue,
    ],
  );
  @override
  String get country => 'Rwanda';
  @override
  String get countryCode => 'RW';
  @override
  String get currency => 'RWF';
  @override
  String get currencySymbol => 'RWF';
  @override
  bool get hasChat => true;
  @override
  bool get hasFanClubs => true;
  @override
  bool get hasShop => true;
  @override
  bool get hasSmsLedger => false;
  @override
  bool get hasTicketing => true;
  @override
  String get language => 'en';
  @override
  String get momoPrefix => '*182*';
  @override
  MomoConfig get momo => const MomoConfig(
    ussdTemplate: '*182*{amount}*{momo}#',
    senderName: 'MTN MoMo',
    countryCode: 'RW',
  );
  @override
  String get supabaseAnonKey => 'anon';
  @override
  String get supabaseUrl => 'https://example.supabase.co';
  @override
  List<String> get supportedLanguages => const <String>['en'];
  @override
  String get environment => 'test';
  @override
  Map<String, bool> get features => const <String, bool>{};
}
