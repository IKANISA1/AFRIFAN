import 'dart:async';

import 'package:core_auth/core_auth.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_shop/src/screens/shop_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:test_support/app_font_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);
  setUp(() {
    ConnectivityService.setOnlineForTest(true);
    FocusManager.instance.primaryFocus?.unfocus(
      disposition: UnfocusDisposition.scope,
    );
  });

  test('shop catalog failures sanitize known backend categories', () {
    expect(
      ShopCatalogFailure.fromError(
        StateError('RLS permission denied for private-product-row-4482'),
      ).kind,
      ShopCatalogFailureKind.permissionDenied,
    );
    expect(
      ShopCatalogFailure.fromError(
        StateError('revision conflict for private-product-row-4482'),
      ).kind,
      ShopCatalogFailureKind.conflict,
    );
    expect(
      ShopCatalogFailure.fromError(
        TimeoutException('private inventory token 4482'),
      ).kind,
      ShopCatalogFailureKind.securityTimeout,
    );
    expect(
      ShopCatalogFailure.fromError(
        StateError('private inventory token 4482'),
      ).toString(),
      'ShopCatalogFailure(unknown)',
    );
  });

  testWidgets('golden Shop route loading state', (tester) async {
    final pendingProducts = Completer<List<Map<String, dynamic>>>();
    addTearDown(() {
      if (!pendingProducts.isCompleted) {
        pendingProducts.complete(const <Map<String, dynamic>>[]);
      }
    });

    await _pumpShopStateGolden(
      tester,
      id: 'loading',
      productLoader: () => pendingProducts.future,
      settle: false,
      afterCapture: () async {
        if (!pendingProducts.isCompleted) {
          pendingProducts.complete(const <Map<String, dynamic>>[]);
        }
        await tester.pump();
      },
    );
  });

  testWidgets('golden Shop route empty state', (tester) async {
    await _pumpShopStateGolden(
      tester,
      id: 'empty',
      productLoader: () async => const <Map<String, dynamic>>[],
    );
  });

  testWidgets('golden Shop route error state', (tester) async {
    await _pumpShopStateGolden(
      tester,
      id: 'error',
      productLoader: () async => throw StateError('store unavailable'),
    );

    expect(find.text('Store unavailable'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('golden Shop route offline state', (tester) async {
    await _pumpShopStateGolden(
      tester,
      id: 'offline',
      online: false,
      productLoader: () async => _products,
    );

    expect(find.text('Store offline'), findsOneWidget);
    expect(
      find.text('Connect to load current club merchandise.'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('golden Shop route large-text state', (tester) async {
    await _pumpShopStateGolden(
      tester,
      id: 'large_text',
      size: const Size(320, 720),
      textScale: 2,
      productLoader: () async => _products,
    );
  });

  testWidgets('golden Shop route selected state', (tester) async {
    await _pumpShopStateGolden(
      tester,
      id: 'selected',
      productLoader: () async => _products,
      afterPump: (tester) async {
        await tester.tap(find.text('Jerseys'));
        await tester.pumpAndSettle();
      },
    );

    final selectedCategory = find.text('Jerseys');
    final semantics = tester.getSemantics(selectedCategory);
    expect(semantics.flagsCollection.isSelected.toBoolOrNull(), isTrue);
    expect(find.text('Home Match Jersey'), findsOneWidget);
    expect(find.text('Club Scarf'), findsNothing);
  });

  testWidgets('golden Shop route disabled state', (tester) async {
    await _pumpShopStateGolden(
      tester,
      id: 'disabled',
      productLoader: () async => _unavailableProducts,
    );

    final addAction = tester.widget<AfriIconButton>(
      find.byKey(const ValueKey<String>('shop-add-jersey-sold-out')),
    );
    expect(addAction.onTap, isNull);
    expect(find.text('OUT OF STOCK'), findsOneWidget);
  });

  testWidgets('golden Shop route focused state', (tester) async {
    final previousHighlightStrategy = FocusManager.instance.highlightStrategy;
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    addTearDown(
      () => FocusManager.instance.highlightStrategy = previousHighlightStrategy,
    );

    await _pumpShopStateGolden(
      tester,
      id: 'focused',
      autofocusProductId: 'jersey-home',
      productLoader: () async => _products,
    );

    expect(FocusManager.instance.primaryFocus?.hasFocus, isTrue);
  });

  testWidgets('golden Shop route pressed state', (tester) async {
    TestGesture? heldGesture;
    await _pumpShopStateGolden(
      tester,
      id: 'pressed',
      productLoader: () async => _products,
      afterPump: (tester) async {
        heldGesture = await tester.startGesture(
          tester.getCenter(
            find.byKey(const ValueKey<String>('shop-product-jersey-home')),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
      },
      afterCapture: () async {
        await heldGesture?.up();
      },
    );
  });

  testWidgets('golden Shop route permission-denied state', (tester) async {
    await _pumpShopStateGolden(
      tester,
      id: 'permission_denied',
      productLoader: () async {
        throw StateError('RLS permission denied for private-product-row-4482');
      },
    );

    expect(find.text('Store access not available'), findsOneWidget);
    expect(find.textContaining('private-product-row-4482'), findsNothing);
  });

  testWidgets('golden Shop route syncing state', (tester) async {
    final refreshCompleter = Completer<List<Map<String, dynamic>>>();
    var invocationCount = 0;
    addTearDown(() {
      if (!refreshCompleter.isCompleted) {
        refreshCompleter.complete(_products);
      }
    });

    await _pumpShopStateGolden(
      tester,
      id: 'syncing',
      productLoader: () {
        invocationCount += 1;
        if (invocationCount == 1) {
          return Future<List<Map<String, dynamic>>>.value(_products);
        }
        return refreshCompleter.future;
      },
      afterPump: (tester) async {
        ConnectivityService.setOnlineForTest(false);
        await tester.pump();
        ConnectivityService.setOnlineForTest(true);
        await tester.pump();
        expect(find.text('Refreshing store'), findsOneWidget);
      },
      afterCapture: () async {
        if (!refreshCompleter.isCompleted) {
          refreshCompleter.complete(_products);
        }
        await tester.pump();
      },
    );
  });

  testWidgets('golden Shop route conflict state', (tester) async {
    await _pumpShopStateGolden(
      tester,
      id: 'conflict',
      productLoader: () async {
        throw StateError('revision conflict for private-product-row-4482');
      },
    );

    expect(find.text('Store inventory changed'), findsOneWidget);
    expect(find.textContaining('private-product-row-4482'), findsNothing);
  });

  testWidgets('golden Shop route security-timeout state', (tester) async {
    final pendingProducts = Completer<List<Map<String, dynamic>>>();
    addTearDown(() {
      if (!pendingProducts.isCompleted) {
        pendingProducts.complete(const <Map<String, dynamic>>[]);
      }
    });

    await _pumpShopStateGolden(
      tester,
      id: 'security_timeout',
      productLoader: () => pendingProducts.future,
      loadTimeout: const Duration(milliseconds: 1),
    );

    expect(find.text('Store security check timed out'), findsOneWidget);
  });

  testWidgets('golden Shop route reduced-motion state', (tester) async {
    await _pumpShopStateGolden(
      tester,
      id: 'reduced_motion',
      reduceMotion: true,
      productLoader: () async => _products,
    );

    final cardContext = tester.element(
      find.byKey(const ValueKey<String>('shop-product-jersey-home')),
    );
    expect(AfriMotion.reduceMotion(cardContext), isTrue);
    expect(
      AfriMotion.resolve(cardContext, AfriMotion.surfaceEntrance),
      Duration.zero,
    );
  });

  testWidgets('golden Shop route explicit dark state', (tester) async {
    await _pumpShopStateGolden(
      tester,
      id: 'dark',
      brightness: Brightness.dark,
      productLoader: () async => _products,
    );

    final cardContext = tester.element(
      find.byKey(const ValueKey<String>('shop-product-jersey-home')),
    );
    expect(Theme.of(cardContext).brightness, Brightness.dark);
  });

  testWidgets('golden Shop route explicit light state', (tester) async {
    await _pumpShopStateGolden(
      tester,
      id: 'light',
      brightness: Brightness.light,
      productLoader: () async => _products,
    );

    final cardContext = tester.element(
      find.byKey(const ValueKey<String>('shop-product-jersey-home')),
    );
    expect(Theme.of(cardContext).brightness, Brightness.light);
  });
}

const _shopStateGoldenPaths = <String, String>{
  'loading': 'goldens/shop_state_loading_dark_390x844.png',
  'empty': 'goldens/shop_state_empty_dark_390x844.png',
  'error': 'goldens/shop_state_error_dark_390x844.png',
  'offline': 'goldens/shop_state_offline_dark_390x844.png',
  'large_text': 'goldens/shop_state_large_text_dark_320x720.png',
  'selected': 'goldens/shop_state_selected_dark_390x844.png',
  'disabled': 'goldens/shop_state_disabled_dark_390x844.png',
  'focused': 'goldens/shop_state_focused_dark_390x844.png',
  'pressed': 'goldens/shop_state_pressed_dark_390x844.png',
  'permission_denied': 'goldens/shop_state_permission_denied_dark_390x844.png',
  'syncing': 'goldens/shop_state_syncing_dark_390x844.png',
  'conflict': 'goldens/shop_state_conflict_dark_390x844.png',
  'security_timeout': 'goldens/shop_state_security_timeout_dark_390x844.png',
  'reduced_motion': 'goldens/shop_state_reduced_motion_dark_390x844.png',
  'dark': 'goldens/shop_state_dark_390x844.png',
  'light': 'goldens/shop_state_light_390x844.png',
};

Future<void> _pumpShopStateGolden(
  WidgetTester tester, {
  required String id,
  required ShopProductLoader productLoader,
  Size size = const Size(390, 844),
  double textScale = 1,
  bool settle = true,
  bool online = true,
  Duration loadTimeout = const Duration(seconds: 12),
  String? autofocusProductId,
  Brightness brightness = Brightness.dark,
  bool reduceMotion = true,
  Future<void> Function(WidgetTester tester)? afterPump,
  Future<void> Function()? afterCapture,
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

  await tester.pumpWidget(
    _buildShopApp(
      productLoader: productLoader,
      goldenKey: const ValueKey<String>('shop-state-golden'),
      loadTimeout: loadTimeout,
      autofocusProductId: autofocusProductId,
      brightness: brightness,
      reduceMotion: reduceMotion,
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
  }

  await afterPump?.call(tester);

  expect(tester.takeException(), isNull);
  final goldenPath = _shopStateGoldenPaths[id];
  expect(goldenPath, isNotNull, reason: 'Missing Shop golden path for $id.');
  await expectLater(
    find.byKey(const ValueKey<String>('shop-state-golden')),
    matchesGoldenFile(goldenPath!),
  );
  await afterCapture?.call();
}

Widget _buildShopApp({
  required ShopProductLoader productLoader,
  Key? goldenKey,
  Duration loadTimeout = const Duration(seconds: 12),
  String? autofocusProductId,
  Brightness brightness = Brightness.dark,
  bool reduceMotion = true,
}) {
  final router = GoRouter(
    initialLocation: '/shop',
    routes: [
      GoRoute(
        path: '/shop',
        builder: (context, state) => RepaintBoundary(
          key: goldenKey,
          child: ShopScreen(
            productLoader: productLoader,
            loadTimeout: loadTimeout,
            autofocusProductId: autofocusProductId,
          ),
        ),
      ),
      GoRoute(
        path: '/shop/cart',
        builder: (context, state) => const SizedBox.shrink(),
      ),
      GoRoute(
        path: '/shop/product/:productId',
        builder: (context, state) => const SizedBox.shrink(),
      ),
    ],
  );

  return ProviderScope(
    overrides: [currentUserProvider.overrideWithValue(_user)],
    child: MaterialApp.router(
      theme: ClubTheme.from(ClubConfig.fallback(), brightness: brightness),
      routerConfig: router,
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(
            disableAnimations: reduceMotion,
            accessibleNavigation: reduceMotion,
          ),
          child: ClubConfigScope(
            config: ClubConfig.fallback(),
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    ),
  );
}

void _setGoldenSurface(
  WidgetTester tester,
  Size size, {
  bool reduceMotion = true,
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

const _user = UserProfile(
  id: 'supporter-1',
  clubId: '24',
  publicUserId: '483912',
);

const _products = <Map<String, dynamic>>[
  <String, dynamic>{
    'id': 'jersey-home',
    'name': 'Home Match Jersey',
    'subtitle': 'Official 2026 supporter edition',
    'category': 'Jerseys',
    'price': 25000,
    'badge_label': 'NEW',
  },
  <String, dynamic>{
    'id': 'scarf-blue',
    'name': 'Club Scarf',
    'subtitle': 'Blue and white woven scarf',
    'category': 'Accessories',
    'price': 8000,
  },
];

const _unavailableProducts = <Map<String, dynamic>>[
  <String, dynamic>{
    'id': 'jersey-sold-out',
    'name': 'Home Match Jersey',
    'subtitle': 'Official 2026 supporter edition',
    'category': 'Jerseys',
    'price': 25000,
    'in_stock': false,
    'stock': 0,
  },
];
