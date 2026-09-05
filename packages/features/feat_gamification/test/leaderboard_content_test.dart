import 'package:feat_gamification/src/models/fet_models.dart';
import 'package:feat_gamification/src/models/prediction_models.dart';
import 'package:feat_gamification/src/providers/leaderboard_provider.dart';
import 'package:feat_gamification/src/screens/leaderboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:test_support/app_font_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);

  Widget buildSubject(Widget child) {
    return MaterialApp(home: Scaffold(body: child));
  }

  testWidgets('returns SizedBox.shrink when FET leaderboard is empty', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(
        const FetLeaderboardContent(
          snapshot: FetLeaderboardSnapshot(),
          currentUserId: null,
        ),
      ),
    );

    expect(find.text('No ranks yet'), findsNothing);
    expect(find.textContaining('predictions settle'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('fet-leaderboard-empty')),
      findsOne,
    );
  });

  testWidgets('hides FET podium until three ranked users exist', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(
        const FetLeaderboardContent(
          currentUserId: 'user-2',
          snapshot: FetLeaderboardSnapshot(
            rows: <PredictionLeaderboardEntry>[
              PredictionLeaderboardEntry(
                rank: 1,
                userId: 'user-1',
                displayName: 'Jean',
                wins: 8,
                totalSettled: 10,
                totalFetEarned: 1200,
                winRate: 80,
              ),
              PredictionLeaderboardEntry(
                rank: 2,
                userId: 'user-2',
                displayName: 'Aline',
                wins: 7,
                totalSettled: 9,
                totalFetEarned: 900,
                winRate: 77.8,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('fet-leaderboard-podium')),
      findsNothing,
    );
    expect(find.text('Jean'), findsOneWidget);
    expect(find.text('Aline'), findsWidgets);
    expect(find.text('You'), findsWidgets);
  });

  testWidgets('returns SizedBox.shrink when supporter leaderboard is empty', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(
        const SupporterLeaderboardContent(
          snapshot: SupporterLeaderboardSnapshot(),
        ),
      ),
    );

    expect(find.text('No supporters yet'), findsNothing);
    expect(find.textContaining('rankings update'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('supporter-leaderboard-empty')),
      findsOne,
    );
  });

  testWidgets('renders supporter podium only with three ranked users', (
    tester,
  ) async {
    const rows = <FetLeaderboardRow>[
      FetLeaderboardRow(
        rank: 1,
        userId: 'fan-1',
        supporterAlias: '111111',
        displayName: 'Diane',
        totalFet: 3200,
        tier: 'gold',
        isCurrentUser: false,
      ),
      FetLeaderboardRow(
        rank: 2,
        userId: 'fan-2',
        supporterAlias: '222222',
        displayName: 'Claude',
        totalFet: 2500,
        tier: 'silver',
        isCurrentUser: true,
      ),
      FetLeaderboardRow(
        rank: 3,
        userId: 'fan-3',
        supporterAlias: '333333',
        displayName: 'Grace',
        totalFet: 2100,
        tier: 'bronze',
        isCurrentUser: false,
      ),
    ];

    await tester.pumpWidget(
      buildSubject(
        const SupporterLeaderboardContent(
          snapshot: SupporterLeaderboardSnapshot(rows: rows),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('supporter-leaderboard-podium')),
      findsOneWidget,
    );
    expect(find.text('Diane'), findsWidgets);
    expect(find.text('Claude'), findsWidgets);
    expect(find.text('Grace'), findsWidgets);
    expect(find.text('You'), findsWidgets);
  });
}
