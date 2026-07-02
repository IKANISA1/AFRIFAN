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
              pageBuilder: (context, state) {
                final matchId = state.pathParameters['id'] ?? '';
                return afriSheetPage(
                  state,
                  MatchDetailScreen(matchId: matchId),
                  fullHeight: true,
                );
              },
            ),
            GoRoute(
              path: 'map/:id',
              pageBuilder: (context, state) {
                final matchId = state.pathParameters['id'] ?? '';
                return afriSheetPage(
                  state,
                  InteractiveSeatMapScreen(matchId: matchId),
                  fullHeight: true,
                );
              },
            ),
          ],
        ),
        GoRoute(
          path: '/my-tickets',
          pageBuilder: (context, state) =>
              afriSheetPage(state, const MyTicketsScreen(), fullHeight: true),
        ),
        GoRoute(
          path: '/e-ticket/:id',
          pageBuilder: (context, state) {
            final ticketId = state.pathParameters['id'] ?? '';
            return afriRoutePage(state, ETicketQrScreen(ticketId: ticketId));
          },
        ),
      ];

  // Ticketing relies on home quick actions, NOT bottom tabs.
  @override
  TabRoute? get tabRoute => null;

  @override
  List<RoutePresentationDecision> get routePresentationDecisions => const [
        RoutePresentationDecision(
          path: '/tickets',
          presentation: RoutePresentation.fullScreen,
          recommendation: 'keep',
          rationale: 'Ticket discovery and buying are primary revenue tasks.',
        ),
        RoutePresentationDecision(
          path: '/tickets/detail/:id',
          presentation: RoutePresentation.fullHeightSheet,
          recommendation: 'convert to sheet',
          targetPath: '/tickets',
          rationale: 'Ticket details are part of selection.',
        ),
        RoutePresentationDecision(
          path: '/tickets/map/:id',
          presentation: RoutePresentation.fullHeightSheet,
          recommendation: 'convert to modal',
          targetPath: '/tickets/detail/:id',
          rationale: 'Seat maps need space but belong to checkout context.',
        ),
        RoutePresentationDecision(
          path: '/my-tickets',
          presentation: RoutePresentation.fullHeightSheet,
          recommendation: 'merge',
          targetPath: '/tickets',
          rationale: 'Owned and purchasable tickets should live together.',
        ),
        RoutePresentationDecision(
          path: '/e-ticket/:id',
          presentation: RoutePresentation.fullScreen,
          recommendation: 'keep',
          rationale: 'QR scanning needs a dedicated distraction-free surface.',
        ),
      ];
}
