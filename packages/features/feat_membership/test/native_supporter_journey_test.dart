import 'dart:async';
import 'dart:convert';

import 'package:feat_membership/native_supporter_journey.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../core/core_auth/test/native_identity/support.dart' as auth;
import 'native_supporter_journey_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  JourneyFixture fixture({bool enabled = true}) {
    final f = JourneyFixture(enabled: enabled);
    addTearDown(f.journey.dispose);
    return f;
  }

  test(
    'construction and disabled actions perform zero storage/network/dialer work',
    () async {
      final f = fixture(enabled: false);
      await f.journey.requestCode(auth.fixturePhone);
      await f.journey.prepare('gold');
      expect(f.identity.transport.requests, isEmpty);
      expect(f.identity.store.reads, 0);
      expect(f.transport.requests, isEmpty);
      expect(f.channel.acquisitions, 0);
      expect(f.dialer.opens, 0);
    },
  );
  test(
    'native credentials connect seven-field identity to separate membership wire contract',
    () async {
      final f = fixture();
      await f.login();
      expect(f.journey.stage, NativeMembershipStage.ready);
      await f.journey.prepare('gold');
      expect(f.journey.stage, NativeMembershipStage.prepared);
      expect(f.transport.prepareKeys, hasLength(1));
      expect(
        f.transport.requests.every(
          (r) => r.headers['x-africlub-client'] == 'native-v1',
        ),
        isTrue,
      );
      expect(
        f.transport.requests.every((r) => !r.headers.containsKey('cookie')),
        isTrue,
      );
      expect(f.journey.matchesClub('24'), isTrue);
      expect(f.journey.matchesClub('024'), isFalse);
      expect(f.dialer.opens, 0);
    },
  );
  test(
    'expired uncertain sign-in requires explicit restart with no replay',
    () async {
      final f = fixture();
      f.identity.transport.handler = (_) =>
          throw TimeoutException('synthetic uncertain issuance');
      await f.journey.requestCode(auth.fixturePhone);
      final original = f.identity.store.journal();
      expect(f.journey.stage, NativeMembershipStage.unresolved);
      f.identity.now += 60000;
      final sent = f.identity.transport.requests.length;
      await f.journey.recoverIdentity();
      expect(f.identity.transport.requests.length, sent);
      expect(f.journey.canRestartSignIn, isTrue);
      await f.journey.restartSignIn(acknowledgement: false);
      expect(
        f.identity.store.journal().pending!.requestKey,
        original.pending!.requestKey,
      );
      await f.journey.restartSignIn(acknowledgement: true);
      expect(f.identity.transport.requests.length, sent);
      expect(f.identity.store.journal().pending, isNull);
      expect(f.identity.store.journal().locallySignedOut, isTrue);
      expect(f.journey.stage, NativeMembershipStage.signedOut);
      expect(f.journey.canRestartSignIn, isFalse);
      f.identity.transport.handler = null;
      await f.journey.requestCode(auth.fixturePhone);
      expect(f.journey.stage, NativeMembershipStage.codeRequested);
      expect(f.identity.entropy.keys, 2);
    },
  );

  test(
    'fresh sign-in preserves financial marker after unknown server logout',
    () async {
      final f = fixture();
      await f.login();
      await f.journey.prepare('gold');
      final markers = Map<String, String>.from(f.channel.values);
      f.identity.transport.handler = (_) =>
          throw TimeoutException('synthetic unknown revoke');
      await f.journey.signOut();
      final requests = f.identity.transport.requests.length;
      final revocation = f.identity.store.journal().revocation;
      expect(f.journey.canRestartSignIn, isTrue);
      await f.journey.restartSignIn(acknowledgement: true);
      expect(f.identity.transport.requests.length, requests);
      expect(f.channel.values, markers);
      expect(f.identity.store.journal().revocation, revocation);
      expect(f.journey.identity, isNull);
      expect(f.journey.stage, NativeMembershipStage.signedOut);
    },
  );
  for (final wrong in ['user', 'club', 'session']) {
    test(
      'wrong membership $wrong is denied before prepare and protected marker',
      () async {
        final f = fixture();
        await f.login();
        if (wrong == 'user') {
          f.transport.userId = '99999999-9999-4999-8999-999999999999';
        }
        if (wrong == 'club') f.transport.clubId = 25;
        if (wrong == 'session') {
          f.transport.sessionId = '99999999-9999-4999-8999-999999999999';
        }
        await f.journey.prepare('gold');
        expect(f.transport.posts, 0);
        expect(f.channel.values, isEmpty);
        expect(f.dialer.opens, 0);
        expect(f.journey.problem, isNotNull);
      },
    );
  }
  test(
    'review and confirmation remain separate and require acknowledgement',
    () async {
      final f = fixture();
      await f.review();
      expect(f.journey.stage, NativeMembershipStage.review);
      expect(f.dialer.opens, 0);
      await f.journey.confirmPayment(acknowledgement: true);
      expect(f.dialer.opens, 0);
      expect(f.transport.posts, 1);
      await f.journey.reviewPayment();
      f.journey.showConfirmation();
      await f.journey.confirmPayment(acknowledgement: false);
      expect(f.dialer.opens, 0);
      expect(f.transport.posts, 1);
    },
  );
  test('explicit confirmed dialer handoff is never a paid success', () async {
    final f = fixture();
    await f.review();
    f.journey.showConfirmation();
    await f.journey.confirmPayment(acknowledgement: true);
    expect(f.dialer.opens, 1);
    expect(f.journey.stage, NativeMembershipStage.unresolved);
    expect(f.journey.checkout!.paymentEvidenceAllocated, isFalse);
    final posts = f.transport.posts;
    await f.journey.inspectRecovery();
    expect(f.transport.posts, posts);
    expect(f.dialer.opens, 1);
    expect(f.journey.recovery!.server.handoff!.phase, 'claimed');
  });
  test(
    'original checkout key survives unknown acknowledgement and explicit recovery',
    () async {
      final f = fixture();
      await f.login();
      f.transport.losePrepareAck = true;
      await f.journey.prepare('gold');
      expect(f.journey.stage, NativeMembershipStage.unresolved);
      final original = f.transport.prepareKeys.single;
      final posts = f.transport.posts;
      await f.journey.inspectRecovery();
      expect(f.transport.posts, posts);
      expect(f.journey.pending!.pending, isTrue);
      await f.journey.retryOriginalCheckout();
      expect(f.transport.prepareKeys, [original, original]);
      expect(f.journey.stage, NativeMembershipStage.prepared);
      expect(f.channel.values.values.any((v) => v.contains(original)), isTrue);
    },
  );
  test(
    'lost claim acknowledgement keeps unknown state and never opens or reclaims',
    () async {
      final f = fixture();
      await f.review();
      f.transport.loseClaimAck = true;
      f.journey.showConfirmation();
      await f.journey.confirmPayment(acknowledgement: true);
      expect(f.journey.stage, NativeMembershipStage.unresolved);
      expect(f.dialer.opens, 0);
      final posts = f.transport.posts;
      await f.journey.inspectRecovery();
      expect(f.transport.posts, posts);
      expect(f.journey.recovery!.server.handoff!.phase, 'claimed');
      await f.journey.prepare('gold');
      expect(f.transport.posts, posts);
      expect(f.journey.problem, NativeJourneyProblem.unresolved);
    },
  );
  test(
    'background and resume hide review and do not recover or launch',
    () async {
      final f = fixture();
      await f.review();
      final calls = f.transport.requests.length,
          identityCalls = f.identity.transport.requests.length;
      f.journey.didChangeAppLifecycleState(AppLifecycleState.paused);
      f.journey.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(f.journey.paymentReview, isNull);
      expect(f.journey.checkout, isNull);
      expect(f.journey.identity, isNull);
      expect(f.transport.requests.length, calls);
      expect(f.identity.transport.requests.length, identityCalls);
      expect(f.dialer.opens, 0);
      expect(f.channel.values, isNotEmpty);
    },
  );
  for (final invalidation in ['route', 'account', 'club']) {
    test(
      '$invalidation change fences a late committed prepare reply and retains original marker',
      () async {
        final f = fixture();
        await f.login();
        f.transport.prepareSent = Completer<void>();
        f.transport.prepareReply = Completer<NativeWireResponse>();
        final action = f.journey.prepare('gold');
        await f.transport.prepareSent!.future;
        final key = f.transport.prepareKeys.single;
        f.journey.invalidate();
        final body = Map<String, Object?>.from(
          f.transport.vectors['prepared:valid']!,
        )..['requestId'] = key;
        f.transport.prepareReply!.complete(f.transport.reply(body));
        await action;
        expect(f.journey.checkout, isNull);
        expect(f.journey.pending, isNull);
        expect(f.journey.stage, NativeMembershipStage.signedOut);
        expect(f.journey.identity, isNull);
        expect(f.dialer.opens, 0);
        final pending =
            jsonDecode(
                  f
                      .channel
                      .values['africlub-membership-v1:24:${auth.fixtureUser}']!,
                )
                as Map;
        expect(pending['requestId'], key);
        expect(pending['orderId'], isNull);
      },
    );
  }
  test(
    'signout hides views and retains financial markers while server revokes',
    () async {
      final f = fixture();
      await f.review();
      final stored = Map<String, String>.from(f.channel.values);
      await f.journey.signOut();
      expect(f.journey.stage, NativeMembershipStage.signedOut);
      expect(f.journey.identity, isNull);
      expect(f.journey.paymentReview, isNull);
      expect(f.journey.checkout, isNull);
      expect(f.channel.values, stored);
      expect(f.dialer.opens, 0);
      expect(
        f.identity.transport.requests.last.uri.path.endsWith(
          '/sessions/revoke',
        ),
        isTrue,
      );
    },
  );
  test(
    'revocation lost acknowledgement is visible without automatic resend',
    () async {
      final f = fixture();
      await f.login();
      f.identity.transport.handler = (request) {
        if (request.uri.path.endsWith('/sessions/revoke')) {
          throw TimeoutException('synthetic');
        }
        return auth.jsonResponse(auth.sessionFixture());
      };
      await f.journey.signOut();
      expect(f.journey.stage, NativeMembershipStage.signedOut);
      expect(f.journey.problem, NativeJourneyProblem.unresolved);
      expect(f.journey.identity, isNull);
    },
  );
  test(
    'authoritative allocation is distinct from historical receipt/current access',
    () async {
      final f = fixture();
      await f.login();
      await f.journey.prepare('gold');
      f.transport.status = 'status:allocated-valid';
      await f.journey.inspectRecovery();
      expect(f.journey.stage, NativeMembershipStage.allocationRecorded);
      expect(f.journey.receipt, isNull);
      await f.journey.readReceipt();
      expect(f.journey.receipt!.historical, isTrue);
      expect(f.dialer.opens, 0);
    },
  );
  test('unapproved tier is refused before network or storage', () async {
    final f = fixture();
    await f.login();
    final count = f.transport.requests.length;
    await f.journey.prepare('unapproved');
    expect(f.transport.requests.length, count);
    expect(f.channel.values, isEmpty);
  });
  test('rapid repeated user action performs one checkout POST', () async {
    final f = fixture();
    await f.login();
    await Future.wait([
      f.journey.prepare('gold'),
      f.journey.prepare('gold'),
      f.journey.prepare('gold'),
    ]);
    expect(f.transport.prepareKeys, hasLength(1));
  });
}
