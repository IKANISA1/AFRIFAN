import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_gamification/src/models/fet_models.dart';
import 'package:feat_gamification/src/providers/fet_wallet_provider.dart';
import 'package:feat_gamification/src/screens/fet_wallet_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:test_support/app_font_loader.dart';

const _goldens = <String, String>{
  'loading': 'goldens/fet_wallet_state_loading_dark_390x844.png',
  'empty': 'goldens/fet_wallet_state_empty_dark_390x844.png',
  'error': 'goldens/fet_wallet_state_error_dark_390x844.png',
  'offline': 'goldens/fet_wallet_state_offline_dark_390x844.png',
  'permission_denied':
      'goldens/fet_wallet_state_permission_denied_dark_390x844.png',
  'disabled': 'goldens/fet_wallet_state_disabled_dark_390x844.png',
  'focused': 'goldens/fet_wallet_state_focused_dark_390x844.png',
  'pressed': 'goldens/fet_wallet_state_pressed_dark_390x844.png',
  'selected': 'goldens/fet_wallet_state_selected_dark_390x844.png',
  'large_text': 'goldens/fet_wallet_state_large_text_dark_320x720.png',
  'reduced_motion': 'goldens/fet_wallet_state_reduced_motion_dark_390x844.png',
  'dark': 'goldens/fet_wallet_state_dark_dark_390x844.png',
  'light': 'goldens/fet_wallet_state_light_light_390x844.png',
  'syncing': 'goldens/fet_wallet_state_syncing_dark_390x844.png',
  'conflict': 'goldens/fet_wallet_state_conflict_dark_390x844.png',
  'security_timeout':
      'goldens/fet_wallet_state_security_timeout_dark_390x844.png',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);
  setUp(() => ConnectivityService.setOnlineForTest(true));
  tearDown(() => ConnectivityService.setOnlineForTest(true));

  testWidgets('FET Wallet refreshes after reconnect', (tester) async {
    ConnectivityService.setOnlineForTest(false);
    final controller = _Controller(
      AsyncData(
        FetWalletSnapshot(
          wallet: _wallet,
          transactions: <FetWalletTransaction>[_transaction],
          phase: FetWalletPhase.degraded,
          failure: const FetWalletFailure(FetWalletFailureKind.offline),
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

  for (final id in _goldens.keys) {
    testWidgets('golden FET Wallet $id state', (tester) async {
      final config = _configFor(id);
      final controller = _Controller(config.value);
      await _pumpRoute(
        tester,
        controller: controller,
        online: config.online,
        enabled: config.enabled,
        brightness: config.brightness,
        size: config.size,
        textScale: config.textScale,
        reducedMotion: config.reducedMotion,
        initialLocation: config.initialLocation,
        settle: id != 'loading',
      );

      if (id == 'focused') {
        final previous = FocusManager.instance.highlightStrategy;
        addTearDown(() => FocusManager.instance.highlightStrategy = previous);
        FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.alwaysTraditional;
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        expect(FocusManager.instance.primaryFocus, isNotNull);
      }
      if (id == 'pressed') {
        final button = find.byKey(const ValueKey<String>('fet-wallet-more'));
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
        expect(find.textContaining('1,250'), findsOneWidget);
      }

      await expectLater(
        find.byKey(const ValueKey<String>('fet-wallet-state-golden')),
        matchesGoldenFile(_goldens[id]!),
      );
    });
  }
}

_Config _configFor(String id) {
  final ready = AsyncData(
    FetWalletSnapshot(
      wallet: _wallet,
      transactions: <FetWalletTransaction>[_transaction],
    ),
  );
  return switch (id) {
    'loading' => const _Config(AsyncLoading<FetWalletSnapshot>()),
    'empty' => const _Config(AsyncData(FetWalletSnapshot())),
    'error' => const _Config(
      AsyncError(
        FetWalletFailure(FetWalletFailureKind.unknown),
        StackTrace.empty,
      ),
    ),
    'offline' => _Config(
      AsyncData(
        FetWalletSnapshot(
          wallet: _wallet,
          transactions: <FetWalletTransaction>[_transaction],
          phase: FetWalletPhase.degraded,
          failure: const FetWalletFailure(FetWalletFailureKind.offline),
        ),
      ),
      online: false,
    ),
    'permission_denied' => const _Config(
      AsyncError(
        FetWalletFailure(FetWalletFailureKind.permissionDenied),
        StackTrace.empty,
      ),
    ),
    'disabled' => _Config(ready, enabled: false),
    'selected' => _Config(
      ready,
      initialLocation: '/fanzone/wallet?section=history',
    ),
    'large_text' => _Config(ready, size: const Size(320, 720), textScale: 2),
    'reduced_motion' => _Config(ready, reducedMotion: true),
    'light' => _Config(ready, brightness: Brightness.light),
    'syncing' => _Config(
      AsyncData(
        FetWalletSnapshot(
          wallet: _wallet,
          transactions: <FetWalletTransaction>[_transaction],
          phase: FetWalletPhase.syncing,
        ),
      ),
    ),
    'conflict' => _Config(
      AsyncData(
        FetWalletSnapshot(
          wallet: _wallet,
          transactions: <FetWalletTransaction>[_transaction],
          phase: FetWalletPhase.degraded,
          failure: const FetWalletFailure(FetWalletFailureKind.conflict),
        ),
      ),
    ),
    'security_timeout' => _Config(
      AsyncData(
        FetWalletSnapshot(
          wallet: _wallet,
          transactions: <FetWalletTransaction>[_transaction],
          phase: FetWalletPhase.degraded,
          failure: const FetWalletFailure(FetWalletFailureKind.securityTimeout),
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
  String initialLocation = '/fanzone/wallet',
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
        path: '/fanzone/wallet',
        builder: (_, _) => const RepaintBoundary(
          key: ValueKey<String>('fet-wallet-state-golden'),
          child: FetWalletScreen(),
        ),
      ),
      GoRoute(path: '/fanzone', builder: (_, _) => const SizedBox.shrink()),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        fetWalletRouteProvider.overrideWith((ref) => controller),
        fetWalletEnabledProvider.overrideWithValue(enabled),
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
  if (capture) expect(find.byType(FetWalletScreen), findsOneWidget);
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
    this.initialLocation = '/fanzone/wallet',
  });

  final AsyncValue<FetWalletSnapshot> value;
  final bool online;
  final bool enabled;
  final Brightness brightness;
  final Size size;
  final double textScale;
  final bool reducedMotion;
  final String initialLocation;
}

const _wallet = FetWalletSummary(
  userId: 'supporter-synthetic',
  clubId: 24,
  membershipId: 'membership-synthetic',
  balance: 1250,
  tier: 'gold',
  weeklyEarned: 200,
  monthlyEarned: 480,
  lifetimeEarned: 1600,
  lifetimeSpent: 350,
  transactionCount: 1,
  historicalBalanceGap: 0,
);

final _transaction = FetWalletTransaction(
  id: 'entry-synthetic',
  entryType: 'partner_promotion_earn',
  direction: FetWalletEntryDirection.credit,
  amount: 300,
  balanceAfter: 1250,
  counterpartyUserId: null,
  counterpartyDisplayName: null,
  counterpartyPublicUserId: null,
  note: 'Matchday partner reward',
  referenceType: 'partner_initiative',
  referenceId: 'initiative-synthetic',
  createdAt: DateTime.utc(2026, 4, 12, 8),
);

class _Controller extends FetWalletController {
  _Controller(AsyncValue<FetWalletSnapshot> value)
    : super(_Gateway(), autoLoad: false) {
    state = value;
  }

  int restoredCalls = 0;

  @override
  Future<void> connectionRestored() async {
    restoredCalls += 1;
  }
}

class _Gateway implements FetWalletGateway {
  @override
  Future<FetWalletSummary?> loadWallet() async => _wallet;

  @override
  Future<List<FetWalletTransaction>> loadTransactions({
    required int limit,
  }) async => <FetWalletTransaction>[_transaction];
}
