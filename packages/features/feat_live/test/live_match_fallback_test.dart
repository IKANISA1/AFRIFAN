import 'package:feat_live/src/screens/live_match_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildSubject({required String? error, required VoidCallback onRetry}) {
    return MaterialApp(
      home: Scaffold(
        body: LiveMatchFallbackContent(error: error, onRetry: onRetry),
      ),
    );
  }

  testWidgets('collapses when no fixture is currently available', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject(error: null, onRetry: () {}));

    expect(find.text('Live center unavailable'), findsNothing);
    expect(find.textContaining('No live or upcoming'), findsNothing);
    expect(find.byType(SizedBox), findsOneWidget);
  });

  testWidgets('shows retryable error when live match loading fails', (
    tester,
  ) async {
    var retried = false;

    await tester.pumpWidget(
      buildSubject(
        error: 'Could not load the live match center right now.',
        onRetry: () {
          retried = true;
        },
      ),
    );

    expect(find.text('Live center unavailable'), findsOneWidget);
    expect(
      find.text('Could not load the live match center right now.'),
      findsOneWidget,
    );
    expect(find.text('Refresh'), findsOneWidget);

    await tester.tap(find.text('Refresh'));

    expect(retried, isTrue);
  });
}
