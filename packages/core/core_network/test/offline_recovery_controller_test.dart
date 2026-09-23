import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OfflineRecoveryController', () {
    test('does not call the network when initially offline', () async {
      final connectivity = ValueNotifier<bool>(false);
      var calls = 0;
      final controller = OfflineRecoveryController<String>(
        connectivity: connectivity,
        load: () async {
          calls += 1;
          return 'live';
        },
      );
      addTearDown(controller.dispose);
      addTearDown(connectivity.dispose);

      await controller.start();

      expect(calls, 0);
      expect(controller.data, isNull);
      expect(controller.phase, OfflineRecoveryPhase.offline);
      expect(controller.networkActionsEnabled, isFalse);
    });

    test('keeps cached data visible throughout a slow refresh', () async {
      final connectivity = ValueNotifier<bool>(true);
      final pending = Completer<String>();
      final controller = OfflineRecoveryController<String>(
        connectivity: connectivity,
        initialData: 'cached',
        load: () => pending.future,
      );
      addTearDown(controller.dispose);
      addTearDown(connectivity.dispose);

      final refresh = controller.refresh();

      expect(controller.data, 'cached');
      expect(controller.phase, OfflineRecoveryPhase.refreshing);
      pending.complete('current');
      await refresh;

      expect(controller.data, 'current');
      expect(controller.phase, OfflineRecoveryPhase.fresh);
      expect(controller.lastSyncedAt, isNotNull);
    });

    test('labels cached data stale after a refresh failure', () async {
      final connectivity = ValueNotifier<bool>(true);
      final controller = OfflineRecoveryController<String>(
        connectivity: connectivity,
        initialData: 'cached',
        load: () async => throw StateError('timeout'),
      );
      addTearDown(controller.dispose);
      addTearDown(connectivity.dispose);

      await controller.refresh();

      expect(controller.data, 'cached');
      expect(controller.phase, OfflineRecoveryPhase.stale);
      expect(controller.lastError, isA<StateError>());
    });

    test('automatically refreshes retained data after reconnect', () async {
      final connectivity = ValueNotifier<bool>(false);
      final loaded = Completer<String>();
      var calls = 0;
      final controller = OfflineRecoveryController<String>(
        connectivity: connectivity,
        initialData: 'cached',
        load: () {
          calls += 1;
          return loaded.future;
        },
      );
      addTearDown(controller.dispose);
      addTearDown(connectivity.dispose);

      await controller.start();
      expect(controller.phase, OfflineRecoveryPhase.stale);
      expect(calls, 0);

      connectivity.value = true;
      await Future<void>.delayed(Duration.zero);

      expect(calls, 1);
      expect(controller.data, 'cached');
      expect(controller.phase, OfflineRecoveryPhase.refreshing);

      loaded.complete('reconnected');
      await Future<void>.delayed(Duration.zero);
      expect(controller.data, 'reconnected');
      expect(controller.phase, OfflineRecoveryPhase.fresh);
    });

    test('coalesces duplicate refresh requests', () async {
      final connectivity = ValueNotifier<bool>(true);
      final pending = Completer<String>();
      var calls = 0;
      final controller = OfflineRecoveryController<String>(
        connectivity: connectivity,
        load: () {
          calls += 1;
          return pending.future;
        },
      );
      addTearDown(controller.dispose);
      addTearDown(connectivity.dispose);

      final first = controller.refresh();
      final second = controller.refresh();
      expect(calls, 1);

      pending.complete('current');
      await Future.wait([first, second]);
      expect(controller.data, 'current');
    });
  });
}
