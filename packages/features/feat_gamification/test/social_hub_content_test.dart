import 'package:feat_gamification/src/models/fet_models.dart';
import 'package:feat_gamification/src/screens/social_hub_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:test_support/app_font_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);

  Widget buildSubject(Widget child) {
    return MaterialApp(home: Scaffold(body: child));
  }

  testWidgets('hides friends section when no friends match', (tester) async {
    await tester.pumpWidget(
      buildSubject(
        SocialHubFriendsSection(
          friends: const <FetFriendProfile>[],
          onViewAll: () {},
          onChallenge: (_) {},
        ),
      ),
    );

    expect(find.text('Your friends'), findsNothing);
    expect(find.text('No friends yet'), findsNothing);
    expect(find.text('No matches'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('social-hub-friends-empty')),
      findsOne,
    );
  });

  testWidgets('renders friends section and forwards challenge taps', (
    tester,
  ) async {
    const friend = FetFriendProfile(
      userId: 'supporter-1',
      publicUserId: '483912',
      displayName: 'Supporter 483912',
      tier: 'legend',
      balance: 1250,
      friendshipStatus: 'accepted',
      isOnline: true,
    );
    FetFriendProfile? challengedFriend;

    await tester.pumpWidget(
      buildSubject(
        SocialHubFriendsSection(
          friends: const <FetFriendProfile>[friend],
          onViewAll: () {},
          onChallenge: (value) {
            challengedFriend = value;
          },
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('social-hub-friends-empty')),
      findsNothing,
    );
    expect(find.text('Your friends'), findsOneWidget);
    expect(find.text('Supporter 483912'), findsOneWidget);
    expect(find.text('#483912 · LEGEND · 1250 pts'), findsOneWidget);
    expect(find.text('Online'), findsOneWidget);

    await tester.tap(find.text('Challenge'));
    await tester.pump();

    expect(challengedFriend, friend);
  });

  testWidgets('hides leaderboard section when no rankings exist', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(
        const SocialHubLeaderboardSection(fans: <FetLeaderboardRow>[]),
      ),
    );

    expect(find.text('Leaderboard'), findsNothing);
    expect(find.text('No rankings yet'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('social-hub-leaderboard-empty')),
      findsOne,
    );
  });

  testWidgets('renders leaderboard rows and current supporter marker', (
    tester,
  ) async {
    const rows = <FetLeaderboardRow>[
      FetLeaderboardRow(
        rank: 1,
        userId: 'supporter-1',
        supporterAlias: '483912',
        displayName: 'Supporter 483912',
        totalFet: 2400,
        tier: 'legend',
        isCurrentUser: true,
      ),
      FetLeaderboardRow(
        rank: 2,
        userId: 'supporter-2',
        supporterAlias: '991122',
        displayName: 'Supporter 991122',
        totalFet: 1800,
        tier: 'imena',
        isCurrentUser: false,
      ),
    ];

    await tester.pumpWidget(
      buildSubject(const SocialHubLeaderboardSection(fans: rows)),
    );

    expect(
      find.byKey(const ValueKey<String>('social-hub-leaderboard-empty')),
      findsNothing,
    );
    expect(find.text('Leaderboard'), findsOneWidget);
    expect(find.text('#1'), findsOneWidget);
    expect(find.text('Supporter 483912 (You)'), findsOneWidget);
    expect(find.text('2400 pts'), findsOneWidget);
    expect(find.text('#2'), findsOneWidget);
    expect(find.text('Supporter 991122'), findsOneWidget);
  });
}
