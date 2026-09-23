import 'dart:convert';
import 'package:club_data/club_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'upcoming fixtures have their own quota beyond historical seasons',
    () async {
      final requests = <Uri>[];
      final client = SupabaseClient(
        'https://test.invalid',
        'test',
        httpClient: MockClient((request) async {
          requests.add(request.url);
          final status = request.url.queryParameters['match_status']!;
          final id = status.startsWith('not.')
              ? 'upcoming'
              : status.contains('completed')
              ? 'recent'
              : 'live';
          return http.Response(
            jsonEncode([
              {'id': id, 'club_id': 24},
            ]),
            200,
            request: request,
            headers: {
              'content-type': 'application/json',
              'content-range': '0-0/1',
            },
          );
        }),
      );
      addTearDown(client.dispose);
      final rows = await PublicMatchWindow(
        client,
      ).load(clubId: 24, limitPerSection: 3, now: DateTime.utc(2026, 9, 6, 12));
      expect(rows.map((r) => r['id']), ['live', 'upcoming', 'recent']);
      expect(requests, hasLength(3));
      for (final uri in requests) {
        expect(uri.queryParameters['club_id'], 'eq.24');
        expect(uri.queryParameters['limit'], '3');
      }
      final upcoming = requests.singleWhere(
        (r) => r.queryParameters['match_status']!.startsWith('not.'),
      );
      expect(
        upcoming.queryParameters['or'],
        contains('2026-09-06T12:00:00.000Z'),
      );
      expect(
        upcoming.queryParameters['order'],
        allOf(contains('match_date.asc'), contains('kickoff_time.asc')),
      );
      final recent = requests.singleWhere(
        (r) =>
            r.queryParameters['match_status']!.startsWith('in.') &&
            r.queryParameters['match_status']!.contains('completed'),
      );
      expect(
        recent.queryParameters['order'],
        allOf(contains('match_date.desc'), contains('kickoff_time.desc')),
      );
    },
  );
}
