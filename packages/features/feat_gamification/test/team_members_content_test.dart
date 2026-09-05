import 'package:feat_gamification/src/models/team_profile_models.dart';
import 'package:feat_gamification/src/widgets/team_profile_tabs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:test_support/app_font_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);

  Widget buildSubject(Widget child) {
    return MaterialApp(home: Scaffold(body: child));
  }

  testWidgets('hides contributor section when no contributors exist', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(
        const TeamMembersContent(
          goldCount: 0,
          silverCount: 0,
          bronzeCount: 0,
          imenaCount: 0,
          contributors: <ClubMemberEntry>[],
        ),
      ),
    );

    expect(find.text('Club members'), findsOneWidget);
    expect(find.text('Top contributors'), findsNothing);
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
          goldCount: 1,
          silverCount: 2,
          bronzeCount: 3,
          imenaCount: 4,
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
    expect(find.text('Gold', skipOffstage: false), findsNWidgets(2));
    expect(find.text('900 pts', skipOffstage: false), findsOneWidget);
    expect(find.text('You', skipOffstage: false), findsOneWidget);
  });
}
