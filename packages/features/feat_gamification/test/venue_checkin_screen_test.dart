import 'package:feat_gamification/src/controllers/venue_checkin_controller.dart';
import 'package:feat_gamification/src/screens/venue_checkin_screen.dart';
import 'package:feat_gamification/src/venue_checkin_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:test_support/app_font_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);

  testWidgets('renders supporter-only venue check-in boundary', (tester) async {
    await tester.pumpWidget(_subject());
    await tester.pumpAndSettle();

    expect(find.text('Venue check-in'), findsOneWidget);
    expect(
      find.textContaining('Supporter check-in never exposes'),
      findsOneWidget,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Raw rotating codes are hashed'),
      findsOneWidget,
    );
    expect(find.textContaining('admin queue'), findsNothing);
  });

  testWidgets('records consent only after supporter action', (tester) async {
    await tester.pumpWidget(_subject());
    await tester.pumpAndSettle();

    expect(find.textContaining('Consent is marked'), findsNothing);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark consent'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Consent is marked'), findsOneWidget);
    expect(find.textContaining('sends no coordinates'), findsOneWidget);
  });
}

Widget _subject() {
  final router = GoRouter(
    initialLocation: '/fanzone/venue',
    routes: [
      GoRoute(
        path: '/fanzone/venue',
        builder: (_, _) => const VenueCheckinScreen(),
      ),
      GoRoute(path: '/fanzone', builder: (_, _) => const SizedBox.shrink()),
    ],
  );
  return ProviderScope(
    overrides: [
      venueCheckinControllerProvider.overrideWith(
        (ref) => VenueCheckinController(_Gateway()),
      ),
    ],
    child: MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: router,
    ),
  );
}

class _Gateway implements VenueCheckinGateway {
  @override
  Future<VenueCheckinResult> submit({
    required String rawCode,
    required String idempotencyKey,
  }) async {
    return const VenueCheckinResult(status: 'confirmed', code: 'ok');
  }
}
