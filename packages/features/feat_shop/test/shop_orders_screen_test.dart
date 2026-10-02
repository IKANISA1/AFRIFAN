import 'dart:async';

import 'package:club_data/club_data.dart';
import 'package:core_auth/core_auth.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_shop/src/screens/shop_orders_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test_support/app_font_loader.dart';

import 'shop_checkout_test_support.dart';

class _Repository extends Mock implements ClubRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);
  testWidgets(
    'actual order history route shows pending boundary and clears stale account response',
    (tester) async {
      final repository = _Repository();
      final previousResponse = Completer<List<ShopCheckoutReceipt>>();
      const secondId = '99962000-0000-4000-8000-000000000002';
      final secondResponse = checkoutResponse(
        userId: secondId,
        total: 500,
        status: 'paid',
        canPay: false,
      );
      secondResponse['order']['id'] = '99962000-0000-4000-8000-000000000211';
      secondResponse['receipt']['order_id'] = secondResponse['order']['id'];
      final second = ShopCheckoutReceipt.fromJson(secondResponse);
      when(
        () => repository.getMyShopCheckouts(checkoutUserId),
      ).thenAnswer((_) => previousResponse.future);
      when(
        () => repository.getMyShopCheckouts(secondId),
      ).thenAnswer((_) async => [second]);
      final account = StateProvider<UserProfile?>(
        (ref) => const UserProfile(id: checkoutUserId, clubId: '24'),
      );
      final providers = ProviderContainer(
        overrides: [
          currentUserProvider.overrideWith((ref) => ref.watch(account)),
          clubRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(providers.dispose);
      final router = GoRouter(
        initialLocation: '/shop/orders',
        routes: [
          GoRoute(
            path: '/shop/orders',
            builder: (_, _) => const ShopOrdersScreen(),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: providers,
          child: MaterialApp.router(
            theme: ClubTheme.from(ClubConfig.fallback()),
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();
      providers.read(account.notifier).state = const UserProfile(
        id: secondId,
        clubId: '24',
      );
      await tester.pumpAndSettle();
      expect(find.text('Order paid'), findsOneWidget);
      expect(
        find.text('Order: 99962000-0000-4000-8000-000000000211'),
        findsOneWidget,
      );
      previousResponse.complete([checkoutReceipt()]);
      await tester.pumpAndSettle();
      expect(find.text('Order: $checkoutOrderId'), findsNothing);
      expect(find.text('Order paid'), findsOneWidget);
      verify(() => repository.getMyShopCheckouts(checkoutUserId)).called(1);
      verify(() => repository.getMyShopCheckouts(secondId)).called(1);
      providers.read(account.notifier).state = null;
      await tester.pumpAndSettle();
      expect(find.text('Order paid'), findsNothing);
      expect(
        find.text('Your prepared orders will appear here.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
