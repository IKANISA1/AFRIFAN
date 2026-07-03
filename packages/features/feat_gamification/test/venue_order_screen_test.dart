import 'package:feat_gamification/src/screens/venue_order_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:test_support/app_font_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);

  Widget buildSubject() {
    final router = GoRouter(
      initialLocation: '/fanzone/venue/order',
      routes: [
        GoRoute(
          path: '/fanzone/venue/order',
          builder: (_, __) => const VenueOrderScreen(),
        ),
      ],
    );

    return MaterialApp.router(routerConfig: router);
  }

  testWidgets('renders supporter drinks ordering and protection states', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('Venue order'), findsOneWidget);
    expect(find.text('Order from the approved drinks menu'), findsOneWidget);
    expect(find.text('Water'), findsOneWidget);
    expect(find.text('Passion juice'), findsOneWidget);
    expect(find.textContaining('Staff queue controls'), findsOneWidget);

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -600));
    await tester.pumpAndSettle();

    expect(find.text('Alcohol items'), findsOneWidget);
    expect(find.text('Age gate required'), findsOneWidget);
    expect(find.text('Venue portal only'), findsOneWidget);
    expect(find.textContaining('admin queue'), findsNothing);
  });

  testWidgets('creates order and exposes status progression', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Create order'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create order'));
    await tester.pumpAndSettle();

    expect(find.text('Order created'), findsOneWidget);

    await tester.tap(find.text('Preview next status'));
    await tester.pumpAndSettle();

    expect(find.text('Accepted by venue'), findsOneWidget);
  });
}
