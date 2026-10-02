import 'dart:convert';

import 'package:feat_gamification/src/predict/predict_models.dart';
import 'package:feat_gamification/src/predict/predict_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Map<String, dynamic> freeFixtureResponse({
  String version = 'free_v1',
  int stake = 0,
  String? outcome,
  int points = 0,
}) => {
  'id': 'fixture',
  'pool_id': 'pool',
  'competition_id': 'league',
  'competition': 'Rwanda Premier League',
  'home_team': 'Rayon Sports FC',
  'away_team': 'APR FC',
  'home_crest': 'https://example.invalid/home.png',
  'away_crest': 'https://example.invalid/away.png',
  'kickoff_at': '2030-10-01T18:00:00Z',
  'locks_at': '2030-10-01T18:00:00Z',
  'status': outcome == null ? 'open' : 'settled',
  'selection': 'home',
  'outcome': outcome ?? 'pending',
  'stake_fet': stake,
  'payout_fet': 0,
  'economics_version': version,
  'score_points': points,
};

void main() {
  late SupabaseClient client;
  late PredictRepository repository;
  late List<http.Request> requests;
  late Map<String, dynamic> fixtureResponse;
  String? serverFailure;
  String serverCode = 'P0001';
  setUp(() async {
    requests = [];
    fixtureResponse = freeFixtureResponse();
    serverFailure = null;
    serverCode = 'P0001';
    client = SupabaseClient(
      'https://predict.invalid',
      'synthetic-anon-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        requests.add(request);
        if (serverFailure != null) {
          return http.Response(
            jsonEncode({'message': serverFailure, 'code': serverCode}),
            400,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }
        final response = request.url.path.endsWith('/predict_dashboard')
            ? {
                'enabled': true,
                'member_session': true,
                'fixtures': [fixtureResponse],
                'history': [
                  freeFixtureResponse(version: 'legacy_paid_v1', stake: 100),
                ],
                'wallet': null,
                'ledger': [],
              }
            : {...fixtureResponse, 'balance_fet': 0};
        return http.Response(
          jsonEncode(response),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(client.dispose);
    await client.auth.recoverSession(
      jsonEncode({
        'access_token': 'synthetic-predict-token',
        'refresh_token': 'synthetic-refresh',
        'token_type': 'bearer',
        'user': {
          'id': '99963000-0000-4000-8000-000000000001',
          'aud': 'authenticated',
          'role': 'authenticated',
          'phone': '+250700000001',
          'phone_confirmed_at': '2026-10-01T10:00:00Z',
          'app_metadata': {'club_id': 24},
          'user_metadata': {'club_id': 25},
          'created_at': '2026-10-01T10:00:00Z',
        },
      }),
    );
    repository = PredictRepository(client);
  });

  test(
    'actual caller sends trusted scope and choices with no price or wallet identity',
    () async {
      final dashboard = await repository.load();
      expect(dashboard.balanceFet, isNull);
      expect(dashboard.fixtures.single.isFreeEntry, isTrue);
      expect(dashboard.history.single.isFreeEntry, isFalse);
      final confirmation = await repository.place(
        'fixture',
        PredictSelection.home,
      );
      expect(confirmation.balanceFet, 0);
      expect(confirmation.fixture.stakeFet, 0);
      final request = requests.singleWhere(
        (r) => r.url.path.endsWith('/predict_place'),
      );
      expect(
        request.headers['authorization'],
        'Bearer synthetic-predict-token',
      );
      expect(jsonDecode(request.body), {
        'p_club_id': 24,
        'p_fixture_id': 'fixture',
        'p_selection': 'home',
      });
      expect(
        requests.where(
          (r) =>
              r.url.path.contains('welcome') || r.url.path.contains('wallet'),
        ),
        isEmpty,
      );
    },
  );

  test('actual caller rejects a historical paid confirmation', () async {
    fixtureResponse = freeFixtureResponse(
      version: 'legacy_paid_v1',
      stake: 100,
    );
    await expectLater(
      repository.place('fixture', PredictSelection.home),
      throwsA(PredictFailure.closed),
    );
  });

  test(
    'closed historical and stale fixture errors require no paid retry',
    () async {
      serverFailure = 'PREDICT_LEGACY_ENTRY_CLOSED';
      await expectLater(
        repository.place('fixture', PredictSelection.home),
        throwsA(PredictFailure.closed),
      );
      expect(requests, hasLength(1));
    },
  );

  test('correct free result remains correct when payout is zero', () {
    final result = PredictFixture.fromJson(
      freeFixtureResponse(outcome: 'won', points: 1),
    );
    expect(result.outcome, 'won');
    expect(result.payoutFet, 0);
    expect(result.scorePoints, 1);
  });

  test('revoked account response clears mutation authority', () async {
    serverFailure = 'ACCOUNT_CLOSURE_PENDING';
    serverCode = '42501';
    await expectLater(
      repository.place('fixture', PredictSelection.home),
      throwsA(PredictFailure.signIn),
    );
    expect(requests, hasLength(1));
  });

  test(
    'free response cannot disguise financial reward or infer correctness from payout',
    () {
      for (final response in [
        freeFixtureResponse()..['payout_fet'] = 1,
        freeFixtureResponse(outcome: 'lost', points: 1),
        freeFixtureResponse(outcome: 'won', points: 0),
      ]) {
        expect(() => PredictFixture.fromJson(response), throwsFormatException);
      }
    },
  );

  test(
    'missing, unknown or charged free versions cannot be treated as free',
    () {
      final historical = freeFixtureResponse(
        version: 'legacy_paid_v1',
        stake: 100,
      )..remove('economics_version');
      expect(PredictFixture.fromJson(historical).isFreeEntry, isFalse);
      for (final response in [
        freeFixtureResponse(version: 'future_v2'),
        freeFixtureResponse(stake: 100),
        freeFixtureResponse()..remove('economics_version'),
      ]) {
        expect(() => PredictFixture.fromJson(response), throwsFormatException);
      }
    },
  );
}
