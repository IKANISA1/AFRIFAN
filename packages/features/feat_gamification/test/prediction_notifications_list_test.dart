import 'package:feat_gamification/src/models/fanzone_models.dart';
import 'package:feat_gamification/src/screens/prediction_notifications_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:test_support/design_font_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadDesignFonts);

  Widget buildSubject({
    required List<PredictionNotification> notifications,
    void Function(PredictionNotification notification)? onOpenNotification,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: PredictionNotificationsList(
          notifications: notifications,
          onOpenNotification: onOpenNotification,
        ),
      ),
    );
  }

  testWidgets('returns SizedBox.shrink when notifications list is empty', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(notifications: const <PredictionNotification>[]),
    );

    expect(find.text('No prediction alerts yet'), findsNothing);
    expect(
      find.textContaining('Settlement and result notifications'),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('prediction-notifications-empty')),
      findsOne,
    );
  });

  testWidgets('renders notification cards with semantic summaries', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    try {
      const notification = PredictionNotification(
        id: 'notification-1',
        notificationType: 'settlement',
        title: 'Prediction settled',
        body: 'Your Rayon Sports result prediction won.',
        payload: <String, dynamic>{
          'route': '/fanzone/my/prediction-1',
          'earned': 120,
        },
        createdAt: null,
        isSent: true,
      );
      PredictionNotification? openedNotification;

      await tester.pumpWidget(
        buildSubject(
          notifications: const <PredictionNotification>[notification],
          onOpenNotification: (value) {
            openedNotification = value;
          },
        ),
      );

      expect(find.text('Prediction settled'), findsOneWidget);
      expect(
        find.text('Your Rayon Sports result prediction won.'),
        findsOneWidget,
      );
      expect(find.text('+120 pts'), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          'Prediction alert, Prediction settled, '
          'Your Rayon Sports result prediction won., Just now, reward 120 points',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('OPEN'));
      await tester.pump();

      expect(openedNotification, notification);
    } finally {
      semantics.dispose();
    }
  });
}
