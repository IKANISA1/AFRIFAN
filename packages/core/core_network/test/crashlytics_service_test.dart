import 'package:core_network/core_network.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CrashlyticsService', () {
    test('isInitialized is false before initialize()', () {
      expect(CrashlyticsService.isInitialized, isFalse);
    });

    test('recordError does not throw when not initialized', () async {
      // Should be a safe no-op when Crashlytics is not initialized.
      await expectLater(
        CrashlyticsService.recordError(
          Exception('test'),
          StackTrace.current,
          reason: 'test',
        ),
        completes,
      );
    });

    test('setUserId does not throw when not initialized', () async {
      await expectLater(CrashlyticsService.setUserId('user123'), completes);
    });

    test('diagnostic messages accept only closed diagnostic codes', () {
      expect(
        CrashlyticsService.sanitizeDiagnosticMessage(
          'upload_queue: retried=428 uploaded=12',
        ),
        isNull,
      );
      expect(
        CrashlyticsService.sanitizeDiagnosticMessage('runtime_error'),
        'runtime_error',
      );
      expect(
        CrashlyticsService.sanitizeDiagnosticMessage(
          'opaque_private_supporter_alias',
        ),
        isNull,
      );
      expect(
        CrashlyticsService.sanitizeDiagnosticMessage(
          'user_id=68f04526-df12-4ec0-847b-af8df86bf432',
        ),
        isNull,
      );
      expect(
        CrashlyticsService.sanitizeDiagnosticMessage(
          'contact support@example.com',
        ),
        isNull,
      );
      expect(
        CrashlyticsService.sanitizeDiagnosticMessage(
          'https://example.com/private/path',
        ),
        isNull,
      );
    });

    test('log does not throw when not initialized', () async {
      await expectLater(CrashlyticsService.log('test message'), completes);
    });
  });
}
