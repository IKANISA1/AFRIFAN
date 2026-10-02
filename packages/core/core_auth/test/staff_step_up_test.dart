import 'dart:async';
import 'dart:convert';

import 'package:core_auth/core_auth.dart';
import 'package:core_network/core_network.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Map<String, dynamic> staffSession({
  String user = 'staff',
  String aal = 'aal2',
  String method = 'totp',
  num? timestamp,
  Map<String, Object?> extra = const {},
}) {
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final claims = <String, Object?>{
    'sub': user,
    'role': 'authenticated',
    'is_anonymous': false,
    'session_id': '$user-session',
    'aal': aal,
    'exp': now + 3600,
    'amr': [
      {'method': method, 'timestamp': timestamp ?? now},
    ],
    ...extra,
  };
  final token =
      '${base64UrlEncode(utf8.encode('{"alg":"HS256"}'))}.${base64UrlEncode(utf8.encode(jsonEncode(claims)))}.local-test';
  return {
    'access_token': token,
    'refresh_token': '$user-refresh',
    'token_type': 'bearer',
    'expires_in': 3600,
    'user': {
      'id': user,
      'aud': 'authenticated',
      'app_metadata': {'club_id': 24},
      'user_metadata': {},
      'created_at': '2026-10-01T00:00:00Z',
    },
  };
}

Session asSession(Map<String, dynamic> json) =>
    Session.fromJson(jsonDecode(jsonEncode(json)))!;
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime.now();
  final seconds = now.millisecondsSinceEpoch ~/ 1000;
  test(
    'staff expiry admits only explicit fresh TOTP methods and binds subject',
    () {
      for (final method in ['totp', 'mfa/totp']) {
        expect(
          staffTotpExpiry(
            asSession(staffSession(method: method, timestamp: seconds)),
            now: now,
          ),
          isNotNull,
        );
      }
      for (final method in [
        'otp',
        'mfa/phone',
        'totp-ish',
        'unknown',
        'passkey',
      ]) {
        expect(
          staffTotpExpiry(
            asSession(staffSession(method: method, timestamp: seconds)),
            now: now,
          ),
          isNull,
        );
      }
      for (final anonymous in [null, 'false', true]) {
        expect(
          staffTotpExpiry(
            asSession(
              staffSession(
                extra: {'is_anonymous': anonymous},
                timestamp: seconds,
              ),
            ),
            now: now,
          ),
          isNull,
        );
      }
      expect(
        staffTotpExpiry(
          asSession(staffSession(aal: 'aal1', timestamp: seconds)),
          now: now,
        ),
        isNull,
      );
      expect(
        staffTotpExpiry(
          asSession(staffSession(extra: {'sub': 'other'}, timestamp: seconds)),
          now: now,
        ),
        isNull,
      );
      expect(
        staffTotpExpiry(
          asSession(
            staffSession(extra: {'is_anonymous': true}, timestamp: seconds),
          ),
          now: now,
        ),
        isNull,
      );
    },
  );
  test(
    'staff expiry rejects old, excessive future, missing and malformed claims',
    () {
      for (final age in [301, -31]) {
        expect(
          staffTotpExpiry(
            asSession(staffSession(timestamp: seconds - age)),
            now: now,
          ),
          isNull,
        );
      }
      expect(
        staffTotpExpiry(
          asSession(staffSession(timestamp: seconds + 20)),
          now: now,
        ),
        isNotNull,
      );
      for (final extra in <Map<String, Object?>>[
        {'amr': null},
        {'amr': 'totp'},
        {
          'amr': [
            {'method': 'totp', 'timestamp': 'now'},
          ],
        },
        {'aal': null},
        {'role': 'service_role'},
        {'exp': seconds - 1},
      ]) {
        expect(
          staffTotpExpiry(asSession(staffSession(extra: extra)), now: now),
          isNull,
        );
      }
      final expiry = staffTotpExpiry(
        asSession(
          staffSession(timestamp: seconds, extra: {'exp': seconds + 5}),
        ),
        now: now,
      )!;
      expect(expiry.difference(now).inSeconds, lessThanOrEqualTo(5));
    },
  );
  test(
    'staff current assignments reject revoked/inactive/foreign rows despite metadata',
    () async {
      final repository = AuthRepository(
        clubId: '24',
        adminAssignmentsLoader: (_) async => [
          {
            'id': 'revoked',
            'user_id': 'staff',
            'role': 'super_admin',
            'is_active': true,
            'revoked_at': '2026-10-01T00:00:00Z',
          },
          {
            'id': 'inactive',
            'user_id': 'staff',
            'role': 'super_admin',
            'is_active': false,
          },
          {
            'id': 'foreign',
            'user_id': 'other',
            'role': 'super_admin',
            'is_active': true,
          },
        ],
        appMetadataLoader: () => {'is_admin': true, 'role': 'super_admin'},
      );
      expect(
        (await repository.resolveAdminAccess('staff')).hasAnyAdminAccess,
        isFalse,
      );
    },
  );
  test(
    'staff actual factor query accepts only verified TOTP for current server user',
    () async {
      late http.Request request;
      final client = SupabaseClient(
        'https://auth.test',
        'test',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((r) async {
          request = r;
          final user = Map<String, dynamic>.from(staffSession()['user']);
          user['factors'] = [
            for (final status in ['verified', 'unverified'])
              {
                'id': status,
                'friendly_name': 'test',
                'factor_type': 'totp',
                'status': status,
                'created_at': '2026-10-01T00:00:00Z',
                'updated_at': '2026-10-01T00:00:00Z',
              },
          ];
          return http.Response(
            jsonEncode(user),
            200,
            request: r,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      await client.auth.recoverSession(jsonEncode(staffSession()));
      final repository = StaffMfaRepository(clientProvider: () => client);
      final factors = await repository.verifiedFactors();
      expect(factors.map((f) => f.id), ['verified']);
      expect(request.url.path, '/auth/v1/user');
      expect(
        request.headers['Authorization'],
        'Bearer ${client.auth.currentSession!.accessToken}',
      );
    },
  );
  for (final verified in [false, true]) {
    test(
      'staff enrollment restart retains other factors and never deletes a verified factor ($verified)',
      () async {
        final calls = <http.Request>[];
        final client = SupabaseClient(
          'https://auth.test',
          'test',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
          httpClient: MockClient((r) async {
            calls.add(r);
            Object body;
            if (r.url.path.endsWith('/user')) {
              final user = Map<String, dynamic>.from(staffSession()['user']);
              user['factors'] = [
                {
                  'id': 'app-factor',
                  'friendly_name': 'AFRICLUB staff authenticator',
                  'factor_type': 'totp',
                  'status': verified ? 'verified' : 'unverified',
                  'created_at': '2026-10-01T00:00:00Z',
                  'updated_at': '2026-10-01T00:00:00Z',
                },
                {
                  'id': 'other-factor',
                  'friendly_name': 'Other pending authenticator',
                  'factor_type': 'totp',
                  'status': 'unverified',
                  'created_at': '2026-10-01T00:00:00Z',
                  'updated_at': '2026-10-01T00:00:00Z',
                },
              ];
              body = user;
            } else if (r.method == 'DELETE') {
              expect(r.url.path, endsWith('/app-factor'));
              body = {'id': 'app-factor'};
            } else {
              expect(r.method, 'POST');
              body = {
                'id': 'new-factor',
                'type': 'totp',
                'totp': {
                  'qr_code': '<svg/>',
                  'secret': 'volatile-new-secret',
                  'uri': 'otpauth://totp/test',
                },
              };
            }
            return http.Response(
              jsonEncode(body),
              200,
              request: r,
              headers: {'content-type': 'application/json'},
            );
          }),
        );
        addTearDown(client.dispose);
        await client.auth.recoverSession(jsonEncode(staffSession(aal: 'aal1')));
        final repository = StaffMfaRepository(clientProvider: () => client);
        if (verified) {
          await expectLater(repository.enroll(), throwsA(isA<StateError>()));
          expect(calls.length, 1);
        } else {
          final result = await repository.enroll();
          expect(result.id, 'new-factor');
          expect(calls.map((r) => r.method), ['GET', 'DELETE', 'POST']);
          expect(
            jsonDecode(calls.last.body)['friendly_name'],
            'AFRICLUB staff authenticator',
          );
        }
        expect(
          calls.where((r) => r.url.path.endsWith('/other-factor')),
          isEmpty,
        );
      },
    );
  }
  test(
    'staff delayed enrollment does not reveal old account setup secret after account switch',
    () async {
      final started = Completer<void>();
      final reply = Completer<http.Response>();
      final client = SupabaseClient(
        'https://auth.test',
        'test',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((r) async {
          if (r.url.path.endsWith('/user')) {
            return http.Response(
              jsonEncode(staffSession(user: 'one')['user']),
              200,
              request: r,
              headers: {'content-type': 'application/json'},
            );
          }
          started.complete();
          return reply.future;
        }),
      );
      addTearDown(client.dispose);
      await client.auth.recoverSession(
        jsonEncode(staffSession(user: 'one', aal: 'aal1')),
      );
      final repository = StaffMfaRepository(clientProvider: () => client);
      final pending = repository.enroll();
      await started.future;
      final assertion = expectLater(
        pending,
        throwsA(isA<SupabaseSessionChangedException>()),
      );
      await client.auth.recoverSession(
        jsonEncode(staffSession(user: 'two', aal: 'aal1')),
      );
      reply.complete(
        http.Response(
          jsonEncode({
            'id': 'old-factor',
            'type': 'totp',
            'totp': {
              'qr_code': '<svg/>',
              'secret': 'volatile-old-secret',
              'uri': 'otpauth://totp/test',
            },
          }),
          200,
        ),
      );
      await assertion;
      expect(client.auth.currentUser!.id, 'two');
    },
  );
  test('staff server denial cannot be replaced by locally fresh JWT', () async {
    final client = SupabaseClient(
      'https://auth.test',
      'test',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient(
        (r) async => http.Response(
          'false',
          200,
          request: r,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );
    addTearDown(client.dispose);
    await client.auth.recoverSession(jsonEncode(staffSession()));
    expect(
      await StaffMfaRepository(clientProvider: () => client).allowed(),
      isFalse,
    );
  });
}
