import 'package:feat_shop/src/widgets/shop_loading_skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shop loading skeleton is static for accessible navigation', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(accessibleNavigation: true),
          child: Scaffold(body: ShopLoadingSkeleton(itemCount: 2)),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(Animate), findsNothing);
    expect(find.byType(ShopLoadingSkeleton), findsOneWidget);
  });
}
