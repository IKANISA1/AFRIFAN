import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shared custom press targets enforce 48 logical pixels', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: AfriPressFeedback(
              onTap: () {},
              child: const SizedBox.square(dimension: 12),
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byType(AfriPressFeedback)),
      const Size.square(SizeTokens.touchTargetMin),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('shared icon buttons expose a 48 by 48 target', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: AfriIconButton(
              icon: Icons.close,
              tooltip: 'Close',
              onTap: () {},
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byType(AfriIconButton)),
      const Size.square(SizeTokens.touchTargetMin),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('loading icon button keeps its target and blocks activation', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AfriIconButton(
            icon: Icons.close,
            tooltip: 'Close',
            isLoading: true,
            onTap: () => taps += 1,
          ),
        ),
      ),
    );

    expect(find.byType(AfriLoadingIndicator), findsOneWidget);
    expect(
      tester.getSize(find.byType(AfriIconButton)),
      const Size.square(SizeTokens.touchTargetMin),
    );
    await tester.tap(find.byType(AfriIconButton));
    expect(taps, 0);
  });

  testWidgets('shared material actions meet the default target floor', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AfriTextButton(onPressed: () {}, child: const Text('Text')),
              AfriOutlinedButton(
                onPressed: () {},
                child: const Text('Outline'),
              ),
              AfriElevatedButton(
                onPressed: () {},
                child: const Text('Elevated'),
              ),
            ],
          ),
        ),
      ),
    );

    for (final type in <Type>[
      AfriTextButton,
      AfriOutlinedButton,
      AfriElevatedButton,
    ]) {
      expect(
        tester.getSize(find.byType(type)).height,
        greaterThanOrEqualTo(SizeTokens.touchTargetMin),
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('interactive info chips are keyboard-operable 48 px targets', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: AfriInfoChip(label: 'Choose', onTap: () => taps += 1),
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byType(AfriInfoChip)).height,
      greaterThanOrEqualTo(SizeTokens.touchTargetMin),
    );
    await tester.tap(find.byType(AfriInfoChip));
    await tester.pump();
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });
}
