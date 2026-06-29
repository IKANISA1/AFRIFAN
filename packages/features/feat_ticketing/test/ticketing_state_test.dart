import 'package:core_auth/core_auth.dart';
import 'package:core_utils/core_utils.dart';
import 'package:feat_club/feat_club.dart';
import 'package:feat_ticketing/src/screens/e_ticket_qr_screen.dart';
import 'package:feat_ticketing/src/screens/interactive_seat_map_screen.dart';
import 'package:feat_ticketing/src/screens/match_list_screen.dart';
import 'package:feat_ticketing/src/ticketing_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

    expect(find.text('No upcoming ticketed fixtures'), findsOneWidget);
    expect(find.textContaining('Upcoming ticket inventory'), findsOneWidget);
  });

  testWidgets('seat map exposes stand buttons beyond canvas hit testing', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: InteractiveSeatMapScreen(matchId: 'match-1')),
    );

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
          myTicketProvider('ticket-1').overrideWith(
            (ref) async => _activeTicket,
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
