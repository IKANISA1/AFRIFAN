import 'package:core_auth/core_auth.dart';
import 'package:feat_club/feat_club.dart';
import 'package:feat_ticketing/src/screens/match_list_screen.dart';
import 'package:feat_ticketing/src/ticketing_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_support/design_font_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadDesignFonts);

  testWidgets('matches the ticketing match list layout', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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
        ],
        child: const MaterialApp(home: MatchListScreen()),
      ),
    );

    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MatchListScreen),
      matchesGoldenFile('goldens/match_list_screen.png'),
    );
  });
}
