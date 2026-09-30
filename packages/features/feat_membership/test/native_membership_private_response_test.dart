import 'dart:convert';
import 'package:feat_membership/native_membership.dart';
import 'package:flutter_test/flutter_test.dart';

const actor = MembershipSession(
  '20000000-0000-4000-8000-000000000001',
  24,
  '30000000-0000-4000-8000-000000000001',
);
const requestId = '40000000-0000-4000-8000-000000000001';

final class PrivateResponseTransport implements NativeMembershipTransport {
  PrivateResponseTransport(this.headers);
  final Map<String, String> headers;
  final calls = <NativeWireRequest>[];
  @override
  Future<NativeWireResponse> send(
    NativeWireRequest request,
    Duration timeout,
  ) async {
    calls.add(request);
    return NativeWireResponse(
      200,
      headers,
      jsonEncode({
        'schemaVersion': 1,
        'clubId': actor.clubId,
        'userId': actor.userId,
        'sessionId': actor.sessionId,
      }),
    );
  }
}

NativeMembershipClient client(PrivateResponseTransport transport) =>
    NativeMembershipClient(
      origin: 'https://synthetic.invalid',
      clubId: 24,
      enabled: true,
      credentials: () async =>
          '${actor.sessionId}.${List.filled(43, 'A').join()}',
      transport: transport,
    );

void main() {
  final badHeaders = <String, Map<String, String>>{
    'no cache policy': {'content-type': 'application/json'},
    'cacheable': {
      'content-type': 'application/json',
      'cache-control': 'private, max-age=60',
    },
    'false no-store prefix': {
      'content-type': 'application/json',
      'cache-control': 'no-store-foreign',
    },
    'cookie': {
      'content-type': 'application/json',
      'cache-control': 'no-store',
      'Set-Cookie': 'synthetic-private',
    },
    'compression': {
      'content-type': 'application/json',
      'cache-control': 'no-store',
      'Content-Encoding': 'gzip',
    },
    'foreign media': {'content-type': 'text/html', 'cache-control': 'no-store'},
    'ambiguous policy': {
      'content-type': 'application/json',
      'cache-control': 'no-store',
      'Cache-Control': 'public',
    },
  };
  for (final entry in badHeaders.entries) {
    test(
      '${entry.key} prevents private reads from becoming trusted state',
      () async {
        final transport = PrivateResponseTransport(entry.value);
        await expectLater(
          client(transport).session(),
          throwsA(
            isA<NativeMembershipException>()
                .having((e) => e.code, 'finite error', 'read_unavailable')
                .having((e) => e.outcome, 'outcome', RequestOutcome.notSent),
          ),
        );
        expect(transport.calls, hasLength(1));
      },
    );
    test(
      '${entry.key} preserves an unknown write and original key without a replay',
      () async {
        final transport = PrivateResponseTransport(entry.value);
        await expectLater(
          client(transport).prepare(actor, requestId, 'gold'),
          throwsA(
            isA<NativeMembershipException>()
                .having(
                  (e) => e.code,
                  'finite error',
                  'checkout_outcome_unknown',
                )
                .having((e) => e.outcome, 'outcome', RequestOutcome.unknown),
          ),
        );
        expect(transport.calls, hasLength(1));
        expect(transport.calls.single.headers['idempotency-key'], requestId);
      },
    );
  }
  test(
    'header names are case insensitive and an exact no-store directive is accepted',
    () async {
      final transport = PrivateResponseTransport({
        'Content-Type': 'application/json; charset=utf-8',
        'Cache-Control': 'PRIVATE, NO-STORE',
        'Content-Encoding': 'identity',
      });
      final session = await client(transport).session();
      expect(session.clubId, actor.clubId);
      expect(session.userId, actor.userId);
      expect(transport.calls, hasLength(1));
    },
  );
}
