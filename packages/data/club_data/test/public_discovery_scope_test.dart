import 'dart:convert';

import 'package:club_data/club_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'shared public discovery remains read-only, scoped and publication-gated',
    () async {
      final requests = <http.Request>[];
      final source = SupabaseClient(
        'https://public-discovery.invalid',
        'synthetic-anonymous-key',
        httpClient: MockClient((request) async {
          requests.add(request);
          final table = request.url.path.split('/').last;
          final Object rows = switch (table) {
            'clubs' => {
              'id': 'published-club',
              'slug': 'rayon-sports',
              'name': 'Rayon Sports',
            },
            'partners' => [
              {
                'id': 'partner-1',
                'name': 'Approved partner',
                'logo_asset_id': 'logo-1',
              },
            ],
            'media_assets' => [
              {
                'id': 'logo-1',
                'asset_url': 'https://media.invalid/partner.png',
                'usage_rights': 'synthetic-approved-rights',
                'usage_scopes': ['partners'],
              },
            ],
            'fanclubs' => [
              {
                'id': 'fanclub-1',
                'name': 'Published chapter',
                'show_member_count': false,
                'member_count_public': '99',
              },
            ],
            _ => [],
          };
          return http.Response(
            jsonEncode(rows),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(source.dispose);
      final fallback = _FallbackGateway();
      final gateway = GikundiroPublicClubGateway(source, fallback);
      expect(await gateway.loadNews(), isEmpty);
      expect(await gateway.loadSquad(), isEmpty);
      expect(await gateway.loadMatches(), isEmpty);
      expect(
        (await loadGikundiroPublicPartners(source)).single['id'],
        'gikundiro-partner-1',
      );
      expect(
        (await loadGikundiroPublicFanclubs(
          source,
        )).single['member_count_label'],
        'Pending confirmation',
      );
      await gateway.loadStandings();
      await gateway.loadHistory();
      expect(fallback.calls, ['standings', 'history']);
      expect(requests, isNotEmpty);
      for (final request in requests) {
        expect(request.method, 'GET');
        final table = request.url.path.split('/').last;
        if (table == 'clubs') {
          expect(request.url.queryParameters['slug'], 'eq.rayon-sports');
        } else {
          expect(request.url.queryParameters['club_id'], 'eq.published-club');
        }
        if ([
          'news_posts',
          'players',
          'partners',
          'media_assets',
          'fanclubs',
        ].contains(table)) {
          expect(request.url.queryParameters['approval_status'], 'eq.approved');
          expect(request.url.queryParameters['active'], 'eq.true');
          expect(request.url.queryParameters['visibility'], 'eq.public');
        }
      }
    },
  );

  test(
    'unresolved public club prevents discovery reads and propagates finite failure',
    () async {
      final tables = <String>[];
      final source = SupabaseClient(
        'https://public-discovery.invalid',
        'synthetic-anonymous-key',
        httpClient: MockClient((request) async {
          tables.add(request.url.path.split('/').last);
          return http.Response(
            '{}',
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(source.dispose);
      await expectLater(loadGikundiroPublicPartners(source), throwsStateError);
      await expectLater(loadGikundiroPublicFanclubs(source), throwsStateError);
      expect(tables, ['clubs', 'clubs']);
    },
  );
}

class _FallbackGateway implements ClubContentGateway {
  final calls = <String>[];
  @override
  Future<List<ClubHistoryItem>> loadHistory() async {
    calls.add('history');
    return [];
  }

  @override
  Future<List<ClubStandingItem>> loadStandings() async {
    calls.add('standings');
    return [];
  }

  @override
  Future<List<ClubFixtureItem>> loadMatches() async => [];
  @override
  Future<List<ClubNewsItem>> loadNews() async => [];
  @override
  Future<ClubOverview?> loadOverview() async => null;
  @override
  Future<List<ClubSquadMember>> loadSquad() async => [];
}
