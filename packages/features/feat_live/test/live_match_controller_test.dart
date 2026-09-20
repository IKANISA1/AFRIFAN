import 'dart:async';
import 'dart:convert';

import 'package:core_network/core_network.dart';
import 'package:feat_live/src/providers/live_match_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _Scope extends ClubScopeResolver {
  _Scope(SupabaseClient client) : super(client: client);
  @override
  Future<ClubScope> requireResolved([String? hint]) async =>
      const ClubScope(partnerId: '', clubId: 26);
}

class _Realtime extends RealtimeService {
  _Realtime(SupabaseClient client) : super(clubId: '26', client: client);
  final changes = <String, void Function(PostgresChangePayload)>{};
  final joins = <String, VoidCallback>{};
  bool disposed = false;
  @override
  RealtimeChannel onTableChanges({
    String schema = 'public',
    required String table,
    required String filterColumn,
    required String filterValue,
    required void Function(PostgresChangePayload) callback,
    VoidCallback? onSubscribed,
  }) {
    expect(filterColumn, 'id');
    final key = '$schema.$table:$filterValue';
    changes[key] = callback;
    if (onSubscribed != null) joins[key] = onSubscribed;
    return client.channel(key);
  }

  void change(
    String key, {
    PostgresChangeEvent event = PostgresChangeEvent.update,
  }) {
    changes[key]!(
      PostgresChangePayload(
        schema: 'football',
        table: 'fixtures',
        commitTimestamp: DateTime.now(),
        eventType: event,
        newRecord: {'id': 'fixture', 'home_score': 99},
        oldRecord: {},
        errors: [],
      ),
    );
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

Future<void> settle() async {
  // HTTP mock futures and coalesced invalidation complete without real sockets.
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late SupabaseClient client;
  late _Realtime realtime;
  late LiveMatchController controller;
  late List<Uri> requests;
  late Map<String, dynamic> row;
  late bool failed;
  late bool empty;
  Completer<void>? held;

  setUp(() {
    requests = [];
    failed = false;
    empty = false;
    held = null;
    row = {
      'id': 'legacy',
      'legacy_match_id': 'legacy',
      'fixture_id': 'fixture',
      'club_id': 26,
      'home_team': 'Nkana FC',
      'away_team': 'Shared opponent',
      'competition': 'Fixture competition',
      'home_score': 1,
      'away_score': 0,
      'match_status': 'live',
      'live_events': [
        {'title': 'Confirmed event'},
      ],
    };
    client = SupabaseClient(
      'https://live-projection.invalid',
      'synthetic',
      httpClient: MockClient((request) async {
        requests.add(request.url);
        final snapshot = Map<String, dynamic>.from(row);
        await held?.future;
        if (failed) return http.Response('{"message":"Synthetic outage"}', 503);
        final isLive = request.url.queryParameters['match_status']!
            .replaceAll('"', '')
            .contains('in.(live,');
        return http.Response(
          jsonEncode(empty || !isLive ? [] : [snapshot]),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    realtime = _Realtime(client);
    controller = LiveMatchController(
      client: client,
      scopeResolver: _Scope(client),
      realtimeFactory: (clubId) {
        expect(clubId, '26');
        return realtime;
      },
      pollInterval: const Duration(milliseconds: 30),
      requestTimeout: const Duration(milliseconds: 60),
    );
  });
  tearDown(() async {
    controller.dispose();
    held?.complete();
    held = null;
    await client.dispose();
  });

  test(
    'subscribes to both underlying IDs and reloads the authorized projection',
    () async {
      await controller.refresh();
      expect(
        realtime.changes.keys,
        unorderedEquals(['public.matches:legacy', 'football.fixtures:fixture']),
      );
      row['home_score'] = 2;
      realtime.change('football.fixtures:fixture');
      await settle();
      expect(
        controller.match?['home_score'],
        2,
      ); // Never the unprojected payload's 99.
      expect(controller.match?['home_team'], 'Nkana FC');
      expect(controller.match?['live_events'], isNotEmpty);
      expect(
        requests.every(
          (r) =>
              r.path == '/rest/v1/unified_matches' &&
              r.queryParameters['club_id'] == 'eq.26',
        ),
        isTrue,
      );
    },
  );

  test(
    'rejoin fetches scores missed while disconnected without resubscribing',
    () async {
      await controller.refresh();
      row['home_score'] = 3;
      realtime.joins['football.fixtures:fixture']!();
      await settle();
      expect(controller.match?['home_score'], 3);
      expect(realtime.changes, hasLength(2));
      expect(requests, hasLength(6));
    },
  );

  test(
    'delete invalidation clears the removed fixture and its subscriptions',
    () async {
      await controller.refresh();
      empty = true;
      realtime.change(
        'public.matches:legacy',
        event: PostgresChangeEvent.delete,
      );
      await settle();
      expect(controller.match, isNull);
      expect(controller.error, isNull);
      expect(realtime.disposed, isTrue);
    },
  );

  test(
    'failed refresh retains confirmed data, exposes failure, and recovers',
    () async {
      await controller.refresh();
      failed = true;
      await controller.refresh();
      expect(controller.match?['home_score'], 1);
      expect(controller.error, isNotNull);
      failed = false;
      row['home_score'] = 4;
      await controller.refresh();
      expect(controller.match?['home_score'], 4);
      expect(controller.error, isNull);
    },
  );

  test('polling catches missed events and pauses in background', () async {
    await controller.start();
    controller.setActive(false);
    final before = requests.length;
    row['home_score'] = 5;
    await Future<void>.delayed(const Duration(milliseconds: 45));
    expect(requests, hasLength(before));
    controller.setActive(true);
    await settle();
    expect(controller.match?['home_score'], 5);
    row['home_score'] = 6;
    await Future<void>.delayed(const Duration(milliseconds: 45));
    expect(controller.match?['home_score'], 6);
  });

  test(
    'burst invalidations coalesce and fetch events received during a read',
    () async {
      await controller.refresh();
      held = Completer<void>();
      row['home_score'] = 2;
      realtime.change('football.fixtures:fixture');
      await settle();
      row['home_score'] = 7;
      for (var i = 0; i < 20; i++) {
        realtime.change('football.fixtures:fixture');
      }
      held!.complete();
      held = null;
      await settle();
      expect(controller.match?['home_score'], 7);
      expect(
        requests,
        hasLength(9),
      ); // initial read + in-flight read + one catch-up.
    },
  );

  test(
    'a stalled request reaches its deadline and its late response is ignored',
    () async {
      await controller.refresh();
      held = Completer<void>();
      row['home_score'] = 99;
      await controller.refresh();
      expect(controller.error, isA<TimeoutException>());
      expect(controller.match?['home_score'], 1);
      held!.complete();
      held = null;
      await settle();
      expect(controller.match?['home_score'], 1);
      row['home_score'] = 8;
      await controller.refresh();
      expect(controller.match?['home_score'], 8);
    },
  );

  test(
    'disposing an in-flight read prevents late notifications and subscriptions',
    () async {
      held = Completer<void>();
      var notifications = 0;
      controller.addListener(() => notifications++);
      final pending = controller.refresh();
      await settle();
      controller.dispose();
      held!.complete();
      held = null;
      await pending;
      expect(notifications, 0);
      expect(realtime.changes, isEmpty);
      // Replace the disposed subject so the common cleanup stays single-dispose.
      controller = LiveMatchController(
        client: client,
        scopeResolver: _Scope(client),
      );
    },
  );
}
