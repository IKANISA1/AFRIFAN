import 'dart:async';

import 'package:club_data/club_data.dart';
import 'package:core_auth/core_auth.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_ticketing/src/screens/match_list_screen.dart';
import 'package:feat_ticketing/src/ticketing_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => ConnectivityService.setOnlineForTest(true));

  testWidgets('retains ticket inventory and refreshes it after reconnect', (
    tester,
  ) async {
    final reconnected = Completer<List<ClubMatch>>();
    var calls = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWithValue(_user),
          ticketMatchesProvider.overrideWith((ref) {
            calls += 1;
            if (calls == 1) return Future.value([_fixture]);
            return reconnected.future;
          }),
          myTicketsProvider.overrideWith((ref) async => const []),
        ],
        child: MaterialApp(
          theme: ClubTheme.from(ClubConfig.fallback()),
          home: ClubConfigScope(
            config: ClubConfig.fallback(),
            child: const MatchListScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Rayon Sports vs APR FC'), findsOneWidget);

    ConnectivityService.setOnlineForTest(false);
    await tester.pump();

    expect(find.text('Saved ticket inventory'), findsOneWidget);
    expect(find.text('Rayon Sports vs APR FC'), findsOneWidget);
    expect(
      find.byTooltip('Connection required to refresh matches'),
      findsOneWidget,
    );

    ConnectivityService.setOnlineForTest(true);
    await tester.pump();

    expect(calls, 2);
    expect(find.text('Refreshing ticket inventory'), findsOneWidget);
    expect(find.text('Rayon Sports vs APR FC'), findsOneWidget);

    reconnected.complete([_fixture]);
    await tester.pumpAndSettle();

    expect(find.text('Saved ticket inventory'), findsNothing);
    expect(find.text('Refreshing ticket inventory'), findsNothing);
    expect(find.text('Rayon Sports vs APR FC'), findsOneWidget);
  });
}

final _fixture = ClubMatch(
  id: 'match-1',
  homeTeam: 'Rayon Sports',
  awayTeam: 'APR FC',
  competition: 'Premier League',
  venue: 'Amahoro Stadium',
  matchDate: DateTime.utc(2099, 8, 1, 15),
  kickoffTime: '15:00',
  isOnSale: true,
  ticketGeneralPrice: 3000,
  ticketVipPrice: 12000,
  saleStartsAt: DateTime.utc(2099, 7, 1),
  capacity: 45000,
);

const _user = UserProfile(
  id: 'supporter-1',
  clubId: '24',
  publicUserId: '483912',
);
