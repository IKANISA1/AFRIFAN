import 'dart:async';

import 'package:core_auth/core_auth.dart';
import 'package:core_l10n/core_l10n.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_onboarding/src/onboarding_content_provider.dart';
import 'package:feat_onboarding/src/screens/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:test_support/app_font_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadAppFonts);

  testWidgets('golden Onboarding route loading state', (tester) async {
    await _pumpOnboardingStateGolden(
      tester,
      id: 'loading',
      repository: const _PendingOnboardingContentRepository(),
      settle: false,
      beforeCapture: (tester) async {
        expect(find.text('Preparing your welcome'), findsOneWidget);
        expect(find.text('Continue with WhatsApp'), findsOneWidget);
      },
    );
  });

  testWidgets('golden Onboarding route empty state', (tester) async {
    await _pumpOnboardingStateGolden(
      tester,
      id: 'empty',
      repository: const _ValueOnboardingContentRepository(
        OnboardingContentSnapshot(slides: <OnboardingSlideId>[]),
      ),
      beforeCapture: (tester) async {
        expect(find.text('Welcome content unavailable'), findsOneWidget);
        expect(find.text('Refresh'), findsOneWidget);
      },
    );
  });

  testWidgets('golden Onboarding route error state', (tester) async {
    await _pumpOnboardingStateGolden(
      tester,
      id: 'error',
      repository: const _ThrowingOnboardingContentRepository(
        'backend row club-991 failed',
      ),
      beforeCapture: (tester) async {
        expect(find.text('Welcome unavailable'), findsOneWidget);
        expect(find.text('Try again'), findsOneWidget);
        expect(find.textContaining('991'), findsNothing);
      },
    );
  });

  testWidgets('golden Onboarding route offline state', (tester) async {
    await _pumpOnboardingStateGolden(
      tester,
      id: 'offline',
      repository: const OnboardingContentRepository(),
      online: false,
      beforeCapture: (tester) async {
        expect(find.text('WhatsApp sign-in unavailable'), findsWidgets);
        expect(
          find.textContaining('Saved welcome is available'),
          findsOneWidget,
        );
        expect(find.text('Continue without sign-in'), findsOneWidget);
      },
    );
  });

  testWidgets('golden Onboarding route permission-denied state', (
    tester,
  ) async {
    await _pumpOnboardingStateGolden(
      tester,
      id: 'permission_denied',
      repository: const _ThrowingOnboardingContentRepository(
        'row-level security rejected account 991',
      ),
      beforeCapture: (tester) async {
        expect(find.text('Welcome access unavailable'), findsOneWidget);
        expect(find.text('Refresh'), findsNothing);
        expect(find.textContaining('991'), findsNothing);
      },
    );
  });

  testWidgets('golden Onboarding route disabled state', (tester) async {
    await _pumpOnboardingStateGolden(
      tester,
      id: 'disabled',
      repository: _ValueOnboardingContentRepository(
        OnboardingContentSnapshot.current(
          whatsAppSignInAvailable: false,
          message: 'Continue without sign-in, or try WhatsApp later.',
        ),
      ),
      beforeCapture: (tester) async {
        final action = tester.widget<AfriButton>(
          find.byKey(const ValueKey<String>('onboarding-whatsapp-action')),
        );
        expect(action.enabled, isFalse);
        expect(find.text('Continue without sign-in'), findsOneWidget);
      },
    );
  });

  testWidgets('golden Onboarding route focused state', (tester) async {
    final previousHighlightStrategy = FocusManager.instance.highlightStrategy;
    addTearDown(
      () => FocusManager.instance.highlightStrategy = previousHighlightStrategy,
    );
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;

    await _pumpOnboardingStateGolden(
      tester,
      id: 'focused',
      repository: _ValueOnboardingContentRepository(
        OnboardingContentSnapshot.current(),
      ),
      beforeCapture: (tester) async {
        final focusable = find
            .descendant(
              of: find.byKey(
                const ValueKey<String>('onboarding-whatsapp-action'),
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

  testWidgets('golden Onboarding route pressed state', (tester) async {
    TestGesture? heldGesture;
    await _pumpOnboardingStateGolden(
      tester,
      id: 'pressed',
      repository: _ValueOnboardingContentRepository(
        OnboardingContentSnapshot.current(),
      ),
      beforeCapture: (tester) async {
        heldGesture = await tester.startGesture(
          tester.getCenter(
            find.byKey(const ValueKey<String>('onboarding-whatsapp-action')),
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

  testWidgets('golden Onboarding route selected state', (tester) async {
    await _pumpOnboardingStateGolden(
      tester,
      id: 'selected',
      repository: _ValueOnboardingContentRepository(
        OnboardingContentSnapshot.current(),
      ),
      beforeCapture: (tester) async {
        await tester.flingFrom(
          const Offset(350, 250),
          const Offset(-320, 0),
          900,
        );
        await tester.pumpAndSettle();
        expect(find.text('Every moment.\nOne blue family.'), findsOneWidget);
      },
    );
  });

  testWidgets('golden Onboarding route large-text state', (tester) async {
    await _pumpOnboardingStateGolden(
      tester,
      id: 'large_text',
      size: const Size(320, 720),
      textScale: 2,
      repository: _ValueOnboardingContentRepository(
        OnboardingContentSnapshot.current(),
      ),
      beforeCapture: (tester) async {
        expect(find.text('Your club.\nYour matchday.'), findsOneWidget);
        expect(find.text('Continue with WhatsApp'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });

  testWidgets('golden Onboarding route syncing state', (tester) async {
    final refreshCompleter = Completer<OnboardingContentSnapshot>();
    final repository = _SequencedOnboardingContentRepository([
      () async => OnboardingContentSnapshot.current(),
      () => refreshCompleter.future,
    ]);
    await _pumpOnboardingStateGolden(
      tester,
      id: 'syncing',
      repository: repository,
      beforeCapture: (tester) async {
        final container = ProviderScope.containerOf(
          tester.element(find.byType(OnboardingScreen)),
        );
        unawaited(container.read(onboardingContentProvider.notifier).refresh());
        await tester.pump();
        expect(find.text('Refreshing welcome'), findsOneWidget);
        expect(find.text('Your club.\nYour matchday.'), findsOneWidget);
      },
      afterCapture: (tester) async {
        refreshCompleter.complete(OnboardingContentSnapshot.current());
        await tester.pumpAndSettle();
      },
    );
  });

  testWidgets('golden Onboarding route conflict state', (tester) async {
    await _pumpOnboardingStateGolden(
      tester,
      id: 'conflict',
      repository: const _ThrowingOnboardingContentRepository(
        'stale revision conflict for supporter-991',
      ),
      beforeCapture: (tester) async {
        expect(find.text('Welcome changed'), findsOneWidget);
        expect(find.text('Refresh'), findsOneWidget);
        expect(find.textContaining('991'), findsNothing);
      },
    );
  });

  testWidgets('golden Onboarding route security-timeout state', (tester) async {
    await _pumpOnboardingStateGolden(
      tester,
      id: 'security_timeout',
      repository: const _PendingOnboardingContentRepository(),
      overrides: [
        onboardingContentProvider.overrideWith(
          () => OnboardingContentNotifier(
            loadTimeout: const Duration(milliseconds: 1),
          ),
        ),
      ],
      beforeCapture: (tester) async {
        expect(find.text('Welcome security check timed out'), findsOneWidget);
        expect(find.text('Refresh'), findsOneWidget);
      },
    );
  });
}

Future<void> _pumpOnboardingStateGolden(
  WidgetTester tester, {
  required String id,
  required OnboardingContentRepository repository,
  Size size = const Size(390, 844),
  double textScale = 1,
  bool settle = true,
  bool online = true,
  List<Override> overrides = const [],
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

  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        onboardingContentRepositoryProvider.overrideWithValue(repository),
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
        ...overrides,
      ],
      child: ClubConfigScope(
        config: ClubConfig.fallback(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [
            AfriLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AfriLocalizations.supportedLocales,
          builder: (context, child) {
            final mediaQuery = MediaQuery.of(context);
            return MediaQuery(
              data: mediaQuery.copyWith(disableAnimations: true),
              child: child!,
            );
          },
          theme: ClubTheme.from(
            ClubConfig.fallback(),
            brightness: Brightness.dark,
          ),
          home: const RepaintBoundary(
            key: ValueKey<String>('onboarding-state-golden'),
            child: OnboardingScreen(),
          ),
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
    const ValueKey<String>('onboarding-state-golden'),
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
      'goldens/onboarding_state_${id}_dark_${size.width.toInt()}x${size.height.toInt()}.png',
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

class _ValueOnboardingContentRepository extends OnboardingContentRepository {
  const _ValueOnboardingContentRepository(this.snapshot);

  final OnboardingContentSnapshot snapshot;

  @override
  Future<OnboardingContentSnapshot> load() async => snapshot;
}

class _PendingOnboardingContentRepository extends OnboardingContentRepository {
  const _PendingOnboardingContentRepository();

  @override
  Future<OnboardingContentSnapshot> load() {
    return Completer<OnboardingContentSnapshot>().future;
  }
}

class _ThrowingOnboardingContentRepository extends OnboardingContentRepository {
  const _ThrowingOnboardingContentRepository(this.message);

  final String message;

  @override
  Future<OnboardingContentSnapshot> load() async {
    throw StateError(message);
  }
}

class _SequencedOnboardingContentRepository
    extends OnboardingContentRepository {
  _SequencedOnboardingContentRepository(this._loads);

  final List<Future<OnboardingContentSnapshot> Function()> _loads;
  int _calls = 0;

  @override
  Future<OnboardingContentSnapshot> load() {
    final load = _loads[_calls];
    _calls += 1;
    return load();
  }
}

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository() : super(clubId: '24');

  @override
  Future<UserProfile?> restoreCurrentUser() async => null;

  @override
  Future<AdminWorkspaceAccess> resolveAdminAccess(String userId) async {
    return AdminWorkspaceAccess.none;
  }

  @override
  Stream<supabase.AuthState> get authStateChanges {
    return const Stream<supabase.AuthState>.empty();
  }
}
