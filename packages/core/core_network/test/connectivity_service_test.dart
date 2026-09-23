import 'package:core_network/core_network.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ConnectivityService', () {
    test('offline QA override is compile-time and fail-closed', () {
      const requested = bool.fromEnvironment('AFRICLUB_QA_FORCE_OFFLINE');

      expect(ConnectivityService.qaOfflineOverrideActive, requested);

      if (requested) {
        ConnectivityService.setOnlineForTest(true);
        expect(ConnectivityService.isOnline, isFalse);
        expect(ConnectivityService.onlineNotifier.value, isFalse);
      }
    });

    setUp(() {
      // Reset to known state before each test.
      ConnectivityService.setOnlineForTest(true);
    });

    tearDown(() async {
      await ConnectivityService.dispose();
    });

    group('initial state', () {
      test('defaults to online (optimistic assumption)', () {
        expect(ConnectivityService.isOnline, isTrue);
      });

      test('onlineNotifier defaults to true', () {
        expect(ConnectivityService.onlineNotifier.value, isTrue);
      });
    });

    group('setOnlineForTest', () {
      test('sets isOnline to false', () {
        ConnectivityService.setOnlineForTest(false);
        expect(ConnectivityService.isOnline, isFalse);
        expect(ConnectivityService.onlineNotifier.value, isFalse);
      });

      test('sets isOnline to true after being false', () {
        ConnectivityService.setOnlineForTest(false);
        expect(ConnectivityService.isOnline, isFalse);

        ConnectivityService.setOnlineForTest(true);
        expect(ConnectivityService.isOnline, isTrue);
        expect(ConnectivityService.onlineNotifier.value, isTrue);
      });
    });

    group('onlineNotifier', () {
      test('notifies listeners on state change', () {
        final transitions = <bool>[];
        ConnectivityService.onlineNotifier.addListener(() {
          transitions.add(ConnectivityService.onlineNotifier.value);
        });

        ConnectivityService.setOnlineForTest(false);
        ConnectivityService.setOnlineForTest(true);
        ConnectivityService.setOnlineForTest(false);

        expect(transitions, equals(<bool>[false, true, false]));

        // Cleanup.
        ConnectivityService.onlineNotifier.removeListener(
          () {},
        ); // no-op, but tests won't leak.
      });
    });

    group('dispose', () {
      test('can be called without error when not initialized', () async {
        await expectLater(ConnectivityService.dispose(), completes);
      });

      test('can be called multiple times safely', () async {
        await ConnectivityService.dispose();
        await expectLater(ConnectivityService.dispose(), completes);
      });
    });
  });
}
