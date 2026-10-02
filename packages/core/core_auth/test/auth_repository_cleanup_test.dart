import 'dart:async';
import 'dart:convert';

import 'package:core_auth/core_auth.dart';
import 'package:core_network/core_network.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

String _sessionJson(String user, int generation, {String? sessionId}) {
  String part(Object data) =>
      base64Url.encode(utf8.encode(jsonEncode(data))).replaceAll('=', '');
  final token =
      '${part({'alg': 'none', 'typ': 'JWT'})}.'
      '${part({'sub': user, 'exp': 4102444800, 'generation': generation, if (sessionId != null) 'session_id': sessionId})}.local-fixture';
  return jsonEncode({
    'access_token': token,
    'refresh_token': 'local-refresh-$user-$generation',
    'token_type': 'bearer',
    'expires_in': 3600,
    'user': {
      'id': user,
      'aud': 'authenticated',
      'app_metadata': {},
      'user_metadata': {},
      'created_at': '2026-09-30T00:00:00Z',
    },
  });
}

Future<void> _requestsStarted(List<http.Request> requests, int count) async {
  for (var attempt = 0; attempt < 400 && requests.length < count; attempt++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(
    requests.length,
    greaterThanOrEqualTo(count),
    reason: 'Controlled SDK request did not start',
  );
}

class _DelayedPkceStorage extends GotrueAsyncStorage {
  final removal = Completer<void>();
  bool removing = false;
  @override
  Future<String?> getItem({required String key}) async => null;
  @override
  Future<void> setItem({required String key, required String value}) async {}
  @override
  Future<void> removeItem({required String key}) async {
    removing = true;
    await removal.future;
  }
}

http.Response respond(http.Request request, Object? body, {int status = 200}) =>
    http.Response(
      jsonEncode(body),
      status,
      request: request,
      headers: {'content-type': 'application/json'},
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<SupabaseClient> clients;
  late List<http.Request> requests;
  late Completer<void> cleanup;
  late SupabaseClient current;
  late AuthRepository repository;
  late List<String?> unregisteredUsers;
  Future<http.Response> Function(http.Request)? responseHook;

  Future<SupabaseClient> createClient(
    String user,
    int generation, {
    String? sessionId,
    GotrueAsyncStorage? storage,
  }) async {
    final client = SupabaseClient(
      'https://local-auth-fixture.invalid',
      'sb_publishable_local_fixture',
      authOptions: AuthClientOptions(
        autoRefreshToken: false,
        pkceAsyncStorage: storage,
      ),
      httpClient: MockClient((request) async {
        requests.add(request);
        if (responseHook != null) return responseHook!(request);
        if (request.url.path.endsWith('/logout')) {
          return http.Response(
            '{}',
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        if (request.url.path.endsWith('/delete-account')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'request_id': jsonDecode(request.body)['request_id'],
                'status': 'deletion_pending',
                'access_revoked': true,
              },
            }),
            202,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        throw StateError('Unexpected local fixture request');
      }),
    );
    clients.add(client);
    await client.auth.setInitialSession(
      _sessionJson(user, generation, sessionId: sessionId),
    );
    return client;
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    clients = [];
    requests = [];
    cleanup = Completer<void>();
    unregisteredUsers = [];
    responseHook = null;
    current = await createClient('supporter-a', 1, sessionId: 'session-a');
    repository = AuthRepository(
      clubId: '1',
      clientProvider: () => current,
      unregisterDevice: ({String? userId}) {
        unregisteredUsers.add(userId);
        return cleanup.future;
      },
    );
  });
  tearDown(() async {
    for (final client in clients) {
      await client.dispose();
    }
  });

  for (final operation in ['logout', 'deletion']) {
    for (final replacement in ['account', 'same-user session', 'client']) {
      test(
        '$operation aborts after $replacement replacement during cleanup',
        () async {
          final oldClient = current;
          final future = operation == 'logout'
              ? repository.signOut()
              : repository.deleteAccount('supporter-a');
          final assertion = expectLater(future, throwsA(isA<StateError>()));
          if (replacement == 'client') {
            current = await createClient(
              'supporter-a',
              2,
              sessionId: 'session-a',
            );
          } else {
            await current.auth.setInitialSession(
              _sessionJson(
                replacement == 'account' ? 'supporter-b' : 'supporter-a',
                2,
                sessionId: 'session-b',
              ),
            );
          }
          cleanup.complete();
          await assertion;
          expect(requests, isEmpty);
          expect(
            current.auth.currentUser?.id,
            replacement == 'account' ? 'supporter-b' : 'supporter-a',
          );
          expect(oldClient.auth.currentSession, isNotNull);
        },
      );
    }
  }

  test(
    'normal logout unregisters captured user and signs out locally',
    () async {
      final token = current.auth.currentSession!.accessToken;
      final future = repository.signOut();
      await Future<void>.delayed(Duration.zero);
      expect(unregisteredUsers, ['supporter-a']);
      cleanup.complete();
      await future;
      expect(current.auth.currentSession, isNull);
      expect(requests.single.url.path, '/auth/v1/logout');
      expect(requests.single.headers['authorization'], 'Bearer $token');
    },
  );

  test(
    'deletion pins captured account and bearer to the installed SDK request',
    () async {
      final token = current.auth.currentSession!.accessToken;
      final future = repository.deleteAccount('supporter-a');
      cleanup.complete();
      await future;
      expect(requests.single.url.path, '/functions/v1/delete-account');
      expect(jsonDecode(requests.single.body)['user_id'], 'supporter-a');
      expect(
        jsonDecode(requests.single.body)['request_id'],
        repository.latestAccountClosureReceipt!.requestId,
      );
      expect(requests.single.headers['authorization'], 'Bearer $token');
      expect(current.auth.currentUser!.id, 'supporter-a');
      expect(
        repository.latestAccountClosureReceipt?.status,
        'deletion_pending',
      );
      expect(repository.latestAccountClosureReceipt?.isComplete, isFalse);
    },
  );

  test(
    'lost closure response retains original capability and recovers pending status after local logout',
    () async {
      String? original;
      responseHook = (request) async {
        if (request.url.path.endsWith('/logout')) return respond(request, {});
        final sent = jsonDecode(request.body) as Map<String, dynamic>;
        final stored = await AccountClosureStore().read();
        expect(stored!.requestId, sent['request_id']);
        original ??= sent['request_id'] as String;
        if (request.url.queryParameters['action'] == 'status') {
          return respond(request, {
            'success': true,
            'data': {
              'request_id': original,
              'status': 'deletion_pending',
              'access_revoked': true,
            },
          });
        }
        return respond(request, {'error': 'Service unavailable'}, status: 503);
      };
      final first = repository.deleteAccount('supporter-a');
      cleanup.complete();
      await expectLater(first, throwsA(isA<StateError>()));
      final beforeRestart = await AccountClosureStore().read();
      expect(beforeRestart!.requestId, original);
      expect(beforeRestart.status, 'requesting');
      await repository.signOutClosedAccount('supporter-a');
      expect(current.auth.currentSession, isNull);
      final recovered = await repository.refreshAccountClosureStatus(
        beforeRestart,
      );
      expect(recovered.requestId, original);
      expect(recovered.status, 'deletion_pending');
      expect((await AccountClosureStore().read())!.requestId, original);
      expect(recovered.isComplete, isFalse);
    },
  );

  for (final responseData in <Map<String, Object>>[
    {'status': 'deletion_pending', 'access_revoked': false},
    {'status': 'completed'},
    {'status': 'unknown', 'access_revoked': true},
  ]) {
    test(
      'status recovery rejects an unconfirmed or unknown receipt $responseData',
      () async {
        final receipt = await AccountClosureStore().prepare();
        responseHook = (request) async => respond(request, {
          'success': true,
          'data': {'request_id': receipt.requestId, ...responseData},
        });
        await expectLater(
          repository.refreshAccountClosureStatus(receipt),
          throwsA(isA<StateError>()),
        );
        final retained = await AccountClosureStore().read();
        expect(retained!.requestId, receipt.requestId);
        expect(retained.status, 'requesting');
      },
    );
  }

  test(
    'deletion rejects a different requested account before device cleanup',
    () async {
      final future = repository.deleteAccount('supporter-b');
      final assertion = expectLater(future, throwsA(isA<StateError>()));
      cleanup.complete();
      await assertion;
      expect(unregisteredUsers, isEmpty);
      expect(requests, isEmpty);
    },
  );

  Map<String, dynamic> profileRow(String user, {int clubId = 1}) => {
    'id': user,
    'club_id': clubId,
    'display_name': 'Local supporter',
    'updated_at': '2026-09-30T00:00:00Z',
  };

  for (final operation in ['logout', 'deletion']) {
    test('$operation permits ordinary same-session token refresh', () async {
      final future = operation == 'logout'
          ? repository.signOut()
          : repository.deleteAccount('supporter-a');
      await current.auth.recoverSession(
        _sessionJson('supporter-a', 2, sessionId: 'session-a'),
      );
      final refreshed = current.auth.currentSession!.accessToken;
      cleanup.complete();
      await future;
      expect(requests.single.headers['authorization'], 'Bearer $refreshed');
    });
    test(
      '$operation rejects silent same-user replacement without session IDs',
      () async {
        await current.auth.setInitialSession(_sessionJson('supporter-a', 1));
        await Future<void>.delayed(Duration.zero);
        final future = operation == 'logout'
            ? repository.signOut()
            : repository.deleteAccount('supporter-a');
        final assertion = expectLater(future, throwsA(isA<StateError>()));
        await current.auth.recoverSession(_sessionJson('supporter-a', 2));
        cleanup.complete();
        await assertion;
        expect(requests, isEmpty);
      },
    );
  }

  test(
    'normal restore retains captured session and merges own private row',
    () async {
      final token = current.auth.currentSession!.accessToken;
      responseHook = (request) async => respond(
        request,
        request.url.path.endsWith('/profiles')
            ? profileRow('supporter-a')
            : {
                'user_id': 'supporter-a',
                'momo_number': 'local-private-contact',
              },
      );
      final result = await repository.restoreCurrentUser();
      expect(result!.id, 'supporter-a');
      expect(result.clubId, '1');
      expect(result.momoNumber, 'local-private-contact');
      expect(requests, hasLength(2));
      expect(
        requests.every(
          (request) => request.headers['authorization'] == 'Bearer $token',
        ),
        isTrue,
      );
    },
  );

  test(
    'restore discards delayed old profile after global client replacement',
    () async {
      final profile = Completer<http.Response>();
      responseHook = (request) async {
        if (request.url.path.endsWith('/profiles')) return profile.future;
        return respond(request, {'user_id': 'supporter-a'});
      };
      final future = repository.restoreCurrentUser();
      final assertion = expectLater(future, throwsA(isA<AuthRestoreFailure>()));
      await _requestsStarted(requests, 2);
      final oldRequest = requests.singleWhere(
        (request) => request.url.path.endsWith('/profiles'),
      );
      current = await createClient('supporter-b', 2, sessionId: 'session-b');
      profile.complete(respond(oldRequest, profileRow('supporter-a')));
      await assertion;
      expect(requests, hasLength(2));
      expect(requests.every((request) => request.method == 'GET'), isTrue);
      expect(current.auth.currentUser!.id, 'supporter-b');
    },
  );

  test(
    'retrying profile read stops before retrying under replacement authority',
    () async {
      responseHook = (request) async {
        if (request.url.path.endsWith('/profiles')) {
          throw http.ClientException('local connection failure');
        }
        return respond(request, {'user_id': 'supporter-a'});
      };
      final future = repository.restoreCurrentUser();
      final assertion = expectLater(future, throwsA(isA<AuthRestoreFailure>()));
      await _requestsStarted(requests, 2);
      current = await createClient('supporter-b', 2, sessionId: 'session-b');
      await assertion;
      expect(requests, hasLength(2));
      expect(requests.every((request) => request.method == 'GET'), isTrue);
    },
  );

  test(
    'profile write completion cannot hydrate a replacement session',
    () async {
      final write = Completer<http.Response>();
      responseHook = (request) => write.future;
      final future = repository.updateProfile(
        const UserProfile(
          id: 'supporter-a',
          clubId: '1',
          displayName: 'Reviewed name',
          updatedAt: '2026-09-30T00:00:00Z',
        ),
      );
      final assertion = expectLater(
        future,
        throwsA(isA<SupabaseSessionChangedException>()),
      );
      await _requestsStarted(requests, 1);
      final oldRequest = requests.single;
      final oldBearer = current.auth.currentSession!.accessToken;
      await current.auth.recoverSession(
        _sessionJson('supporter-a', 2, sessionId: 'session-b'),
      );
      write.complete(respond(oldRequest, {'id': 'supporter-a'}));
      await assertion;
      expect(requests, hasLength(1));
      expect(oldRequest.method, 'PATCH');
      expect(oldRequest.headers['authorization'], 'Bearer $oldBearer');
    },
  );

  test(
    'bootstrap completion stops before private contact write on account switch',
    () async {
      final write = Completer<http.Response>();
      responseHook = (request) => write.future;
      final future = repository.updateProfile(
        const UserProfile(
          id: 'supporter-a',
          clubId: '1',
          displayName: 'Reviewed name',
        ),
      );
      final assertion = expectLater(
        future,
        throwsA(isA<SupabaseSessionChangedException>()),
      );
      await _requestsStarted(requests, 1);
      final oldRequest = requests.single;
      await current.auth.setInitialSession(
        _sessionJson('supporter-b', 2, sessionId: 'session-b'),
      );
      write.complete(respond(oldRequest, {'id': 'supporter-a'}));
      await assertion;
      expect(requests, hasLength(1));
      expect(oldRequest.url.path, '/rest/v1/rpc/bootstrap_supporter_profile');
    },
  );

  test(
    'anonymous sign-in on a replaced SDK cannot bootstrap the new account',
    () async {
      final signup = Completer<http.Response>();
      responseHook = (request) => signup.future;
      final future = repository.signInAnonymously();
      final assertion = expectLater(
        future,
        throwsA(isA<SupabaseSessionChangedException>()),
      );
      await _requestsStarted(requests, 1);
      final oldRequest = requests.single;
      current = await createClient('supporter-b', 2, sessionId: 'session-b');
      signup.complete(
        respond(
          oldRequest,
          jsonDecode(_sessionJson('supporter-a', 3, sessionId: 'session-c')),
        ),
      );
      await assertion;
      expect(requests, hasLength(1));
      expect(oldRequest.url.path, '/auth/v1/signup');
      expect(current.auth.currentUser!.id, 'supporter-b');
    },
  );

  test(
    'profile writes reject foreign identity and club before SDK requests',
    () async {
      for (final profile in [
        const UserProfile(id: 'supporter-b', clubId: '1'),
        const UserProfile(id: 'supporter-a', clubId: '2'),
      ]) {
        await expectLater(
          repository.updateProfile(profile),
          throwsA(isA<StateError>()),
        );
      }
      expect(requests, isEmpty);
    },
  );
  for (final method in ['anonymous', 'sign-in OTP', 'phone-change OTP']) {
    test(
      '$method retains legitimate SDK sign-in and hydrates its own profile',
      () async {
        responseHook = (request) async {
          if (request.url.path.startsWith('/auth/v1/')) {
            return respond(
              request,
              jsonDecode(
                _sessionJson('supporter-a', 3, sessionId: 'session-c'),
              ),
            );
          }
          if (request.url.path.endsWith('/bootstrap_supporter_profile')) {
            expect(jsonDecode(request.body)['p_club_id'], 1);
            return respond(request, {'id': 'supporter-a'});
          }
          if (request.url.path.endsWith('/profiles')) {
            return respond(request, profileRow('supporter-a'));
          }
          return respond(request, {'user_id': 'supporter-a'});
        };
        final profile = switch (method) {
          'anonymous' => await repository.signInAnonymously(),
          'sign-in OTP' => await repository.verifyPhoneSignInOtp(
            phone: '+10000000001',
            token: 'local-fixture',
          ),
          _ => await repository.verifyPhoneVerificationOtp(
            phone: '+10000000001',
            token: 'local-fixture',
          ),
        };
        expect(profile.id, 'supporter-a');
        expect(profile.clubId, '1');
        expect(requests, hasLength(5));
        final token = current.auth.currentSession!.accessToken;
        expect(
          requests
              .skip(1)
              .every(
                (request) =>
                    request.headers['authorization'] == 'Bearer $token',
              ),
          isTrue,
        );
      },
    );
  }

  test(
    'missing own profile restores through guarded bootstrap and reread',
    () async {
      var reads = 0;
      responseHook = (request) async {
        if (request.url.path.endsWith('/profiles')) {
          return respond(
            request,
            reads++ == 0 ? null : profileRow('supporter-a'),
          );
        }
        if (request.url.path.endsWith('/bootstrap_supporter_profile')) {
          return respond(request, {'id': 'supporter-a'});
        }
        return respond(request, {'user_id': 'supporter-a'});
      };
      final profile = await repository.restoreCurrentUser();
      expect(profile!.id, 'supporter-a');
      expect(requests, hasLength(6));
      expect(
        requests.where((request) => request.method == 'POST'),
        hasLength(2),
      );
    },
  );

  test(
    'successful compare-and-set profile update rereads only its own identity',
    () async {
      responseHook = (request) async => respond(
        request,
        request.method == 'PATCH'
            ? {'id': 'supporter-a'}
            : request.url.path.endsWith('/profiles')
            ? profileRow('supporter-a')
            : {'user_id': 'supporter-a'},
      );
      final profile = await repository.updateProfile(
        const UserProfile(
          id: 'supporter-a',
          clubId: '1',
          displayName: 'Reviewed name',
          updatedAt: '2026-09-30T00:00:00Z',
        ),
      );
      expect(profile.id, 'supporter-a');
      expect(requests, hasLength(3));
      expect(
        requests.first.url.queryParameters['updated_at'],
        'eq.2026-09-30T00:00:00Z',
      );
    },
  );

  test(
    'profile compare-and-set conflict remains finite without a fallback write',
    () async {
      responseHook = (request) async => respond(request, null);
      await expectLater(
        repository.updateProfile(
          const UserProfile(
            id: 'supporter-a',
            clubId: '1',
            updatedAt: '2026-09-30T00:00:00Z',
          ),
        ),
        throwsA(isA<ProfileConflictException>()),
      );
      expect(requests, hasLength(1));
      expect(requests.single.method, 'PATCH');
    },
  );

  for (final clubId in [1, 2, 3, 4, 5]) {
    test(
      'configured local club $clubId rejects a foreign restored row',
      () async {
        repository = AuthRepository(
          clubId: '$clubId',
          clientProvider: () => current,
        );
        responseHook = (request) async => respond(
          request,
          request.url.path.endsWith('/profiles')
              ? profileRow('supporter-a', clubId: clubId == 5 ? 1 : clubId + 1)
              : {'user_id': 'supporter-a'},
        );
        await expectLater(
          repository.restoreCurrentUser(),
          throwsA(isA<AuthRestoreFailure>()),
        );
        expect(requests.every((request) => request.method == 'GET'), isTrue);
      },
    );
  }
  for (final scenario in [
    'concurrent OTP',
    'verification during logout cleanup',
    'anonymous after newer login',
  ]) {
    test('SDK mutation ordering: $scenario retains the newer authority', () async {
      final firstResponse = Completer<http.Response>();
      final secondResponse = Completer<http.Response>();
      final observed = <String>[];
      final subscription = current.auth.onAuthStateChange.listen((event) {
        observed.add('${event.event.name}:${event.session?.user.id ?? 'none'}');
      }, onError: (Object error, StackTrace stackTrace) {});
      responseHook = (request) async {
        if (request.url.path.startsWith('/auth/v1/') &&
            !request.url.path.endsWith('/logout')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          return body['token'] == 'second'
              ? secondResponse.future
              : firstResponse.future;
        }
        if (request.url.path.endsWith('/logout')) return respond(request, {});
        final user =
            request.url.queryParameters['id']?.replaceFirst('eq.', '') ??
            request.url.queryParameters['user_id']?.replaceFirst('eq.', '') ??
            current.auth.currentUser!.id;
        return respond(
          request,
          request.url.path.endsWith('/profiles')
              ? profileRow(user)
              : {'user_id': user},
        );
      };
      final old = scenario == 'anonymous after newer login'
          ? repository.signInAnonymously()
          : repository.verifyPhoneSignInOtp(
              phone: '+10000000001',
              token: 'first',
            );
      final oldResult = old.then<Object>(
        (value) => value,
        onError: (Object error) => error,
      );
      await _requestsStarted(requests, 1);
      final oldRequest = requests.first;
      Future<Object>? logoutResult;
      if (scenario == 'concurrent OTP') {
        final newer = repository.verifyPhoneSignInOtp(
          phone: '+10000000002',
          token: 'second',
        );
        await _requestsStarted(requests, 2);
        final newerRequest = requests[1];
        secondResponse.complete(
          respond(
            newerRequest,
            jsonDecode(_sessionJson('supporter-b', 2, sessionId: 'session-b')),
          ),
        );
        expect((await newer).id, 'supporter-b');
      } else if (scenario == 'verification during logout cleanup') {
        logoutResult = repository.signOut().then<Object>(
          (_) => 'signed-out',
          onError: (Object error) => error,
        );
      } else {
        await current.auth.setInitialSession(
          _sessionJson('supporter-b', 2, sessionId: 'session-b'),
        );
      }
      firstResponse.complete(
        respond(
          oldRequest,
          jsonDecode(_sessionJson('supporter-a', 3, sessionId: 'session-c')),
        ),
      );
      final obsolete = await oldResult;
      cleanup.complete();
      if (logoutResult != null) await logoutResult;
      await Future<void>.delayed(Duration.zero);
      final active = current.auth.currentUser?.id;
      await subscription.cancel();
      // Diagnostic text contains only synthetic identities, events and result types.
      debugPrint(
        'AUTH_SDK_ORDERING ${jsonEncode({'scenario': scenario, 'oldResultType': obsolete.runtimeType.toString(), 'activeUser': active, 'events': observed})}',
      );
      expect(obsolete, isA<StateError>());
      expect(
        active,
        scenario == 'verification during logout cleanup'
            ? isNull
            : 'supporter-b',
      );
      expect(observed, isNot(contains('signedIn:supporter-a')));
    });
  }
  test(
    'SDK account edit cannot overwrite a newer account after its reply',
    () async {
      final edit = Completer<http.Response>();
      responseHook = (_) => edit.future;
      final pending = repository.requestPhoneVerificationOtp(
        phone: '+10000000001',
      );
      final assertion = expectLater(pending, throwsA(isA<StateError>()));
      await _requestsStarted(requests, 1);
      final request = requests.single;
      await current.auth.setInitialSession(
        _sessionJson('supporter-b', 2, sessionId: 'session-b'),
      );
      final user = jsonDecode(_sessionJson('supporter-a', 1))['user'];
      edit.complete(respond(request, {'user': user}));
      await assertion;
      expect(current.auth.currentUser!.id, 'supporter-b');
      expect(request.method, 'PUT');
    },
  );

  test(
    'pending OTP remains valid across an actual same-session SDK refresh',
    () async {
      final verify = Completer<http.Response>();
      responseHook = (request) async {
        if (request.url.path.endsWith('/verify')) return verify.future;
        if (request.url.path.endsWith('/token')) {
          return respond(
            request,
            jsonDecode(_sessionJson('supporter-a', 2, sessionId: 'session-a')),
          );
        }
        return respond(
          request,
          request.url.path.endsWith('/profiles')
              ? profileRow('supporter-a')
              : {'user_id': 'supporter-a'},
        );
      };
      final pending = repository.verifyPhoneSignInOtp(
        phone: '+10000000001',
        token: 'first',
      );
      await _requestsStarted(requests, 1);
      final request = requests.single;
      await current.auth.refreshSession();
      verify.complete(
        respond(
          request,
          jsonDecode(_sessionJson('supporter-a', 3, sessionId: 'session-c')),
        ),
      );
      expect((await pending).id, 'supporter-a');
      expect(current.auth.currentUser!.id, 'supporter-a');
      expect(
        requests.where((request) => request.url.path.endsWith('/token')),
        hasLength(1),
      );
    },
  );

  test(
    'successful SDK auth event still precedes delayed repository hydration',
    () async {
      final profile = Completer<http.Response>();
      var sdkAuthenticated = false;
      var replyCompleted = false;
      final subscription = current.auth.onAuthStateChange.listen((event) {
        if (event.event == AuthChangeEvent.signedIn &&
            event.session?.user.id == 'supporter-b') {
          sdkAuthenticated = true;
          expect(replyCompleted, isFalse);
        }
      }, onError: (Object error, StackTrace stackTrace) {});
      responseHook = (request) async {
        if (request.url.path.endsWith('/verify')) {
          return respond(
            request,
            jsonDecode(_sessionJson('supporter-b', 2, sessionId: 'session-b')),
          );
        }
        if (request.url.path.endsWith('/profiles')) return profile.future;
        return respond(request, {'user_id': 'supporter-b'});
      };
      final pending = repository
          .verifyPhoneSignInOtp(phone: '+10000000002', token: 'second')
          .then((value) {
            replyCompleted = true;
            return value;
          });
      await _requestsStarted(requests, 5);
      final request = requests.singleWhere(
        (request) => request.url.path.endsWith('/profiles'),
      );
      expect(sdkAuthenticated, isTrue);
      expect(replyCompleted, isFalse);
      profile.complete(respond(request, profileRow('supporter-b')));
      expect((await pending).id, 'supporter-b');
      await subscription.cancel();
    },
  );
  for (final replacement in ['same SDK', 'replacement SDK']) {
    test(
      'obsolete repository cancellation preserves newer login on $replacement',
      () async {
        final first = Completer<http.Response>();
        final second = Completer<http.Response>();
        responseHook = (request) async {
          if (request.url.path.endsWith('/verify')) {
            return jsonDecode(request.body)['token'] == 'first'
                ? first.future
                : second.future;
          }
          return respond(
            request,
            request.url.path.endsWith('/profiles')
                ? profileRow('supporter-b')
                : {'user_id': 'supporter-b'},
          );
        };
        final obsoleteRepository = repository;
        final old = obsoleteRepository.verifyPhoneSignInOtp(
          phone: '+10000000001',
          token: 'first',
        );
        final assertion = expectLater(old, throwsA(isA<StateError>()));
        await _requestsStarted(requests, 1);
        final oldRequest = requests.first;
        if (replacement == 'replacement SDK') {
          current = await createClient(
            'supporter-b',
            2,
            sessionId: 'session-b',
          );
        }
        final newRepository = AuthRepository(
          clubId: '1',
          clientProvider: () => current,
        );
        final newer = newRepository.verifyPhoneSignInOtp(
          phone: '+10000000002',
          token: 'second',
        );
        await _requestsStarted(requests, 2);
        final newRequest = requests[1];
        obsoleteRepository.invalidatePendingAuthentication();
        first.complete(
          respond(
            oldRequest,
            jsonDecode(_sessionJson('supporter-a', 3, sessionId: 'session-c')),
          ),
        );
        await assertion;
        second.complete(
          respond(
            newRequest,
            jsonDecode(_sessionJson('supporter-b', 4, sessionId: 'session-d')),
          ),
        );
        expect((await newer).id, 'supporter-b');
        expect(current.auth.currentUser!.id, 'supporter-b');
      },
    );
  }

  test(
    'repository scope invalidation stops delayed hydration with unchanged SDK',
    () async {
      final profile = Completer<http.Response>();
      responseHook = (request) async => request.url.path.endsWith('/profiles')
          ? profile.future
          : respond(request, {'user_id': 'supporter-a'});
      final future = repository.restoreCurrentUser();
      final assertion = expectLater(future, throwsA(isA<AuthRestoreFailure>()));
      await _requestsStarted(requests, 2);
      final request = requests.singleWhere(
        (request) => request.url.path.endsWith('/profiles'),
      );
      repository.invalidatePendingAuthentication();
      profile.complete(respond(request, profileRow('supporter-a')));
      await assertion;
      expect(current.auth.currentUser!.id, 'supporter-a');
      expect(requests, hasLength(2));
    },
  );

  test(
    'repository scope invalidation stops bootstrap continuation with same session',
    () async {
      final bootstrap = Completer<http.Response>();
      responseHook = (_) => bootstrap.future;
      final future = repository.updateProfile(
        const UserProfile(
          id: 'supporter-a',
          clubId: '1',
          displayName: 'Reviewed name',
        ),
      );
      final assertion = expectLater(
        future,
        throwsA(isA<SupabaseSessionChangedException>()),
      );
      await _requestsStarted(requests, 1);
      final request = requests.single;
      repository.invalidatePendingAuthentication();
      bootstrap.complete(respond(request, {'id': 'supporter-a'}));
      await assertion;
      expect(requests, hasLength(1));
      expect(current.auth.currentUser!.id, 'supporter-a');
    },
  );

  test(
    'actual notifier disposal cancels its repository pending SDK verification',
    () async {
      final verify = Completer<http.Response>();
      responseHook = (request) async => request.url.path.endsWith('/verify')
          ? verify.future
          : respond(
              request,
              request.url.path.endsWith('/profiles')
                  ? profileRow('supporter-a')
                  : {'user_id': 'supporter-a'},
            );
      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
      );
      container.read(authStateProvider);
      final future = repository.verifyPhoneSignInOtp(
        phone: '+10000000001',
        token: 'first',
      );
      final assertion = expectLater(future, throwsA(isA<StateError>()));
      await _requestsStarted(requests, 1);
      final request = requests.singleWhere(
        (request) => request.url.path.endsWith('/verify'),
      );
      final requestCount = requests.length;
      container.dispose();
      verify.complete(
        respond(
          request,
          jsonDecode(_sessionJson('supporter-b', 2, sessionId: 'session-b')),
        ),
      );
      await assertion;
      expect(current.auth.currentUser!.id, 'supporter-a');
      expect(requests, hasLength(requestCount));
    },
  );
  test(
    'SDK logout completion cannot publish signedOut for a newer login',
    () async {
      final storage = _DelayedPkceStorage();
      current = await createClient(
        'supporter-a',
        1,
        sessionId: 'session-a',
        storage: storage,
      );
      final events = <String>[];
      final subscription = current.auth.onAuthStateChange.listen((event) {
        events.add('${event.event.name}:${event.session?.user.id ?? 'none'}');
      }, onError: (Object error, StackTrace stackTrace) {});
      final logout = current.auth.signOut();
      for (var attempt = 0; attempt < 200 && !storage.removing; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }
      expect(storage.removing, isTrue);
      await current.auth.setInitialSession(
        _sessionJson('supporter-b', 2, sessionId: 'session-b'),
      );
      storage.removal.complete();
      await logout;
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();
      debugPrint(
        'AUTH_SDK_LOGOUT_ORDERING ${jsonEncode({'activeUser': current.auth.currentUser?.id, 'events': events})}',
      );
      expect(current.auth.currentUser!.id, 'supporter-b');
      expect(events.where((event) => event.startsWith('signedOut:')), isEmpty);
    },
  );
  test(
    'SDK delayed-storage logout still publishes its own signedOut',
    () async {
      final storage = _DelayedPkceStorage();
      current = await createClient('supporter-a', 1, storage: storage);
      final events = <String>[];
      final subscription = current.auth.onAuthStateChange.listen((event) {
        events.add('${event.event.name}:${event.session?.user.id ?? 'none'}');
      }, onError: (Object error, StackTrace stackTrace) {});
      final logout = current.auth.signOut();
      for (var attempt = 0; attempt < 200 && !storage.removing; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }
      storage.removal.complete();
      await logout;
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();
      expect(storage.removing, isTrue);
      expect(current.auth.currentSession, isNull);
      expect(events.where((event) => event == 'signedOut:none'), hasLength(1));
      expect(requests.single.url.path, endsWith('/logout'));
    },
  );
}
