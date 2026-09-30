import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('single-action buttons expose one named accessible tap target', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AfriButton(label: 'Review payment', onTap: () {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      expect(find.bySemanticsLabel('Review payment'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });
  testWidgets('outlined choices honor their card shape and custom insets', (
    tester,
  ) async {
    const padding = EdgeInsets.symmetric(horizontal: 4, vertical: 12);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: AfriOutlinedButton(
              style: AfriOutlinedButton.styleFrom(
                padding: padding,
                shape: shape,
              ),
              onPressed: () => taps++,
              child: const Text('Draw'),
            ),
          ),
        ),
      ),
    );
    final finder = find.byType(OutlinedButton);
    final button = tester.widget<OutlinedButton>(finder);
    expect(button.style?.padding?.resolve({}), padding);
    expect(button.style?.shape?.resolve({}), shape);
    expect(tester.getSize(finder).height, greaterThanOrEqualTo(48));
    await tester.tap(finder);
    expect(taps, 1);
  });

  testWidgets(
    'text actions honor custom insets while keeping the touch target',
    (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AfriTextButton(
                style: AfriTextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  foregroundColor: Colors.purple,
                ),
                onPressed: () => taps++,
                child: const Text('Resend'),
              ),
            ),
          ),
        ),
      );
      final button = find.byType(TextButton);
      expect(
        tester.getRect(find.text('Resend')).left,
        tester.getRect(button).left,
      );
      expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
      expect(
        tester.widget<TextButton>(button).style?.foregroundColor?.resolve({}),
        Colors.purple,
      );
      await tester.tap(button);
      expect(taps, 1);
    },
  );

  testWidgets('supports injected focus and keyboard Select activation', (
    tester,
  ) async {
    final focusNode = FocusNode(debugLabel: 'test AfriButton');
    addTearDown(focusNode.dispose);
    var taps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: AfriButton(
              label: 'Continue',
              onTap: () => taps += 1,
              focusNode: focusNode,
              autofocus: true,
              fullWidth: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(focusNode.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();

    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('destructive variant uses an accessible danger treatment', (
    tester,
  ) async {
    final config = ClubConfig.fallback();
    ColorTokens.init();
    await tester.pumpWidget(
      MaterialApp(
        theme: ClubTheme.from(config),
        home: Scaffold(
          body: AfriButton(
            label: 'Delete account',
            variant: AfriButtonVariant.destructive,
            fullWidth: false,
            onTap: () {},
          ),
        ),
      ),
    );

    final animated = tester.widgetList<AnimatedContainer>(
      find.byType(AnimatedContainer),
    );
    final decoration = animated
        .map((widget) => widget.decoration)
        .whereType<BoxDecoration>()
        .firstWhere((value) => value.color != null);
    final colors = AfriSemanticColors.dark;
    expect(decoration.color, colors.danger);
    expect(
      ColorTokens.contrastForeground(colors.danger),
      isNot(Colors.transparent),
    );
    expect(find.text('Delete account'), findsOneWidget);
  });
}
