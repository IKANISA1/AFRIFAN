import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:feat_gamification/src/models/prediction_models.dart';
import 'package:feat_gamification/src/providers/fanzone_hub_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => ConnectivityService.setOnlineForTest(true));

  test('retains Fan Zone data and refreshes it after reconnect', () async {
    final reconnected = Completer<FanzoneHubSnapshot>();
    var calls = 0;
    final container = ProviderContainer(
      overrides: [
        fanzoneHubProvider.overrideWith(
          () => FanzoneHubNotifier(
            loadOverride: () {
              calls += 1;
              if (calls == 1) {
                return Future.value(_snapshot(totalPredictions: 12));
              }
              return reconnected.future;
            },
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(fanzoneHubProvider.future);
    ConnectivityService.setOnlineForTest(false);

    final stale = container.read(fanzoneHubProvider).valueOrNull;
    expect(stale?.dashboard?.totalPredictions, 12);
    expect(stale?.status, FanzoneHubStatus.degraded);
    expect(stale?.message, contains('Showing saved Fan Zone content'));

    ConnectivityService.setOnlineForTest(true);
    await Future<void>.delayed(Duration.zero);

    expect(calls, 2);
    expect(container.read(fanzoneHubProvider).isRefreshing, isTrue);
    expect(
      container
          .read(fanzoneHubProvider)
          .valueOrNull
          ?.dashboard
          ?.totalPredictions,
      12,
    );

    reconnected.complete(_snapshot(totalPredictions: 18));
    await Future<void>.delayed(Duration.zero);

    expect(
      container
          .read(fanzoneHubProvider)
          .valueOrNull
          ?.dashboard
          ?.totalPredictions,
      18,
    );
    expect(
      container.read(fanzoneHubProvider).valueOrNull?.status,
      FanzoneHubStatus.ok,
    );
  });
}

FanzoneHubSnapshot _snapshot({required int totalPredictions}) {
  return FanzoneHubSnapshot(
    dashboard: PredictionDashboard(
      totalPredictions: totalPredictions,
      settledCount: 8,
      wonCount: 5,
      lostCount: 3,
      activeCount: 4,
      totalFetEarned: 240,
      currentStreak: 3,
      winRate: 62.5,
    ),
  );
}
