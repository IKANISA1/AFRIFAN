import 'dart:convert';

import 'package:core_feature_config/core_feature_config.dart';
import 'package:core_network/core_network.dart';
import 'package:feat_home/src/repositories/home_content_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FixtureScope extends ClubScopeResolver {
  _FixtureScope(SupabaseClient client) : super(client: client);

  @override
  Future<ClubScope> requireResolved([String? hint]) async =>
      const ClubScope(partnerId: '', clubId: 26);
}

void main() {
  for (final enforced in [false, true]) {
    test(
      'guest public Home avoids private reads with store policy $enforced',
      () async {
        final requests = <Uri>[];
        final client = SupabaseClient(
          'https://guest-home.invalid',
          'synthetic',
          httpClient: MockClient((request) async {
            requests.add(request.url);
            if (request.url.path.endsWith('/fan_memberships')) {
              return http.Response(
                '{"code":"42501","message":"Membership requires authentication"}',
                401,
                request: request,
              );
            }
            return http.Response(
              jsonEncode(
                request.url.path.endsWith('/quick_actions')
                    ? [
                        {
                          'id': 'qa-news',
                          'action_key': 'news',
                          'title': 'Club news',
                          'route': '/club/news',
                          'icon_key': 'news',
                          'is_active': true,
                        },
                      ]
                    : [],
              ),
              200,
              request: request,
              headers: {'content-type': 'application/json'},
            );
          }),
        );
        addTearDown(client.dispose);
        final result = await SupabaseHomeFeedRepository(
          client: client,
          storeReleasePolicy: StoreReleasePolicy(isEnforced: enforced),
          scopeResolver: _FixtureScope(client),
        ).load();
        expect(result.status, HomeFeedStatus.empty);
        expect(result.notice, HomeFeedNotice.matchdayPending);
        expect(result.quickActions.single.actionKey, 'news');
        expect(
          requests.map((r) => r.path),
          isNot(contains('/rest/v1/fan_memberships')),
        );
        expect(
          requests.where((r) => r.path.endsWith('/unified_matches')),
          hasLength(3),
        );
        expect(
          requests
              .where((r) => r.path.endsWith('/unified_matches'))
              .every((r) => r.queryParameters['club_id'] == 'eq.26'),
          isTrue,
        );
      },
    );
  }

  for (final failedTable in ['unified_matches', 'quick_actions']) {
    test(
      'guest Home preserves real $failedTable outages and recovers',
      () async {
        var failed = true;
        final client = SupabaseClient(
          'https://guest-home.invalid',
          'synthetic',
          httpClient: MockClient(
            (request) async =>
                failed && request.url.path.endsWith('/$failedTable')
                ? http.Response(
                    '{"message":"Synthetic public outage"}',
                    503,
                    request: request,
                  )
                : http.Response(
                    '[]',
                    200,
                    request: request,
                    headers: {'content-type': 'application/json'},
                  ),
          ),
        );
        addTearDown(client.dispose);
        final repository = SupabaseHomeFeedRepository(
          client: client,
          storeReleasePolicy: const StoreReleasePolicy.unenforced(),
          scopeResolver: _FixtureScope(client),
        );
        expect((await repository.load()).status, HomeFeedStatus.degraded);
        failed = false;
        expect((await repository.load()).status, HomeFeedStatus.empty);
      },
    );
  }
}
