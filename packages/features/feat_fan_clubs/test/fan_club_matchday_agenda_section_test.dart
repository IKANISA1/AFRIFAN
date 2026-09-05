import 'package:core_l10n/core_l10n.dart';
import 'package:feat_fan_clubs/src/screens/fan_club_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildSubject({
    required bool isActive,
    required Map<String, dynamic>? match,
    Locale locale = const Locale('en'),
  }) {
    return AfriLocalizationsScope(
      locale: locale,
      child: MaterialApp(
        home: Scaffold(
          body: FanClubMatchdayAgendaSection(isActive: isActive, match: match),
        ),
      ),
    );
  }

  testWidgets('matchday agenda hides when fan club is inactive', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject(isActive: false, match: _match));

    expect(
      find.byKey(const ValueKey<String>('fan-club-matchday-agenda-empty')),
      findsOneWidget,
    );
    expect(find.text('Matchday agenda'), findsNothing);
    expect(find.textContaining('unlock'), findsNothing);
  });

  testWidgets('matchday agenda hides when no match is linked', (tester) async {
    await tester.pumpWidget(buildSubject(isActive: true, match: null));

    expect(
      find.byKey(const ValueKey<String>('fan-club-matchday-agenda-empty')),
      findsOneWidget,
    );
    expect(find.text('Matchday agenda'), findsNothing);
    expect(find.textContaining('No upcoming club fixture'), findsNothing);
  });

  testWidgets('matchday agenda renders linked match details', (tester) async {
    await tester.pumpWidget(buildSubject(isActive: true, match: _match));

    expect(
      find.byKey(const ValueKey<String>('fan-club-matchday-agenda-empty')),
      findsNothing,
    );
    expect(find.text('Matchday agenda'), findsOneWidget);
    expect(find.text('Rayon Sports vs APR'), findsOneWidget);
    expect(find.text('Primus League  •  Amahoro Stadium'), findsOneWidget);
    expect(find.text('2026-07-01  •  18:00'), findsOneWidget);
  });

  testWidgets('matchday agenda renders French and Kinyarwanda task copy', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(isActive: true, match: _match, locale: const Locale('fr')),
    );
    expect(find.text('Programme du jour de match'), findsOneWidget);
    expect(find.text('Rayon Sports contre APR'), findsOneWidget);

    await tester.pumpWidget(
      buildSubject(isActive: true, match: _match, locale: const Locale('rw')),
    );
    await tester.pump();
    expect(find.text('Gahunda y’umunsi w’umukino'), findsOneWidget);
    expect(find.text('Rayon Sports na APR'), findsOneWidget);
  });
}

const _match = <String, dynamic>{
  'home_team': 'Rayon Sports',
  'away_team': 'APR',
  'competition': 'Primus League',
  'venue': 'Amahoro Stadium',
  'match_date': '2026-07-01',
  'kickoff_time': '18:00',
};
