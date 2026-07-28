import 'package:core_theme/core_theme.dart';
import 'package:feat_gamification/src/widgets/animated_fet_counter.dart';
import 'package:feat_gamification/src/widgets/confetti_overlay.dart';
import 'package:feat_gamification/src/widgets/notification_toast_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('FET counters expose their final value without count-up motion', (
    tester,
  ) async {
    final value = ValueNotifier<int>(1250);
    addTearDown(value.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(accessibleNavigation: true),
          child: ValueListenableBuilder<int>(
            valueListenable: value,
            builder: (context, current, _) =>
                AnimatedFetCounter(value: current),
          ),
        ),
      ),
    );

    expect(find.text('+1,250 FET'), findsOneWidget);

    value.value = 2400;
    await tester.pump();

    expect(find.text('+2,400 FET'), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('decorative confetti is skipped under reduced motion', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Builder(
            builder: (context) => AfriButton(
              label: 'Celebrate',
              onTap: () => showConfettiOverlay(context),
            ),
          ),
        ),
      ),
    );

    final ignorePointersBefore = tester
        .widgetList<IgnorePointer>(find.byType(IgnorePointer))
        .length;
    await tester.tap(find.text('Celebrate'));
    await tester.pump();

    expect(
      tester.widgetList<IgnorePointer>(find.byType(IgnorePointer)).length,
      ignorePointersBefore,
    );
  });

  testWidgets('notification content appears without entrance delay', (
    tester,
  ) async {
    late BuildContext triggerContext;

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(accessibleNavigation: true),
          child: NotificationToastOverlay(
            child: Builder(
              builder: (context) {
                triggerContext = context;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      ),
    );

    NotificationToastOverlay.show(
      triggerContext,
      title: 'Ticket ready',
      message: 'Open your ticket wallet.',
    );
    await tester.pump();

    expect(find.text('Ticket ready'), findsOneWidget);
    expect(find.text('Open your ticket wallet.'), findsOneWidget);
  });
}
