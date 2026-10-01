import 'dart:async';

import 'package:core_auth/core_auth.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_settings/src/models/user_notification_settings.dart';
import 'package:feat_settings/src/notification_permission_gateway.dart';
import 'package:feat_settings/src/screens/notification_preferences_screen.dart';
import 'package:feat_settings/src/settings_providers.dart';
import 'package:feat_settings/src/settings_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:test_support/app_font_loader.dart';

import '../../../testing/test_support/test/fixtures/local_route_state_assertions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadAppFonts);

  testWidgets('golden Notifications route loading state', (tester) async {
    await _pumpNotificationStateGolden(
      tester,
      id: 'loading',
      overrides: <Override>[
        notificationSettingsProvider.overrideWith(
          (ref) => Completer<UserNotificationSettings?>().future,
        ),
      ],
      settle: false,
      beforeCapture: (tester) async {
        expect(find.text('Loading notifications'), findsOneWidget);
        expect(
          find.text('Checking your saved delivery preference.'),
          findsOneWidget,
        );
      },
    );
  });

  testWidgets('golden Notifications route empty state', (tester) async {
    await _pumpNotificationStateGolden(
      tester,
      id: 'empty',
      profile: null,
      beforeCapture: (tester) async {
        expect(
          find.text('Notification preferences unavailable'),
          findsOneWidget,
        );
        expect(
          find.text('Sign in to manage notification delivery.'),
          findsOneWidget,
        );
      },
    );
  });

  testWidgets('golden Notifications route error state', (tester) async {
    await _pumpNotificationStateGolden(
      tester,
      id: 'error',
      reader: const _ThrowingNotificationSettingsReader(
        'notification row supporter-991 failed',
      ),
      beforeCapture: (tester) async {
        expect(
          find.text('Could not load notification settings.'),
          findsOneWidget,
        );
        expect(find.textContaining('991'), findsNothing);
      },
    );
  });

  testWidgets('golden Notifications route offline state', (tester) async {
    await _pumpNotificationStateGolden(
      tester,
      id: 'offline',
      online: false,
      beforeCapture: (tester) async {
        expect(find.text('Saved notification settings'), findsOneWidget);
        expect(
          tester
              .widget<AfriButton>(
                find.byKey(
                  const ValueKey<String>('notifications-delivery-action'),
                ),
              )
              .enabled,
          isFalse,
        );
        expect(
          tester
              .widget<AfriButton>(
                find.byKey(const ValueKey<String>('notifications-save-action')),
              )
              .enabled,
          isFalse,
        );
      },
    );
  });

  testWidgets('golden Notifications route permission-denied state', (
    tester,
  ) async {
    await _pumpNotificationStateGolden(
      tester,
      id: 'permission_denied',
      reader: const _ThrowingNotificationSettingsReader(
        'row-level security rejected supporter-991',
      ),
      beforeCapture: (tester) async {
        expect(find.text('Notification access limited'), findsOneWidget);
        expect(find.textContaining('991'), findsNothing);
      },
    );
  });

  testWidgets('golden Notifications route disabled state', (tester) async {
    await _pumpNotificationStateGolden(
      tester,
      id: 'disabled',
      gateway: _FakeNotificationGateway(
        status: PushPermissionStatus.unavailable,
      ),
      beforeCapture: (tester) async {
        expect(find.text('Device alerts unavailable'), findsOneWidget);
        expect(
          tester
              .widget<AfriButton>(
                find.byKey(
                  const ValueKey<String>('notifications-delivery-action'),
                ),
              )
              .enabled,
          isFalse,
        );
      },
    );
  });

  testWidgets('golden Notifications route focused state', (tester) async {
    final previousHighlightStrategy = FocusManager.instance.highlightStrategy;
    final focusNode = FocusNode();
    addTearDown(
      () => FocusManager.instance.highlightStrategy = previousHighlightStrategy,
    );
    addTearDown(focusNode.dispose);
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;

    await _pumpNotificationStateGolden(
      tester,
      id: 'focused',
      deliveryFocusNode: focusNode,
      beforeCapture: (tester) async {
        focusNode.requestFocus();
        await tester.pumpAndSettle();
        expect(focusNode.hasFocus, isTrue);
      },
    );
  });

  testWidgets('golden Notifications route pressed state', (tester) async {
    GestureDetector? pressedDetector;
    await _pumpNotificationStateGolden(
      tester,
      id: 'pressed',
      resetScroll: false,
      beforeCapture: (tester) async {
        final routeList = find
            .descendant(
              of: find.byType(NotificationPreferencesScreen),
              matching: find.byType(ListView),
            )
            .first;
        final routeScrollable = find
            .descendant(of: routeList, matching: find.byType(Scrollable))
            .first;
        final routePosition = tester
            .state<ScrollableState>(routeScrollable)
            .position;
        expect(routePosition.pixels, 0);
        final action = find.byKey(
          const ValueKey<String>('notifications-delivery-action'),
        );
        expect(tester.widget<AfriButton>(action).enabled, isTrue);
        final gestureDetector = find
            .descendant(
              of: action,
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is GestureDetector && widget.onTapDown != null,
              ),
            )
            .hitTestable()
            .first;
        pressedDetector = tester.widget<GestureDetector>(gestureDetector);
        pressedDetector!.onTapDown!(
          TapDownDetails(globalPosition: tester.getCenter(gestureDetector)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 240));
        expect(routePosition.pixels, 0);
        final scaleValues = find
            .descendant(of: action, matching: find.byType(ScaleTransition))
            .evaluate()
            .map((element) => (element.widget as ScaleTransition).scale.value)
            .toList(growable: false);
        expect(
          scaleValues.any((value) => value < 1),
          isTrue,
          reason: 'The pressed action must visibly scale down: $scaleValues',
        );
      },
      afterCapture: (tester) async {
        pressedDetector?.onTapCancel?.call();
        await tester.pumpAndSettle();
      },
    );
  });

  testWidgets('golden Notifications route selected state', (tester) async {
    await _pumpNotificationStateGolden(
      tester,
      id: 'selected',
      settings: _enabledSettings,
      beforeCapture: (tester) async {
        expect(find.text('Alerts enabled.'), findsOneWidget);
        expect(find.text('Disable alerts'), findsOneWidget);
        final selectedSemantics = find
            .ancestor(
              of: find.byKey(
                const ValueKey<String>('notifications-delivery-action'),
              ),
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is Semantics && widget.properties.toggled == true,
              ),
            )
            .first;
        expect(
          tester.widget<Semantics>(selectedSemantics).properties.toggled,
          isTrue,
        );
      },
    );
  });

  testWidgets('golden Notifications route large-text state', (tester) async {
    await _pumpNotificationStateGolden(
      tester,
      id: 'large_text',
      size: const Size(320, 720),
      textScale: 2,
      beforeCapture: (tester) async {
        final routeScrollable = find
            .descendant(
              of: find.byType(NotificationPreferencesScreen),
              matching: find.byType(Scrollable),
            )
            .first;
        final saveAction = find.byKey(
          const ValueKey<String>('notifications-save-action'),
        );
        await tester.scrollUntilVisible(
          saveAction,
          220,
          scrollable: routeScrollable,
        );
        await tester.pumpAndSettle();
        expect(saveAction, findsOneWidget);
        expect(tester.takeException(), isNull);
        final scrollableState = tester.state<ScrollableState>(routeScrollable);
        scrollableState.position.jumpTo(0);
        await tester.pumpAndSettle();
      },
    );
  });

  testWidgets('golden Notifications route reduced-motion state', (
    tester,
  ) async {
    await _pumpNotificationStateGolden(
      tester,
      id: 'reduced_motion',
      reduceMotion: true,
      beforeCapture: (tester) async {
        final mediaQuery = MediaQuery.of(
          tester.element(find.byType(NotificationPreferencesScreen)),
        );
        expect(mediaQuery.disableAnimations, isTrue);
        expect(mediaQuery.accessibleNavigation, isTrue);
      },
    );
  });

  testWidgets('golden Notifications route dark state', (tester) async {
    await _pumpNotificationStateGolden(
      tester,
      id: 'dark',
      brightness: Brightness.dark,
      beforeCapture: (tester) async {
        expect(
          Theme.of(
            tester.element(find.byType(NotificationPreferencesScreen)),
          ).brightness,
          Brightness.dark,
        );
      },
    );
  });

  testWidgets('golden Notifications route light state', (tester) async {
    await _pumpNotificationStateGolden(
      tester,
      id: 'light',
      brightness: Brightness.light,
      beforeCapture: (tester) async {
        expect(
          Theme.of(
            tester.element(find.byType(NotificationPreferencesScreen)),
          ).brightness,
          Brightness.light,
        );
      },
    );
  });

  testWidgets('golden Notifications route syncing state', (tester) async {
    final saveCompleter = Completer<UserNotificationSettings>();
    final writer = _BlockingNotificationSettingsWriter(saveCompleter);
    await _pumpNotificationStateGolden(
      tester,
      id: 'syncing',
      writer: writer,
      beforeCapture: (tester) async {
        await tester.tap(
          find.byKey(const ValueKey<String>('notifications-save-action')),
        );
        await tester.pump();
        expect(find.text('Saving notification preferences'), findsOneWidget);
        expect(
          find.text('Enable alerts for matches, receipts & updates.'),
          findsOneWidget,
        );
        expect(writer.saveCount, 1);
      },
      afterCapture: (tester) async {
        saveCompleter.complete(_disabledSettings);
        await tester.pumpAndSettle();
      },
    );
  });

  testWidgets('golden Notifications route conflict state', (tester) async {
    await _pumpNotificationStateGolden(
      tester,
      id: 'conflict',
      writer: const _ThrowingNotificationSettingsWriter(
        SettingsConflictException('Notification settings'),
      ),
      beforeCapture: (tester) async {
        await tester.tap(
          find.byKey(const ValueKey<String>('notifications-save-action')),
        );
        await tester.pumpAndSettle();
        expect(
          find.text('Notification settings changed elsewhere'),
          findsOneWidget,
        );
        expect(find.text('Notification delivery'), findsOneWidget);
      },
    );
  });

  testWidgets('golden Notifications route security-timeout state', (
    tester,
  ) async {
    final saveCompleter = Completer<UserNotificationSettings>();
    await _pumpNotificationStateGolden(
      tester,
      id: 'security_timeout',
      writer: _BlockingNotificationSettingsWriter(saveCompleter),
      operationTimeout: const Duration(milliseconds: 1),
      beforeCapture: (tester) async {
        await tester.tap(
          find.byKey(const ValueKey<String>('notifications-save-action')),
        );
        await tester.pump(const Duration(milliseconds: 2));
        await tester.pumpAndSettle();
        expect(find.text('Notification save not confirmed'), findsOneWidget);
        expect(
          tester
              .widget<AfriButton>(
                find.byKey(const ValueKey<String>('notifications-save-action')),
              )
              .enabled,
          isFalse,
        );
      },
      afterCapture: (tester) async {
        saveCompleter.complete(_disabledSettings);
        await tester.pump();
      },
    );
  });
}

Future<void> _pumpNotificationStateGolden(
  WidgetTester tester, {
  required String id,
  NotificationSettingsReader? reader,
  NotificationSettingsWriter? writer,
  NotificationPermissionGateway? gateway,
  UserNotificationSettings settings = _disabledSettings,
  UserProfile? profile = _profile,
  Duration operationTimeout = const Duration(seconds: 12),
  FocusNode? deliveryFocusNode,
  Size size = const Size(390, 844),
  double textScale = 1,
  bool settle = true,
  bool online = true,
  bool reduceMotion = false,
  bool resetScroll = true,
  Brightness brightness = Brightness.dark,
  List<Override> overrides = const <Override>[],
  Future<void> Function(WidgetTester tester)? beforeCapture,
  Future<void> Function(WidgetTester tester)? afterCapture,
}) async {
  _setGoldenSurface(tester, size, reduceMotion: reduceMotion);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  TypographyTokens.debugUseFallbackFonts = true;
  addTearDown(() => TypographyTokens.debugUseFallbackFonts = false);
  ColorTokens.setBrightness(brightness);
  addTearDown(() => ColorTokens.setBrightness(Brightness.dark));
  ConnectivityService.setOnlineForTest(online);
  addTearDown(() => ConnectivityService.setOnlineForTest(true));

  final router = GoRouter(
    initialLocation: '/settings/notifications',
    routes: <RouteBase>[
      GoRoute(
        path: '/settings/notifications',
        builder: (context, state) => NotificationPreferencesScreen(
          operationTimeout: operationTimeout,
          deliveryFocusNode: deliveryFocusNode,
        ),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Settings destination'))),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: <Override>[
        currentUserProvider.overrideWith((ref) => localRouteProfile(profile)),
        notificationSettingsReaderProvider.overrideWithValue(
          reader ?? _ValueNotificationSettingsReader(settings),
        ),
        notificationSettingsWriterProvider.overrideWithValue(
          writer ?? const _ValueNotificationSettingsWriter(),
        ),
        notificationPermissionGatewayProvider.overrideWithValue(
          gateway ??
              _FakeNotificationGateway(status: PushPermissionStatus.authorized),
        ),
        ...overrides,
      ],
      child: ClubConfigScope(
        config: localRouteConfigOrFallback(),
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          builder: (context, child) {
            final mediaQuery = MediaQuery.of(context);
            return MediaQuery(
              data: mediaQuery.copyWith(
                disableAnimations: reduceMotion,
                accessibleNavigation: reduceMotion,
              ),
              child: RepaintBoundary(
                key: const ValueKey<String>('notifications-state-golden'),
                child: child!,
              ),
            );
          },
          theme: ClubTheme.from(
            localRouteConfigOrFallback(),
            brightness: Brightness.light,
          ),
          darkTheme: ClubTheme.from(
            localRouteConfigOrFallback(),
            brightness: Brightness.dark,
          ),
          themeMode: brightness == Brightness.dark
              ? ThemeMode.dark
              : ThemeMode.light,
          routerConfig: router,
        ),
      ),
    ),
  );

  if (settle) {
    await tester.pump();
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }

  final routeBoundary = find.byKey(
    const ValueKey<String>('notifications-state-golden'),
  );
  if (resetScroll) {
    await _resetNotificationRouteScroll(tester, routeBoundary);
  }

  await beforeCapture?.call(tester);
  if (resetScroll) {
    await _resetNotificationRouteScroll(tester, routeBoundary);
  }

  expect(tester.takeException(), isNull);
  await expectGoldenOrClubAssertions(
    tester,
    routeBoundary,
    'goldens/notifications_state_${id}_${brightness.name}_${size.width.toInt()}x${size.height.toInt()}.png',
    route: '/settings/notifications',
    kind: 'route',
  );

  await afterCapture?.call(tester);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

Future<void> _resetNotificationRouteScroll(
  WidgetTester tester,
  Finder routeBoundary,
) async {
  final routeLists = find.descendant(
    of: routeBoundary,
    matching: find.byType(ListView),
  );
  if (routeLists.evaluate().isEmpty) return;

  final routeScrollable = find
      .descendant(of: routeLists.first, matching: find.byType(Scrollable))
      .first;
  final position = tester.state<ScrollableState>(routeScrollable).position;
  position.jumpTo(0);
  await tester.pump();
}

void _setGoldenSurface(
  WidgetTester tester,
  Size size, {
  required bool reduceMotion,
}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      FakeAccessibilityFeatures(
        disableAnimations: reduceMotion,
        accessibleNavigation: reduceMotion,
      );
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

const _profile = UserProfile(
  id: 'notification-user',
  clubId: '24',
  displayName: 'Blue Lion',
  publicUserId: '483912',
  languageCode: 'en',
);

const _disabledSettings = UserNotificationSettings(
  userId: 'notification-user',
  clubId: '24',
  pushEnabled: false,
  allowAll: false,
  matchAlerts: false,
  contributionReceipts: false,
  fetMilestones: false,
  teamNews: false,
  challenges: false,
  groupChat: false,
  updatedAt: '2026-07-28T04:00:00Z',
);

const _enabledSettings = UserNotificationSettings(
  userId: 'notification-user',
  clubId: '24',
  pushEnabled: true,
  allowAll: true,
  matchAlerts: true,
  contributionReceipts: true,
  fetMilestones: true,
  teamNews: true,
  challenges: true,
  groupChat: true,
  updatedAt: '2026-07-28T04:00:00Z',
);

class _ValueNotificationSettingsReader implements NotificationSettingsReader {
  const _ValueNotificationSettingsReader(this.settings);

  final UserNotificationSettings? settings;

  @override
  Future<UserNotificationSettings?> load({
    required String userId,
    required String clubId,
  }) async {
    return settings;
  }
}

class _ThrowingNotificationSettingsReader
    implements NotificationSettingsReader {
  const _ThrowingNotificationSettingsReader(this.message);

  final String message;

  @override
  Future<UserNotificationSettings?> load({
    required String userId,
    required String clubId,
  }) async {
    throw StateError(message);
  }
}

class _ValueNotificationSettingsWriter implements NotificationSettingsWriter {
  const _ValueNotificationSettingsWriter();

  @override
  Future<UserNotificationSettings> save(
    UserNotificationSettings settings,
  ) async {
    return settings;
  }
}

class _BlockingNotificationSettingsWriter
    implements NotificationSettingsWriter {
  _BlockingNotificationSettingsWriter(this.gate);

  final Completer<UserNotificationSettings> gate;
  int saveCount = 0;

  @override
  Future<UserNotificationSettings> save(UserNotificationSettings settings) {
    saveCount += 1;
    return gate.future;
  }
}

class _ThrowingNotificationSettingsWriter
    implements NotificationSettingsWriter {
  const _ThrowingNotificationSettingsWriter(this.error);

  final Object error;

  @override
  Future<UserNotificationSettings> save(
    UserNotificationSettings settings,
  ) async {
    throw error;
  }
}

class _FakeNotificationGateway implements NotificationPermissionGateway {
  _FakeNotificationGateway({required this.status});

  PushPermissionStatus status;

  @override
  Future<PushPermissionStatus> getPermissionStatus() async => status;

  @override
  Future<PushPermissionStatus> requestPermission() async => status;

  @override
  Future<void> syncToken() async {}

  @override
  Future<void> unregisterCurrentDevice() async {}
}
