import 'package:feat_gamification/src/screens/streak_calendar_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:test_support/app_font_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);

  Widget buildSubject({
    required List<int> heat,
    required int currentStreak,
    required int bestStreak,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: StreakCalendarContent(
          heat: heat,
          currentStreak: currentStreak,
          bestStreak: bestStreak,
        ),
      ),
    );
  }

  testWidgets('hides zero-streak empty copy while preserving metrics', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(
        heat: List<int>.filled(35, 0),
        currentStreak: 0,
        bestStreak: 0,
      ),
    );

    expect(find.text('No activity streak has started yet.'), findsNothing);
    expect(find.byKey(const ValueKey<String>('streak-status-empty')), findsOne);
    expect(find.text('0 DAYS'), findsOneWidget);
    expect(find.text('Next bonus'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('renders active streak text and semantic heat cells', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    try {
      await tester.pumpWidget(
        buildSubject(
          heat: <int>[0, 1, 3, ...List<int>.filled(32, 0)],
          currentStreak: 3,
          bestStreak: 8,
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('streak-status-empty')),
        findsNothing,
      );
      expect(find.text('3 DAYS'), findsOneWidget);
      expect(find.text('Streak active.'), findsOneWidget);
      expect(find.text('Best'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
      expect(find.bySemanticsLabel('Streak day 2: 1 win'), findsOneWidget);
      expect(find.bySemanticsLabel('Streak day 3: 3 wins'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });
}
