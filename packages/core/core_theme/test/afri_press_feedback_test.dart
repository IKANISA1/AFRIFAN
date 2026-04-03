import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('supports keyboard activation when focused', (tester) async {
    var taps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: AfriPressFeedback(
              autofocus: true,
              onTap: () => taps += 1,
              semanticsLabel: 'Open action',
              child: const SizedBox(width: 120, height: 48),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    expect(taps, 1);
  });
}
