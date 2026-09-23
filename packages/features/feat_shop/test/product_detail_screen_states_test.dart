import 'dart:async';

import 'package:core_auth/core_auth.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_shop/src/screens/product_detail_screen.dart';
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

  test('product-detail failures sanitize known backend categories', () {
    expect(
      ProductDetailFailure.fromError(
        StateError('RLS permission denied for private-product-row-4482'),
      ).kind,
      ProductDetailFailureKind.permissionDenied,
    );
    expect(
      ProductDetailFailure.fromError(
        StateError('revision conflict for private-product-row-4482'),
      ).kind,
      ProductDetailFailureKind.conflict,
    );
    expect(
      ProductDetailFailure.fromError(
        TimeoutException('private product token 4482'),
      ).kind,
      ProductDetailFailureKind.securityTimeout,
    );
    expect(
      ProductDetailFailure.fromError(
        StateError('private product token 4482'),
      ).toString(),
      'ProductDetailFailure(unknown)',
    );
  });

  testWidgets('product detail reloads automatically after reconnect', (
    tester,
  ) async {
    var loadCount = 0;
    _setGoldenSurface(tester, const Size(390, 844));
    ConnectivityService.setOnlineForTest(false);
    addTearDown(() => ConnectivityService.setOnlineForTest(true));

    await tester.pumpWidget(
      _buildProductDetailApp(
        productLoader: (_) async {
          loadCount += 1;
          return _product;
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Product details offline'), findsOneWidget);
    expect(loadCount, 0);

    ConnectivityService.setOnlineForTest(true);
    await tester.pumpAndSettle();

    expect(find.text('Home Match Jersey'), findsOneWidget);
    expect(loadCount, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('golden product-detail loading state', (tester) async {
    final pendingProduct = Completer<Map<String, dynamic>?>();
    addTearDown(() {
      if (!pendingProduct.isCompleted) {
        pendingProduct.complete(null);
      }
    });

    await _pumpProductDetailGolden(
      tester,
      id: 'loading',
      productLoader: (_) => pendingProduct.future,
      settle: false,
      afterCapture: () async {
        if (!pendingProduct.isCompleted) {
          pendingProduct.complete(null);
        }
        await tester.pump();
      },
    );
  });

  testWidgets('golden product-detail empty state', (tester) async {
    await _pumpProductDetailGolden(
      tester,
      id: 'empty',
      productLoader: (_) async => null,
    );

    expect(find.text('Product not found'), findsOneWidget);
    expect(find.text('Back to store'), findsOneWidget);
  });

  testWidgets('golden product-detail error state', (tester) async {
    await _pumpProductDetailGolden(
      tester,
      id: 'error',
      productLoader: (_) async => throw StateError('catalog unavailable'),
    );

    expect(find.text('Product unavailable'), findsOneWidget);
    expect(find.text('Refresh'), findsOneWidget);
  });

  testWidgets('golden product-detail offline state', (tester) async {
    await _pumpProductDetailGolden(
      tester,
      id: 'offline',
      online: false,
      productLoader: (_) async => _product,
    );

    expect(find.text('Product details offline'), findsOneWidget);
    expect(
      find.text('Reconnect to check the latest price, size, and availability.'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('golden product-detail large-text state', (tester) async {
    await _pumpProductDetailGolden(
      tester,
      id: 'large_text',
      size: const Size(320, 720),
      textScale: 2,
      productLoader: (_) async => _product,
      afterPump: (tester) async {
        await tester.scrollUntilVisible(
          find.text('Select size'),
          220,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
      },
    );
  });

  testWidgets('golden product-detail selected-size state', (tester) async {
    await _pumpProductDetailGolden(
      tester,
      id: 'selected',
      productLoader: (_) async => _product,
      afterPump: (tester) async {
        final xlSize = find.bySemanticsLabel('Size XL');
        await tester.ensureVisible(xlSize);
        await tester.pumpAndSettle();
        await tester.tap(xlSize);
        await tester.pumpAndSettle();
      },
    );

    final selectedSize = find.bySemanticsLabel('Size XL');
    final semantics = tester.getSemantics(selectedSize);
    expect(semantics.flagsCollection.isSelected.toBoolOrNull(), isTrue);
  });

  testWidgets('golden product-detail permission-denied state', (tester) async {
    await _pumpProductDetailGolden(
      tester,
      id: 'permission_denied',
      productLoader: (_) async {
        throw StateError('RLS permission denied for private-product-row-4482');
      },
    );

    expect(find.text('Product access not available'), findsOneWidget);
    expect(find.textContaining('private-product-row-4482'), findsNothing);
  });

  testWidgets('golden product-detail disabled state', (tester) async {
    await _pumpProductDetailGolden(
      tester,
      id: 'disabled',
      productLoader: (_) async => _outOfStockProduct,
    );

    expect(find.text('Out of stock'), findsOneWidget);
    expect(
      tester
          .widget<AfriButton>(
            find.byKey(const ValueKey<String>('product-detail-add')),
          )
          .enabled,
      isFalse,
    );
  });

  testWidgets('golden product-detail focused state', (tester) async {
    final previousHighlightStrategy = FocusManager.instance.highlightStrategy;
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    addTearDown(
      () => FocusManager.instance.highlightStrategy = previousHighlightStrategy,
    );

    await _pumpProductDetailGolden(
      tester,
      id: 'focused',
      autofocusSize: 'M',
      productLoader: (_) async => _product,
      afterPump: (tester) async {
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey<String>('product-detail-size-M')),
          220,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
      },
    );

    expect(FocusManager.instance.primaryFocus?.hasFocus, isTrue);
  });

  testWidgets('golden product-detail pressed state', (tester) async {
    TestGesture? heldGesture;
    await _pumpProductDetailGolden(
      tester,
      id: 'pressed',
      productLoader: (_) async => _product,
      afterPump: (tester) async {
        final size = find.byKey(
          const ValueKey<String>('product-detail-size-M'),
        );
        await tester.scrollUntilVisible(
          size,
          220,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        heldGesture = await tester.startGesture(tester.getCenter(size));
        await tester.pump(const Duration(milliseconds: 100));
      },
      afterCapture: () async {
        await heldGesture?.up();
      },
    );
  });

  testWidgets('golden product-detail reduced-motion state', (tester) async {
    await _pumpProductDetailGolden(
      tester,
      id: 'reduced_motion',
      reduceMotion: true,
      productLoader: (_) async => _product,
    );

    final context = tester.element(
      find.byKey(const ValueKey<String>('product-detail-add')),
    );
    expect(AfriMotion.reduceMotion(context), isTrue);
  });

  testWidgets('golden product-detail explicit dark state', (tester) async {
    await _pumpProductDetailGolden(
      tester,
      id: 'dark',
      brightness: Brightness.dark,
      productLoader: (_) async => _product,
    );
  });

  testWidgets('golden product-detail explicit light state', (tester) async {
    await _pumpProductDetailGolden(
      tester,
      id: 'light',
      brightness: Brightness.light,
      productLoader: (_) async => _product,
    );
  });

  testWidgets('golden product-detail syncing state', (tester) async {
    final refreshCompleter = Completer<Map<String, dynamic>?>();
    var invocationCount = 0;
    addTearDown(() {
      if (!refreshCompleter.isCompleted) {
        refreshCompleter.complete(_product);
      }
    });

    await _pumpProductDetailGolden(
      tester,
      id: 'syncing',
      productLoader: (_) {
        invocationCount += 1;
        if (invocationCount == 1) {
          return Future<Map<String, dynamic>?>.value(_product);
        }
        return refreshCompleter.future;
      },
      afterPump: (tester) async {
        ConnectivityService.setOnlineForTest(false);
        await tester.pump();
        ConnectivityService.setOnlineForTest(true);
        await tester.pump();
        expect(find.text('Refreshing product details'), findsOneWidget);
      },
      afterCapture: () async {
        if (!refreshCompleter.isCompleted) {
          refreshCompleter.complete(_product);
        }
        await tester.pump();
      },
    );
  });

  testWidgets('golden product-detail conflict state', (tester) async {
    await _pumpProductDetailGolden(
      tester,
      id: 'conflict',
      productLoader: (_) async {
        throw StateError('revision conflict for private-product-row-4482');
      },
    );

    expect(find.text('Product details changed'), findsOneWidget);
    expect(find.textContaining('private-product-row-4482'), findsNothing);
  });

  testWidgets('golden product-detail security-timeout state', (tester) async {
    final pendingProduct = Completer<Map<String, dynamic>?>();
    addTearDown(() {
      if (!pendingProduct.isCompleted) pendingProduct.complete(null);
    });

    await _pumpProductDetailGolden(
      tester,
      id: 'security_timeout',
      loadTimeout: const Duration(milliseconds: 1),
      productLoader: (_) => pendingProduct.future,
    );

    expect(find.text('Product security check timed out'), findsOneWidget);
  });
}

const _productDetailGoldenPaths = <String, String>{
  'loading': 'goldens/product_detail_state_loading_dark_390x844.png',
  'empty': 'goldens/product_detail_state_empty_dark_390x844.png',
  'error': 'goldens/product_detail_state_error_dark_390x844.png',
  'offline': 'goldens/product_detail_state_offline_dark_390x844.png',
  'large_text': 'goldens/product_detail_state_large_text_dark_320x720.png',
  'selected': 'goldens/product_detail_state_selected_dark_390x844.png',
  'permission_denied':
      'goldens/product_detail_state_permission_denied_dark_390x844.png',
  'disabled': 'goldens/product_detail_state_disabled_dark_390x844.png',
  'focused': 'goldens/product_detail_state_focused_dark_390x844.png',
  'pressed': 'goldens/product_detail_state_pressed_dark_390x844.png',
  'reduced_motion':
      'goldens/product_detail_state_reduced_motion_dark_390x844.png',
  'dark': 'goldens/product_detail_state_dark_390x844.png',
  'light': 'goldens/product_detail_state_light_390x844.png',
  'syncing': 'goldens/product_detail_state_syncing_dark_390x844.png',
  'conflict': 'goldens/product_detail_state_conflict_dark_390x844.png',
  'security_timeout':
      'goldens/product_detail_state_security_timeout_dark_390x844.png',
};

Future<void> _pumpProductDetailGolden(
  WidgetTester tester, {
  required String id,
  required ProductDetailLoader productLoader,
  Size size = const Size(390, 844),
  double textScale = 1,
  bool settle = true,
  bool online = true,
  Duration loadTimeout = const Duration(seconds: 12),
  String? autofocusSize,
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
    _buildProductDetailApp(
      productLoader: productLoader,
      goldenKey: const ValueKey<String>('product-detail-state-golden'),
      loadTimeout: loadTimeout,
      autofocusSize: autofocusSize,
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
  final goldenPath = _productDetailGoldenPaths[id];
  expect(
    goldenPath,
    isNotNull,
    reason: 'Missing product-detail golden path for $id.',
  );
  await expectLater(
    find.byKey(const ValueKey<String>('product-detail-state-golden')),
    matchesGoldenFile(goldenPath!),
  );
  await afterCapture?.call();
}

Widget _buildProductDetailApp({
  required ProductDetailLoader productLoader,
  Key? goldenKey,
  Duration loadTimeout = const Duration(seconds: 12),
  String? autofocusSize,
  Brightness brightness = Brightness.dark,
  bool reduceMotion = true,
}) {
  final router = GoRouter(
    initialLocation: '/shop/product/jersey-home',
    routes: [
      GoRoute(
        path: '/shop/product/:productId',
        builder: (context, state) => RepaintBoundary(
          key: goldenKey,
          child: ProductDetailScreen(
            productId: state.pathParameters['productId']!,
            productLoader: productLoader,
            loadTimeout: loadTimeout,
            autofocusSize: autofocusSize,
          ),
        ),
      ),
      GoRoute(
        path: '/shop',
        builder: (context, state) => const SizedBox.shrink(),
      ),
      GoRoute(
        path: '/shop/cart',
        builder: (context, state) => const SizedBox.shrink(),
      ),
      GoRoute(
        path: '/onboarding',
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

const _product = <String, dynamic>{
  'id': 'jersey-home',
  'name': 'Home Match Jersey',
  'description':
      'Official 2026 supporter edition with breathable stadium fabric and '
      'a premium woven club mark.',
  'price': 25000,
  'badge_label': 'OFFICIAL',
  'available_sizes': <String>['S', 'M', 'L', 'XL'],
  'inventory_count': 47,
  'in_stock': true,
  'image_url': '',
};

const _outOfStockProduct = <String, dynamic>{
  'id': 'jersey-home',
  'name': 'Home Match Jersey',
  'description': 'Official 2026 supporter edition.',
  'price': 25000,
  'badge_label': 'SOLD OUT',
  'available_sizes': <String>['S', 'M', 'L', 'XL'],
  'inventory_count': 0,
  'in_stock': false,
  'image_url': '',
};
