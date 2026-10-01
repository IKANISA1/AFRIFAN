import 'dart:ui' show SemanticsAction;

import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('info chip is readable on membership $brightness canvas', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          MaterialApp(
            theme: ClubTheme.from(
              ClubConfig.fallback(),
              brightness: brightness,
            ),
            home: Scaffold(
              body: GradientBackground(
                routePath: '/membership',
                child: Align(
                  alignment: Alignment.topCenter,
                  child: AfriInfoChip(
                    label: 'Share',
                    icon: Icons.share,
                    onTap: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      } finally {
        semantics.dispose();
      }
    });
  }

  testWidgets('selected choice chip keeps its palette and readable text', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        MaterialApp(
          theme: ClubTheme.from(
            ClubConfig.fallback(),
            brightness: Brightness.dark,
          ),
          home: Scaffold(
            body: Center(
              child: AfriChoiceChip(
                selected: true,
                label: const Text('News'),
                onSelected: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final chip = tester.widget<ChoiceChip>(find.byType(ChoiceChip));
      expect(chip.selectedColor, ColorTokens.primaryContainer);
      expect(
        chip.labelStyle!.color,
        ColorTokens.contrastForeground(ColorTokens.primaryContainer),
      );
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    } finally {
      semantics.dispose();
    }
  });

  testWidgets(
    'disabled selected chip remains readable and exposes no tap action',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          MaterialApp(
            theme: ClubTheme.from(
              ClubConfig.fallback(),
              brightness: Brightness.dark,
            ),
            home: const Scaffold(
              body: Center(
                child: AfriChoiceChip(selected: true, label: Text('Schedule')),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final node = tester.getSemantics(find.bySemanticsLabel('Schedule'));
        expect(node.flagsCollection.isEnabled.toBoolOrNull(), false);
        expect(node.flagsCollection.isSelected.toBoolOrNull(), true);
        expect(node.getSemanticsData().hasAction(SemanticsAction.tap), false);
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pumpAndSettle();
        expect(node.getSemanticsData().hasAction(SemanticsAction.tap), false);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'a switch exposes one labeled toggled control and keyboard action',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        var value = false;
        await tester.pumpWidget(
          MaterialApp(
            theme: ClubTheme.from(
              ClubConfig.fallback(),
              brightness: Brightness.dark,
            ),
            home: Scaffold(
              body: Center(
                child: StatefulBuilder(
                  builder: (context, setState) => AfriSwitch(
                    semanticsLabel: 'Show shop',
                    value: value,
                    onChanged: (selected) => setState(() => value = selected),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final control = find.bySemanticsLabel('Show shop');
        expect(control, findsOneWidget);
        expect(
          tester.getSemantics(control).flagsCollection.isToggled.toBoolOrNull(),
          false,
        );
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pumpAndSettle();
        expect(value, true);
        expect(
          tester.getSemantics(control).flagsCollection.isToggled.toBoolOrNull(),
          true,
        );
      } finally {
        semantics.dispose();
      }
    },
  );
}
