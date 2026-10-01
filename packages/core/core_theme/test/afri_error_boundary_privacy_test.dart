import 'package:core_theme/core_theme.dart';
import 'package:flutter/foundation.dart' show debugPrint, ValueNotifier;
import 'package:flutter/material.dart'
    show
        BuildContext,
        ErrorWidget,
        MaterialApp,
        StatelessWidget,
        Widget,
        SizedBox,
        ValueListenableBuilder;
import 'package:flutter_test/flutter_test.dart';

class _Failure extends StatelessWidget {
  const _Failure();

  @override
  Widget build(BuildContext context) =>
      throw StateError('opaque-private-framework-sentinel');
}

void main() {
  testWidgets(
    'nested boundaries restore the original global builder after each frame',
    (tester) async {
      final original = ErrorWidget.builder;
      try {
        await tester.pumpWidget(
          const MaterialApp(
            home: AfriErrorBoundary(
              child: AfriErrorBoundary(child: SizedBox()),
            ),
          ),
        );
        expect(identical(ErrorWidget.builder, original), isTrue);
        await tester.pumpWidget(
          const MaterialApp(
            home: AfriErrorBoundary(
              child: AfriErrorBoundary(child: SizedBox(width: 12)),
            ),
          ),
        );
        expect(identical(ErrorWidget.builder, original), isTrue);
        await tester.pumpWidget(const SizedBox());
        expect(identical(ErrorWidget.builder, original), isTrue);
      } finally {
        await tester.pumpWidget(const SizedBox());
        ErrorWidget.builder = original;
      }
    },
  );

  for (final removeInnerFirst in <bool>[true, false]) {
    testWidgets(
      'nested boundary teardown restores global builder innerFirst=$removeInnerFirst',
      (tester) async {
        final original = ErrorWidget.builder;
        final depth = ValueNotifier<int>(2);
        try {
          await tester.pumpWidget(
            MaterialApp(
              home: ValueListenableBuilder<int>(
                valueListenable: depth,
                builder: (context, value, _) => value == 0
                    ? const SizedBox()
                    : AfriErrorBoundary(
                        child: value == 2
                            ? const AfriErrorBoundary(child: SizedBox())
                            : const SizedBox(),
                      ),
              ),
            ),
          );
          if (removeInnerFirst) {
            depth.value = 1;
            await tester.pump();
            expect(identical(ErrorWidget.builder, original), isTrue);
          }
          depth.value = 0;
          await tester.pump();
          expect(identical(ErrorWidget.builder, original), isTrue);
        } finally {
          await tester.pumpWidget(const SizedBox());
          depth.dispose();
          ErrorWidget.builder = original;
        }
      },
    );
  }

  testWidgets('widget recovery never prints private error text', (
    tester,
  ) async {
    final previous = debugPrint;
    final previousBuilder = ErrorWidget.builder;
    final output = <String>[];
    debugPrint = (String? value, {int? wrapWidth}) {
      if (value != null) output.add(value);
    };
    try {
      await tester.pumpWidget(
        const MaterialApp(home: AfriErrorBoundary(child: _Failure())),
      );
      expect(tester.takeException(), isA<StateError>());
      await tester.pump();
      expect(find.text('Something went wrong'), findsOneWidget);
      expect(
        output.join('\n'),
        isNot(contains('opaque-private-framework-sentinel')),
      );
      expect(output.join('\n'), contains('runtime_failure'));
      expect(identical(ErrorWidget.builder, previousBuilder), isTrue);
    } finally {
      debugPrint = previous;
      ErrorWidget.builder = previousBuilder;
    }
  });
}
