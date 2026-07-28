import 'package:core_network/core_network.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => ConnectivityService.setOnlineForTest(true));
  tearDown(() async {
    ConnectivityService.setOnlineForTest(true);
    await ConnectivityService.dispose();
  });

  testWidgets(
    'labels stale content and unavailable network actions while offline',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: OfflineBanner(child: Text('Saved fixture'))),
        ),
      );

      ConnectivityService.setOnlineForTest(false);
      await tester.pump();

      expect(find.text('Saved fixture'), findsOneWidget);
      expect(
        find.text(
          'Offline. Content may be out of date. '
          'Network actions are unavailable.',
        ),
        findsOneWidget,
      );
      final bannerSemantics = tester.widget<Semantics>(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label ==
                  'Offline. Content may be out of date. '
                      'Network actions are unavailable.',
        ),
      );
      expect(bannerSemantics.properties.liveRegion, isTrue);
    },
  );

  testWidgets('announces recovery and then dismisses the status banner', (
    tester,
  ) async {
    ConnectivityService.setOnlineForTest(false);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: OfflineBanner(child: Text('Saved fixture'))),
      ),
    );

    ConnectivityService.setOnlineForTest(true);
    await tester.pump();

    expect(
      find.text('Connection restored. Refreshing current content.'),
      findsOneWidget,
    );
    final bannerSemantics = tester.widget<Semantics>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label ==
                'Connection restored. Refreshing current content.',
      ),
    );
    expect(bannerSemantics.properties.liveRegion, isTrue);

    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.text('Connection restored. Refreshing current content.'),
      findsNothing,
    );
    expect(find.text('Saved fixture'), findsOneWidget);
  });

  testWidgets('ConnectivityBuilder disables and relabels network actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConnectivityBuilder(
            builder: (context, isOnline) => ElevatedButton(
              onPressed: isOnline ? () {} : null,
              child: Text(isOnline ? 'Refresh' : 'Connection required'),
            ),
          ),
        ),
      ),
    );

    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).enabled,
      isTrue,
    );

    ConnectivityService.setOnlineForTest(false);
    await tester.pump();

    expect(find.text('Connection required'), findsOneWidget);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).enabled,
      isFalse,
    );
  });
}
