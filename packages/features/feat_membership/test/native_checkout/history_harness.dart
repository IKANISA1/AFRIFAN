// Authored pure-Dart history regression harness. Requires the real Dart SDK.
import 'dart:convert';
import 'dart:io';
import 'package:feat_membership/native_membership.dart';

const actor = MembershipSession(
  '20000000-0000-4000-8000-000000000001',
  24,
  '30000000-0000-4000-8000-000000000001',
);
Map<String, dynamic> page() => {
  'schemaVersion': 1,
  'clubId': 24,
  'userId': actor.userId,
  'observedAt': 2000,
  'scope': 'membership_allocations',
  'historical': true,
  'snapshot': false,
  'items': [
    {
      'orderId': '40000000-0000-4000-8000-000000000001',
      'allocationId': '50000000-0000-4000-8000-000000000001',
      'recordedAt': 1000,
      'amount': 10000,
      'currency': 'RWF',
    },
  ],
  'nextCursor': null,
};
int passed = 0;
void check(bool ok) {
  if (!ok) throw StateError('History contract failed');
  passed++;
}

void rejects(void Function() f) {
  bool denied = false;
  try {
    f();
  } catch (_) {
    denied = true;
  }
  check(denied);
}

final class Transport implements NativeMembershipTransport {
  final calls = <NativeWireRequest>[];
  @override
  Future<NativeWireResponse> send(NativeWireRequest r, Duration timeout) async {
    calls.add(r);
    return NativeWireResponse(200, {
      'content-type': 'application/json',
    }, jsonEncode(page()));
  }
}

Future<void> main() async {
  final valid = MembershipHistoryPage.parse(page(), actor);
  check(
    valid.historical && !valid.snapshot && valid.items.single.amount == 10000,
  );
  rejects(() => valid.items.clear());
  for (final field in ['clubId', 'userId', 'snapshot', 'historical']) {
    final p = page();
    p[field] = field == 'clubId'
        ? 25
        : field == 'userId'
        ? 'bad'
        : !(p[field] as bool);
    rejects(() => MembershipHistoryPage.parse(p, actor));
  }
  final duplicate = page();
  (duplicate['items'] as List).add((duplicate['items'] as List).first);
  rejects(() => MembershipHistoryPage.parse(duplicate, actor));
  rejects(
    () => MembershipHistoryCursor.parse(
      'mh1:25:${actor.userId}:1000:50000000-0000-4000-8000-000000000001',
      actor,
    ),
  );
  final bad = page();
  ((bad['items'] as List).first as Map)['currency'] = 'RWF\n';
  rejects(() => MembershipHistoryPage.parse(bad, actor));
  final transport = Transport(),
      client = NativeMembershipClient(
        origin: 'https://membership.example.invalid',
        clubId: 24,
        credentials: () async =>
            '${actor.sessionId}.${List.filled(43, 'A').join()}',
        transport: transport,
        enabled: true,
      );
  await client.history(actor);
  check(
    transport.calls.single.method == 'GET' &&
        transport.calls.single.body == null &&
        !transport.calls.single.headers.containsKey('idempotency-key'),
  );
  await client.history(
    actor,
    cursor: 'mh1:24:${actor.userId}:2000:60000000-0000-4000-8000-000000000001',
  );
  check(
    transport.calls.last.headers.containsKey('x-africlub-history-cursor') &&
        !transport.calls.last.uri.hasQuery,
  );
  stdout.writeln('PASS $passed authored history checks');
}
