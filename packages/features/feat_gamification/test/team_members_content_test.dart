import 'package:feat_gamification/src/models/team_profile_models.dart';
import 'package:feat_gamification/src/widgets/team_profile_tabs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:test_support/design_font_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadDesignFonts);

  Widget buildSubject(Widget child) {
    return MaterialApp(home: Scaffold(body: child));
  }

  testWidgets('hides contributor section when no contributors exist', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(
        const TeamMembersContent(
          legendCount: 0,
          ultraCount: 0,
          memberCount: 0,
          supporterCount: 0,
          contributors: <ClubMemberEntry>[],
        ),
      ),
    );

    expect(find.text('CLUB MEMBERS'), findsOneWidget);
    expect(find.text('TOP CONTRIBUTORS'), findsNothing);
    expect(find.text('No contributors yet'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('team-members-contributors-title')),
      findsNothing,
    );
  });

  testWidgets('renders contributor section when contributor rows exist', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(
        const TeamMembersContent(
          legendCount: 1,
          ultraCount: 2,
          memberCount: 3,
          supporterCount: 4,
          contributors: <ClubMemberEntry>[
            ClubMemberEntry(
              userId: 'user-1',
              displayLabel: '#123456',
              tier: 'gold',
              points: 900,
              isCurrentUser: true,
            ),
          ],
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('team-members-contributors-title')),
      findsOneWidget,
    );
    expect(find.text('#123456', skipOffstage: false), findsOneWidget);
    expect(find.text('GOLD', skipOffstage: false), findsOneWidget);
    expect(find.text('900 FET', skipOffstage: false), findsOneWidget);
    expect(find.text('YOU', skipOffstage: false), findsOneWidget);
  });
}
