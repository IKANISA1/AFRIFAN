import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:feat_membership/src/providers/membership_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => ConnectivityService.setOnlineForTest(true));

  test('retains membership data and refreshes it after reconnect', () async {
    final reconnected = Completer<MembershipSnapshot>();
    var calls = 0;
    final container = ProviderContainer(
      overrides: [
        membershipProvider.overrideWith(
          () => MembershipNotifier(
            loadOverride: () {
              calls += 1;
              if (calls == 1) {
                return Future.value(_snapshot('Imena'));
              }
              return reconnected.future;
            },
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(membershipProvider.future);
    ConnectivityService.setOnlineForTest(false);

    final stale = container.read(membershipProvider).valueOrNull;
    expect(stale?.packages.single['title'], 'Imena');
    expect(stale?.isStale, isTrue);
    expect(stale?.recoveryMessage, contains('Showing saved membership'));

    ConnectivityService.setOnlineForTest(true);
    await Future<void>.delayed(Duration.zero);

    expect(calls, 2);
    expect(container.read(membershipProvider).isRefreshing, isTrue);
    expect(
      container.read(membershipProvider).valueOrNull?.packages.single['title'],
      'Imena',
    );

    reconnected.complete(_snapshot('Inyamibwa'));
    await Future<void>.delayed(Duration.zero);

    final current = container.read(membershipProvider).valueOrNull;
    expect(current?.packages.single['title'], 'Inyamibwa');
    expect(current?.isStale, isFalse);
  });
}

MembershipSnapshot _snapshot(String title) {
  return MembershipSnapshot(
    packages: [
      {'tier': 'imena', 'title': title},
    ],
    membership: null,
    applications: const [],
    contributions: const [],
  );
}
