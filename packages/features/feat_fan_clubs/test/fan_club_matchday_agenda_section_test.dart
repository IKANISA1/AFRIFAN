import 'package:feat_fan_clubs/src/screens/fan_club_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildSubject({
    required bool isActive,
    required Map<String, dynamic>? match,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: FanClubMatchdayAgendaSection(isActive: isActive, match: match),
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
    expect(find.text('MATCHDAY AGENDA'), findsNothing);
    expect(find.textContaining('unlock'), findsNothing);
  });

  testWidgets('matchday agenda hides when no match is linked', (tester) async {
    await tester.pumpWidget(buildSubject(isActive: true, match: null));

    expect(
      find.byKey(const ValueKey<String>('fan-club-matchday-agenda-empty')),
      findsOneWidget,
    );
    expect(find.text('MATCHDAY AGENDA'), findsNothing);
    expect(find.textContaining('No upcoming club fixture'), findsNothing);
  });

  testWidgets('matchday agenda renders linked match details', (tester) async {
    await tester.pumpWidget(buildSubject(isActive: true, match: _match));

    expect(
      find.byKey(const ValueKey<String>('fan-club-matchday-agenda-empty')),
      findsNothing,
    );
    expect(find.text('MATCHDAY AGENDA'), findsOneWidget);
    expect(find.text('Rayon Sports vs APR'), findsOneWidget);
    expect(find.text('Primus League  •  Amahoro Stadium'), findsOneWidget);
    expect(find.text('2026-07-01  •  18:00'), findsOneWidget);
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
