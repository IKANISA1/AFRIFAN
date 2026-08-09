import 'dart:async';

import 'package:core_auth/core_auth.dart';
import 'package:core_feature_config/core_feature_config.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:feat_club/feat_club.dart';
import 'package:feat_shop/src/screens/cart_screen.dart';
import 'package:feat_shop/src/shop_cart_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_support/app_font_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);
  late List<AfriCountry> previousCountries;
  setUp(() {
    ConnectivityService.setOnlineForTest(true);
    previousCountries = AfriCountryCatalog.all;
    AfriCountryCatalog.withCountries(const <AfriCountry>[_rwanda]);
  });
  tearDown(() => AfriCountryCatalog.withCountries(previousCountries));

  testWidgets('cart refreshes payment availability after reconnect', (
    tester,
  ) async {
    var loadCount = 0;
    ConnectivityService.setOnlineForTest(false);
    addTearDown(() => ConnectivityService.setOnlineForTest(true));

    await tester.pumpWidget(
      _buildCartApp(
        paymentRouteLoader: (_) async {
          loadCount += 1;
          return _route;
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Connection required'), findsOneWidget);
    expect(loadCount, 0);

    ConnectivityService.setOnlineForTest(true);
    await tester.pumpAndSettle();

    expect(find.text('Checkout via MOMO'), findsOneWidget);
    expect(loadCount, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cart sanitizes unexpected checkout failures', (tester) async {
    await tester.pumpWidget(
      _buildCartApp(
        paymentRouteLoader: (_) async => _route,
        orderPlacer:
            ({
              required userId,
              required partnerId,
              required items,
              required deliveryAddress,
              required paymentReference,
            }) async => throw StateError(
              'private database diagnostic for tenant account 491',
            ),
      ),
    );
    await tester.pumpAndSettle();
    await _submitOrderFromCart(tester);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.ensureVisible(find.text('Checkout could not start'));
    await tester.pump();

    expect(find.text('Checkout could not start'), findsOneWidget);
    expect(find.textContaining('private database diagnostic'), findsNothing);
    expect(find.text('Review cart'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('golden cart loading state', (tester) async {
    final pendingRoute = Completer<PartnerPaymentRoute?>();
    addTearDown(() {
      if (!pendingRoute.isCompleted) pendingRoute.complete(_route);
    });

    await _pumpCartGolden(
      tester,
      id: 'loading',
      paymentRouteLoader: (_) => pendingRoute.future,
      settle: false,
      afterPump: (tester) async {
        await tester.ensureVisible(find.text('Checking payment').first);
        await tester.pump();
      },
    );

    expect(find.text('Checking payment'), findsWidgets);
  });

  testWidgets('golden cart empty state', (tester) async {
    await _pumpCartGolden(
      tester,
      id: 'empty',
      seeded: false,
      paymentRouteLoader: (_) async => _route,
    );

    expect(find.text('Cart is empty'), findsOneWidget);
    expect(find.text('Back to shop'), findsOneWidget);
  });

  testWidgets('golden cart error state', (tester) async {
    await _pumpCartGolden(
      tester,
      id: 'error',
      paymentRouteLoader: (_) async =>
          throw StateError('payment availability unavailable'),
      afterPump: (tester) async {
        await tester.ensureVisible(find.text('Payment check failed').first);
        await tester.pumpAndSettle();
      },
    );

    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('golden cart offline state', (tester) async {
    await _pumpCartGolden(
      tester,
      id: 'offline',
      online: false,
      paymentRouteLoader: (_) async => _route,
      afterPump: (tester) async {
        await tester.ensureVisible(find.text('Checkout unavailable'));
        await tester.pumpAndSettle();
      },
    );

    expect(find.text('Connection required'), findsOneWidget);
    expect(find.text('Checkout unavailable'), findsOneWidget);
  });

  testWidgets('golden cart disabled state', (tester) async {
    await _pumpCartGolden(
      tester,
      id: 'disabled',
      paymentRouteLoader: (_) async => null,
      afterPump: (tester) async {
        await tester.ensureVisible(find.text('Payment route not ready'));
        await tester.pumpAndSettle();
      },
    );

    expect(
      tester
          .widget<AfriButton>(
            find.widgetWithText(AfriButton, 'Payment route not ready'),
          )
          .enabled,
      isFalse,
    );
  });

  testWidgets('golden cart focused address state', (tester) async {
    await _pumpCartGolden(
      tester,
      id: 'focused',
      paymentRouteLoader: (_) async => _route,
      afterPump: (tester) async {
        final address = find.widgetWithText(AfriInputField, 'Delivery address');
        await tester.ensureVisible(address);
        await tester.tap(address);
        await tester.enterText(address, '12 Amahoro Avenue');
        await tester.pump();
      },
    );

    expect(FocusManager.instance.primaryFocus?.debugLabel, 'Delivery address');
  });

  testWidgets('golden cart selected quantity state', (tester) async {
    await _pumpCartGolden(
      tester,
      id: 'selected',
      paymentRouteLoader: (_) async => _route,
      afterPump: (tester) async {
        final increase = find.byTooltip('Increase quantity');
        await tester.tap(increase);
        await tester.pumpAndSettle();
      },
    );

    expect(find.text('Qty 2'), findsOneWidget);
  });

  testWidgets('golden cart pressed checkout state', (tester) async {
    TestGesture? heldGesture;
    await _pumpCartGolden(
      tester,
      id: 'pressed',
      paymentRouteLoader: (_) async => _route,
      afterPump: (tester) async {
        final checkout = find.widgetWithText(AfriButton, 'Checkout via MOMO');
        await tester.ensureVisible(checkout);
        heldGesture = await tester.startGesture(tester.getCenter(checkout));
        await tester.pump(const Duration(milliseconds: 120));
      },
    );

    await heldGesture?.up();
  });

  testWidgets('golden cart permission-denied checkout state', (tester) async {
    await _pumpCartGolden(
      tester,
      id: 'permission_denied',
      paymentRouteLoader: (_) async => _route,
      orderPlacer:
          ({
            required userId,
            required partnerId,
            required items,
            required deliveryAddress,
            required paymentReference,
          }) async => throw StateError(
            'permission denied by tenant RLS for private account 491',
          ),
      afterPump: (tester) async {
        await _submitOrderFromCart(tester);
        await tester.pump(const Duration(milliseconds: 300));
      },
    );

    expect(find.text('Checkout not permitted'), findsWidgets);
    expect(find.textContaining('private account'), findsNothing);
    expect(
      tester
          .widget<AfriButton>(
            find.widgetWithText(AfriButton, 'Checkout not permitted'),
          )
          .enabled,
      isFalse,
    );
  });

  testWidgets('golden cart syncing checkout state', (tester) async {
    final pendingOrder = Completer<String>();
    addTearDown(() {
      if (!pendingOrder.isCompleted) pendingOrder.complete('order-1');
    });

    await _pumpCartGolden(
      tester,
      id: 'syncing',
      paymentRouteLoader: (_) async => _route,
      orderPlacer:
          ({
            required userId,
            required partnerId,
            required items,
            required deliveryAddress,
            required paymentReference,
          }) => pendingOrder.future,
      checkoutTimeout: const Duration(seconds: 1),
      afterPump: (tester) async {
        await _submitOrderFromCart(tester);
        await tester.pump(const Duration(milliseconds: 300));
      },
    );

    expect(find.text('Processing'), findsOneWidget);
    expect(
      tester
          .widget<AfriButton>(find.widgetWithText(AfriButton, 'Processing'))
          .enabled,
      isFalse,
    );
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('golden cart conflict checkout state', (tester) async {
    await _pumpCartGolden(
      tester,
      id: 'conflict',
      paymentRouteLoader: (_) async => _route,
      orderPlacer:
          ({
            required userId,
            required partnerId,
            required items,
            required deliveryAddress,
            required paymentReference,
          }) async => throw const OrderConflictException(),
      afterPump: (tester) async {
        await _submitOrderFromCart(tester);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.ensureVisible(find.text('Order details changed'));
        await tester.pump();
      },
    );

    expect(find.text('Order details changed'), findsOneWidget);
    expect(find.text('Review cart'), findsOneWidget);
  });

  testWidgets('golden cart security-timeout checkout state', (tester) async {
    final pendingOrder = Completer<String>();
    addTearDown(() {
      if (!pendingOrder.isCompleted) pendingOrder.complete('order-1');
    });

    await _pumpCartGolden(
      tester,
      id: 'security_timeout',
      paymentRouteLoader: (_) async => _route,
      orderPlacer:
          ({
            required userId,
            required partnerId,
            required items,
            required deliveryAddress,
            required paymentReference,
          }) => pendingOrder.future,
      checkoutTimeout: const Duration(milliseconds: 20),
      afterPump: (tester) async {
        await _submitOrderFromCart(tester);
        await tester.pump(const Duration(milliseconds: 40));
        await tester.ensureVisible(find.text('Order status is uncertain'));
        await tester.pump();
      },
    );

    expect(find.text('Order status is uncertain'), findsOneWidget);
    expect(find.textContaining('Do not submit again'), findsOneWidget);
    expect(
      tester
          .widget<AfriButton>(
            find.widgetWithText(AfriButton, 'Status uncertain'),
          )
          .enabled,
      isFalse,
    );
  });

  testWidgets('golden cart large-text state', (tester) async {
    await _pumpCartGolden(
      tester,
      id: 'large_text',
      size: const Size(320, 720),
      textScale: 2,
      paymentRouteLoader: (_) async => _route,
      afterPump: (tester) async {
        await tester.ensureVisible(find.text('Pay with MOMO'));
        await tester.pumpAndSettle();
      },
    );

    expect(find.text('Pay with MOMO'), findsOneWidget);
  });
}

const _cartGoldenPaths = <String, String>{
  'loading': 'goldens/cart_state_loading_dark_390x844.png',
  'empty': 'goldens/cart_state_empty_dark_390x844.png',
  'error': 'goldens/cart_state_error_dark_390x844.png',
  'offline': 'goldens/cart_state_offline_dark_390x844.png',
  'disabled': 'goldens/cart_state_disabled_dark_390x844.png',
  'focused': 'goldens/cart_state_focused_dark_390x844.png',
  'permission_denied': 'goldens/cart_state_permission_denied_dark_390x844.png',
  'pressed': 'goldens/cart_state_pressed_dark_390x844.png',
  'selected': 'goldens/cart_state_selected_dark_390x844.png',
  'syncing': 'goldens/cart_state_syncing_dark_390x844.png',
  'conflict': 'goldens/cart_state_conflict_dark_390x844.png',
  'security_timeout': 'goldens/cart_state_security_timeout_dark_390x844.png',
  'large_text': 'goldens/cart_state_large_text_dark_320x720.png',
};

Future<void> _pumpCartGolden(
  WidgetTester tester, {
  required String id,
  required CartPaymentRouteLoader paymentRouteLoader,
  Size size = const Size(390, 844),
  double textScale = 1,
  bool settle = true,
  bool online = true,
  bool seeded = true,
  UserProfile? user = _user,
  CartOrderPlacer? orderPlacer,
  Duration checkoutTimeout = const Duration(seconds: 30),
  Future<void> Function(WidgetTester tester)? afterPump,
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
    _buildCartApp(
      paymentRouteLoader: paymentRouteLoader,
      seeded: seeded,
      user: user,
      orderPlacer: orderPlacer,
      checkoutTimeout: checkoutTimeout,
      goldenKey: const ValueKey<String>('cart-state-golden'),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
  }

  await afterPump?.call(tester);

  expect(tester.takeException(), isNull);
  final goldenPath = _cartGoldenPaths[id];
  expect(goldenPath, isNotNull, reason: 'Missing cart golden path for $id.');
  await expectLater(
    find.byKey(const ValueKey<String>('cart-state-golden')),
    matchesGoldenFile(goldenPath!),
  );
}

Widget _buildCartApp({
  required CartPaymentRouteLoader paymentRouteLoader,
  bool seeded = true,
  UserProfile? user = _user,
  CartOrderPlacer? orderPlacer,
  Duration checkoutTimeout = const Duration(seconds: 30),
  Key? goldenKey,
}) {
  return ProviderScope(
    overrides: [
      storeReleasePolicyProvider.overrideWithValue(
        const StoreReleasePolicy.unenforced(),
      ),
      currentUserProvider.overrideWithValue(user),
      if (seeded) shopCartProvider.overrideWith((ref) => _SeededCartNotifier()),
    ],
    child: MaterialApp(
      theme: ClubTheme.from(ClubConfig.fallback(), brightness: Brightness.dark),
      home: ClubConfigScope(
        config: ClubConfig.fallback(),
        child: RepaintBoundary(
          key: goldenKey,
          child: CartScreen(
            paymentRouteLoader: paymentRouteLoader,
            orderPlacer: orderPlacer,
            checkoutTimeout: checkoutTimeout,
          ),
        ),
      ),
    ),
  );
}

Future<void> _submitOrderFromCart(WidgetTester tester) async {
  final address = find.widgetWithText(AfriInputField, 'Delivery address');
  await tester.enterText(address, '12 Amahoro Avenue');
  final checkout = find.widgetWithText(AfriButton, 'Checkout via MOMO');
  await tester.ensureVisible(checkout);
  await tester.tap(checkout);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  final confirm = find.widgetWithText(AfriButton, 'I submitted the payment');
  await tester.ensureVisible(confirm);
  await tester.tap(confirm);
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

class _SeededCartNotifier extends ShopCartNotifier {
  _SeededCartNotifier() {
    addRawProduct(const <String, dynamic>{
      'id': 'shirt-1',
      'name': 'Home shirt',
      'category': 'jersey',
      'price': 25000,
      'stock': 5,
    }, partnerId: '24');
  }
}

const _user = UserProfile(
  id: 'supporter-1',
  clubId: '24',
  publicUserId: '483912',
);

const _route = PartnerPaymentRoute(
  id: 'route-1',
  partnerId: '24',
  partnerName: 'Rayon Sports',
  partnerSlug: 'rayon-sports',
  countryCode: 'RW',
  providerId: 'mtn',
  recipientCode: '1828',
  reconciliationLabel: 'Shop orders',
  status: PartnerPaymentRouteStatus.active,
);

const _rwanda = AfriCountry(
  isoCode: 'RW',
  dialCode: '+250',
  name: 'Rwanda',
  flagEmoji: '',
  currencyCode: 'RWF',
  currencyName: 'Rwandan franc',
  momoUssdTemplate: '*182*1*1*{recipient}*{amount}#',
  momoCodeUssdTemplate: '*182*8*1*{recipient}*{amount}#',
);
