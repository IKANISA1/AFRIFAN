import 'package:core_router/core_router.dart';
import 'package:go_router/go_router.dart';

import 'screens/e_ticket_qr_screen.dart';
import 'screens/interactive_seat_map_screen.dart';
import 'screens/match_detail_screen.dart';
import 'screens/match_list_screen.dart';
import 'screens/my_tickets_screen.dart';

class TicketingModule extends FeatureModule {
  @override
  String get featureKey => 'ticketing';

  @override
  List<GoRoute> get routes => [
        GoRoute(
          path: '/tickets',
          builder: (context, state) => const MatchListScreen(),
          routes: [
            GoRoute(
              path: 'detail/:id',
              builder: (context, state) {
                final matchId = state.pathParameters['id'] ?? '';
                return MatchDetailScreen(matchId: matchId);
              },
            ),
            GoRoute(
              path: 'map/:id',
              builder: (context, state) {
                final matchId = state.pathParameters['id'] ?? '';
                return InteractiveSeatMapScreen(matchId: matchId);
              },
            ),
          ],
        ),
        GoRoute(
          path: '/my-tickets',
          builder: (context, state) => const MyTicketsScreen(),
        ),
        GoRoute(
          path: '/e-ticket/:id',
          builder: (context, state) {
            final ticketId = state.pathParameters['id'] ?? '';
            return ETicketQrScreen(ticketId: ticketId);
          },
        ),
      ];

  // Ticketing relies on home quick actions, NOT bottom tabs.
  @override
  TabRoute? get tabRoute => null;
}
