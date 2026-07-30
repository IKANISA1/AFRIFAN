import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_membership/src/providers/tier_detail_provider.dart';
import 'package:feat_membership/src/screens/tier_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:test_support/app_font_loader.dart';

const _goldens = <String, String>{
  'loading': 'goldens/tier_detail_state_loading_dark_390x844.png',
  'empty': 'goldens/tier_detail_state_empty_dark_390x844.png',
  'error': 'goldens/tier_detail_state_error_dark_390x844.png',
  'offline': 'goldens/tier_detail_state_offline_dark_390x844.png',
  'permission_denied':
      'goldens/tier_detail_state_permission_denied_dark_390x844.png',
  'disabled': 'goldens/tier_detail_state_disabled_dark_390x844.png',
  'focused': 'goldens/tier_detail_state_focused_dark_390x844.png',
  'pressed': 'goldens/tier_detail_state_pressed_dark_390x844.png',
  'selected': 'goldens/tier_detail_state_selected_dark_390x844.png',
  'large_text': 'goldens/tier_detail_state_large_text_dark_320x720.png',
  'reduced_motion': 'goldens/tier_detail_state_reduced_motion_dark_390x844.png',
  'dark': 'goldens/tier_detail_state_dark_dark_390x844.png',
  'light': 'goldens/tier_detail_state_light_light_390x844.png',
  'syncing': 'goldens/tier_detail_state_syncing_dark_390x844.png',
  'conflict': 'goldens/tier_detail_state_conflict_dark_390x844.png',
  'security_timeout':
      'goldens/tier_detail_state_security_timeout_dark_390x844.png',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);
  setUp(() => ConnectivityService.setOnlineForTest(true));
  tearDown(() => ConnectivityService.setOnlineForTest(true));

  testWidgets('Tier Detail refreshes after reconnect', (tester) async {
    ConnectivityService.setOnlineForTest(false);
    final controller = _Controller(
      AsyncData(
        TierDetailState(
          data: _detail,
          phase: TierDetailPhase.degraded,
          failure: const TierDetailFailure(TierDetailFailureKind.offline),
        ),
      ),
    );
    await _pumpRoute(
      tester,
      controller: controller,
      online: false,
      capture: false,
    );

    ConnectivityService.setOnlineForTest(true);
    await tester.pump();
    await tester.pump();

    expect(controller.restoredCalls, 1);
  });

  testWidgets('Tier Detail direct close uses the safe membership fallback', (
    tester,
  ) async {
    final controller = _Controller(AsyncData(TierDetailState(data: _detail)));
    await _pumpRoute(tester, controller: controller, capture: false);

    await tester.tap(find.byKey(const ValueKey<String>('tier-detail-back')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('membership-fallback')), findsOne);
  });

  testWidgets('Tier Detail never renders raw unknown tier identifiers', (
    tester,
  ) async {
    final controller = _Controller(const AsyncData(TierDetailState()));
    await _pumpRoute(
      tester,
      controller: controller,
      initialLocation: '/membership/tier/member-secret-42',
      capture: false,
    );

    expect(find.textContaining('member-secret-42'), findsNothing);
    expect(find.text('Tier not found'), findsOneWidget);
  });

  for (final id in _goldens.keys) {
    testWidgets('golden Tier Detail $id state', (tester) async {
      final config = _configFor(id);
      final controller = _Controller(config.value);

      if (id == 'focused') {
        final previous = FocusManager.instance.highlightStrategy;
        addTearDown(() => FocusManager.instance.highlightStrategy = previous);
        FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.alwaysTraditional;
      }

      await _pumpRoute(
        tester,
        controller: controller,
        online: config.online,
        enabled: config.enabled,
        brightness: config.brightness,
        size: config.size,
        textScale: config.textScale,
        reducedMotion: config.reducedMotion,
        settle: id != 'loading',
      );

      if (id == 'focused') {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        expect(FocusManager.instance.primaryFocus, isNotNull);
      }
      if (id == 'pressed') {
        final button = find.byKey(const ValueKey<String>('tier-detail-back'));
        final gesture = await tester.startGesture(tester.getCenter(button));
        addTearDown(gesture.cancel);
        await tester.pump(const Duration(milliseconds: 120));
        await tester.pump(const Duration(milliseconds: 40));
        expect(
          tester
              .widgetList<ScaleTransition>(
                find.descendant(
                  of: button,
                  matching: find.byType(ScaleTransition),
                ),
              )
              .any((transition) => transition.scale.value < 1),
          isTrue,
        );
      }
      if (id == 'selected') {
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && widget.properties.selected == true,
          ),
          findsAtLeastNWidgets(1),
        );
      }
      if (id == 'large_text') {
        expect(tester.takeException(), isNull);
        expect(find.text('GOLD'), findsOneWidget);
      }

      await expectLater(
        find.byKey(const ValueKey<String>('tier-detail-state-golden')),
        matchesGoldenFile(_goldens[id]!),
      );
    });
  }
}

_Config _configFor(String id) {
  final ready = AsyncData(TierDetailState(data: _detail));
  return switch (id) {
    'loading' => const _Config(AsyncLoading<TierDetailState>()),
    'empty' => const _Config(AsyncData(TierDetailState())),
    'error' => const _Config(
      AsyncError(
        TierDetailFailure(TierDetailFailureKind.unknown),
        StackTrace.empty,
      ),
    ),
    'offline' => _Config(
      AsyncData(
        TierDetailState(
          data: _detail,
          phase: TierDetailPhase.degraded,
          failure: const TierDetailFailure(TierDetailFailureKind.offline),
        ),
      ),
      online: false,
    ),
    'permission_denied' => const _Config(
      AsyncError(
        TierDetailFailure(TierDetailFailureKind.permissionDenied),
        StackTrace.empty,
      ),
    ),
    'disabled' => _Config(ready, enabled: false),
    'large_text' => _Config(ready, size: const Size(320, 720), textScale: 2),
    'reduced_motion' => _Config(ready, reducedMotion: true),
    'light' => _Config(ready, brightness: Brightness.light),
    'syncing' => _Config(
      AsyncData(TierDetailState(data: _detail, phase: TierDetailPhase.syncing)),
    ),
    'conflict' => _Config(
      AsyncData(
        TierDetailState(
          data: _detail,
          phase: TierDetailPhase.degraded,
          failure: const TierDetailFailure(TierDetailFailureKind.conflict),
        ),
      ),
    ),
    'security_timeout' => _Config(
      AsyncData(
        TierDetailState(
          data: _detail,
          phase: TierDetailPhase.degraded,
          failure: const TierDetailFailure(
            TierDetailFailureKind.securityTimeout,
          ),
        ),
      ),
    ),
    _ => _Config(ready),
  };
}

Future<void> _pumpRoute(
  WidgetTester tester, {
  required _Controller controller,
  bool online = true,
  bool enabled = true,
  Brightness brightness = Brightness.dark,
  Size size = const Size(390, 844),
  double textScale = 1,
  bool reducedMotion = false,
  String initialLocation = '/membership/tier/gold',
  bool settle = true,
  bool capture = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  TypographyTokens.debugUseFallbackFonts = true;
  addTearDown(() => TypographyTokens.debugUseFallbackFonts = false);
  ColorTokens.setBrightness(brightness);
  addTearDown(() => ColorTokens.setBrightness(Brightness.dark));
  ConnectivityService.setOnlineForTest(online);
  addTearDown(() => ConnectivityService.setOnlineForTest(true));

  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/membership/tier/:tierId',
        builder: (_, state) => RepaintBoundary(
          key: const ValueKey<String>('tier-detail-state-golden'),
          child: TierDetailScreen(
            tierId: state.pathParameters['tierId'] ?? 'gold',
          ),
        ),
      ),
      GoRoute(
        path: '/membership',
        builder: (_, _) =>
            const SizedBox(key: ValueKey<String>('membership-fallback')),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tierDetailProvider.overrideWith((ref, tierId) => controller),
        tierDetailEnabledProvider.overrideWithValue(enabled),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        builder: (context, child) {
          final media = MediaQuery.of(context);
          return MediaQuery(
            data: media.copyWith(
              disableAnimations: reducedMotion,
              accessibleNavigation: reducedMotion,
            ),
            child: child ?? const SizedBox.shrink(),
          );
        },
        theme: ClubTheme.from(ClubConfig.fallback(), brightness: brightness),
        routerConfig: router,
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  if (capture) expect(find.byType(TierDetailScreen), findsOneWidget);
}

class _Config {
  const _Config(
    this.value, {
    this.online = true,
    this.enabled = true,
    this.brightness = Brightness.dark,
    this.size = const Size(390, 844),
    this.textScale = 1,
    this.reducedMotion = false,
  });

  final AsyncValue<TierDetailState> value;
  final bool online;
  final bool enabled;
  final Brightness brightness;
  final Size size;
  final double textScale;
  final bool reducedMotion;
}

final _detail = TierDetailData.fromOfficialSlug('gold');

class _Controller extends TierDetailController {
  _Controller(AsyncValue<TierDetailState> value)
    : super(_Gateway(), 'gold', autoLoad: false) {
    state = value;
  }

  int restoredCalls = 0;

  @override
  Future<void> connectionRestored() async {
    restoredCalls += 1;
  }
}

class _Gateway implements TierDetailGateway {
  @override
  Future<TierDetailData?> load(String tierId) async => _detail;
}
