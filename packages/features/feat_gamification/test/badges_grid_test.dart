import 'package:core_theme/core_theme.dart';
import 'package:feat_gamification/src/models/fanzone_models.dart';
import 'package:feat_gamification/src/screens/badges_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:test_support/app_font_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);

  Widget buildSubject({
    required List<PredictionBadge> badges,
    required ValueChanged<PredictionBadge> onBadgeTap,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: BadgesGrid(badges: badges, onBadgeTap: onBadgeTap),
      ),
    );
  }

  testWidgets('returns SizedBox.shrink when badge list is empty', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(badges: const <PredictionBadge>[], onBadgeTap: (_) {}),
    );

    expect(find.text('No badges unlocked yet'), findsNothing);
    expect(find.textContaining('Prediction milestone badges'), findsNothing);
    expect(find.byType(SizedBox), findsOneWidget);
  });

  testWidgets('renders badge controls and forwards badge taps', (tester) async {
    const badge = PredictionBadge(
      badgeSlug: 'gold-streak',
      badgeName: 'Gold Streak',
      badgeDescription: 'Won several predictions in sequence.',
      thresholdWins: 5,
    );
    PredictionBadge? selectedBadge;

    await tester.pumpWidget(
      buildSubject(
        badges: const <PredictionBadge>[badge],
        onBadgeTap: (value) {
          selectedBadge = value;
        },
      ),
    );

    expect(find.byTooltip('Gold Streak'), findsOneWidget);
    expect(find.byIcon(AfriIcons.rank), findsOneWidget);

    await tester.tap(find.byTooltip('Gold Streak'));
    await tester.pump();

    expect(selectedBadge, badge);
  });
}
