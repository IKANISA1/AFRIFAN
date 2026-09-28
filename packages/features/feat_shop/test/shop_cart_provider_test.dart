import 'package:club_data/club_data.dart';
import 'package:feat_shop/src/shop_cart_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'product media metadata survives cart and serialization, including revocation',
    () {
      final notifier = ShopCartNotifier();
      addTearDown(notifier.dispose);
      final product = <String, dynamic>{
        'id': 'published-kit',
        'name': 'Home kit',
        'price': 25000,
        'stock': 5,
        'image_url': 'https://media.example.invalid/home.jpg',
        'image_rights_approved': true,
        'image_provenance_id': 'fixture-publication-record',
      };
      notifier.addRawProduct(product, partnerId: 'club', selectedVariant: 'M');
      final item = notifier.state.single;
      expect(item.selectedVariant, 'M');
      expect(item.product.imageUrl, product['image_url']);
      expect(item.product.imageRightsApproved, isTrue);
      final restored = ClubProduct.fromJson(item.product.toJson());
      expect(restored.imageProvenanceId, product['image_provenance_id']);
      expect(restored.imageRightsApproved, isTrue);
      notifier.addRawProduct(
        {...product, 'image_rights_approved': false},
        partnerId: 'club',
        selectedVariant: 'M',
      );
      expect(notifier.state.single.product.imageRightsApproved, isFalse);
      expect(notifier.state.single.product, isNot(item.product));
      expect(notifier.state.single.quantity, 2);
      expect(notifier.state.single.lineTotal, 50000);
      expect(
        ClubProduct.fromJson({'id': 'legacy'}).imageRightsApproved,
        isFalse,
      );
    },
  );
  test('enquiry products never enter the payable cart', () {
    final cart = ShopCartNotifier();
    addTearDown(cart.dispose);
    cart.addRawProduct({
      'id': 'enquiry',
      'name': 'Club shirt',
      'price': 5000,
      'stock': 12,
      'commerce_mode': 'enquiry',
    }, partnerId: 'club');
    expect(cart.state, isEmpty);
  });
  group('ShopCartNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    final rawProductA = {
      'id': 'PROD_A',
      'name': 'Jersey',
      'price': 15000,
      'stock': 100,
      'available_sizes': 'S,M,L,XL',
    };

    final rawProductB = {
      'id': 'PROD_B',
      'name': 'Cap',
      'price': 5000,
      'stock': 50,
      'available_sizes': const <dynamic>[],
    };

    test('addRawProduct adds a new item to the cart', () {
      final notifier = container.read(shopCartProvider.notifier);
      notifier.addRawProduct(
        rawProductA,
        partnerId: 'PARTNER1',
        selectedVariant: 'M',
      );

      final cart = container.read(shopCartProvider);
      expect(cart.length, 1);
      expect(cart.first.product.id, 'PROD_A');
      expect(cart.first.quantity, 1);
      expect(cart.first.selectedVariant, 'M');
      expect(cart.first.product.availableSizes, ['S', 'M', 'L', 'XL']);
    });

    test('addRawProduct increments quantity for same product and variant', () {
      final notifier = container.read(shopCartProvider.notifier);
      notifier.addRawProduct(
        rawProductA,
        partnerId: 'PARTNER1',
        selectedVariant: 'M',
        quantity: 2,
      );
      notifier.addRawProduct(
        rawProductA,
        partnerId: 'PARTNER1',
        selectedVariant: 'M',
        quantity: 1,
      );

      final cart = container.read(shopCartProvider);
      expect(cart.length, 1);
      expect(cart.first.quantity, 3);
    });

    test('addRawProduct creates separate items for different variants', () {
      final notifier = container.read(shopCartProvider.notifier);
      notifier.addRawProduct(
        rawProductA,
        partnerId: 'PARTNER1',
        selectedVariant: 'M',
      );
      notifier.addRawProduct(
        rawProductA,
        partnerId: 'PARTNER1',
        selectedVariant: 'L',
      );

      final cart = container.read(shopCartProvider);
      expect(cart.length, 2);
    });

    test('increment and decrement update quantity', () {
      final notifier = container.read(shopCartProvider.notifier);
      notifier.addRawProduct(rawProductB, partnerId: 'PARTNER1');

      var cart = container.read(shopCartProvider);
      final item = cart.first;

      notifier.increment(item);
      cart = container.read(shopCartProvider);
      expect(cart.first.quantity, 2);

      notifier.decrement(cart.first);
      cart = container.read(shopCartProvider);
      expect(cart.first.quantity, 1);
    });

    test('decrementing to 0 removes the item', () {
      final notifier = container.read(shopCartProvider.notifier);
      notifier.addRawProduct(rawProductB, partnerId: 'PARTNER1');

      var cart = container.read(shopCartProvider);
      notifier.decrement(cart.first);

      cart = container.read(shopCartProvider);
      expect(cart.isEmpty, true);
    });

    test('remove removes item completely', () {
      final notifier = container.read(shopCartProvider.notifier);
      notifier.addRawProduct(
        rawProductA,
        partnerId: 'PARTNER1',
        selectedVariant: 'M',
      );
      notifier.addRawProduct(rawProductB, partnerId: 'PARTNER1');

      var cart = container.read(shopCartProvider);
      expect(cart.length, 2);

      notifier.remove(cart.firstWhere((i) => i.product.id == 'PROD_A'));
      cart = container.read(shopCartProvider);
      expect(cart.length, 1);
      expect(cart.first.product.id, 'PROD_B');
    });

    test('clear empties the cart', () {
      final notifier = container.read(shopCartProvider.notifier);
      notifier.addRawProduct(
        rawProductA,
        partnerId: 'PARTNER1',
        selectedVariant: 'M',
      );
      notifier.addRawProduct(rawProductB, partnerId: 'PARTNER1');

      notifier.clear();
      expect(container.read(shopCartProvider).isEmpty, true);
    });

    test('totals providers calculate correctly', () {
      final notifier = container.read(shopCartProvider.notifier);
      notifier.addRawProduct(
        rawProductA,
        partnerId: 'PARTNER1',
        selectedVariant: 'M',
        quantity: 2,
      ); // 2 * 15000 = 30000
      notifier.addRawProduct(
        rawProductB,
        partnerId: 'PARTNER1',
        quantity: 3,
      ); // 3 * 5000 = 15000

      final count = container.read(shopCartItemCountProvider);
      final total = container.read(shopCartTotalProvider);

      expect(count, 5);
      expect(total, 45000);
    });
  });
}
