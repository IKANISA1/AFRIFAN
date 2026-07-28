import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'keeps a hidden value out of semantics until explicitly revealed',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final changes = <bool>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AfriMaskedValue(
              label: 'Account number',
              value: '1234567890',
              visibleCharacterCount: 4,
              onVisibilityChanged: changes.add,
            ),
          ),
        ),
      );

      expect(find.text('••••••7890'), findsOneWidget);
      expect(find.text('1234567890'), findsNothing);
      expect(
        tester.getSemantics(find.byType(AfriMaskedValue)).label,
        'Account number, hidden',
      );
      expect(
        tester.getSemantics(find.byTooltip('Reveal Account number')).label,
        isNot(contains('1234567890')),
      );

      await tester.tap(find.byTooltip('Reveal Account number'));
      await tester.pump();

      expect(find.text('1234567890'), findsOneWidget);
      expect(find.text('••••••7890'), findsNothing);
      expect(changes, <bool>[true]);
      expect(find.byTooltip('Hide Account number'), findsOneWidget);
      semantics.dispose();
    },
  );

  testWidgets('disabled reveal control cannot expose the protected value', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AfriMaskedValue(
            label: 'Account number',
            value: '1234567890',
            visibleCharacterCount: 4,
            enabled: false,
          ),
        ),
      ),
    );

    expect(find.text('••••••7890'), findsOneWidget);
    await tester.tap(find.byTooltip('Reveal Account number'));
    await tester.pump();
    expect(find.text('1234567890'), findsNothing);
    expect(find.text('••••••7890'), findsOneWidget);
  });
}
