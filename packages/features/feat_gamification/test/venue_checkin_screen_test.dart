import 'package:feat_gamification/src/screens/venue_checkin_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:test_support/app_font_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);

  Widget buildSubject() {
    final router = GoRouter(
      initialLocation: '/fanzone/venue',
      routes: [
        GoRoute(
          path: '/fanzone/venue',
          builder: (_, __) => const VenueCheckinScreen(),
        ),
      ],
    );

    return MaterialApp.router(routerConfig: router);
  }

  testWidgets('renders supporter-only venue check-in states', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('Venue check-in'), findsOneWidget);
    expect(
      find.text(
        'Use the rotating TV or QR code after you arrive. Staff and admin operations are never available in the supporter app.',
      ),
      findsOneWidget,
    );

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.text('Expired code'), findsOneWidget);
    expect(find.text('Alcohol items'), findsOneWidget);
    expect(find.textContaining('admin queue'), findsNothing);
  });

  testWidgets('requests location only after supporter action', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('Location check pending'), findsNothing);

    await tester.ensureVisible(find.text('Verify location'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Verify location'));
    await tester.pumpAndSettle();

    expect(find.text('Location check pending'), findsOneWidget);
    expect(find.text('Location pending'), findsOneWidget);
  });
}
