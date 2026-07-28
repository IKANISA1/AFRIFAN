import 'dart:async';

import 'package:core_auth/core_auth.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_settings/src/profile_route_content_provider.dart';
import 'package:feat_settings/src/screens/edit_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:test_support/app_font_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadAppFonts);

  testWidgets('golden Edit profile route loading state', (tester) async {
    await _pumpProfileStateGolden(
      tester,
      id: 'loading',
      repository: const _PendingProfileRouteContentRepository(),
      settle: false,
      beforeCapture: (tester) async {
        expect(find.text('Loading profile'), findsOneWidget);
        expect(find.text('Checking your saved profile.'), findsOneWidget);
      },
    );
  });

  testWidgets('golden Edit profile route empty state', (tester) async {
    await _pumpProfileStateGolden(
      tester,
      id: 'empty',
      repository: const _ValueProfileRouteContentRepository(
        ProfileRouteContentSnapshot(profile: null),
      ),
      beforeCapture: (tester) async {
        expect(find.text('Profile unavailable'), findsOneWidget);
        expect(find.text('Sign in again'), findsOneWidget);
      },
    );
  });

  testWidgets('golden Edit profile route error state', (tester) async {
    await _pumpProfileStateGolden(
      tester,
      id: 'error',
      repository: const _ThrowingProfileRouteContentRepository(
        'backend profile row supporter-991 failed',
      ),
      beforeCapture: (tester) async {
        expect(find.text('Could not load profile'), findsOneWidget);
        expect(find.textContaining('991'), findsNothing);
      },
    );
  });

  testWidgets('golden Edit profile route offline state', (tester) async {
    await _pumpProfileStateGolden(
      tester,
      id: 'offline',
      repository: const ProfileRouteContentRepository(),
      online: false,
      beforeCapture: (tester) async {
        expect(find.text('Offline profile'), findsOneWidget);
        expect(find.textContaining('Reconnect to edit'), findsOneWidget);
        expect(
          tester
              .widget<AfriInputField>(
                find.byKey(const ValueKey<String>('profile-nickname-field')),
              )
              .enabled,
          isFalse,
        );
        expect(
          tester
              .widget<AfriButton>(
                find.byKey(const ValueKey<String>('profile-save-action')),
              )
              .enabled,
          isFalse,
        );
      },
    );
  });

  testWidgets('golden Edit profile route permission-denied state', (
    tester,
  ) async {
    await _pumpProfileStateGolden(
      tester,
      id: 'permission_denied',
      repository: const _ThrowingProfileRouteContentRepository(
        'row-level security rejected supporter-991',
      ),
      beforeCapture: (tester) async {
        expect(find.text('Profile access limited'), findsOneWidget);
        expect(find.textContaining('991'), findsNothing);
      },
    );
  });

  testWidgets('golden Edit profile route disabled state', (tester) async {
    await _pumpProfileStateGolden(
      tester,
      id: 'disabled',
      repository: const _ValueProfileRouteContentRepository(
        ProfileRouteContentSnapshot(
          profile: _profile,
          editingEnabled: false,
          message:
              'Profile editing is unavailable. Your saved profile stays visible.',
        ),
      ),
      beforeCapture: (tester) async {
        expect(find.text('Profile editing unavailable'), findsOneWidget);
        expect(
          tester
              .widget<AfriInputField>(
                find.byKey(const ValueKey<String>('profile-nickname-field')),
              )
              .enabled,
          isFalse,
        );
        expect(
          tester
              .widget<AfriButton>(
                find.byKey(const ValueKey<String>('profile-save-action')),
              )
              .enabled,
          isFalse,
        );
      },
    );
  });

  testWidgets('golden Edit profile route focused state', (tester) async {
    final previousHighlightStrategy = FocusManager.instance.highlightStrategy;
    addTearDown(
      () => FocusManager.instance.highlightStrategy = previousHighlightStrategy,
    );
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;

    await _pumpProfileStateGolden(
      tester,
      id: 'focused',
      beforeCapture: (tester) async {
        final field = find.descendant(
          of: find.byKey(const ValueKey<String>('profile-nickname-field')),
          matching: find.byType(TextField),
        );
        await tester.tap(field);
        await tester.pumpAndSettle();
        expect(tester.widget<TextField>(field).focusNode?.hasFocus, isTrue);
      },
    );
  });

  testWidgets('golden Edit profile route pressed state', (tester) async {
    TestGesture? heldGesture;
    await _pumpProfileStateGolden(
      tester,
      id: 'pressed',
      beforeCapture: (tester) async {
        final action = find.byKey(
          const ValueKey<String>('profile-save-action'),
        );
        final gestureDetector = find
            .descendant(
              of: action,
              matching: find.byType(GestureDetector),
            )
            .first;
        heldGesture = await tester.startGesture(
          tester.getCenter(gestureDetector),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 240));
        final scaleValues = find
            .descendant(
              of: action,
              matching: find.byType(ScaleTransition),
            )
            .evaluate()
            .map(
              (element) =>
                  (element.widget as ScaleTransition).scale.value,
            )
            .toList(growable: false);
        expect(
          scaleValues.any((value) => value < 1),
          isTrue,
          reason: 'The pressed action must visibly scale down: $scaleValues',
        );
      },
      afterCapture: (tester) async {
        await heldGesture?.cancel();
        await tester.pumpAndSettle();
      },
    );
  });

  testWidgets('golden Edit profile route selected state', (tester) async {
    await _pumpProfileStateGolden(
      tester,
      id: 'selected',
      beforeCapture: (tester) async {
        final field = find.descendant(
          of: find.byKey(const ValueKey<String>('profile-nickname-field')),
          matching: find.byType(TextField),
        );
        await tester.tap(field);
        final controller = tester.widget<TextField>(field).controller!;
        controller.selection = const TextSelection(
          baseOffset: 0,
          extentOffset: 4,
        );
        await tester.pumpAndSettle();
        expect(controller.selection.isCollapsed, isFalse);
      },
    );
  });

  testWidgets('golden Edit profile route large-text state', (tester) async {
    await _pumpProfileStateGolden(
      tester,
      id: 'large_text',
      size: const Size(320, 720),
      textScale: 2,
      resetScroll: false,
      beforeCapture: (tester) async {
        final routeScrollable = find
            .descendant(
              of: find.byType(EditProfileScreen),
              matching: find.byType(Scrollable),
            )
            .first;
        final deleteAction = find.byKey(
          const ValueKey<String>('profile-delete-action'),
        );
        await tester.scrollUntilVisible(
          deleteAction,
          220,
          scrollable: routeScrollable,
        );
        await tester.pumpAndSettle();
        expect(deleteAction, findsOneWidget);

        final saveAction = find.byKey(
          const ValueKey<String>('profile-save-action'),
        );
        await tester.scrollUntilVisible(
          saveAction,
          -180,
          scrollable: routeScrollable,
        );
        await tester.pumpAndSettle();
        expect(saveAction, findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });

  testWidgets('golden Edit profile route reduced-motion state', (tester) async {
    await _pumpProfileStateGolden(
      tester,
      id: 'reduced_motion',
      reduceMotion: true,
      beforeCapture: (tester) async {
        final mediaQuery = MediaQuery.of(
          tester.element(find.byType(EditProfileScreen)),
        );
        expect(mediaQuery.disableAnimations, isTrue);
        expect(mediaQuery.accessibleNavigation, isTrue);
      },
    );
  });

  testWidgets('golden Edit profile route dark state', (tester) async {
    await _pumpProfileStateGolden(
      tester,
      id: 'dark',
      brightness: Brightness.dark,
      beforeCapture: (tester) async {
        expect(
          Theme.of(tester.element(find.byType(EditProfileScreen))).brightness,
          Brightness.dark,
        );
      },
    );
  });

  testWidgets('golden Edit profile route light state', (tester) async {
    await _pumpProfileStateGolden(
      tester,
      id: 'light',
      brightness: Brightness.light,
      beforeCapture: (tester) async {
        expect(
          Theme.of(tester.element(find.byType(EditProfileScreen))).brightness,
          Brightness.light,
        );
      },
    );
  });

  testWidgets('golden Edit profile route syncing state', (tester) async {
    final saveCompleter = Completer<String?>();
    final notifier = _BlockingProfileAuthNotifier(saveCompleter);
    await _pumpProfileStateGolden(
      tester,
      id: 'syncing',
      authNotifier: notifier,
      beforeCapture: (tester) async {
        final field = find.descendant(
          of: find.byKey(const ValueKey<String>('profile-nickname-field')),
          matching: find.byType(TextField),
        );
        await tester.enterText(field, 'Blue Lion draft');
        await tester.tap(
          find.byKey(const ValueKey<String>('profile-save-action')),
        );
        await tester.pump();
        expect(find.text('Saving profile'), findsOneWidget);
        expect(find.text('Blue Lion draft'), findsOneWidget);
        expect(notifier.updateCount, 1);
      },
      afterCapture: (tester) async {
        saveCompleter.complete('Profile service is temporarily unavailable.');
        await tester.pumpAndSettle();
      },
    );
  });

  testWidgets('golden Edit profile route conflict state', (tester) async {
    final notifier = _ConflictProfileAuthNotifier();
    await _pumpProfileStateGolden(
      tester,
      id: 'conflict',
      authNotifier: notifier,
      beforeCapture: (tester) async {
        final field = find.descendant(
          of: find.byKey(const ValueKey<String>('profile-nickname-field')),
          matching: find.byType(TextField),
        );
        await tester.enterText(field, 'Stale draft');
        await tester.tap(
          find.byKey(const ValueKey<String>('profile-save-action')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Profile changed elsewhere'), findsOneWidget);
        expect(find.text('Blue Lion'), findsOneWidget);
        expect(notifier.refreshCount, 1);
      },
    );
  });

  testWidgets('golden Edit profile route security-timeout state', (
    tester,
  ) async {
    final saveCompleter = Completer<String?>();
    final notifier = _BlockingProfileAuthNotifier(saveCompleter);
    await _pumpProfileStateGolden(
      tester,
      id: 'security_timeout',
      authNotifier: notifier,
      operationTimeout: const Duration(milliseconds: 1),
      beforeCapture: (tester) async {
        final field = find.descendant(
          of: find.byKey(const ValueKey<String>('profile-nickname-field')),
          matching: find.byType(TextField),
        );
        await tester.enterText(field, 'Timeout draft');
        await tester.tap(
          find.byKey(const ValueKey<String>('profile-save-action')),
        );
        await tester.pump(const Duration(milliseconds: 2));
        await tester.pumpAndSettle();
        expect(find.text('Profile save not confirmed'), findsOneWidget);
        expect(find.text('Timeout draft'), findsOneWidget);
        expect(
          tester
              .widget<AfriButton>(
                find.byKey(const ValueKey<String>('profile-save-action')),
              )
              .enabled,
          isFalse,
        );
      },
      afterCapture: (tester) async {
        saveCompleter.complete(null);
        await tester.pump();
      },
    );
  });
}

Future<void> _pumpProfileStateGolden(
  WidgetTester tester, {
  required String id,
  ProfileRouteContentRepository repository =
      const _ValueProfileRouteContentRepository(
        ProfileRouteContentSnapshot(profile: _profile),
      ),
  UserProfile? profile = _profile,
  AuthNotifier? authNotifier,
  Duration operationTimeout = const Duration(seconds: 12),
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
    initialLocation: '/settings/edit-profile',
    routes: <RouteBase>[
      GoRoute(
        path: '/settings/edit-profile',
        builder: (context, state) =>
            EditProfileScreen(operationTimeout: operationTimeout),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Settings destination'))),
      ),
      GoRoute(
        path: '/auth/phone',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Sign-in destination'))),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: <Override>[
        currentUserProvider.overrideWith((ref) => profile),
        profileRouteContentRepositoryProvider.overrideWithValue(repository),
        if (authNotifier != null)
          authStateProvider.overrideWith(() => authNotifier),
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
                key: const ValueKey<String>('profile-state-golden'),
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

  await beforeCapture?.call(tester);

  final routeBoundary = find.byKey(
    const ValueKey<String>('profile-state-golden'),
  );
  if (resetScroll) {
    final scrollables = find.descendant(
      of: routeBoundary,
      matching: find.byType(Scrollable),
    );
    for (final candidate in scrollables.evaluate()) {
      final scrollableState = (candidate as StatefulElement).state;
      final position = (scrollableState as ScrollableState).position;
      if (position.axis == Axis.vertical) {
        position.jumpTo(position.minScrollExtent);
        await tester.pump();
        break;
      }
    }
  }

  expect(tester.takeException(), isNull);
  await expectLater(
    routeBoundary,
    matchesGoldenFile(
      'goldens/profile_state_${id}_${brightness.name}_${size.width.toInt()}x${size.height.toInt()}.png',
    ),
  );

  await afterCapture?.call(tester);
  await tester.pumpWidget(const SizedBox.shrink());
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
  id: 'profile-user',
  clubId: '24',
  displayName: 'Blue Lion',
  publicUserId: '483912',
  languageCode: 'en',
);

class _ValueProfileRouteContentRepository
    extends ProfileRouteContentRepository {
  const _ValueProfileRouteContentRepository(this.snapshot);

  final ProfileRouteContentSnapshot snapshot;

  @override
  Future<ProfileRouteContentSnapshot> load(Ref ref) async => snapshot;
}

class _PendingProfileRouteContentRepository
    extends ProfileRouteContentRepository {
  const _PendingProfileRouteContentRepository();

  @override
  Future<ProfileRouteContentSnapshot> load(Ref ref) {
    return Completer<ProfileRouteContentSnapshot>().future;
  }
}

class _ThrowingProfileRouteContentRepository
    extends ProfileRouteContentRepository {
  const _ThrowingProfileRouteContentRepository(this.message);

  final String message;

  @override
  Future<ProfileRouteContentSnapshot> load(Ref ref) async {
    throw StateError(message);
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

class _ConflictProfileAuthNotifier extends AuthNotifier {
  int refreshCount = 0;

  @override
  AuthState build() => const AuthAuthenticated(
    profile: _profile,
    workspace: AdminWorkspaceAccess.none,
  );

  @override
  Future<String?> updateProfile(UserProfile profile) async {
    return 'Profile changed on another device.';
  }

  @override
  Future<String?> refreshProfile() async {
    refreshCount += 1;
    return null;
  }
}
