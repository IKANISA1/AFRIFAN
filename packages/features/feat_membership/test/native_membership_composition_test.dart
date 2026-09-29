import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:feat_membership/native_membership_composition_flutter.dart';
import 'package:feat_membership/native_membership_storage_flutter.dart';
import 'package:feat_membership/native_membership_storage_ios.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'native_checkout/contract_harness.dart' as contracts;
import 'native_checkout/platform_recovery_harness.dart' as recovery;

const user = '20000000-0000-4000-8000-000000000001';
const session = '20000000-0000-4000-8000-000000000002';
const rotated = '20000000-0000-4000-8000-000000000003';
const actor = MembershipSession(user, 24, session);
const scope = 'africlub-membership-v1:24:$user';

final class ControlledApi implements NativeMembershipApi {
  ControlledApi(CurrentCheckout status)
    : delegate = contracts.FakeApi(actor, status);
  final contracts.FakeApi delegate;
  int sessionReads = 0;
  int? failSessionRead;
  Completer<PreparedCheckout>? reply;
  Completer<void>? sent;
  @override
  Future<MembershipSession> session() async {
    sessionReads++;
    if (sessionReads == failSessionRead) throw StateError('identity read lost');
    return delegate.actor;
  }

  @override
  Future<PreparedCheckout> prepare(
    MembershipSession actor,
    String key,
    String tier,
  ) async {
    final result = await delegate.prepare(actor, key, tier);
    if (sent != null && !sent!.isCompleted) sent!.complete();
    return reply == null ? result : reply!.future;
  }

  @override
  Future<CurrentCheckout> read(MembershipSession actor, String orderId) =>
      delegate.read(actor, orderId);
  @override
  Future<ServerHandoffStatus> handoffCurrent(MembershipSession actor) =>
      delegate.handoffCurrent(actor);
  @override
  Future<ServerHandoffStatus> reserveHandoff(
    MembershipSession actor,
    String orderId,
    String requestId,
  ) => delegate.reserveHandoff(actor, orderId, requestId);
  @override
  Future<ServerHandoffStatus> releaseHandoff(
    MembershipSession actor,
    String handoffId,
    String requestId,
  ) => delegate.releaseHandoff(actor, handoffId, requestId);
  @override
  Future<ServerHandoffStatus> claimHandoff(
    MembershipSession actor,
    String handoffId,
    String requestId,
  ) => delegate.claimHandoff(actor, handoffId, requestId);
  @override
  Future<HistoricalMembershipReceipt> receipt(
    MembershipSession actor,
    String orderId,
  ) => delegate.receipt(actor, orderId);
}

Matcher unknownReply = isA<NativeMembershipException>().having(
  (e) => e.outcome,
  'outcome',
  RequestOutcome.unknown,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final fixture =
      jsonDecode(
            File(
              Directory('test/native_checkout').existsSync()
                  ? 'test/native_checkout/wire-vectors.json'
                  : 'packages/features/feat_membership/test/native_checkout/wire-vectors.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final expected = fixture['expected'] as Map<String, dynamic>;
  final valid =
      (fixture['vectors'] as List).firstWhere(
            (dynamic row) => row['name'] == 'status:valid',
          )
          as Map<String, dynamic>;
  final status = CurrentCheckout.parse(
    valid['body'],
    24,
    expected['orderId'] as String,
  );
  NativeMembershipComposition compose(
    ControlledApi api,
    recovery.FakeChannel channel, {
    bool enabled = true,
    contracts.FakeDialer? dialer,
  }) => NativeMembershipComposition(
    api: api,
    clubId: 24,
    channel: channel,
    dialer: dialer ?? contracts.FakeDialer(),
    enabled: enabled,
  );

  test(
    'default disabled composition initializes safely on unsupported platform',
    () async {
      final api = ControlledApi(status);
      final composition = NativeMembershipComposition(api: api, clubId: 24);
      addTearDown(composition.dispose);
      await expectLater(
        composition.checkout.restore(),
        throwsA(isA<NativeMembershipException>()),
      );
      expect(api.sessionReads, 0);
    },
  );
  test('disabled composition makes no API, storage or dialer call', () async {
    final api = ControlledApi(status),
        channel = recovery.FakeChannel(),
        dialer = contracts.FakeDialer();
    final composition = compose(api, channel, enabled: false, dialer: dialer);
    addTearDown(composition.dispose);
    await expectLater(
      composition.checkout.begin('gold'),
      throwsA(isA<NativeMembershipException>()),
    );
    expect(api.sessionReads, 0);
    expect(channel.acquisitions, 0);
    expect(dialer.opens, 0);
  });
  test(
    'wrong club is rejected before acquiring storage or sending checkout',
    () async {
      final api = ControlledApi(status)
        ..delegate.actor = const MembershipSession(user, 25, session);
      final channel = recovery.FakeChannel(),
          composition = compose(api, channel);
      addTearDown(composition.dispose);
      await expectLater(
        composition.checkout.begin('gold'),
        throwsA(isA<NativeMembershipException>()),
      );
      expect(api.delegate.posts, 0);
      expect(channel.acquisitions, 0);
    },
  );
  test('background and resume never submit or open external apps', () async {
    final api = ControlledApi(status),
        channel = recovery.FakeChannel(),
        dialer = contracts.FakeDialer();
    final composition = compose(api, channel, dialer: dialer);
    addTearDown(composition.dispose);
    composition.didChangeAppLifecycleState(AppLifecycleState.paused);
    await expectLater(
      composition.checkout.begin('gold'),
      throwsA(isA<NativeMembershipException>()),
    );
    composition.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(api.sessionReads, 0);
    expect(channel.acquisitions, 0);
    expect(dialer.opens, 0);
  });
  test(
    'lost identity recheck after committed checkout is unknown and retains key',
    () async {
      final api = ControlledApi(status)..failSessionRead = 3;
      final channel = recovery.FakeChannel(),
          composition = compose(api, channel);
      addTearDown(composition.dispose);
      await expectLater(
        composition.checkout.begin('gold'),
        throwsA(unknownReply),
      );
      expect(api.delegate.posts, 1);
      // Use the composition's actual channel to prove the unresolved marker survives.
      final actualChannel = channel;
      final marker = PendingNativeCheckout.decode(
        actualChannel.values[scope],
        actor,
      )!;
      expect(marker.pending, isTrue);
      expect(marker.requestId, api.delegate.previousKey);
      expect(channel.values.length, 1);
    },
  );
  test(
    'background during sent checkout fences reply; explicit rotated session retry retains key',
    () async {
      final api = ControlledApi(status)
        ..reply = Completer<PreparedCheckout>()
        ..sent = Completer<void>();
      final channel = recovery.FakeChannel(),
          composition = compose(api, channel);
      addTearDown(composition.dispose);
      final pending = composition.checkout.begin('gold');
      final assertion = expectLater(pending, throwsA(unknownReply));
      await api.sent!.future;
      final key = api.delegate.previousKey!;
      composition.didChangeAppLifecycleState(AppLifecycleState.paused);
      api.reply!.complete(
        PreparedCheckout(key, 24, status.orderId, 'gold', false),
      );
      await assertion;
      expect(
        PendingNativeCheckout.decode(channel.values[scope], actor)!.pending,
        isTrue,
      );
      api.reply = null;
      api.delegate.actor = const MembershipSession(user, 24, rotated);
      composition.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(api.delegate.posts, 1);
      expect((await composition.checkout.restore())!.requestId, key);
      expect(api.delegate.posts, 1);
      await composition.checkout.resume();
      expect(api.delegate.posts, 2);
      expect(api.delegate.previousKey, key);
      expect((await composition.checkout.restore())!.pending, isFalse);
    },
  );
  test(
    'logout during sent checkout retains original account marker; other account cannot restore it',
    () async {
      final api = ControlledApi(status)
        ..reply = Completer<PreparedCheckout>()
        ..sent = Completer<void>();
      final channel = recovery.FakeChannel(),
          composition = compose(api, channel);
      final pending = composition.checkout.begin('gold');
      final assertion = expectLater(pending, throwsA(unknownReply));
      await api.sent!.future;
      final key = api.delegate.previousKey!;
      composition.dispose();
      api.reply!.complete(
        PreparedCheckout(key, 24, status.orderId, 'gold', false),
      );
      await assertion;
      final marker = channel.values[scope];
      api.reply = null;
      api.delegate.actor = const MembershipSession(
        '20000000-0000-4000-8000-000000000004',
        24,
        rotated,
      );
      final next = compose(api, channel);
      addTearDown(next.dispose);
      expect(await next.checkout.restore(), isNull);
      expect(channel.values[scope], marker);
      expect(api.delegate.posts, 1);
    },
  );
  test(
    'identity invalidation cancels reviewed handoff without dialer or server mutation',
    () async {
      final api = ControlledApi(status),
          channel = recovery.FakeChannel(),
          dialer = contracts.FakeDialer();
      final composition = compose(api, channel, dialer: dialer);
      addTearDown(composition.dispose);
      final review = await composition.handoff.review(status.orderId);
      composition.invalidateIdentity();
      await expectLater(
        composition.handoff.confirm(review.reviewId, acknowledgement: true),
        throwsA(isA<NativeMembershipException>()),
      );
      expect(api.delegate.journalPosts, 0);
      expect(dialer.opens, 0);
    },
  );
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    test('protected channel uses versioned contract on $platform', () async {
      debugDefaultTargetPlatformOverride = platform;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      const methodChannel = MethodChannel(
        'africlub/native-checkout-recovery/v1',
      );
      final calls = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(methodChannel, (call) async {
        calls.add(call);
        return {'version': 1, 'value': null};
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(methodChannel, null),
      );
      final RecoveryPlatformChannel channel = platform == TargetPlatform.android
          ? const AndroidCheckoutRecoveryChannel(enabled: true)
          : const IOSCheckoutRecoveryChannel(enabled: true);
      expect(await channel.invoke('load', {'scope': scope, 'lease': session}), {
        'version': 1,
        'value': null,
      });
      expect(calls.single.method, 'load');
      expect(calls.single.arguments, {'scope': scope, 'lease': session});
      messenger.setMockMethodCallHandler(
        methodChannel,
        (_) async => throw PlatformException(code: 'recovery_device_locked'),
      );
      await expectLater(
        channel.invoke('load', {}),
        throwsA(
          isA<RecoveryPlatformFailure>().having(
            (e) => e.code,
            'code',
            'recovery_device_locked',
          ),
        ),
      );
      messenger.setMockMethodCallHandler(methodChannel, null);
      await expectLater(
        channel.invoke('load', {}),
        throwsA(
          isA<RecoveryPlatformFailure>().having(
            (e) => e.code,
            'code',
            'recovery_channel_unavailable',
          ),
        ),
      );
    });
  }
}
