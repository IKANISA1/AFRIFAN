import 'dart:async';

import 'package:core_auth/core_auth.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_settings/src/models/user_privacy_settings.dart';
import 'package:feat_settings/src/screens/privacy_settings_screen.dart';
import 'package:feat_settings/src/settings_providers.dart';
import 'package:feat_settings/src/settings_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:test_support/app_font_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadAppFonts);

  testWidgets('golden Privacy route loading state', (tester) async {
    await _pumpPrivacyStateGolden(
      tester,
      id: 'loading',
      overrides: <Override>[
        privacySettingsProvider.overrideWith(
          (ref) => Completer<UserPrivacySettings?>().future,
        ),
      ],
      settle: false,
      beforeCapture: (tester) async {
        expect(find.text('Loading privacy settings'), findsOneWidget);
        expect(
          find.text('Checking your saved privacy choices.'),
          findsOneWidget,
        );
      },
    );
  });

  testWidgets('golden Privacy route empty state', (tester) async {
    await _pumpPrivacyStateGolden(
      tester,
      id: 'empty',
      profile: null,
      beforeCapture: (tester) async {
        expect(find.text('Privacy settings unavailable'), findsOneWidget);
        expect(
          find.text('Sign in to review and manage your privacy choices.'),
          findsOneWidget,
        );
      },
    );
  });

  testWidgets('golden Privacy route error state', (tester) async {
    await _pumpPrivacyStateGolden(
      tester,
      id: 'error',
      reader: const _ThrowingPrivacySettingsReader(
        'privacy row supporter-991 failed',
      ),
      beforeCapture: (tester) async {
        expect(find.text('Could not load privacy settings.'), findsOneWidget);
        expect(find.textContaining('991'), findsNothing);
      },
    );
  });

  testWidgets('golden Privacy route offline state', (tester) async {
    await _pumpPrivacyStateGolden(
      tester,
      id: 'offline',
      online: false,
      beforeCapture: (tester) async {
        expect(find.text('Saved privacy settings'), findsOneWidget);
        expect(
          tester
              .widget<AfriSwitchListTile>(
                find.byKey(const ValueKey<String>('privacy-analytics-toggle')),
              )
              .onChanged,
          isNull,
        );
        expect(
          tester
              .widget<AfriButton>(
                find.byKey(const ValueKey<String>('privacy-save-action')),
              )
              .enabled,
          isFalse,
        );
      },
    );
  });

  testWidgets('golden Privacy route permission-denied state', (tester) async {
    await _pumpPrivacyStateGolden(
      tester,
      id: 'permission_denied',
      reader: const _ThrowingPrivacySettingsReader(
        'row-level security rejected supporter-991',
      ),
      beforeCapture: (tester) async {
        expect(find.text('Privacy access limited'), findsOneWidget);
        expect(find.textContaining('991'), findsNothing);
      },
    );
  });

  testWidgets('golden Privacy route disabled state', (tester) async {
    await _pumpPrivacyStateGolden(
      tester,
      id: 'disabled',
      overrides: <Override>[
        privacySettingsEditingEnabledProvider.overrideWithValue(false),
      ],
      beforeCapture: (tester) async {
        expect(find.text('Privacy editing unavailable'), findsOneWidget);
        expect(
          tester
              .widget<AfriSwitchListTile>(
                find.byKey(const ValueKey<String>('privacy-analytics-toggle')),
              )
              .onChanged,
          isNull,
        );
        expect(
          tester
              .widget<AfriButton>(
                find.byKey(const ValueKey<String>('privacy-save-action')),
              )
              .enabled,
          isFalse,
        );
      },
    );
  });

  testWidgets('golden Privacy route focused state', (tester) async {
    final previousHighlightStrategy = FocusManager.instance.highlightStrategy;
    final focusNode = FocusNode();
    addTearDown(
      () => FocusManager.instance.highlightStrategy = previousHighlightStrategy,
    );
    addTearDown(focusNode.dispose);
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;

    await _pumpPrivacyStateGolden(
      tester,
      id: 'focused',
      saveFocusNode: focusNode,
      beforeCapture: (tester) async {
        await tester.tap(
          find.byKey(const ValueKey<String>('privacy-analytics-toggle')),
        );
        await tester.pumpAndSettle();
        focusNode.requestFocus();
        await tester.pumpAndSettle();
        expect(focusNode.hasFocus, isTrue);
      },
    );
  });

  testWidgets('golden Privacy route pressed state', (tester) async {
    GestureDetector? pressedDetector;
    await _pumpPrivacyStateGolden(
      tester,
      id: 'pressed',
      resetScroll: false,
      beforeCapture: (tester) async {
        final routeList = find
            .descendant(
              of: find.byType(PrivacySettingsScreen),
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

        await tester.tap(
          find.byKey(const ValueKey<String>('privacy-analytics-toggle')),
        );
        await tester.pumpAndSettle();
        final action = find.byKey(
          const ValueKey<String>('privacy-save-action'),
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

  testWidgets('golden Privacy route selected state', (tester) async {
    await _pumpPrivacyStateGolden(
      tester,
      id: 'selected',
      settings: _analyticsEnabledSettings,
      beforeCapture: (tester) async {
        final selectedSemantics = find
            .ancestor(
              of: find.byKey(
                const ValueKey<String>('privacy-analytics-toggle'),
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

  testWidgets('golden Privacy route large-text state', (tester) async {
    await _pumpPrivacyStateGolden(
      tester,
      id: 'large_text',
      size: const Size(320, 720),
      textScale: 2,
      beforeCapture: (tester) async {
        final routeScrollable = find
            .descendant(
              of: find.byType(PrivacySettingsScreen),
              matching: find.byType(Scrollable),
            )
            .first;
        final sessionsAction = find.byKey(
          const ValueKey<String>('privacy-sessions-action'),
        );
        await tester.scrollUntilVisible(
          sessionsAction,
          220,
          scrollable: routeScrollable,
        );
        await tester.pumpAndSettle();
        expect(sessionsAction, findsOneWidget);
        expect(tester.takeException(), isNull);
        tester.state<ScrollableState>(routeScrollable).position.jumpTo(0);
        await tester.pumpAndSettle();
      },
    );
  });

  testWidgets('golden Privacy route reduced-motion state', (tester) async {
    await _pumpPrivacyStateGolden(
      tester,
      id: 'reduced_motion',
      reduceMotion: true,
      beforeCapture: (tester) async {
        final mediaQuery = MediaQuery.of(
          tester.element(find.byType(PrivacySettingsScreen)),
        );
        expect(mediaQuery.disableAnimations, isTrue);
        expect(mediaQuery.accessibleNavigation, isTrue);
      },
    );
  });

  testWidgets('golden Privacy route dark state', (tester) async {
    await _pumpPrivacyStateGolden(
      tester,
      id: 'dark',
      brightness: Brightness.dark,
      beforeCapture: (tester) async {
        expect(
          Theme.of(
            tester.element(find.byType(PrivacySettingsScreen)),
          ).brightness,
          Brightness.dark,
        );
      },
    );
  });

  testWidgets('golden Privacy route light state', (tester) async {
    await _pumpPrivacyStateGolden(
      tester,
      id: 'light',
      brightness: Brightness.light,
      beforeCapture: (tester) async {
        expect(
          Theme.of(
            tester.element(find.byType(PrivacySettingsScreen)),
          ).brightness,
          Brightness.light,
        );
      },
    );
  });

  testWidgets('golden Privacy route syncing state', (tester) async {
    final saveCompleter = Completer<UserPrivacySettings>();
    final writer = _BlockingPrivacySettingsWriter(saveCompleter);
    await _pumpPrivacyStateGolden(
      tester,
      id: 'syncing',
      writer: writer,
      beforeCapture: (tester) async {
        await tester.tap(
          find.byKey(const ValueKey<String>('privacy-analytics-toggle')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey<String>('privacy-save-action')),
        );
        await tester.pump();
        expect(find.text('Saving privacy settings'), findsOneWidget);
        expect(find.text('PRIVACY CONTROLS'), findsOneWidget);
        expect(writer.saveCount, 1);
      },
      afterCapture: (tester) async {
        saveCompleter.complete(_analyticsEnabledSettings);
        await tester.pumpAndSettle();
      },
    );
  });

  testWidgets('golden Privacy route conflict state', (tester) async {
    await _pumpPrivacyStateGolden(
      tester,
      id: 'conflict',
      writer: const _ThrowingPrivacySettingsWriter(
        SettingsConflictException('Privacy settings'),
      ),
      beforeCapture: (tester) async {
        await tester.tap(
          find.byKey(const ValueKey<String>('privacy-analytics-toggle')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey<String>('privacy-save-action')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Privacy settings changed elsewhere'), findsOneWidget);
        expect(find.text('PRIVACY CONTROLS'), findsOneWidget);
      },
    );
  });

  testWidgets('golden Privacy route security-timeout state', (tester) async {
    final saveCompleter = Completer<UserPrivacySettings>();
    await _pumpPrivacyStateGolden(
      tester,
      id: 'security_timeout',
      writer: _BlockingPrivacySettingsWriter(saveCompleter),
      operationTimeout: const Duration(milliseconds: 1),
      beforeCapture: (tester) async {
        await tester.tap(
          find.byKey(const ValueKey<String>('privacy-analytics-toggle')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey<String>('privacy-save-action')),
        );
        await tester.pump(const Duration(milliseconds: 2));
        await tester.pumpAndSettle();
        expect(find.text('Privacy save not confirmed'), findsOneWidget);
        expect(
          tester
              .widget<AfriButton>(
                find.byKey(const ValueKey<String>('privacy-save-action')),
              )
              .enabled,
          isFalse,
        );
      },
      afterCapture: (tester) async {
        saveCompleter.complete(_analyticsEnabledSettings);
        await tester.pump();
      },
    );
  });
}

Future<void> _pumpPrivacyStateGolden(
  WidgetTester tester, {
  required String id,
  PrivacySettingsReader? reader,
  PrivacySettingsWriter? writer,
  UserPrivacySettings settings = _defaultSettings,
  UserProfile? profile = _profile,
  Duration operationTimeout = const Duration(seconds: 12),
  FocusNode? saveFocusNode,
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
    initialLocation: '/settings/privacy',
    routes: <RouteBase>[
      GoRoute(
        path: '/settings/privacy',
        builder: (context, state) => PrivacySettingsScreen(
          operationTimeout: operationTimeout,
          saveFocusNode: saveFocusNode,
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
        currentUserProvider.overrideWith((ref) => profile),
        privacySettingsReaderProvider.overrideWithValue(
          reader ?? _ValuePrivacySettingsReader(settings),
        ),
        privacySettingsWriterProvider.overrideWithValue(
          writer ?? const _ValuePrivacySettingsWriter(),
        ),
        ...overrides,
      ],
      child: ClubConfigScope(
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
              child: RepaintBoundary(
                key: const ValueKey<String>('privacy-state-golden'),
                child: child!,
              ),
            );
          },
          theme: ClubTheme.from(
            ClubConfig.fallback(),
            brightness: Brightness.light,
          ),
          darkTheme: ClubTheme.from(
            ClubConfig.fallback(),
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
    const ValueKey<String>('privacy-state-golden'),
  );
  if (resetScroll) {
    await _resetPrivacyRouteScroll(tester, routeBoundary);
  }

  await beforeCapture?.call(tester);
  if (resetScroll) {
    await _resetPrivacyRouteScroll(tester, routeBoundary);
  }

  expect(tester.takeException(), isNull);
  await expectLater(
    routeBoundary,
    matchesGoldenFile(
      'goldens/privacy_state_${id}_${brightness.name}_${size.width.toInt()}x${size.height.toInt()}.png',
    ),
  );

  await afterCapture?.call(tester);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

Future<void> _resetPrivacyRouteScroll(
  WidgetTester tester,
  Finder routeBoundary,
) async {
  final routeLists = find.descendant(
    of: find.descendant(
      of: routeBoundary,
      matching: find.byType(PrivacySettingsScreen),
    ),
    matching: find.byType(ListView),
  );
  if (routeLists.evaluate().isEmpty) return;

  final routeScrollable = find
      .descendant(of: routeLists.first, matching: find.byType(Scrollable))
      .first;
  tester.state<ScrollableState>(routeScrollable).position.jumpTo(0);
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
  id: 'privacy-user',
  clubId: '24',
  displayName: 'Blue Lion',
  publicUserId: '483912',
  languageCode: 'en',
);

const _defaultSettings = UserPrivacySettings(
  userId: 'privacy-user',
  clubId: '24',
  groupVisibility: 'members',
  analyticsEnabled: false,
  momoSmsAutoreadEnabled: false,
  biometricLoginEnabled: true,
  showActivityStatus: true,
  updatedAt: '2026-07-28T05:00:00Z',
);

const _analyticsEnabledSettings = UserPrivacySettings(
  userId: 'privacy-user',
  clubId: '24',
  groupVisibility: 'members',
  analyticsEnabled: true,
  momoSmsAutoreadEnabled: false,
  biometricLoginEnabled: true,
  showActivityStatus: true,
  updatedAt: '2026-07-28T05:00:00Z',
);

class _ValuePrivacySettingsReader implements PrivacySettingsReader {
  const _ValuePrivacySettingsReader(this.settings);

  final UserPrivacySettings? settings;

  @override
  Future<UserPrivacySettings?> load({
    required String userId,
    required String clubId,
  }) async {
    return settings;
  }
}

class _ThrowingPrivacySettingsReader implements PrivacySettingsReader {
  const _ThrowingPrivacySettingsReader(this.message);

  final String message;

  @override
  Future<UserPrivacySettings?> load({
    required String userId,
    required String clubId,
  }) async {
    throw StateError(message);
  }
}

class _ValuePrivacySettingsWriter implements PrivacySettingsWriter {
  const _ValuePrivacySettingsWriter();

  @override
  Future<UserPrivacySettings> save(UserPrivacySettings settings) async {
    return settings;
  }
}

class _BlockingPrivacySettingsWriter implements PrivacySettingsWriter {
  _BlockingPrivacySettingsWriter(this.gate);

  final Completer<UserPrivacySettings> gate;
  int saveCount = 0;

  @override
  Future<UserPrivacySettings> save(UserPrivacySettings settings) {
    saveCount += 1;
    return gate.future;
  }
}

class _ThrowingPrivacySettingsWriter implements PrivacySettingsWriter {
  const _ThrowingPrivacySettingsWriter(this.error);

  final Object error;

  @override
  Future<UserPrivacySettings> save(UserPrivacySettings settings) async {
    throw error;
  }
}
