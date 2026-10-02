import 'package:club_data/club_data.dart';
import 'package:core_auth/core_auth.dart';
import 'package:core_feature_config/core_feature_config.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:feat_shop/src/screens/cart_screen.dart';
import 'package:feat_shop/src/shop_cart_provider.dart';
import 'package:feat_shop/src/shop_checkout_recovery.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test_support/app_font_loader.dart';
import 'package:test_support/shop_fixture_images.dart';

import 'shop_checkout_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);
  useShopFixtureImages();
  setUp(() => ConnectivityService.setOnlineForTest(true));
  testWidgets('empty cart uses the responsive scaffold on tablet', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(720, 1024);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shopCheckoutJournalProvider.overrideWithValue(
            MemoryShopCheckoutJournal(),
          ),
          storeReleasePolicyProvider.overrideWithValue(
            const StoreReleasePolicy.unenforced(),
          ),
          currentUserProvider.overrideWithValue(null),
        ],
        child: MaterialApp(
          home: ClubConfigScope(
            config: ClubConfig.fallback(),
            child: const CartScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AfriScreenScaffold), findsOneWidget);
    expect(find.text('Cart is empty'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('cart-empty-state'))).width,
      AfriResponsive.tabletContentMax,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('production policy keeps checkout and payment lookup closed', (
    tester,
  ) async {
    final repository = _FakeClubRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shopCheckoutJournalProvider.overrideWithValue(
            MemoryShopCheckoutJournal(),
          ),
          storeReleasePolicyProvider.overrideWithValue(
            const StoreReleasePolicy(isEnforced: true),
          ),
          currentUserProvider.overrideWithValue(_user),
          clubRepositoryProvider.overrideWithValue(repository),
          shopCartProvider.overrideWith((ref) => _SeededCartNotifier()),
        ],
        child: MaterialApp(
          home: ClubConfigScope(
            config: ClubConfig.fallback(),
            child: const CartScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final blocked = find.widgetWithText(AfriButton, 'Checkout not permitted');
    expect(blocked, findsOneWidget);
    expect(tester.widget<AfriButton>(blocked).enabled, isFalse);
    verifyNever(() => repository.findActivePaymentRoute(any()));
  });

  testWidgets(
    'checkout announces address error, retains input, supports autofill, and releases focus',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final previousCountries = AfriCountryCatalog.all;
      AfriCountryCatalog.withCountries(const <AfriCountry>[_rwanda]);
      addTearDown(() => AfriCountryCatalog.withCountries(previousCountries));
      final repository = _FakeClubRepository();
      when(
        () => repository.findActivePaymentRoute(any()),
      ).thenAnswer((_) async => _route);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            shopCheckoutJournalProvider.overrideWithValue(
              MemoryShopCheckoutJournal(),
            ),
            storeReleasePolicyProvider.overrideWithValue(
              const StoreReleasePolicy.unenforced(),
            ),
            currentUserProvider.overrideWithValue(_user),
            clubRepositoryProvider.overrideWithValue(repository),
            shopCartProvider.overrideWith((ref) => _SeededCartNotifier()),
          ],
          child: MaterialApp(
            home: ClubConfigScope(
              config: ClubConfig.fallback(),
              child: const CartScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final addressField = find.widgetWithText(
        AfriInputField,
        'Delivery address',
      );
      await tester.enterText(addressField, '   ');
      final checkoutButton = find.text('Checkout via MOMO');
      await tester.ensureVisible(checkoutButton);
      await tester.pumpAndSettle();
      await tester.tap(checkoutButton);
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(
        find.descendant(of: addressField, matching: find.byType(TextField)),
      );
      expect(textField.controller?.text, '   ');
      expect(
        textField.autofillHints,
        contains(AutofillHints.fullStreetAddress),
      );
      expect(
        find.bySemanticsLabel(
          'Delivery address. Error: Enter a delivery address first.',
        ),
        findsOneWidget,
      );
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'Delivery address',
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        isNot('Delivery address'),
      );
      semantics.dispose();
    },
  );

  testWidgets(
    'keeps the cart draft and refreshes payment state after reconnect',
    (tester) async {
      final previousCountries = AfriCountryCatalog.all;
      AfriCountryCatalog.withCountries(const <AfriCountry>[_rwanda]);
      addTearDown(() => AfriCountryCatalog.withCountries(previousCountries));
      final repository = _FakeClubRepository();
      when(
        () => repository.findActivePaymentRoute(any()),
      ).thenAnswer((_) async => _route);
      ConnectivityService.setOnlineForTest(false);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            shopCheckoutJournalProvider.overrideWithValue(
              MemoryShopCheckoutJournal(),
            ),
            storeReleasePolicyProvider.overrideWithValue(
              const StoreReleasePolicy.unenforced(),
            ),
            currentUserProvider.overrideWithValue(_user),
            clubRepositoryProvider.overrideWithValue(repository),
            shopCartProvider.overrideWith((ref) => _SeededCartNotifier()),
          ],
          child: MaterialApp(
            home: ClubConfigScope(
              config: ClubConfig.fallback(),
              child: const CartScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final addressField = find.widgetWithText(
        AfriInputField,
        'Delivery address',
      );
      await tester.enterText(addressField, 'Kigali delivery address');
      final blocked = find.widgetWithText(AfriButton, 'Connection required');
      await tester.ensureVisible(blocked);
      await tester.pumpAndSettle();

      expect(tester.widget<AfriButton>(blocked).enabled, isFalse);
      expect(find.text('Kigali delivery address'), findsOneWidget);
      verifyNever(() => repository.findActivePaymentRoute(any()));

      ConnectivityService.setOnlineForTest(true);
      await tester.pumpAndSettle();

      expect(find.text('Kigali delivery address'), findsOneWidget);
      expect(find.text('Checkout via MOMO'), findsOneWidget);
      verify(() => repository.findActivePaymentRoute(any())).called(1);
    },
  );

  testWidgets('checkout cancellation restores the address draft for review', (
    tester,
  ) async {
    final previousCountries = AfriCountryCatalog.all;
    AfriCountryCatalog.withCountries(const <AfriCountry>[_rwanda]);
    addTearDown(() => AfriCountryCatalog.withCountries(previousCountries));
    final repository = _FakeClubRepository();
    when(
      () => repository.findActivePaymentRoute(any()),
    ).thenAnswer((_) async => _route);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shopCheckoutJournalProvider.overrideWithValue(
            MemoryShopCheckoutJournal(),
          ),
          storeReleasePolicyProvider.overrideWithValue(
            const StoreReleasePolicy.unenforced(),
          ),
          currentUserProvider.overrideWithValue(_user),
          clubRepositoryProvider.overrideWithValue(repository),
          shopCartProvider.overrideWith((ref) => _SeededCartNotifier()),
        ],
        child: MaterialApp(
          home: ClubConfigScope(
            config: ClubConfig.fallback(),
            child: const CartScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final addressField = find.widgetWithText(
      AfriInputField,
      'Delivery address',
    );
    await tester.enterText(addressField, '12 Amahoro Avenue, Kigali');
    final checkout = find.text('Checkout via MOMO');
    await tester.ensureVisible(checkout);
    await tester.tap(checkout);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Review order'), findsOneWidget);
    expect(find.text('12 Amahoro Avenue, Kigali'), findsWidgets);
    expect(
      tester
          .widget<AfriButton>(find.widgetWithText(AfriButton, 'Processing'))
          .enabled,
      isFalse,
    );
    await tester.tap(find.text('Back'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      tester
          .widget<TextField>(
            find.descendant(of: addressField, matching: find.byType(TextField)),
          )
          .controller
          ?.text,
      '12 Amahoro Avenue, Kigali',
    );
    expect(find.text('Checkout via MOMO'), findsOneWidget);
    verifyNever(
      () => repository.placeOrder(
        userId: any(named: 'userId'),
        partnerId: any(named: 'partnerId'),
        items: any(named: 'items'),
        deliveryAddress: any(named: 'deliveryAddress'),
        paymentReference: any(named: 'paymentReference'),
      ),
    );
  });

  testWidgets(
    'keyboard-open checkout keeps address error and action reachable',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 320);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final previousCountries = AfriCountryCatalog.all;
      AfriCountryCatalog.withCountries(const <AfriCountry>[_rwanda]);
      addTearDown(() => AfriCountryCatalog.withCountries(previousCountries));
      final repository = _FakeClubRepository();
      when(
        () => repository.findActivePaymentRoute(any()),
      ).thenAnswer((_) async => _route);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            shopCheckoutJournalProvider.overrideWithValue(
              MemoryShopCheckoutJournal(),
            ),
            storeReleasePolicyProvider.overrideWithValue(
              const StoreReleasePolicy.unenforced(),
            ),
            currentUserProvider.overrideWithValue(_user),
            clubRepositoryProvider.overrideWithValue(repository),
            shopCartProvider.overrideWith((ref) => _SeededCartNotifier()),
          ],
          child: MaterialApp(
            home: ClubConfigScope(
              config: ClubConfig.fallback(),
              child: const CartScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final addressField = find.widgetWithText(
        AfriInputField,
        'Delivery address',
      );
      final checkout = find.widgetWithText(AfriButton, 'Checkout via MOMO');
      await tester.showKeyboard(addressField);
      await tester.enterText(addressField, '   ');
      await tester.ensureVisible(checkout);
      await tester.tap(checkout);
      await tester.pumpAndSettle();

      final error = find
          .descendant(
            of: addressField,
            matching: find.text('Enter a delivery address first.'),
          )
          .first;
      await tester.ensureVisible(addressField);
      await tester.pumpAndSettle();
      _expectInKeyboardViewport(tester, addressField);
      _expectInKeyboardViewport(tester, error);
      await tester.ensureVisible(checkout);
      await tester.pumpAndSettle();
      _expectInKeyboardViewport(tester, checkout);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    '200 percent text keeps populated cart and confirmation sheet usable',
    (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final previousCountries = AfriCountryCatalog.all;
      AfriCountryCatalog.withCountries(const <AfriCountry>[_rwanda]);
      addTearDown(() => AfriCountryCatalog.withCountries(previousCountries));
      final repository = _FakeClubRepository();
      when(
        () => repository.findActivePaymentRoute(any()),
      ).thenAnswer((_) async => _route);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            shopCheckoutJournalProvider.overrideWithValue(
              MemoryShopCheckoutJournal(),
            ),
            storeReleasePolicyProvider.overrideWithValue(
              const StoreReleasePolicy.unenforced(),
            ),
            currentUserProvider.overrideWithValue(_user),
            clubRepositoryProvider.overrideWithValue(repository),
            shopCartProvider.overrideWith((ref) => _SeededCartNotifier()),
          ],
          child: MaterialApp(
            home: ClubConfigScope(
              config: ClubConfig.fallback(),
              child: const CartScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Home shirt'), findsOneWidget);
      final addressField = find.widgetWithText(
        AfriInputField,
        'Delivery address',
      );
      final checkout = find.widgetWithText(AfriButton, 'Pay with MOMO');
      await tester.enterText(addressField, '   ');
      await tester.ensureVisible(checkout);
      await tester.tap(checkout);
      await tester.pumpAndSettle();
      final error = find
          .descendant(
            of: addressField,
            matching: find.text('Enter a delivery address first.'),
          )
          .first;
      await tester.ensureVisible(error);
      expect(tester.takeException(), isNull);

      await tester.enterText(addressField, '12 Amahoro Avenue, Kigali');
      await tester.pump(const Duration(seconds: 4));
      await tester.ensureVisible(checkout);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(checkout);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Review order'), findsOneWidget);
      final confirm = find.widgetWithText(AfriButton, 'Prepare order');
      final back = find.widgetWithText(AfriButton, 'Back');
      await tester.ensureVisible(confirm);
      await tester.ensureVisible(back);
      expect(tester.takeException(), isNull);
    },
  );

  for (final profile in <String, Size>{
    'standard landscape': const Size(852, 393),
    'compact-height landscape': const Size(720, 320),
  }.entries) {
    testWidgets('${profile.key} keeps populated cart form and action usable', (
      tester,
    ) async {
      tester.view.physicalSize = profile.value;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final previousCountries = AfriCountryCatalog.all;
      AfriCountryCatalog.withCountries(const <AfriCountry>[_rwanda]);
      addTearDown(() => AfriCountryCatalog.withCountries(previousCountries));
      final repository = _FakeClubRepository();
      when(
        () => repository.findActivePaymentRoute(any()),
      ).thenAnswer((_) async => _route);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            shopCheckoutJournalProvider.overrideWithValue(
              MemoryShopCheckoutJournal(),
            ),
            storeReleasePolicyProvider.overrideWithValue(
              const StoreReleasePolicy.unenforced(),
            ),
            currentUserProvider.overrideWithValue(_user),
            clubRepositoryProvider.overrideWithValue(repository),
            shopCartProvider.overrideWith((ref) => _SeededCartNotifier()),
          ],
          child: MaterialApp(
            home: ClubConfigScope(
              config: ClubConfig.fallback(),
              child: const CartScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final addressField = find.widgetWithText(
        AfriInputField,
        'Delivery address',
      );
      final checkout = find.widgetWithText(AfriButton, 'Checkout via MOMO');
      await tester.enterText(addressField, '12 Amahoro Avenue, Kigali');
      await tester.ensureVisible(addressField);
      await tester.ensureVisible(checkout);
      expect(find.text('Home shirt'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final profile in _compactGoldenProfiles) {
    testWidgets('golden compact shop checkout ${profile.id}', (tester) async {
      _setGoldenSurface(tester, profile.size);
      TypographyTokens.debugUseFallbackFonts = true;
      addTearDown(() => TypographyTokens.debugUseFallbackFonts = false);
      ColorTokens.setBrightness(profile.brightness);
      addTearDown(() => ColorTokens.setBrightness(Brightness.dark));
      final previousCountries = AfriCountryCatalog.all;
      AfriCountryCatalog.withCountries(const <AfriCountry>[_rwanda]);
      addTearDown(() => AfriCountryCatalog.withCountries(previousCountries));
      final repository = _FakeClubRepository();
      when(
        () => repository.findActivePaymentRoute(any()),
      ).thenAnswer((_) async => _route);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            shopCheckoutJournalProvider.overrideWithValue(
              MemoryShopCheckoutJournal(),
            ),
            storeReleasePolicyProvider.overrideWithValue(
              const StoreReleasePolicy.unenforced(),
            ),
            currentUserProvider.overrideWithValue(_user),
            clubRepositoryProvider.overrideWithValue(repository),
            shopCartProvider.overrideWith((ref) => _SeededCartNotifier()),
          ],
          child: MaterialApp(
            theme: ClubTheme.from(
              ClubConfig.fallback(),
              brightness: profile.brightness,
            ),
            home: ClubConfigScope(
              config: ClubConfig.fallback(),
              child: const RepaintBoundary(
                key: ValueKey<String>('shop-checkout-golden'),
                child: CartScreen(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.widgetWithText(AfriButton, 'Checkout via MOMO'),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await settleShopFixtureImages(tester);
      await expectLater(
        find.byKey(const ValueKey<String>('shop-checkout-golden')),
        matchesGoldenFile('goldens/shop_checkout_${profile.id}.png'),
      );
    });
  }
}

const _compactGoldenProfiles =
    <({String id, Size size, Brightness brightness})>[
      (
        id: 'compact_dark_320x760',
        size: Size(320, 760),
        brightness: Brightness.dark,
      ),
      (
        id: 'compact_light_374x812',
        size: Size(374, 812),
        brightness: Brightness.light,
      ),
      (
        id: 'standard_dark_390x844',
        size: Size(390, 844),
        brightness: Brightness.dark,
      ),
      (
        id: 'large_light_430x900',
        size: Size(430, 900),
        brightness: Brightness.light,
      ),
      (
        id: 'wide_dark_599x900',
        size: Size(599, 900),
        brightness: Brightness.dark,
      ),
      (
        id: 'foldable_half_light_674x842',
        size: Size(674, 842),
        brightness: Brightness.light,
      ),
      (
        id: 'tablet_dark_834x1194',
        size: Size(834, 1194),
        brightness: Brightness.dark,
      ),
    ];

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

void _expectInKeyboardViewport(WidgetTester tester, Finder finder) {
  final visibleBottom =
      tester.view.physicalSize.height / tester.view.devicePixelRatio -
      tester.view.viewInsets.bottom;
  final rect = tester.getRect(finder);
  expect(rect.top, greaterThanOrEqualTo(0));
  expect(rect.bottom, lessThanOrEqualTo(visibleBottom));
}

class _SeededCartNotifier extends ShopCartNotifier {
  _SeededCartNotifier() {
    addRawProduct(const <String, dynamic>{
      'id': 'shirt-1',
      'name': 'Home shirt',
      'image_url': shopHomePhoto,
      'image_rights_approved': true,
      'image_provenance_id': shopPhotoProvenance,
      'category': 'jersey',
      'price': 25000,
      'stock': 5,
    }, partnerId: '24');
  }
}

class _FakeClubRepository extends Mock implements ClubRepository {}

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
