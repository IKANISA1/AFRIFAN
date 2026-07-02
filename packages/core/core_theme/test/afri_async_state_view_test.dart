import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders resolved data', (tester) async {
    await tester.pumpWidget(
      _wrap(
        AfriAsyncStateView<int>(
          value: const AsyncValue<int>.data(7),
          data: (context, value) => Text('value $value'),
        ),
      ),
    );

    expect(find.text('value 7'), findsOneWidget);
  });

  testWidgets('renders default skeleton loading state with live semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      _wrap(
        AfriAsyncStateView<int>(
          value: const AsyncValue<int>.loading(),
          data: (context, value) => Text('$value'),
          loadingLabel: 'Loading settings',
        ),
      ),
    );

    expect(find.byType(AfriSkeletonList), findsOneWidget);
    expect(find.bySemanticsLabel('Loading settings'), findsOneWidget);

    semantics.dispose();
  });

  testWidgets('renders default error state and invokes retry action', (
    tester,
  ) async {
    var retries = 0;

    await tester.pumpWidget(
      _wrap(
        AfriAsyncStateView<int>(
          value: AsyncValue<int>.error(
            StateError('offline'),
            StackTrace.current,
          ),
          data: (context, value) => Text('$value'),
          errorTitle: 'Could not load',
          errorMessage: 'Network unavailable.',
          onRetry: () => retries += 1,
        ),
      ),
    );

    expect(find.text('Could not load'), findsOneWidget);
    expect(find.text('Network unavailable.'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    expect(retries, 1);
  });

  testWidgets('uses custom loading and error builders', (tester) async {
    await tester.pumpWidget(
      _wrap(
        AfriAsyncStateView<int>(
          value: const AsyncValue<int>.loading(),
          data: (context, value) => Text('$value'),
          loading: (_) => const Text('custom loading'),
        ),
      ),
    );

    expect(find.text('custom loading'), findsOneWidget);

    await tester.pumpWidget(
      _wrap(
        AfriAsyncStateView<int>(
          value: AsyncValue<int>.error(
            StateError('offline'),
            StackTrace.current,
          ),
          data: (context, value) => Text('$value'),
          error: (_, error, stackTrace) => Text('custom $error'),
        ),
      ),
    );

    expect(find.textContaining('custom Bad state: offline'), findsOneWidget);
  });
}

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}
