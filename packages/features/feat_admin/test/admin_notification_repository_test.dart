import 'dart:async';
import 'dart:convert';

import 'package:core_network/core_network.dart';
import 'package:feat_admin/feat_admin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/core_auth/test/staff_step_up_test.dart' show staffSession;
import 'notification_command_test_support.dart';

const _args = <String, dynamic>{
  'audience': 'all_fans',
  'title': 'Matchday alert',
  'body': 'Kickoff soon.',
  'delivery_mode': 'send_now',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final mismatch in [
    null,
    'operation_id',
    'actor_id',
    'club_id',
    'arguments_sha256',
  ]) {
    test(
      'actual notification adapter binds original receipt ($mismatch)',
      () async {
        final attempt = AdminNotificationAttempt(
          userId: notificationTestUser,
          clubId: 24,
          operationId: notificationTestOperation,
          arguments: _args,
        );
        final requests = <http.Request>[];
        final client = _client((request) async {
          requests.add(request);
          expect(request.url.path, '/functions/v1/admin-send-notification');
          final body = jsonDecode(request.body) as Map;
          expect(body, {
            'action': 'submit',
            'operation_id': notificationTestOperation,
            'club_id': 24,
            ...attempt.arguments,
          });
          expect(body.containsKey('actor_id'), isFalse);
          final receipt = notificationTestReceipt(attempt);
          if (mismatch != null) {
            (receipt['command'] as Map)[mismatch] = 'foreign';
          }
          return _response(request, {'success': true, 'data': receipt});
        });
        addTearDown(client.dispose);
        await client.auth.recoverSession(
          jsonEncode(staffSession(user: notificationTestUser)),
        );
        final repository = AdminRepository(client: client);
        final pending = repository.submitAdminNotification(
          attempt,
          submit: true,
        );
        if (mismatch == null) {
          expect(
            (await pending)['command']['operation_id'],
            notificationTestOperation,
          );
        } else {
          await expectLater(pending, throwsFormatException);
        }
        expect(requests, hasLength(1));
        final wrong = AdminNotificationAttempt(
          userId: notificationTestUser,
          clubId: 25,
          operationId: notificationTestOperation,
          arguments: _args,
        );
        await expectLater(
          repository.submitAdminNotification(wrong, submit: true),
          throwsA(isA<SupabaseSessionChangedException>()),
        );
        expect(requests, hasLength(1));
      },
    );
  }

  test(
    'actual status transport is read-only and retains original identity/hash',
    () async {
      final attempt = AdminNotificationAttempt(
        userId: notificationTestUser,
        clubId: 24,
        operationId: notificationTestOperation,
        arguments: _args,
      );
      final client = _client((r) async {
        expect(jsonDecode(r.body), {
          'action': 'status',
          'operation_id': notificationTestOperation,
          'club_id': 24,
        });
        return _response(r, {
          'success': true,
          'data': notificationTestReceipt(
            attempt,
            state: 'unknown',
            status: 'unknown',
            unknown: 1,
            sent: 0,
          ),
        });
      });
      addTearDown(client.dispose);
      await client.auth.recoverSession(
        jsonEncode(staffSession(user: notificationTestUser)),
      );
      final receipt = await AdminRepository(
        client: client,
      ).submitAdminNotification(attempt, submit: false);
      expect(receipt['command']['state'], 'unknown');
    },
  );

  test(
    'actual current GLOBAL assignment, null club and fresh assurance are required',
    () async {
      var rows = <Map<String, Object?>>[];
      var allowed = false;
      var edgeCalls = 0;
      final client = _client((r) async {
        if (r.url.path.endsWith('admin_role_assignments')) {
          expect(r.url.queryParameters['user_id'], 'eq.$notificationTestUser');
          expect(r.url.queryParameters['revoked_at'], 'is.null');
          return _response(r, rows);
        }
        if (r.url.path.endsWith('staff_step_up_allowed')) {
          return _response(r, allowed);
        }
        edgeCalls++;
        throw StateError('Unexpected edge request');
      });
      addTearDown(client.dispose);
      await client.auth.recoverSession(
        jsonEncode(staffSession(user: notificationTestUser)),
      );
      final repository = AdminRepository(client: client);
      for (final row in [
        {
          'role': 'club_admin',
          'club_id': 24,
          'is_active': true,
          'revoked_at': null,
        },
        {'role': 'admin', 'club_id': 24, 'is_active': true, 'revoked_at': null},
        {
          'role': 'admin',
          'club_id': null,
          'is_active': true,
          'revoked_at': '2026-10-02T00:00:00Z',
        },
      ]) {
        rows = [row];
        allowed = true;
        expect(await repository.isCurrentUserNotificationAdmin(), isFalse);
      }
      rows = [
        {
          'role': 'admin',
          'club_id': null,
          'is_active': true,
          'revoked_at': null,
        },
      ];
      allowed = false;
      expect(await repository.isCurrentUserNotificationAdmin(), isFalse);
      allowed = true;
      expect(await repository.isCurrentUserNotificationAdmin(), isTrue);
      expect(edgeCalls, 0);
    },
  );

  for (final change in ['logout', 'switch', 'same-user-login']) {
    test('actual delayed Edge result cannot regain $change owner', () async {
      final requestStarted = Completer<void>();
      final result = Completer<http.Response>();
      final attempt = AdminNotificationAttempt(
        userId: notificationTestUser,
        clubId: 24,
        operationId: notificationTestOperation,
        arguments: _args,
      );
      late http.Request original;
      final client = _client((r) async {
        original = r;
        requestStarted.complete();
        return result.future;
      });
      addTearDown(client.dispose);
      await client.auth.recoverSession(
        jsonEncode(staffSession(user: notificationTestUser)),
      );
      final pending = AdminRepository(
        client: client,
      ).submitAdminNotification(attempt, submit: true);
      final assertion = expectLater(
        pending,
        throwsA(isA<SupabaseSessionChangedException>()),
      );
      await requestStarted.future;
      if (change == 'logout') {
        await client.auth.signOut(scope: SignOutScope.local);
      } else {
        await client.auth.recoverSession(
          jsonEncode(
            staffSession(
              user: change == 'switch'
                  ? '99969000-0000-4000-8000-000000000002'
                  : notificationTestUser,
              extra: {'session_id': 'new-login-session'},
            ),
          ),
        );
      }
      result.complete(
        _response(original, {
          'success': true,
          'data': notificationTestReceipt(attempt),
        }),
      );
      await assertion;
    });
  }
}

SupabaseClient _client(Future<http.Response> Function(http.Request) handler) =>
    SupabaseClient(
      'https://notification.test',
      'local-test',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((r) async {
        if (r.url.path.endsWith('/logout')) return _response(r, {});
        return handler(r);
      }),
    );
http.Response _response(http.Request r, Object value) => http.Response(
  jsonEncode(value),
  200,
  request: r,
  headers: {'content-type': 'application/json'},
);
