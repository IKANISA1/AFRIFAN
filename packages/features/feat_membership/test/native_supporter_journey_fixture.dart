import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:feat_membership/native_supporter_journey.dart';

import '../../../core/core_auth/test/native_identity/support.dart' as auth;
import 'native_checkout/platform_recovery_harness.dart' as recovery;

// Synthetic, memory-backed contract doubles only. No OS protection, carrier,
// provider, server deployment or physical device acceptance is implied.
final class JourneyFixture {
  JourneyFixture({bool enabled = true, List<NativeMembershipPlan>? plans}) {
    journey = NativeSupporterJourney(
      identityClient: identity.client,
      credentialStore: identity.store,
      identityEntropy: identity.entropy,
      membershipTransport: transport,
      plans: plans ?? [NativeMembershipPlan('gold', 'Gold')],
      enabled: enabled,
      recoveryChannel: channel,
      dialer: dialer,
    );
  }
  final identity = auth.IdentityFixture();
  final transport = JourneyMembershipTransport();
  final channel = recovery.FakeChannel();
  final dialer = JourneyDialer();
  late final NativeSupporterJourney journey;
  Future<void> login() async {
    await journey.requestCode(auth.fixturePhone);
    await journey.verifyCode('123456');
  }

  Future<void> review() async {
    await login();
    await journey.prepare('gold');
    await journey.reviewPayment();
  }
}

final class JourneyDialer implements MembershipDialer {
  int opens = 0;
  bool result = true;
  @override
  Future<bool> open(String code) async {
    opens++;
    return result;
  }
}

final class JourneyMembershipTransport implements NativeMembershipTransport {
  JourneyMembershipTransport() {
    final path = [
      'test/native_checkout/wire-vectors.json',
      'packages/features/feat_membership/test/native_checkout/wire-vectors.json',
      '../../packages/features/feat_membership/test/native_checkout/wire-vectors.json',
    ].firstWhere((path) => File(path).existsSync());
    final fixture =
        jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
    for (final row in fixture['vectors'] as List<dynamic>) {
      final map = row as Map<String, dynamic>;
      vectors[map['name'] as String] = Map<String, Object?>.from(
        map['body'] as Map,
      );
    }
  }
  final vectors = <String, Map<String, Object?>>{};
  final requests = <NativeWireRequest>[];
  final prepareKeys = <String>[];
  Map<String, Object?>? handoff;
  String status = 'status:valid';
  String userId = auth.fixtureUser, sessionId = auth.fixtureSession;
  int clubId = 24;
  bool losePrepareAck = false, loseClaimAck = false;
  Completer<void>? prepareSent;
  Completer<NativeWireResponse>? prepareReply;
  String get orderId => vectors['status:valid']!['orderId']! as String;
  int get posts => requests.where((r) => r.method == 'POST').length;
  NativeWireResponse reply(Object? body) => NativeWireResponse(200, {
    'content-type': 'application/json',
    'cache-control': 'no-store',
  }, jsonEncode(body));

  @override
  Future<NativeWireResponse> send(
    NativeWireRequest request,
    Duration timeout,
  ) async {
    requests.add(request);
    final path = request.uri.path;
    if (path.endsWith('/session')) {
      return reply({
        'schemaVersion': 1,
        'clubId': clubId,
        'userId': userId,
        'sessionId': sessionId,
      });
    }
    if (path.endsWith('/handoffs/current')) {
      return reply({
        'schemaVersion': 1,
        'handoff': handoff,
        'mayOpenDialer': false,
      });
    }
    if (path.endsWith('/checkouts') && request.method == 'POST') {
      prepareKeys.add(request.headers['idempotency-key']!);
      final body = Map<String, Object?>.from(vectors['prepared:valid']!)
        ..['requestId'] = request.headers['idempotency-key']
        ..['tier'] = (jsonDecode(request.body!) as Map)['tier']
        ..['reused'] = prepareKeys.length > 1;
      prepareSent?.complete();
      if (losePrepareAck) {
        losePrepareAck = false;
        throw TimeoutException('synthetic lost ack');
      }
      return prepareReply == null ? reply(body) : prepareReply!.future;
    }
    if (path.endsWith('/handoffs/reservations')) {
      handoff = {
        'handoffId': '55555555-5555-4555-8555-555555555555',
        'orderId': orderId,
        'clubId': 24,
        'phase': 'reserved',
        'createdAt': 1790431200000,
        'claimedAt': null,
        'orderExpiresAt': 1790517600123,
        'observedAt': 1790431200123,
        'paymentEvidenceAllocated': false,
      };
      return reply({
        'schemaVersion': 1,
        'handoff': handoff,
        'mayOpenDialer': false,
      });
    }
    if (path.endsWith('/claims')) {
      handoff = Map<String, Object?>.from(handoff!)
        ..['phase'] = 'claimed'
        ..['claimedAt'] = 1790431200100;
      if (loseClaimAck) {
        loseClaimAck = false;
        throw TimeoutException('synthetic lost claim ack');
      }
      return reply({
        'schemaVersion': 1,
        'handoff': handoff,
        'mayOpenDialer': true,
      });
    }
    if (path.endsWith('/releases')) {
      handoff = Map<String, Object?>.from(handoff!)..['phase'] = 'released';
      return reply({
        'schemaVersion': 1,
        'handoff': handoff,
        'mayOpenDialer': false,
      });
    }
    if (path.endsWith('/receipt')) return reply(vectors['receipt:valid']);
    if (path.endsWith('/checkouts/$orderId')) return reply(vectors[status]);
    throw StateError('Unexpected synthetic membership operation');
  }
}
