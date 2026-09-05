import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_gamification/src/controllers/venue_order_controller.dart';
import 'package:feat_gamification/src/screens/venue_order_screen.dart';
import 'package:feat_gamification/src/venue_order_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:test_support/app_font_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);
  setUp(() => ConnectivityService.setOnlineForTest(true));
  tearDown(() => ConnectivityService.setOnlineForTest(true));

  Widget buildSubject(_Controller controller) {
    final router = GoRouter(
      initialLocation: '/fanzone/venue/order',
      routes: [
        GoRoute(
          path: '/fanzone/venue/order',
          builder: (_, __) => const VenueOrderScreen(),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        venueOrderControllerProvider.overrideWith((ref) => controller),
      ],
      child: MaterialApp.router(
        theme: ClubTheme.from(ClubConfig.fallback()),
        routerConfig: router,
      ),
    );
  }

  testWidgets('renders supporter drinks ordering and protection states', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(
        _Controller(const AsyncData<VenueOrderRouteState>(_readyState)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Venue order'), findsOneWidget);
    expect(find.text('Order drinks at this venue'), findsOneWidget);
    expect(find.text('Water'), findsOneWidget);
    expect(find.text('Passion juice'), findsOneWidget);
    expect(find.textContaining('Staff queue actions'), findsOneWidget);

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -1200));
    await tester.pumpAndSettle();

    expect(find.text('Duplicate submission'), findsOneWidget);
    expect(find.text('No queued or automatic replay'), findsOneWidget);
    expect(find.text('Venue portal only'), findsOneWidget);
    expect(find.text('Preview next status'), findsNothing);
  });

  testWidgets('selects a drink and creates one server-confirmed order', (
    tester,
  ) async {
    final controller = _Controller(
      const AsyncData<VenueOrderRouteState>(_readyState),
    );
    await tester.pumpWidget(buildSubject(controller));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('venue-order-add-water')),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey<String>('venue-order-submit')),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    final submit = find.byKey(const ValueKey<String>('venue-order-submit'));
    final submitDetector = find.descendant(
      of: submit,
      matching: find.byType(GestureDetector),
    );
    expect(submitDetector, findsOneWidget);
    await tester.tap(submitDetector);
    await tester.pumpAndSettle();

    expect(controller.submitCalls, 1);
    expect(find.text('Order confirmed'), findsOneWidget);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 1200));
    await tester.pumpAndSettle();
    expect(find.text('Order created'), findsOneWidget);
  });

  testWidgets('shows a semantic age confirmation for alcohol items', (
    tester,
  ) async {
    const alcoholState = VenueOrderRouteState(
      context: VenueOrderContext(
        checkinId: 'checkin-1',
        venueId: 'venue-1',
        menu: <VenueDrinkItem>[
          VenueDrinkItem(
            id: 'malt',
            venueId: 'venue-1',
            name: 'Malt drink',
            priceAmount: 2500,
            currencyCode: 'RWF',
            isAlcohol: true,
          ),
        ],
      ),
      quantities: <String, int>{'malt': 1},
      ageGateConfirmed: true,
    );
    await tester.pumpWidget(
      buildSubject(
        _Controller(const AsyncData<VenueOrderRouteState>(alcoholState)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Age confirmation required'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Age confirmation required'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.selected == true,
      ),
      findsWidgets,
    );
    expect(find.textContaining('legal age requirement'), findsOneWidget);
  });
}

const _menu = <VenueDrinkItem>[
  VenueDrinkItem(
    id: 'water',
    venueId: 'venue-1',
    name: 'Water',
    description: 'Still water',
    priceAmount: 1500,
    currencyCode: 'RWF',
  ),
  VenueDrinkItem(
    id: 'juice',
    venueId: 'venue-1',
    name: 'Passion juice',
    description: 'Fresh juice',
    priceAmount: 2500,
    currencyCode: 'RWF',
  ),
];

const _readyState = VenueOrderRouteState(
  context: VenueOrderContext(
    checkinId: 'checkin-1',
    venueId: 'venue-1',
    menu: _menu,
  ),
);

class _Controller extends VenueOrderController {
  _Controller(AsyncValue<VenueOrderRouteState> value)
    : super(_Gateway(), autoLoad: false) {
    state = value;
  }

  int submitCalls = 0;

  @override
  Future<bool> submit() async {
    submitCalls += 1;
    final current = state.valueOrNull!;
    state = AsyncData<VenueOrderRouteState>(
      current.copyWith(
        phase: VenueOrderPhase.confirmed,
        result: const VenueOrderResult(
          status: 'created',
          code: 'ok',
          orderId: 'order-1',
          totalAmount: 1500,
        ),
      ),
    );
    return true;
  }
}

class _Gateway implements VenueOrderGateway {
  @override
  Future<VenueOrderContext> load() async => _readyState.context;

  @override
  Future<VenueOrderResult> create({
    required VenueOrderContext context,
    required Map<String, int> quantities,
    required bool ageGateConfirmed,
    required String idempotencyKey,
  }) async => const VenueOrderResult(status: 'created', code: 'ok');
}
