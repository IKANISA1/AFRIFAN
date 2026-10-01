import 'package:core_utils/core_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

class _PrivateError {
  @override
  String toString() => throw StateError('private error must never be rendered');
}

void main() {
  final output = <String>[];
  late DebugPrintCallback previous;

  setUp(() {
    output.clear();
    previous = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) output.add(message);
    };
  });
  tearDown(() => debugPrint = previous);

  final payloads = <String>[
    'access_token=sentinel-private-token refresh_token=sentinel-refresh',
    'Authorization: Bearer sentinel-credential',
    'supporter.private@example.invalid +250788123456',
    'https://example.invalid/recover?code=sentinel-otp#sentinel-fragment',
    'customer=Jean Private invoice=INV-private-2045',
    'opaque-secret-with-no-recognizable-sensitive-pattern',
  ];
  for (final severity in ['info', 'warn', 'error']) {
    for (var i = 0; i < payloads.length; i++) {
      test('$severity discards private message payload $i', () {
        switch (severity) {
          case 'info':
            AfriLogger.info('AuthRepository', payloads[i]);
          case 'warn':
            AfriLogger.warn('AuthRepository', payloads[i]);
          case 'error':
            AfriLogger.error('AuthRepository', payloads[i]);
        }
        expect(output, isNotEmpty);
        expect(output.join('\n'), isNot(contains(payloads[i])));
        expect(output.join('\n'), isNot(contains('sentinel')));
      });
    }
  }

  test('private component names cannot create diagnostic labels', () {
    AfriLogger.error('private-account-2045@example.invalid', 'Failed');
    expect(output.join('\n'), isNot(contains('private-account')));
  });

  test('error contents and supplied stack paths are never forwarded', () {
    AfriLogger.error(
      'AuthRepository',
      'Token refresh failed',
      StateError('sentinel-private-error'),
      StackTrace.fromString('/Users/private/supporter/sentinel-stack'),
    );
    expect(output.join('\n'), isNot(contains('sentinel')));
    expect(output.join('\n'), contains('state'));
  });

  test('logging never invokes an unknown error renderer', () {
    expect(
      () => AfriLogger.warn('AuthRepository', 'Failure', _PrivateError()),
      returnsNormally,
    );
  });

  test('finite severity and known component retain diagnostic context', () {
    AfriLogger.error(
      'AuthRepository',
      'Failure',
      const FormatException('secret'),
    );
    expect(output.join('\n'), contains('AuthRepository'));
    expect(output.join('\n'), contains('format'));
    expect(output.join('\n'), isNot(contains('secret')));
  });

  test(
    'framework console receives finite details without private callbacks',
    () {
      var collectorInvoked = false;
      final original = FlutterErrorDetails(
        exception: StateError('opaque-private-framework-error'),
        stack: StackTrace.fromString('/Users/private/opaque-private-stack'),
        library: 'opaque-private-library',
        context: ErrorDescription('opaque-private-context'),
        informationCollector: () {
          collectorInvoked = true;
          return <DiagnosticsNode>[
            ErrorDescription('opaque-private-information'),
          ];
        },
      );
      final safe = AfriLogger.frameworkErrorDetails(original);
      FlutterError.dumpErrorToConsole(safe, forceReport: true);
      expect(collectorInvoked, isFalse);
      expect(output.join('\n'), isNot(contains('opaque-private')));
      expect(output.join('\n'), contains('native_framework_failure:state'));
    },
  );

  test('framework diagnostics never render an unknown error', () {
    final safe = AfriLogger.frameworkErrorDetails(
      FlutterErrorDetails(exception: _PrivateError(), silent: true),
    );
    expect(
      safe.exception.toString(),
      contains('native_framework_failure:failure'),
    );
    expect(safe.silent, isTrue);
    expect(safe.informationCollector, isNull);
    expect(safe.stackFilter, isNull);
  });
}
