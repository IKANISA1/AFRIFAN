import 'package:core_auth/core_auth.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:feat_club/feat_club.dart';
import 'package:feat_ticketing/src/providers/e_ticket_provider.dart';
import 'package:feat_ticketing/src/providers/ticket_detail_provider.dart';
import 'package:feat_ticketing/src/screens/e_ticket_qr_screen.dart';
import 'package:feat_ticketing/src/screens/interactive_seat_map_screen.dart';
import 'package:feat_ticketing/src/screens/match_detail_screen.dart';
import 'package:feat_ticketing/src/screens/match_list_screen.dart';
import 'package:feat_ticketing/src/ticketing_providers.dart';
import 'package:feat_ticketing/src/widgets/ticket_checkout_shared.dart';
import 'package:feat_ticketing/src/widgets/ticket_checkout_step.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:test_support/app_font_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);
  setUp(() => ConnectivityService.setOnlineForTest(true));

  testWidgets('match list shows explicit empty state for upcoming fixtures', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWith(
            (ref) => const UserProfile(
              id: 'user-1',
              clubId: '24',
              publicUserId: '483912',
            ),
          ),
          ticketMatchesProvider.overrideWith((ref) async => const []),
        ],
        child: const MaterialApp(home: MatchListScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (widget) => widget is AfriAsyncStateView<List<ClubMatch>>,
      ),
      findsOneWidget,
    );
    expect(find.text('No upcoming ticketed fixtures'), findsOneWidget);
    expect(find.textContaining('Upcoming ticket inventory'), findsOneWidget);
  });

  testWidgets('checkout uses route warning banner', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var purchaseRequests = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TicketCheckoutStep(
            match: _match,
            currency: CurrencyFormatter(
              currencyCode: 'RWF',
              currencySymbol: 'RWF',
            ),
            selectedSeatType: SeatType.general,
            selectedSeatCode: 'A-12',
            quantity: 2,
            paymentRoute: null,
            paymentRouteMessage:
                'Ticket payment setup is pending club activation.',
            submitting: false,
            onPurchaseRequest: () => purchaseRequests += 1,
          ),
        ),
      ),
    );

    expect(find.byType(AfriStateBanner), findsOneWidget);
    expect(find.text('Payment route'), findsOneWidget);
    expect(
      find.text('Ticket payment setup is pending club activation.'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        'Warning status: Payment route. '
        'Ticket payment setup is pending club activation.',
      ),
      findsOneWidget,
    );
    expect(find.text('A-12'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('RWF 6,000'), findsOneWidget);

    await tester.tap(find.text('Payment route not ready'), warnIfMissed: false);
    expect(purchaseRequests, 0);
    semantics.dispose();
  });

  testWidgets('checkout loading blocks duplicate purchase and retains draft', (
    tester,
  ) async {
    final previousCountries = AfriCountryCatalog.all;
    AfriCountryCatalog.withCountries(const <AfriCountry>[_rwanda]);
    addTearDown(() => AfriCountryCatalog.withCountries(previousCountries));
    var purchaseRequests = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TicketCheckoutStep(
            match: _match,
            currency: CurrencyFormatter(
              currencyCode: 'RWF',
              currencySymbol: 'RWF',
            ),
            selectedSeatType: SeatType.vip,
            selectedSeatCode: 'VIP-7',
            quantity: 3,
            paymentRoute: _route,
            paymentRouteMessage: null,
            submitting: true,
            onPurchaseRequest: () => purchaseRequests += 1,
          ),
        ),
      ),
    );

    expect(find.text('VIP-7'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('RWF 36,000'), findsOneWidget);
    final processing = find.widgetWithText(AfriButton, 'Processing');
    expect(tester.widget<AfriButton>(processing).enabled, isFalse);
    await tester.tap(processing, warnIfMissed: false);
    expect(purchaseRequests, 0);
  });

  testWidgets('checkout retains the ticket draft but blocks purchase offline', (
    tester,
  ) async {
    final previousCountries = AfriCountryCatalog.all;
    AfriCountryCatalog.withCountries(const <AfriCountry>[_rwanda]);
    addTearDown(() => AfriCountryCatalog.withCountries(previousCountries));
    ConnectivityService.setOnlineForTest(false);
    var purchaseRequests = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TicketCheckoutStep(
            match: _match,
            currency: CurrencyFormatter(
              currencyCode: 'RWF',
              currencySymbol: 'RWF',
            ),
            selectedSeatType: SeatType.vip,
            selectedSeatCode: 'VIP-7',
            quantity: 3,
            paymentRoute: _route,
            paymentRouteMessage: null,
            submitting: false,
            onPurchaseRequest: () => purchaseRequests += 1,
          ),
        ),
      ),
    );

    expect(find.text('VIP-7'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('RWF 36,000'), findsOneWidget);
    final blocked = find.widgetWithText(AfriButton, 'Connection required');
    expect(tester.widget<AfriButton>(blocked).enabled, isFalse);
    await tester.tap(blocked, warnIfMissed: false);
    expect(purchaseRequests, 0);
  });

  testWidgets(
    'keyboard-open compact viewport keeps ticket summary and action reachable',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 320);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final previousCountries = AfriCountryCatalog.all;
      AfriCountryCatalog.withCountries(const <AfriCountry>[_rwanda]);
      addTearDown(() => AfriCountryCatalog.withCountries(previousCountries));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TicketCheckoutStep(
              match: _match,
              currency: CurrencyFormatter(
                currencyCode: 'RWF',
                currencySymbol: 'RWF',
              ),
              selectedSeatType: SeatType.vip,
              selectedSeatCode: 'VIP-7',
              quantity: 3,
              paymentRoute: _route,
              paymentRouteMessage: null,
              submitting: false,
              onPurchaseRequest: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final summary = find.text('CHECKOUT SUMMARY');
      _expectInKeyboardViewport(tester, summary);
      final submit = find.widgetWithText(AfriButton, 'Pay via MOMO');
      await tester.ensureVisible(submit);
      await tester.pumpAndSettle();
      _expectInKeyboardViewport(tester, submit);
      expect(find.text('VIP-7'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    '200 percent text keeps populated ticket checkout and warning usable',
    (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TicketCheckoutStep(
              match: _match,
              currency: CurrencyFormatter(
                currencyCode: 'RWF',
                currencySymbol: 'RWF',
              ),
              selectedSeatType: SeatType.vip,
              selectedSeatCode: 'VIP-7',
              quantity: 3,
              paymentRoute: null,
              paymentRouteMessage:
                  'Ticket payment setup is pending club activation.',
              submitting: false,
              onPurchaseRequest: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CHECKOUT SUMMARY'), findsOneWidget);
      expect(find.text('VIP-7'), findsOneWidget);
      final warning = find.byType(AfriStateBanner);
      final action = find.widgetWithText(
        AfriButton,
        'Payment route not ready',
      );
      await tester.ensureVisible(warning);
      await tester.ensureVisible(action);
      expect(tester.takeException(), isNull);
    },
  );

  for (final profile in <String, Size>{
    'standard landscape': const Size(852, 393),
    'compact-height landscape': const Size(720, 320),
  }.entries) {
    testWidgets(
      '${profile.key} keeps ticket summary, warning, and action usable',
      (tester) async {
        tester.view.physicalSize = profile.value;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TicketCheckoutStep(
                match: _match,
                currency: CurrencyFormatter(
                  currencyCode: 'RWF',
                  currencySymbol: 'RWF',
                ),
                selectedSeatType: SeatType.vip,
                selectedSeatCode: 'VIP-7',
                quantity: 3,
                paymentRoute: null,
                paymentRouteMessage:
                    'Ticket payment setup is pending club activation.',
                submitting: false,
                onPurchaseRequest: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final summary = find.text('CHECKOUT SUMMARY');
        final warning = find.byType(AfriStateBanner);
        final action = find.widgetWithText(
          AfriButton,
          'Payment route not ready',
        );
        await tester.ensureVisible(summary);
        await tester.ensureVisible(warning);
        await tester.ensureVisible(action);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('checkout back cancellation retains the reservation draft', (
    tester,
  ) async {
    final previousCountries = AfriCountryCatalog.all;
    AfriCountryCatalog.withCountries(const <AfriCountry>[_rwanda]);
    addTearDown(() => AfriCountryCatalog.withCountries(previousCountries));
    final repository = _FakeClubRepository();
    when(
      () => repository.findActivePaymentRoute(any()),
    ).thenAnswer((_) async => _route);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWithValue(_user),
          clubRepositoryProvider.overrideWithValue(repository),
          ticketMatchProvider('match-1').overrideWith((ref) async => _match),
        ],
        child: MaterialApp(
          home: ClubConfigScope(
            config: ClubConfig.fallback(),
            child: const MatchDetailScreen(matchId: 'match-1'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.ancestor(
        of: find.text('Premium lounge seating'),
        matching: find.byType(SeatTypeCard),
      ),
    );
    final add = find.byIcon(AfriIcons.add);
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.pump();
    await tester.tap(add);
    await tester.pump();
    final review = find.text('Review reservation');
    await tester.ensureVisible(review);
    await tester.tap(review);
    await tester.pumpAndSettle();

    expect(find.text('VIP'), findsWidgets);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('RWF 36,000'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(review);
    await tester.tap(review);
    await tester.pumpAndSettle();

    expect(find.text('VIP'), findsWidgets);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('RWF 36,000'), findsOneWidget);
    verifyNever(
      () => repository.purchaseTickets(
        matchId: any(named: 'matchId'),
        userId: any(named: 'userId'),
        seatType: any(named: 'seatType'),
        quantity: any(named: 'quantity'),
        paymentReference: any(named: 'paymentReference'),
      ),
    );
  });

  testWidgets('seat map exposes stand buttons beyond canvas hit testing', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ticketDetailGatewayProvider.overrideWithValue(
            _StaticTicketDetailGateway(_match),
          ),
        ],
        child: const MaterialApp(
          home: InteractiveSeatMapScreen(matchId: 'match-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('VIP Gold'), findsOneWidget);
    expect(find.text('East Stand'), findsOneWidget);

    await tester.tap(find.text('East Stand'));
    await tester.pumpAndSettle();

    expect(find.text('SELECTED SEAT'), findsOneWidget);
    expect(find.text('East Stand, Seat 1'), findsOneWidget);
  });

  testWidgets('QR screen disables scanner overlay when motion is reduced', (
    tester,
  ) async {
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(
      accessibleNavigation: true,
      disableAnimations: true,
      reduceMotion: true,
    );
    addTearDown(
      tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          eTicketGatewayProvider.overrideWithValue(
            _StaticETicketGateway(_activeTicket),
          ),
        ],
        child: const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              accessibleNavigation: true,
              disableAnimations: true,
            ),
            child: ETicketQrScreen(ticketId: 'ticket-1'),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.byKey(const Key('qr_scanner_overlay')), findsNothing);
  });

  for (final profile in _compactGoldenProfiles) {
    testWidgets(
      'golden compact ticket checkout ${profile.id}',
      (tester) async {
        _setGoldenSurface(tester, profile.size);
        TypographyTokens.debugUseFallbackFonts = true;
        addTearDown(() => TypographyTokens.debugUseFallbackFonts = false);
        ColorTokens.setBrightness(profile.brightness);
        addTearDown(() => ColorTokens.setBrightness(Brightness.dark));
        final previousCountries = AfriCountryCatalog.all;
        AfriCountryCatalog.withCountries(const <AfriCountry>[_rwanda]);
        addTearDown(() => AfriCountryCatalog.withCountries(previousCountries));

        await tester.pumpWidget(
          MaterialApp(
            theme: ClubTheme.from(
              ClubConfig.fallback(),
              brightness: profile.brightness,
            ),
            home: RepaintBoundary(
              key: const ValueKey<String>('ticket-checkout-golden'),
              child: AfriScreenScaffold(
                showAppBar: false,
                scrollable: false,
                child: TicketCheckoutStep(
                  match: _match,
                  currency: CurrencyFormatter(
                    currencyCode: 'RWF',
                    currencySymbol: 'RWF',
                  ),
                  selectedSeatType: SeatType.vip,
                  selectedSeatCode: 'VIP-7',
                  quantity: 3,
                  paymentRoute: _route,
                  paymentRouteMessage: null,
                  submitting: false,
                  onPurchaseRequest: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        await expectLater(
          find.byKey(const ValueKey<String>('ticket-checkout-golden')),
          matchesGoldenFile('goldens/ticket_checkout_${profile.id}.png'),
        );
      },
    );
  }
}

class _StaticETicketGateway implements ETicketGateway {
  const _StaticETicketGateway(this.ticket);

  final ClubTicket ticket;

  @override
  Future<ClubTicket?> load(String ticketId) async => ticket;
}

class _StaticTicketDetailGateway implements TicketDetailGateway {
  const _StaticTicketDetailGateway(this.match);

  final ClubMatch match;

  @override
  Future<ClubMatch?> load(String matchId) async => match;
}

const _compactGoldenProfiles =
    <({String id, Size size, Brightness brightness})>[
  (
    id: 'compact_dark_320x760',
    size: Size(320, 760),
    brightness: Brightness.dark,
  ),
  (
    id: 'compact_light_374x812',
    size: Size(374, 812),
    brightness: Brightness.light,
  ),
  (
    id: 'standard_dark_390x844',
    size: Size(390, 844),
    brightness: Brightness.dark,
  ),
  (
    id: 'large_light_430x900',
    size: Size(430, 900),
    brightness: Brightness.light,
  ),
  (
    id: 'wide_dark_599x900',
    size: Size(599, 900),
    brightness: Brightness.dark,
  ),
  (
    id: 'foldable_half_light_674x842',
    size: Size(674, 842),
    brightness: Brightness.light,
  ),
  (
    id: 'tablet_dark_834x1194',
    size: Size(834, 1194),
    brightness: Brightness.dark,
  ),
];

void _setGoldenSurface(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(
    disableAnimations: true,
    accessibleNavigation: true,
  );
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

void _expectInKeyboardViewport(WidgetTester tester, Finder finder) {
  final visibleBottom =
      tester.view.physicalSize.height / tester.view.devicePixelRatio -
          tester.view.viewInsets.bottom;
  final rect = tester.getRect(finder);
  expect(rect.top, greaterThanOrEqualTo(0));
  expect(rect.bottom, lessThanOrEqualTo(visibleBottom));
}

final ClubMatch _match = ClubMatch(
  id: 'match-1',
  homeTeam: 'Rayon Sports',
  awayTeam: 'APR',
  competition: 'National League',
  venue: 'Amahoro Stadium',
  matchDate: DateTime(2099, 4, 18, 18),
  kickoffTime: '18:00',
  isOnSale: true,
  ticketGeneralPrice: 3000,
  ticketVipPrice: 12000,
  saleStartsAt: DateTime(2099, 4, 10, 9),
  capacity: 18000,
);

final ClubTicket _activeTicket = ClubTicket(
  id: 'ticket-1',
  matchId: 'match-1',
  match: _match,
  userId: 'user-1',
  seatType: SeatType.general,
  amountPaid: 3000,
  qrCode: 'ticket-1-code',
  paymentReference: 'momo-1',
  status: TicketStatus.active,
  purchasedAt: DateTime(2099, 4, 10, 12),
);

const _route = PartnerPaymentRoute(
  id: 'route-1',
  partnerId: '24',
  partnerName: 'Rayon Sports',
  partnerSlug: 'rayon-sports',
  countryCode: 'RW',
  providerId: 'mtn',
  recipientCode: '1828',
  reconciliationLabel: 'Ticket sales',
  status: PartnerPaymentRouteStatus.active,
);

const _rwanda = AfriCountry(
  isoCode: 'RW',
  dialCode: '+250',
  name: 'Rwanda',
  flagEmoji: '',
  currencyCode: 'RWF',
  currencyName: 'Rwandan franc',
  momoUssdTemplate: '*182*1*1*{recipient}*{amount}#',
  momoCodeUssdTemplate: '*182*8*1*{recipient}*{amount}#',
);

class _FakeClubRepository extends Mock implements ClubRepository {}

const _user = UserProfile(
  id: 'supporter-1',
  clubId: '24',
  publicUserId: '483912',
);
