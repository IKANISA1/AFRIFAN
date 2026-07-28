import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('keeps primary and menu actions separate and reachable', (
    tester,
  ) async {
    var primaryTaps = 0;
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AfriSplitButton<String>(
            label: 'Save',
            onPressed: () => primaryTaps += 1,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'draft', child: Text('Save as draft')),
            ],
            onSelected: (value) => selected = value,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Save'));
    expect(primaryTaps, 1);
    expect(selected, isNull);

    final menuTarget = tester.getSize(find.byTooltip('More actions'));
    expect(menuTarget.width, greaterThanOrEqualTo(48));
    expect(menuTarget.height, greaterThanOrEqualTo(48));
    await tester.tap(find.byTooltip('More actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save as draft'));
    await tester.pumpAndSettle();

    expect(primaryTaps, 1);
    expect(selected, 'draft');
  });

  testWidgets('loading disables both split actions', (tester) async {
    var primaryTaps = 0;
    var selections = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AfriSplitButton<String>(
            label: 'Saving',
            isLoading: true,
            onPressed: () => primaryTaps += 1,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'draft', child: Text('Save as draft')),
            ],
            onSelected: (_) => selections += 1,
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byType(AfriButton));
    await tester.tap(find.byTooltip('More actions'));
    await tester.pump();
    expect(primaryTaps, 0);
    expect(selections, 0);
    expect(find.text('Save as draft'), findsNothing);
  });
}
