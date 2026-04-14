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
      await expectLater(
        CrashlyticsService.setUserId('user123'),
        completes,
      );
    });

    test('log does not throw when not initialized', () async {
      await expectLater(
        CrashlyticsService.log('test message'),
        completes,
      );
    });
  });
}
