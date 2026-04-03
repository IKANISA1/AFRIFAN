import 'package:feat_shop/src/widgets/checkout_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CheckoutBar Widget', () {
    testWidgets('Renders properly and formats total currency', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CheckoutBar(itemCount: 3, total: 15400.0, onCheckout: () {}),
          ),
        ),
      );

      // Verify text elements
      expect(find.text('3'), findsOneWidget);
      expect(find.text('FRw 15,400'), findsOneWidget);
      expect(find.text('CHECKOUT'), findsOneWidget);
    });

    testWidgets('Triggers onCheckout when items are in cart', (tester) async {
      bool pressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CheckoutBar(
              itemCount: 1,
              total: 100.0,
              onCheckout: () {
                pressed = true;
              },
            ),
          ),
        ),
      );

      // Tap checkout
      await tester.tap(find.text('CHECKOUT'));
      await tester.pump();

      expect(pressed, true);
    });
  });
}
