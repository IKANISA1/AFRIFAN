import 'dart:async';

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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_support/app_font_loader.dart';

import 'shop_checkout_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);
  late MemoryShopCheckoutJournal journal;
  late List<String> requests;
  late List<String> launches;
  ShopCheckoutReceipt? server;
  var loseResponse = false;
  var launchResult = true;
  late StateProvider<UserProfile?> account;

  ProviderContainer container() => ProviderContainer(
    overrides: [
      shopCheckoutJournalProvider.overrideWithValue(journal),
      storeReleasePolicyProvider.overrideWithValue(
        const StoreReleasePolicy.unenforced(),
      ),
      currentUserProvider.overrideWith((ref) => ref.watch(account)),
      shopCartProvider.overrideWith((ref) => _ReceiptCart()),
    ],
  );
  Widget screen(ProviderContainer providers, {Key? key}) =>
      UncontrolledProviderScope(
        container: providers,
        child: MaterialApp(
          theme: ClubTheme.from(ClubConfig.fallback()),
          home: ClubConfigScope(
            config: ClubConfig.fallback(),
            child: CartScreen(
              key: key,
              paymentRouteLoader: (_) async => const PartnerPaymentRoute(
                id: 'route',
                partnerId: '24',
                partnerName: 'Rayon Sports',
                partnerSlug: 'rayon-sports',
                countryCode: 'RW',
                providerId: 'mtn',
                recipientCode: '12345',
                reconciliationLabel: 'Shop',
                status: PartnerPaymentRouteStatus.active,
              ),
              orderPlacer:
                  ({
                    required userId,
                    required partnerId,
                    required items,
                    required deliveryAddress,
                    required paymentReference,
                  }) async {
                    requests.add(paymentReference);
                    server = checkoutReceipt(reference: paymentReference);
                    if (loseResponse) throw TimeoutException('response lost');
                    return server!;
                  },
              orderRecoverer:
                  ({
                    required userId,
                    required clubId,
                    required paymentReference,
                  }) async {
                    expect(paymentReference, requests.single);
                    return server;
                  },
              paymentValidator: (_) async => server!,
              dialerLauncher: (ussd) async {
                launches.add(ussd);
                return launchResult;
              },
            ),
          ),
        ),
      );
  setUp(() {
    final previousCountries = AfriCountryCatalog.all;
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
    addTearDown(() => AfriCountryCatalog.withCountries(previousCountries));
    ConnectivityService.setOnlineForTest(true);
    journal = MemoryShopCheckoutJournal();
    requests = [];
    launches = [];
    server = null;
    loseResponse = false;
    launchResult = true;
    account = StateProvider(
      (ref) => const UserProfile(
        id: checkoutUserId,
        clubId: '24',
        publicUserId: '483912',
      ),
    );
  });

  testWidgets(
    'real cart retains items until reviewed server amount is acknowledged and dials exact receipt',
    (tester) async {
      final providers = container();
      addTearDown(providers.dispose);
      await tester.pumpWidget(screen(providers));
      await tester.pumpAndSettle();
      await _prepare(tester);
      expect(providers.read(shopCartProvider), hasLength(1));
      expect(launches, isEmpty);
      expect(requests, hasLength(1));
      await _tap(tester, 'Review payment');
      expect(
        find.textContaining('The catalog total changed from'),
        findsOneWidget,
      );
      expect(find.text('Recipient code: 12345'), findsWidgets);
      expect(
        find.text('Dialer instruction: *182*8*1*1300*12345#'),
        findsOneWidget,
      );
      final confirm = find.widgetWithText(AfriButton, 'Confirm and open MoMo');
      expect(tester.widget<AfriButton>(confirm).enabled, isFalse);
      final acknowledge = find.byType(CheckboxListTile);
      await tester.ensureVisible(acknowledge);
      await tester.tap(acknowledge);
      await tester.pump();
      await _tap(tester, 'Confirm and open MoMo');
      expect(launches, ['*182*8*1*1300*12345#']);
      expect(providers.read(shopCartProvider), isEmpty);
      expect(find.text('Payment pending'), findsOneWidget);
      expect(find.textContaining('not confirmation of payment'), findsNothing);
      expect(server!.serverStatus, 'pending');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'lost checkout response relaunch binds original order without fresh mutation',
    (tester) async {
      loseResponse = true;
      final providers = container();
      addTearDown(providers.dispose);
      await tester.pumpWidget(screen(providers, key: const ValueKey('first')));
      await tester.pumpAndSettle();
      await _prepare(tester);
      expect(find.text('Order status is uncertain'), findsWidgets);
      final original = requests.single;
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        screen(providers, key: const ValueKey('relaunched')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Order prepared'), findsOneWidget);
      expect(find.text('Request: $original'), findsOneWidget);
      expect(find.text('Order: $checkoutOrderId'), findsOneWidget);
      expect(requests, [original]);
      expect(launches, isEmpty);
      expect(providers.read(shopCartProvider), hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'unknown dialer result survives relaunch with pending status and no second payment action',
    (tester) async {
      launchResult = false;
      final providers = container();
      addTearDown(providers.dispose);
      await tester.pumpWidget(screen(providers));
      await tester.pumpAndSettle();
      await _prepare(tester);
      await _tap(tester, 'Review payment');
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      await _tap(tester, 'Confirm and open MoMo');
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        screen(providers, key: const ValueKey('restart')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Payment pending'), findsOneWidget);
      expect(find.widgetWithText(AfriButton, 'Review payment'), findsNothing);
      expect(
        find.widgetWithText(AfriButton, 'Retry original request'),
        findsNothing,
      );
      expect(launches, hasLength(1));
      expect(requests, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'account switch hides previous receipt and private delivery address',
    (tester) async {
      final providers = container();
      addTearDown(providers.dispose);
      await tester.pumpWidget(screen(providers));
      await tester.pumpAndSettle();
      await _prepare(tester);
      expect(find.text('Order: $checkoutOrderId'), findsOneWidget);
      providers.read(account.notifier).state = const UserProfile(
        id: '99962000-0000-4000-8000-000000000002',
        clubId: '24',
        publicUserId: '483913',
      );
      await tester.pumpAndSettle();
      expect(find.text('Order: $checkoutOrderId'), findsNothing);
      expect(find.textContaining(requests.single), findsNothing);
      final input = tester.widget<AfriInputField>(
        find.widgetWithText(AfriInputField, 'Delivery address'),
      );
      expect(input.controller.text, isEmpty);
      expect(launches, isEmpty);
      expect(journal.values, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );
}

class _ReceiptCart extends ShopCartNotifier {
  _ReceiptCart() {
    state = [checkoutItem()];
  }
}

Future<void> _tap(WidgetTester tester, String label) async {
  final target = find.widgetWithText(AfriButton, label);
  await tester.ensureVisible(target);
  await tester.pump();
  await tester.tap(target);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

Future<void> _prepare(WidgetTester tester) async {
  await tester.enterText(
    find.widgetWithText(AfriInputField, 'Delivery address'),
    '12 Amahoro Avenue',
  );
  await _tap(tester, 'Checkout via MOMO');
  await _tap(tester, 'Prepare order');
}
