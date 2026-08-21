import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_support/touch_target_audit.dart';

void main() {
  testWidgets('audits enabled route controls at the 48 pixel floor', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          ),
        ),
        home: Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Close',
                onPressed: () {},
              ),
              TextButton(onPressed: () {}, child: const Text('Continue')),
              Switch(value: true, onChanged: (_) {}),
            ],
          ),
        ),
      ),
    );

    expectTapTargetsMeetMinimum(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rejects an unapproved undersized tap target', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: GestureDetector(
            onTap: () {},
            child: const SizedBox.square(dimension: 40),
          ),
        ),
      ),
    );

    expect(
      () => expectTapTargetsMeetMinimum(tester),
      throwsA(isA<TestFailure>()),
    );
  });

  testWidgets('allows only an explicitly keyed 44 pixel dense exception', (
    tester,
  ) async {
    const denseKey = ValueKey<String>('approved-dense-control');
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: GestureDetector(
            key: denseKey,
            onTap: () {},
            child: const SizedBox.square(dimension: 44),
          ),
        ),
      ),
    );

    expectTapTargetsMeetMinimum(tester, approvedDenseKeys: <Key>{denseKey});
  });
}
