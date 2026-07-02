import 'package:feat_gamification/src/models/fet_models.dart';
import 'package:feat_gamification/src/screens/friends_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:test_support/design_font_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadDesignFonts);

  Widget buildSubject({
    required bool searchMode,
    required List<FetFriendProfile> supporters,
    required ValueChanged<FetFriendProfile> onAction,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: FriendSupportersSection(
          searchMode: searchMode,
          supporters: supporters,
          onAction: onAction,
        ),
      ),
    );
  }

  testWidgets('returns SizedBox.shrink when friend list is empty', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(
        searchMode: false,
        supporters: const <FetFriendProfile>[],
        onAction: (_) {},
      ),
    );

    expect(find.text('Your friends'), findsNothing);
    expect(find.text('No friends yet'), findsNothing);
    expect(find.textContaining('Search for supporters'), findsNothing);
    expect(find.byKey(const ValueKey<String>('friends-list-empty')), findsOne);
  });

  testWidgets('returns SizedBox.shrink when search results are empty', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(
        searchMode: true,
        supporters: const <FetFriendProfile>[],
        onAction: (_) {},
      ),
    );

    expect(find.text('Results'), findsNothing);
    expect(find.text('No supporters found'), findsNothing);
    expect(find.textContaining('Try another name'), findsNothing);
    expect(find.byKey(const ValueKey<String>('friends-list-empty')), findsOne);
  });

  testWidgets('renders supporter rows and forwards actions', (tester) async {
    const supporter = FetFriendProfile(
      userId: 'supporter-1',
      publicUserId: '483912',
      displayName: 'Supporter 483912',
      tier: 'legend',
      balance: 1250,
      friendshipStatus: 'accepted',
      isOnline: true,
    );
    FetFriendProfile? selectedSupporter;

    await tester.pumpWidget(
      buildSubject(
        searchMode: false,
        supporters: const <FetFriendProfile>[supporter],
        onAction: (value) {
          selectedSupporter = value;
        },
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('friends-list-empty')),
      findsNothing,
    );
    expect(find.text('Your friends'), findsOneWidget);
    expect(find.text('Supporter 483912'), findsOneWidget);
    expect(find.text('#483912 · LEGEND · 1250 pts'), findsOneWidget);
    expect(find.text('Online'), findsOneWidget);
    expect(find.text('Challenge'), findsOneWidget);

    await tester.tap(find.text('Challenge'));
    await tester.pump();

    expect(selectedSupporter, supporter);
  });
}
