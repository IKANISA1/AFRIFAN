// Standalone Dart harness. Run through verify_native_membership.py, not as Flutter QA.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:feat_membership/native_membership.dart';

int passed = 0, failed = 0;
Future<void> check(String name, Future<void> Function() body) async {
  try {
    await body();
    passed++;
    stdout.writeln('PASS $name');
  } catch (e) {
    failed++;
    stderr.writeln('FAIL $name: $e');
  }
}

void expect(bool ok) {
  if (!ok) throw StateError('assertion failed');
}

Future<void> failure(Future<dynamic> Function() body) async {
  bool rejected = false;
  try {
    await body();
  } catch (_) {
    rejected = true;
  }
  expect(rejected);
}

// Test doubles only. In-memory recovery is forbidden in a shipped app.
final class MemoryStore implements NativeRecoveryStore {
  final values = <String, String>{};
  final tails = <String, Future<void>>{};
  bool fail = false;
  @override
  Future<T> runExclusive<T>(String key, Future<T> Function() work) async {
    final prior = tails[key] ?? Future<void>.value();
    final done = Completer<void>();
    tails[key] = done.future;
    await prior;
    try {
      return await work();
    } finally {
      done.complete();
    }
  }

  @override
  Future<String?> load(String key) async => values[key];
  @override
  Future<bool> compareAndSet(String key, String? old, String next) async {
    if (fail) return false;
    if (values[key] != old) return false;
    values[key] = next;
    return true;
  }
}

final class FakeApi implements NativeMembershipApi {
  @override
  Future<ServerHandoffStatus> releaseHandoff(
    MembershipSession actor,
    String handoffId,
    String requestId,
  ) async {
    releasePosts++;
    previousReleaseKey ??= requestId;
    expect(previousReleaseKey == requestId);
    final m = marker;
    requireContract(
      m != null &&
          m.handoffId == handoffId &&
          m.claimedAt == null &&
          ['reserved', 'released'].contains(m.phase),
      'handoff_not_releasable',
    );
    final current = m!;
    marker = ServerPaymentHandoff(
      current.handoffId,
      current.orderId,
      current.clubId,
      'released',
      current.createdAt,
      null,
      current.orderExpiresAt,
      current.observedAt,
      false,
    );
    if (releaseLost) {
      releaseLost = false;
      throw const NativeMembershipException(
        'handoff_outcome_unknown',
        RequestOutcome.unknown,
      );
    }
    return ServerHandoffStatus(marker, false);
  }

  FakeApi(this.actor, this.status);
  MembershipSession actor;
  CurrentCheckout status;
  int posts = 0;
  bool lost = false;
  String? previousKey;
  ServerPaymentHandoff? marker;
  bool claimLost = false, reserveLost = false, releaseLost = false;
  int journalPosts = 0, releasePosts = 0;
  String? previousReleaseKey;
  @override
  Future<ServerHandoffStatus> handoffCurrent(MembershipSession actor) async =>
      ServerHandoffStatus(marker, false);
  @override
  Future<ServerHandoffStatus> reserveHandoff(
    MembershipSession actor,
    String orderId,
    String key,
  ) async {
    journalPosts++;
    if (marker?.phase == 'released') marker = null;
    marker ??= ServerPaymentHandoff(
      newOperationId(),
      orderId,
      actor.clubId,
      'reserved',
      status.observedAt,
      null,
      status.expiresAt,
      status.observedAt,
      false,
    );
    if (reserveLost) {
      reserveLost = false;
      throw const NativeMembershipException(
        'handoff_outcome_unknown',
        RequestOutcome.unknown,
      );
    }
    return ServerHandoffStatus(marker, false);
  }

  @override
  Future<ServerHandoffStatus> claimHandoff(
    MembershipSession actor,
    String handoffId,
    String key,
  ) async {
    journalPosts++;
    final m = marker!;
    requireContract(m.phase != 'released', 'handoff_released');
    if (m.claimedAt != null) return ServerHandoffStatus(m, false);
    marker = ServerPaymentHandoff(
      m.handoffId,
      m.orderId,
      m.clubId,
      'claimed',
      m.createdAt,
      status.observedAt,
      m.orderExpiresAt,
      status.observedAt,
      false,
    );
    if (claimLost) {
      throw const NativeMembershipException(
        'handoff_outcome_unknown',
        RequestOutcome.unknown,
      );
    }
    return ServerHandoffStatus(marker, true);
  }

  @override
  Future<MembershipSession> session() async => actor;
  @override
  Future<CurrentCheckout> read(MembershipSession actor, String orderId) async =>
      status;
  @override
  Future<PreparedCheckout> prepare(
    MembershipSession actor,
    String key,
    String tier,
  ) async {
    posts++;
    previousKey ??= key;
    expect(previousKey == key);
    if (lost) {
      lost = false;
      throw const NativeMembershipException(
        'checkout_outcome_unknown',
        RequestOutcome.unknown,
      );
    }
    return PreparedCheckout(key, actor.clubId, status.orderId, tier, false);
  }

  @override
  Future<HistoricalMembershipReceipt> receipt(
    MembershipSession actor,
    String orderId,
  ) async => throw UnimplementedError();
}

final class FakeDialer implements MembershipDialer {
  int opens = 0;
  bool unknown = false;
  @override
  Future<bool> open(String code) async {
    opens++;
    if (unknown) throw StateError('synthetic platform timeout');
    return true;
  }
}

Future<void> main(List<String> args) async {
  final root = Uri.base.resolve('test/native_checkout/wire-vectors.json');
  final fixture =
          jsonDecode(await File.fromUri(root).readAsString())
              as Map<String, dynamic>,
      e = fixture['expected'] as Map<String, dynamic>;
  final actor = MembershipSession(
    e['userId'] as String,
    e['clubId'] as int,
    e['sessionId'] as String,
  );
  for (final raw in fixture['vectors'] as List) {
    final v = raw as Map<String, dynamic>;
    await check('wire ${v['name']}', () async {
      bool accepted = true;
      try {
        switch (v['kind']) {
          case 'session':
            MembershipSession.parse(v['body'], actor.clubId);
            break;
          case 'prepared':
            PreparedCheckout.parse(
              v['body'],
              actor.clubId,
              e['requestId'] as String,
              e['tier'] as String,
            );
            break;
          case 'status':
            CurrentCheckout.parse(
              v['body'],
              actor.clubId,
              e['orderId'] as String,
            );
            break;
          case 'receipt':
            HistoricalMembershipReceipt.parse(
              v['body'],
              actor.clubId,
              e['orderId'] as String,
            );
            break;
          default:
            throw StateError('unknown vector');
        }
      } catch (_) {
        accepted = false;
      }
      expect(accepted == v['accept']);
    });
  }
  final valid =
      (fixture['vectors'] as List).firstWhere(
            (dynamic v) => v['name'] == 'status:valid',
          )
          as Map<String, dynamic>;
  CurrentCheckout status() => CurrentCheckout.parse(
    valid['body'],
    actor.clubId,
    e['orderId'] as String,
  );
  await check('UUID is random canonical version 4', () async {
    final ids = List.generate(100, (_) => newOperationId());
    expect(ids.toSet().length == 100 && ids.every(isUuid));
  });
  await check('disabled coordinator makes no POST', () async {
    final api = FakeApi(actor, status());
    await failure(
      () => NativeCheckoutCoordinator(api, MemoryStore()).begin('gold'),
    );
    expect(api.posts == 0);
  });
  await check('persist before POST and explicit same-key recovery', () async {
    final api = FakeApi(actor, status())..lost = true,
        store = MemoryStore(),
        flow = NativeCheckoutCoordinator(api, store, enabled: true);
    await failure(() => flow.begin('gold'));
    expect(api.posts == 1);
    expect((await flow.restore())!.pending);
    expect(api.posts == 1);
    await failure(() => flow.begin('silver'));
    expect(api.posts == 1);
    await flow.resume();
    expect(api.posts == 2);
    expect(!(await flow.restore())!.pending);
  });
  await check('failed persistence prevents POST', () async {
    final api = FakeApi(actor, status()), store = MemoryStore()..fail = true;
    await failure(
      () => NativeCheckoutCoordinator(api, store, enabled: true).begin('gold'),
    );
    expect(api.posts == 0);
  });
  await check('handoff requires a separate confirmation', () async {
    final api = FakeApi(actor, status()),
        d = FakeDialer(),
        flow = NativePaymentHandoff(api, MemoryStore(), d, enabled: true);
    final q = await flow.review(api.status.orderId);
    expect(d.opens == 0);
    await failure(() => flow.confirm(q.reviewId, acknowledgement: false));
    expect(d.opens == 0);
    final result = await flow.confirm(q.reviewId, acknowledgement: true);
    expect(
      result.platformOpened == true &&
          !result.paymentVerified &&
          api.posts == 0,
    );
    await failure(() => flow.confirm(q.reviewId, acknowledgement: true));
    expect(d.opens == 1);
  });
  await check('unknown handoff is never replayed by recovery', () async {
    final api = FakeApi(actor, status()),
        d = FakeDialer()..unknown = true,
        store = MemoryStore(),
        flow = NativePaymentHandoff(api, store, d, enabled: true);
    final q = await flow.review(api.status.orderId);
    expect(
      (await flow.confirm(q.reviewId, acknowledgement: true)).platformOpened ==
          null,
    );
    expect((await flow.recover())!.attempt?.phase == 'unknown');
    await failure(() => flow.review(api.status.orderId));
    expect(d.opens == 1);
  });
  await check('background invalidates review', () async {
    final api = FakeApi(actor, status()),
        d = FakeDialer(),
        flow = NativePaymentHandoff(api, MemoryStore(), d, enabled: true);
    final q = await flow.review(api.status.orderId);
    flow.invalidateReview();
    await failure(() => flow.confirm(q.reviewId, acknowledgement: true));
    expect(d.opens == 0);
  });
  await check('review time window uses monotonic clock', () async {
    var now = 0;
    final api = FakeApi(actor, status()),
        d = FakeDialer(),
        flow = NativePaymentHandoff(
          api,
          MemoryStore(),
          d,
          enabled: true,
          monotonicNow: () => now,
        );
    final q = await flow.review(api.status.orderId);
    now = 30001;
    await failure(() => flow.confirm(q.reviewId, acknowledgement: true));
    expect(d.opens == 0);
  });
  await check('tel URI preserves hash in path not fragment', () async {
    final code = status().instruction!.ussdCode,
        u = Uri(scheme: 'tel', path: code);
    expect(
      Uri.decodeComponent(u.path) == code &&
          !u.hasFragment &&
          !u.hasQuery &&
          u.toString().contains('%23'),
    );
  });
  await check('server marker survives new empty local store', () async {
    final api = FakeApi(actor, status()),
        d = FakeDialer(),
        flow = NativePaymentHandoff(api, MemoryStore(), d, enabled: true);
    final q = await flow.review(api.status.orderId);
    await flow.confirm(q.reviewId, acknowledgement: true);
    final restarted = NativePaymentHandoff(
      api,
      MemoryStore(),
      d,
      enabled: true,
    );
    expect((await restarted.recover())!.attempt == null);
    await failure(() => restarted.review(api.status.orderId));
    expect(d.opens == 1);
  });
  await check('lost server claim response never opens dialer', () async {
    final api = FakeApi(actor, status())..claimLost = true,
        d = FakeDialer(),
        flow = NativePaymentHandoff(api, MemoryStore(), d, enabled: true);
    final q = await flow.review(api.status.orderId);
    await failure(() => flow.confirm(q.reviewId, acknowledgement: true));
    expect(d.opens == 0 && api.marker?.phase == 'claimed');
    await failure(
      () => NativePaymentHandoff(
        api,
        MemoryStore(),
        d,
        enabled: true,
      ).review(api.status.orderId),
    );
  });
  await check('server status rejects a grant from read operation', () async {
    await failure(
      () async => ServerHandoffStatus.parse({
        'schemaVersion': 1,
        'handoff': null,
        'mayOpenDialer': true,
      }, actor.clubId),
    );
  });
  await check(
    'unclaimed server reservation is released only by explicit action',
    () async {
      final api = FakeApi(actor, status())..reserveLost = true,
          d = FakeDialer(),
          store = MemoryStore(),
          flow = NativePaymentHandoff(api, store, d, enabled: true);
      final q = await flow.review(api.status.orderId);
      await failure(() => flow.confirm(q.reviewId, acknowledgement: true));
      final id = api.marker!.handoffId;
      await flow.recover();
      expect(api.releasePosts == 0 && d.opens == 0);
      await failure(() => flow.releaseUnclaimed(id, acknowledgement: false));
      expect(api.releasePosts == 0);
      final r = await flow.releaseUnclaimed(id, acknowledgement: true);
      expect(
        r.handoff!.phase == 'released' && !r.mayOpenDialer && d.opens == 0,
      );
      expect(
        HandoffAttempt.decode(store.values.values.first, actor)!.phase ==
            'not_opened',
      );
    },
  );
  await check(
    'lost unclaimed-release reply retains exact original key',
    () async {
      final api = FakeApi(actor, status())
            ..reserveLost = true
            ..releaseLost = true,
          d = FakeDialer(),
          store = MemoryStore(),
          flow = NativePaymentHandoff(api, store, d, enabled: true);
      final q = await flow.review(api.status.orderId);
      await failure(() => flow.confirm(q.reviewId, acknowledgement: true));
      final id = api.marker!.handoffId;
      await failure(() => flow.releaseUnclaimed(id, acknowledgement: true));
      await flow.releaseUnclaimed(id, acknowledgement: true);
      expect(
        api.previousReleaseKey == id && api.releasePosts == 2 && d.opens == 0,
      );
    },
  );
  await check(
    'claimed uncertain operation cannot be reset by release',
    () async {
      final api = FakeApi(actor, status())..claimLost = true,
          d = FakeDialer(),
          flow = NativePaymentHandoff(api, MemoryStore(), d, enabled: true);
      final q = await flow.review(api.status.orderId);
      await failure(() => flow.confirm(q.reviewId, acknowledgement: true));
      await failure(
        () =>
            flow.releaseUnclaimed(api.marker!.handoffId, acknowledgement: true),
      );
      expect(api.releasePosts == 0 && d.opens == 0);
    },
  );
  stdout.writeln(
    jsonEncode({
      'dartChecksPassed': passed,
      'dartChecksFailed': failed,
      'providerRequests': 0,
      'platformDialerTested': false,
    }),
  );
  if (failed > 0) exitCode = 1;
}
