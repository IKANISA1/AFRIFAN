import 'package:core_router/core_router.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'guest reading never unlocks account, payment or ticket credentials',
    () {
      for (final path in [
        '/home',
        '/club',
        '/club/team/player-1',
        '/club/news/story-1',
        '/shop/product/item-1',
        '/fan-clubs/club-1',
        '/tickets',
      ]) {
        expect(PublicReadRoutes.allows(Uri.parse(path)), isTrue, reason: path);
      }
      for (final path in [
        '/membership',
        '/settings',
        '/wallet',
        '/shop/cart',
        '/tickets?tab=mine',
        '/tickets/qr/secret',
        '/tickets/checkout',
        '/club/admin',
        '//attacker.example/home',
      ]) {
        expect(PublicReadRoutes.allows(Uri.parse(path)), isFalse, reason: path);
      }
    },
  );
}
