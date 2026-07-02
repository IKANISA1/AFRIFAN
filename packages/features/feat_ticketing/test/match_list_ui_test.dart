import 'dart:async';

import 'package:core_auth/core_auth.dart';
import 'package:feat_club/feat_club.dart';
import 'package:feat_ticketing/src/screens/match_list_screen.dart';
import 'package:feat_ticketing/src/ticketing_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:test_support/app_font_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);

  testWidgets('matches the ticketing match list layout', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _buildTicketingApp(
        ticketMatchesProvider.overrideWith(
          (ref) async => [
            ClubMatch(
              id: 'fixture-1',
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
              soldCount: 5400,
            ),
          ],
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(MatchListScreen), findsOneWidget);
  });

  testWidgets('matches the ticketing loading layout', (tester) async {
    _setMobileSurface(tester);
    final pendingMatches = Completer<List<ClubMatch>>();
    addTearDown(() {
      if (!pendingMatches.isCompleted) {
        pendingMatches.complete(const <ClubMatch>[]);
      }
    });

    await tester.pumpWidget(
      _buildTicketingApp(
        ticketMatchesProvider.overrideWith((ref) => pendingMatches.future),
      ),
    );
    await tester.pump();

    expect(find.byType(MatchListScreen), findsOneWidget);
  });

  testWidgets('matches the ticketing empty layout', (tester) async {
    _setMobileSurface(tester);

    await tester.pumpWidget(
      _buildTicketingApp(
        ticketMatchesProvider.overrideWith((ref) async => const <ClubMatch>[]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MatchListScreen), findsOneWidget);
  });

  testWidgets('matches the ticketing error layout', (tester) async {
    _setMobileSurface(tester);

    await tester.pumpWidget(
      _buildTicketingApp(
        ticketMatchesProvider.overrideWith(
          (ref) async => throw StateError('ticketing unavailable'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MatchListScreen), findsOneWidget);
  });

  testWidgets('matches the ticketing match list at 200 percent text', (
    tester,
  ) async {
    _setMobileSurface(tester);
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      _buildTicketingApp(
        ticketMatchesProvider.overrideWith((ref) async => [_fixture()]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MatchListScreen), findsOneWidget);
  });
}

Widget _buildTicketingApp(Override ticketMatchesOverride) {
  final router = GoRouter(
    initialLocation: '/tickets',
    routes: [
      GoRoute(
        path: '/tickets',
        builder: (context, state) => const MatchListScreen(),
      ),
      GoRoute(
        path: '/tickets/:matchId',
        builder: (context, state) => const SizedBox.shrink(),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      currentUserProvider.overrideWith(
        (ref) => const UserProfile(
          id: 'user-1',
          clubId: '24',
          publicUserId: '483912',
        ),
      ),
      ticketMatchesOverride,
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void _setMobileSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

ClubMatch _fixture() {
  return ClubMatch(
    id: 'fixture-1',
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
    soldCount: 5400,
  );
}
