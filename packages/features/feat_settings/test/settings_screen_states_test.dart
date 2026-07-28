import 'dart:async';

import 'package:core_auth/core_auth.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_settings/src/screens/settings_screen.dart';
import 'package:feat_settings/src/settings_route_content_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:test_support/app_font_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadAppFonts);

  testWidgets('golden Settings route loading state', (tester) async {
    await _pumpSettingsStateGolden(
      tester,
      id: 'loading',
      repository: const _PendingSettingsRouteContentRepository(),
      settle: false,
      beforeCapture: (tester) async {
        expect(find.text('Loading settings'), findsOneWidget);
        expect(find.text('Membership details'), findsOneWidget);
      },
    );
  });

  testWidgets('golden Settings route empty state', (tester) async {
    await _pumpSettingsStateGolden(
      tester,
      id: 'empty',
      repository: _ValueSettingsRouteContentRepository(
        SettingsRouteContentSnapshot.current(supportWhatsApp: null),
      ),
      beforeCapture: (tester) async {
        expect(find.text('Support contact unavailable'), findsOneWidget);
        expect(
          find.text('Other settings still work. Refresh to check again.'),
          findsOneWidget,
        );
      },
    );
  });

  testWidgets('golden Settings route error state', (tester) async {
    await _pumpSettingsStateGolden(
      tester,
      id: 'error',
      repository: const _ThrowingSettingsRouteContentRepository(
        'backend row club-991 failed',
      ),
      beforeCapture: (tester) async {
        expect(find.text('Could not load support settings'), findsOneWidget);
        expect(find.textContaining('991'), findsNothing);
      },
    );
  });

  testWidgets('golden Settings route offline state', (tester) async {
    await _pumpSettingsStateGolden(
      tester,
      id: 'offline',
      repository: const SettingsRouteContentRepository(),
      online: false,
      beforeCapture: (tester) async {
        expect(find.text('Offline settings'), findsOneWidget);
        expect(find.textContaining('Reconnect for support'), findsOneWidget);
      },
    );
  });

  testWidgets('golden Settings route permission-denied state', (tester) async {
    await _pumpSettingsStateGolden(
      tester,
      id: 'permission_denied',
      repository: const _ThrowingSettingsRouteContentRepository(
        'row-level security rejected account 991',
      ),
      beforeCapture: (tester) async {
        expect(find.text('Settings access limited'), findsOneWidget);
        expect(find.textContaining('991'), findsNothing);
      },
    );
  });

  testWidgets('golden Settings route disabled state', (tester) async {
    await _pumpSettingsStateGolden(
      tester,
      id: 'disabled',
      repository: _ValueSettingsRouteContentRepository(
        SettingsRouteContentSnapshot.current(
          supportWhatsApp: '250000000000',
          supportEnabled: false,
          message:
              'Help and support is unavailable. Other settings still work.',
        ),
      ),
      beforeCapture: (tester) async {
        expect(find.text('Help and support unavailable'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey<String>('settings-support-action')),
          220,
        );
        await tester.pumpAndSettle();
        final support = tester.widget<AfriListRow>(
          find.byKey(const ValueKey<String>('settings-support-action')),
        );
        expect(support.enabled, isFalse);
      },
    );
  });

  testWidgets('golden Settings route focused state', (tester) async {
    final previousHighlightStrategy = FocusManager.instance.highlightStrategy;
    addTearDown(
      () => FocusManager.instance.highlightStrategy = previousHighlightStrategy,
    );
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;

    await _pumpSettingsStateGolden(
      tester,
      id: 'focused',
      repository: _currentRepository,
      beforeCapture: (tester) async {
        final focusable = find
            .descendant(
              of: find.byKey(
                const ValueKey<String>('settings-appearance-action'),
              ),
              matching: find.byType(FocusableActionDetector),
            )
            .first;
        final gestureDetector = find
            .descendant(of: focusable, matching: find.byType(GestureDetector))
            .first;
        Focus.of(tester.element(gestureDetector)).requestFocus();
        await tester.pumpAndSettle();
        expect(Focus.of(tester.element(gestureDetector)).hasFocus, isTrue);
      },
    );
  });

  testWidgets('golden Settings route pressed state', (tester) async {
    TestGesture? heldGesture;
    await _pumpSettingsStateGolden(
      tester,
      id: 'pressed',
      repository: _currentRepository,
      beforeCapture: (tester) async {
        heldGesture = await tester.startGesture(
          tester.getCenter(
            find.byKey(const ValueKey<String>('settings-appearance-action')),
          ),
        );
        await tester.pump(const Duration(milliseconds: 120));
      },
      afterCapture: (tester) async {
        await heldGesture?.cancel();
        await tester.pumpAndSettle();
      },
    );
  });

  testWidgets('golden Settings route selected state', (tester) async {
    await _pumpSettingsStateGolden(
      tester,
      id: 'selected',
      repository: _currentRepository,
      beforeCapture: (tester) async {
        await tester.tap(
          find.byKey(const ValueKey<String>('settings-appearance-action')),
        );
        await tester.pumpAndSettle();
        final selector = tester.widget<AfriSegmentedControl>(
          find.byType(AfriSegmentedControl),
        );
        expect(selector.selectedIndex, 0);
        expect(
          find.text('Choose a theme or follow your device setting.'),
          findsOneWidget,
        );
      },
    );
  });

  testWidgets('golden Settings route large-text state', (tester) async {
    await _pumpSettingsStateGolden(
      tester,
      id: 'large_text',
      size: const Size(320, 720),
      textScale: 2,
      repository: _currentRepository,
      beforeCapture: (tester) async {
        expect(find.text('Membership details'), findsOneWidget);
        expect(find.text('Edit profile'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });

  testWidgets('golden Settings route syncing state', (tester) async {
    final refreshCompleter = Completer<SettingsRouteContentSnapshot>();
    final repository = _SequencedSettingsRouteContentRepository([
      () async => _currentSnapshot,
      () => refreshCompleter.future,
    ]);
    await _pumpSettingsStateGolden(
      tester,
      id: 'syncing',
      repository: repository,
      beforeCapture: (tester) async {
        final container = ProviderScope.containerOf(
          tester.element(find.byType(SettingsScreen)),
        );
        unawaited(
          container.read(settingsRouteContentProvider.notifier).refresh(),
        );
        await tester.pump();
        expect(find.text('Refreshing settings'), findsOneWidget);
        expect(find.text('Membership details'), findsOneWidget);
      },
      afterCapture: (tester) async {
        refreshCompleter.complete(_currentSnapshot);
        await tester.pumpAndSettle();
      },
    );
  });

  testWidgets('golden Settings route conflict state', (tester) async {
    await _pumpSettingsStateGolden(
      tester,
      id: 'conflict',
      repository: const _ThrowingSettingsRouteContentRepository(
        'stale revision conflict for supporter-991',
      ),
      beforeCapture: (tester) async {
        expect(find.text('Settings changed'), findsOneWidget);
        expect(find.textContaining('991'), findsNothing);
      },
    );
  });

  testWidgets('golden Settings route security-timeout state', (tester) async {
    await _pumpSettingsStateGolden(
      tester,
      id: 'security_timeout',
      repository: const _PendingSettingsRouteContentRepository(),
      overrides: <Override>[
        settingsRouteContentProvider.overrideWith(
          () => SettingsRouteContentNotifier(
            loadTimeout: const Duration(milliseconds: 1),
          ),
        ),
      ],
      beforeCapture: (tester) async {
        expect(find.text('Settings security check timed out'), findsOneWidget);
      },
    );
  });
}

const _currentSnapshot = SettingsRouteContentSnapshot(
  supportWhatsApp: '250000000000',
);

const _currentRepository = _ValueSettingsRouteContentRepository(
  _currentSnapshot,
);

Future<void> _pumpSettingsStateGolden(
  WidgetTester tester, {
  required String id,
  required SettingsRouteContentRepository repository,
  Size size = const Size(390, 844),
  double textScale = 1,
  bool settle = true,
  bool online = true,
  List<Override> overrides = const <Override>[],
  Future<void> Function(WidgetTester tester)? beforeCapture,
  Future<void> Function(WidgetTester tester)? afterCapture,
}) async {
  _setGoldenSurface(tester, size);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  TypographyTokens.debugUseFallbackFonts = true;
  addTearDown(() => TypographyTokens.debugUseFallbackFonts = false);
  ColorTokens.setBrightness(Brightness.dark);
  addTearDown(() => ColorTokens.setBrightness(Brightness.dark));
  ConnectivityService.setOnlineForTest(online);
  addTearDown(() => ConnectivityService.setOnlineForTest(true));

  final router = GoRouter(
    initialLocation: '/settings',
    routes: <RouteBase>[
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/membership',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Membership destination'))),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: <Override>[
        currentUserProvider.overrideWith((ref) => _profile),
        settingsRouteContentRepositoryProvider.overrideWithValue(repository),
        ...overrides,
      ],
      child: ClubConfigScope(
        config: ClubConfig.fallback(),
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          builder: (context, child) {
            final mediaQuery = MediaQuery.of(context);
            return MediaQuery(
              data: mediaQuery.copyWith(disableAnimations: true),
              child: RepaintBoundary(
                key: const ValueKey<String>('settings-state-golden'),
                child: child!,
              ),
            );
          },
          theme: ClubTheme.from(
            ClubConfig.fallback(),
            brightness: Brightness.dark,
          ),
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
    const ValueKey<String>('settings-state-golden'),
  );
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

  expect(tester.takeException(), isNull);
  await expectLater(
    routeBoundary,
    matchesGoldenFile(
      'goldens/settings_state_${id}_dark_${size.width.toInt()}x${size.height.toInt()}.png',
    ),
  );

  await afterCapture?.call(tester);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void _setGoldenSurface(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(
        disableAnimations: true,
        accessibleNavigation: true,
      );
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

const _profile = UserProfile(
  id: 'settings-user',
  clubId: '24',
  publicUserId: '483912',
  languageCode: 'en',
);

class _ValueSettingsRouteContentRepository
    extends SettingsRouteContentRepository {
  const _ValueSettingsRouteContentRepository(this.snapshot);

  final SettingsRouteContentSnapshot snapshot;

  @override
  Future<SettingsRouteContentSnapshot> load(Ref ref) async => snapshot;
}

class _PendingSettingsRouteContentRepository
    extends SettingsRouteContentRepository {
  const _PendingSettingsRouteContentRepository();

  @override
  Future<SettingsRouteContentSnapshot> load(Ref ref) {
    return Completer<SettingsRouteContentSnapshot>().future;
  }
}

class _ThrowingSettingsRouteContentRepository
    extends SettingsRouteContentRepository {
  const _ThrowingSettingsRouteContentRepository(this.message);

  final String message;

  @override
  Future<SettingsRouteContentSnapshot> load(Ref ref) async {
    throw StateError(message);
  }
}

class _SequencedSettingsRouteContentRepository
    extends SettingsRouteContentRepository {
  _SequencedSettingsRouteContentRepository(this._loads);

  final List<Future<SettingsRouteContentSnapshot> Function()> _loads;
  int _calls = 0;

  @override
  Future<SettingsRouteContentSnapshot> load(Ref ref) {
    final load = _loads[_calls];
    _calls += 1;
    return load();
  }
}
