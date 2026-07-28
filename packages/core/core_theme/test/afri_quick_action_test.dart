import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('is circular, semantic, keyboard operable, and scaling-safe', (
    tester,
  ) async {
    var taps = 0;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      MaterialApp(
        theme: ClubTheme.from(ClubConfig.fallback()),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 120,
              child: AfriQuickAction(
                icon: AfriIcons.tickets,
                label: 'Match tickets',
                onTap: () => taps += 1,
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    final circle = tester.getSize(
      find.byKey(const ValueKey<String>('afri-quick-action-circle')),
    );
    expect(circle, const Size.square(64));
    final semantics = tester
        .getSemantics(find.byType(AfriQuickAction))
        .getSemanticsData();
    expect(semantics.label, 'Match tickets');

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(taps, 1);
  });
}
