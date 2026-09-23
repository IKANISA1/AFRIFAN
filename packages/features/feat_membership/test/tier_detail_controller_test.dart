import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:feat_membership/src/providers/tier_detail_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => ConnectivityService.setOnlineForTest(true));
  tearDown(() => ConnectivityService.setOnlineForTest(true));

  test(
    'starts with the bundled official tier without claiming remote success',
    () {
      final controller = TierDetailController(
        _Gateway(),
        'gold',
        autoLoad: false,
      );
      addTearDown(controller.dispose);

      final snapshot = controller.state.value!;
      expect(snapshot.data?.slug, 'gold');
      expect(snapshot.data?.title, 'GOLD');
      expect(snapshot.phase, TierDetailPhase.ready);
      expect(
        snapshot.data?.accessItems,
        contains('Official Rayon Sports membership category list'),
      );
    },
  );

  test(
    'successful refresh replaces bundled detail with confirmed remote data',
    () async {
      final remote = _detail(title: 'GOLD REMOTE');
      final gateway = _Gateway(result: remote);
      final controller = TierDetailController(gateway, 'gold', autoLoad: false);
      addTearDown(controller.dispose);

      await controller.refresh();

      expect(gateway.calls, 1);
      expect(controller.state.value!.data?.title, 'GOLD REMOTE');
      expect(controller.state.value!.phase, TierDetailPhase.ready);
      expect(controller.state.value!.failure, isNull);
    },
  );

  test('unknown tier becomes a truthful empty result', () async {
    final controller = TierDetailController(
      _Gateway(),
      'member-secret-42',
      autoLoad: false,
    );
    addTearDown(controller.dispose);

    expect(controller.state.value!.data, isNull);
    await controller.refresh();
    expect(controller.state.value!.data, isNull);
  });

  test(
    'offline refresh retains bundled detail and does not call gateway',
    () async {
      ConnectivityService.setOnlineForTest(false);
      final gateway = _Gateway(result: _detail());
      final controller = TierDetailController(gateway, 'gold', autoLoad: false);
      addTearDown(controller.dispose);

      await controller.refresh();

      final snapshot = controller.state.value!;
      expect(gateway.calls, 0);
      expect(snapshot.data?.slug, 'gold');
      expect(snapshot.phase, TierDetailPhase.degraded);
      expect(snapshot.failure?.kind, TierDetailFailureKind.offline);
    },
  );

  test('bounded timeout retains bundled detail as degraded', () async {
    final pending = Completer<TierDetailData?>();
    addTearDown(() {
      if (!pending.isCompleted) pending.complete();
    });
    final controller = TierDetailController(
      _Gateway(pending: pending),
      'gold',
      loadTimeout: const Duration(milliseconds: 10),
      autoLoad: false,
    );
    addTearDown(controller.dispose);

    await controller.refresh();

    final snapshot = controller.state.value!;
    expect(snapshot.data?.slug, 'gold');
    expect(snapshot.phase, TierDetailPhase.degraded);
    expect(snapshot.failure?.kind, TierDetailFailureKind.securityTimeout);
  });

  test('permission failure is typed and retains official content', () async {
    final controller = TierDetailController(
      _Gateway(error: StateError('row-level security secret-table-42')),
      'gold',
      autoLoad: false,
    );
    addTearDown(controller.dispose);

    await controller.refresh();

    final snapshot = controller.state.value!;
    expect(snapshot.data?.slug, 'gold');
    expect(snapshot.phase, TierDetailPhase.degraded);
    expect(snapshot.failure?.kind, TierDetailFailureKind.permissionDenied);
    expect(snapshot.failure.toString(), isNot(contains('secret-table-42')));
  });

  test('overlapping refreshes coalesce to one gateway read', () async {
    final pending = Completer<TierDetailData?>();
    final gateway = _Gateway(pending: pending);
    final controller = TierDetailController(gateway, 'gold', autoLoad: false);
    addTearDown(controller.dispose);

    final first = controller.refresh();
    final second = controller.refresh();
    await Future<void>.delayed(Duration.zero);
    expect(gateway.calls, 1);
    pending.complete(_detail(title: 'GOLD CONFIRMED'));
    await Future.wait([first, second]);

    expect(controller.state.value!.data?.title, 'GOLD CONFIRMED');
  });

  test('reconnect refreshes only an offline-degraded state', () async {
    ConnectivityService.setOnlineForTest(false);
    final gateway = _Gateway(result: _detail(title: 'GOLD CONFIRMED'));
    final controller = TierDetailController(gateway, 'gold', autoLoad: false);
    addTearDown(controller.dispose);

    await controller.refresh();
    expect(gateway.calls, 0);
    ConnectivityService.setOnlineForTest(true);
    await controller.connectionRestored();

    expect(gateway.calls, 1);
    expect(controller.state.value!.data?.title, 'GOLD CONFIRMED');
    expect(controller.state.value!.failure, isNull);
  });

  test('failure sanitizer never exposes raw service diagnostics', () {
    final failure = TierDetailFailure.fromError(
      Exception('postgres secret.membership_tiers trace member-4482'),
    );

    expect(failure.kind, TierDetailFailureKind.unknown);
    expect(failure.toString(), 'TierDetailFailure(unknown)');
    expect(failure.toString(), isNot(contains('4482')));
  });
}

TierDetailData _detail({String title = 'GOLD'}) {
  final bundled = TierDetailData.fromOfficialSlug('gold');
  return TierDetailData(
    slug: bundled.slug,
    title: title,
    subtitle: bundled.subtitle,
    description: bundled.description,
    benefits: bundled.benefits,
    priceLabel: bundled.priceLabel,
    accessItems: bundled.accessItems,
    icon: bundled.icon,
  );
}

class _Gateway implements TierDetailGateway {
  _Gateway({this.result, this.error, this.pending});

  final TierDetailData? result;
  final Object? error;
  final Completer<TierDetailData?>? pending;
  int calls = 0;

  @override
  Future<TierDetailData?> load(String tierId) async {
    calls += 1;
    if (error case final error?) throw error;
    if (pending case final pending?) return pending.future;
    return result;
  }
}
