import 'dart:async';
import 'dart:convert';
import 'package:feat_admin/src/repositories/admin_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/core_auth/test/staff_step_up_test.dart' show staffSession;

void main() {
  test(
    'staff repository queries current grants and never falls back to metadata',
    () async {
      final requests = <http.Request>[];
      var rows = <Map<String, Object?>>[];
      var allowed = false;
      final client = SupabaseClient(
        'https://auth.test',
        'local-test',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((r) async {
          requests.add(r);
          final Object body = r.url.path.endsWith('/staff_step_up_allowed')
              ? allowed
              : rows;
          return http.Response(
            jsonEncode(body),
            200,
            request: r,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      final session =
          jsonDecode(jsonEncode(staffSession())) as Map<String, dynamic>;
      session['user']['app_metadata']['is_admin'] = true;
      await client.auth.recoverSession(jsonEncode(session));
      final repository = AdminRepository(client: client);
      expect(await repository.isCurrentUserAdmin(), false);
      rows = [
        {
          'role': 'super_admin',
          'club_id': null,
          'is_active': true,
          'revoked_at': '2026-10-01T00:00:00Z',
        },
      ];
      expect(await repository.isCurrentUserAdmin(), false);
      rows = [
        {
          'role': 'club_admin',
          'club_id': 25,
          'is_active': true,
          'revoked_at': null,
        },
      ];
      expect(await repository.isCurrentUserAdmin(), false);
      rows = [
        {
          'role': 'club_admin',
          'club_id': 24,
          'is_active': true,
          'revoked_at': null,
        },
      ];
      expect(await repository.isCurrentUserAppMetadataAdmin(), false);
      allowed = true;
      expect(await repository.isCurrentUserAppMetadataAdmin(), true);
      expect(await repository.isCurrentUserAppMetadataPlatformAdmin(), false);
      rows = [
        {
          'role': 'super_admin',
          'club_id': null,
          'is_active': true,
          'revoked_at': null,
        },
      ];
      expect(await repository.isCurrentUserAppMetadataPlatformAdmin(), true);
      for (final r in requests.where(
        (r) => r.url.path.endsWith('/admin_role_assignments'),
      )) {
        expect(r.url.queryParameters['user_id'], 'eq.staff');
        expect(r.url.queryParameters['is_active'], 'eq.true');
        expect(r.url.queryParameters['revoked_at'], 'is.null');
        expect(r.url.queryParameters['select'], contains('revoked_at'));
      }
    },
  );
  for (final mismatch in [false, true]) {
    test(
      'fixture adapter preserves original caller operation and receipt binding ($mismatch)',
      () async {
        var calls = 0;
        const operation = '11111111-2222-4333-8444-555555555555';
        const fixture = '11111111-2222-4333-8444-111111111111';
        final client = SupabaseClient(
          'https://auth.test',
          'local-test',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
          httpClient: MockClient((r) async {
            calls++;
            expect(r.url.path, '/functions/v1/admin-settle-fixture');
            expect(jsonDecode(r.body)['operation_id'], operation);
            expect(r.headers['authorization'], startsWith('Bearer '));
            return http.Response(
              jsonEncode({
                'success': true,
                'data': {
                  'receipt': {
                    'status': 'success',
                    'fixture_id': fixture,
                    'operation_id': mismatch
                        ? '11111111-2222-4333-8444-666666666666'
                        : operation,
                    'score': '3 - 1',
                    'markets_settled': 1,
                    'total_won': 1,
                    'total_lost': 0,
                  },
                },
              }),
              200,
              request: r,
              headers: {'content-type': 'application/json'},
            );
          }),
        );
        addTearDown(client.dispose);
        await client.auth.recoverSession(jsonEncode(staffSession()));
        final repository = AdminRepository(client: client);
        final request = {
          'fixture_id': fixture,
          'home_score': 3,
          'away_score': 1,
          'operation_id': operation,
        };
        await expectLater(
          repository.settlePredictionFixture({
            ...request,
            'operation_id': null,
          }),
          throwsFormatException,
        );
        expect(calls, 0);
        final pending = repository.settlePredictionFixture(request);
        if (mismatch) {
          await expectLater(pending, throwsFormatException);
        } else {
          expect((await pending)['operation_id'], operation);
        }
        expect(calls, 1);
      },
    );
  }
  test(
    'staff delayed role response cannot authorize a replacement account',
    () async {
      final response = Completer<http.Response>();
      final started = Completer<http.Request>();
      final client = SupabaseClient(
        'https://auth.test',
        'local-test',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((r) {
          started.complete(r);
          return response.future;
        }),
      );
      addTearDown(client.dispose);
      await client.auth.recoverSession(jsonEncode(staffSession()));
      final pending = AdminRepository(client: client).isCurrentUserAdmin();
      final request = await started.future;
      await client.auth.recoverSession(
        jsonEncode(staffSession(user: 'replacement')),
      );
      response.complete(
        http.Response(
          '[{"role":"super_admin","club_id":null,"is_active":true,"revoked_at":null}]',
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        ),
      );
      expect(await pending, false);
      expect(client.auth.currentUser?.id, 'replacement');
    },
  );
}
