import 'package:core_auth/core_auth.dart';
import 'package:core_feature_config/core_feature_config.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:feat_shop/src/screens/cart_screen.dart';
import 'package:feat_shop/src/screens/product_detail_screen.dart';
import 'package:feat_shop/src/screens/shop_screen.dart';
import 'package:feat_shop/src/shop_cart_provider.dart';
import 'package:feat_shop/src/widgets/shop_product_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:test_support/app_font_loader.dart';
import 'package:test_support/shop_fixture_images.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);
  useShopFixtureImages();

  for (final mode in [Brightness.dark, Brightness.light]) {
    testWidgets(
      'photographed product, size and quantity reach cart in ${mode.name}',
      (tester) async {
        final container = await _pumpShop(tester, mode: mode);
        await settleShopFixtureImages(tester);
        await tester.tap(find.text('Home Match Jersey'));
        await tester.pumpAndSettle();
        await settleShopFixtureImages(tester);
        await tester.ensureVisible(find.text('M'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('M'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(AfriButton, 'Buy now'));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 4));
        await settleShopFixtureImages(tester);
        await dismissShopFixtureFeedback(tester);
        await tester.pumpAndSettle();
        final item = container.read(shopCartProvider).single;
        expect(item.selectedVariant, 'M');
        expect(item.product.imageUrl, shopHomePhoto);
        expect(item.product.imageRightsApproved, isTrue);
        expect(find.byType(ShopProductImage), findsOneWidget);
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/shop_cart_photo_${mode.name}_390x844.png'),
        );

        final address = find.byType(AfriInputField);
        await tester.ensureVisible(address);
        await tester.enterText(address, '12 Amahoro Avenue, Kigali');
        final pay = find.widgetWithText(AfriButton, 'Checkout via MOMO');
        await tester.ensureVisible(pay);
        await tester.pumpAndSettle();
        await tester.tap(pay);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await settleShopFixtureImages(tester, settleAnimations: false);
        expect(find.text('Review order'), findsOneWidget);
        expect(find.byType(ShopProductImage), findsWidgets);
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'goldens/shop_order_review_photo_${mode.name}_390x844.png',
          ),
        );
        // Dismiss the review without placing an order or launching payment.
        final context = tester.element(find.text('Review order'));
        Navigator.of(context).pop(false);
        await tester.pumpAndSettle();
        expect(container.read(shopCartProvider).single.selectedVariant, 'M');
      },
    );

    testWidgets(
      'shop search has product photos and navigates in ${mode.name}',
      (tester) async {
        await _pumpShop(tester, mode: mode);
        await _openSearch(tester);
        await settleShopFixtureImages(tester);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'goldens/shop_search_photo_${mode.name}_390x844.png',
          ),
        );
        await tester.enterText(find.byType(TextField).last, 'Away');
        await tester.pumpAndSettle();
        expect(find.text('Away Match Jersey').hitTestable(), findsOneWidget);
        await tester.tap(find.text('Away Match Jersey').hitTestable());
        await tester.pumpAndSettle();
        expect(find.byType(ProductDetailScreen), findsOneWidget);
        expect(
          tester
              .widget<ProductDetailScreen>(find.byType(ProductDetailScreen))
              .productId,
          'jersey-away',
        );
      },
    );
  }

  testWidgets(
    'large-text search handles keyboard and no results without clipping',
    (tester) async {
      await _pumpShop(
        tester,
        mode: Brightness.dark,
        size: const Size(320, 720),
        textScale: 2,
      );
      await _openSearch(tester);
      await settleShopFixtureImages(tester);
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/shop_search_photo_large_text_dark_320x720.png',
        ),
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 250);
      addTearDown(tester.view.resetViewInsets);
      await tester.enterText(find.byType(TextField).last, 'unlisted');
      await tester.pumpAndSettle();
      expect(find.text('No result matches “unlisted”.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'missing or revoked photo approval does not resolve a remote image',
    (tester) async {
      for (final record in [
        {
          'url': shopHomePhoto,
          'approved': false,
          'provenance': shopPhotoProvenance,
        },
        {'url': shopHomePhoto, 'approved': true, 'provenance': ''},
        {'url': 'https:', 'approved': true, 'provenance': shopPhotoProvenance},
        {
          'url': 'http://example.invalid/photo.jpg',
          'approved': true,
          'provenance': shopPhotoProvenance,
        },
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            home: ShopProductImage(
              url: record['url'] as String,
              name: 'Product',
              rightsApproved: record['approved'] as bool,
              provenanceId: record['provenance'] as String,
            ),
          ),
        );
        expect(find.byType(Image), findsNothing);
        expect(tester.takeException(), isNull);
      }
    },
  );
}

Future<void> _openSearch(WidgetTester tester) async {
  await tester.tap(find.byIcon(AfriIcons.search).first);
  await tester.pumpAndSettle();
}

Future<ProviderContainer> _pumpShop(
  WidgetTester tester, {
  required Brightness mode,
  Size size = const Size(390, 844),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  TypographyTokens.debugUseFallbackFonts = true;
  ColorTokens.setBrightness(mode);
  ConnectivityService.setOnlineForTest(true);
  final countries = AfriCountryCatalog.all;
  AfriCountryCatalog.withCountries(const [
    AfriCountry(
      isoCode: 'RW',
      dialCode: '+250',
      name: 'Rwanda',
      flagEmoji: '',
      currencyCode: 'RWF',
      currencyName: 'Rwandan franc',
      momoUssdTemplate: '*182*1*1*{recipient}*{amount}#',
      momoCodeUssdTemplate: '*182*8*1*{recipient}*{amount}#',
    ),
  ]);
  addTearDown(() {
    TypographyTokens.debugUseFallbackFonts = false;
    ColorTokens.setBrightness(Brightness.dark);
    AfriCountryCatalog.withCountries(countries);
  });
  final container = ProviderContainer(
    overrides: [
      currentUserProvider.overrideWithValue(
        const UserProfile(
          id: 'review-user',
          clubId: '24',
          publicUserId: '483912',
        ),
      ),
      storeReleasePolicyProvider.overrideWithValue(
        const StoreReleasePolicy.unenforced(),
      ),
    ],
  );
  final router = GoRouter(
    initialLocation: '/shop',
    routes: [
      GoRoute(
        path: '/shop',
        builder: (_, _) => ShopScreen(productLoader: () async => _products),
      ),
      GoRoute(
        path: '/shop/product/:productId',
        builder: (_, state) => ProductDetailScreen(
          productId: state.pathParameters['productId']!,
          productLoader: (id) async =>
              _products.firstWhere((product) => product['id'] == id),
        ),
      ),
      GoRoute(
        path: '/shop/cart',
        builder: (_, _) => CartScreen(
          orderPlacer:
              ({
                required userId,
                required partnerId,
                required items,
                required deliveryAddress,
                required paymentReference,
              }) async => throw StateError(
                'The review journey must not place an order.',
              ),
          paymentRouteLoader: (_) async => const PartnerPaymentRoute(
            id: 'review-route',
            partnerId: '24',
            partnerName: 'Rayon Sports',
            partnerSlug: 'rayon-sports',
            countryCode: 'RW',
            providerId: 'mtn',
            recipientCode: '1828',
            reconciliationLabel: 'Shop orders',
            status: PartnerPaymentRouteStatus.active,
          ),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: ClubTheme.from(ClubConfig.fallback(), brightness: mode),
        routerConfig: router,
        builder: (context, child) =>
            ClubConfigScope(config: ClubConfig.fallback(), child: child!),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

const _products = <Map<String, dynamic>>[
  {
    'id': 'jersey-home',
    'name': 'Home Match Jersey',
    'category': 'Jerseys',
    'description': 'Blue and white supporter edition',
    'price': 25000,
    'stock': 47,
    'available_sizes': ['S', 'M', 'L', 'XL'],
    'image_url': shopHomePhoto,
    'image_rights_approved': true,
    'image_provenance_id': shopPhotoProvenance,
  },
  {
    'id': 'jersey-away',
    'name': 'Away Match Jersey',
    'category': 'Jerseys',
    'description': 'White and blue supporter edition',
    'price': 25000,
    'stock': 12,
    'available_sizes': ['S', 'M', 'L', 'XL'],
    'image_url': shopAwayPhoto,
    'image_rights_approved': true,
    'image_provenance_id': shopPhotoProvenance,
  },
];
