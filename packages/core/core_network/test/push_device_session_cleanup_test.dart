import 'dart:async';
import 'dart:convert';

import 'package:core_network/core_network.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

String _sessionJson(String user, int generation, {String? sessionId}) {
  String part(Object data) =>
      base64Url.encode(utf8.encode(jsonEncode(data))).replaceAll('=', '');
  return jsonEncode({
    'access_token':
        '${part({'alg': 'none', 'typ': 'JWT'})}.'
        '${part({'sub': user, 'exp': 4102444800, 'generation': generation, if (sessionId != null) 'session_id': sessionId})}.local-fixture',
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

NotificationSettings _settings(AuthorizationStatus status) =>
    NotificationSettings(
      alert: AppleNotificationSetting.enabled,
      announcement: AppleNotificationSetting.enabled,
      authorizationStatus: status,
      badge: AppleNotificationSetting.enabled,
      carPlay: AppleNotificationSetting.enabled,
      lockScreen: AppleNotificationSetting.enabled,
      notificationCenter: AppleNotificationSetting.enabled,
      showPreviews: AppleShowPreviewSetting.always,
      timeSensitive: AppleNotificationSetting.enabled,
      criticalAlert: AppleNotificationSetting.disabled,
      sound: AppleNotificationSetting.enabled,
      providesAppNotificationSettings: AppleNotificationSetting.disabled,
    );

class _Messaging extends Fake implements FirebaseMessaging {
  _Messaging(this.refresh);
  final StreamController<String> refresh;
  final operations = <String>[];
  String? token = 'device-a';
  bool autoInit = true;
  AuthorizationStatus permission = AuthorizationStatus.authorized;
  Future<void> Function(bool enabled)? autoInitHook;
  Future<void> Function()? deleteHook;
  Future<String?> Function()? tokenHook;
  Future<NotificationSettings> Function()? permissionHook;
  Future<void> Function(String topic)? subscribeHook;
  @override
  Future<NotificationSettings> requestPermission({
    bool alert = true,
    bool announcement = false,
    bool badge = true,
    bool carPlay = false,
    bool criticalAlert = false,
    bool provisional = false,
    bool providesAppNotificationSettings = false,
    bool sound = true,
  }) async =>
      permissionHook == null ? _settings(permission) : await permissionHook!();
  @override
  Future<void> subscribeToTopic(String topic) async {
    operations.add('subscribe-$topic-start');
    await subscribeHook?.call(topic);
    operations.add('subscribe-$topic-end');
  }

  @override
  Future<void> unsubscribeFromTopic(String topic) async {
    operations.add('unsubscribe-$topic');
  }

  @override
  Stream<String> get onTokenRefresh => refresh.stream;
  @override
  Future<NotificationSettings> getNotificationSettings() async =>
      _settings(permission);
  @override
  Future<void> setAutoInitEnabled(bool enabled) async {
    operations.add('auto-init-$enabled-start');
    await autoInitHook?.call(enabled);
    autoInit = enabled;
    operations.add('auto-init-$enabled-end');
  }

  @override
  Future<String?> getToken({String? vapidKey}) async {
    operations.add('get-token');
    return tokenHook == null ? token : await tokenHook!();
  }

  @override
  Future<void> deleteToken() async {
    operations.add('delete-token-start');
    await deleteHook?.call();
    token = null;
    operations.add('delete-token-end');
  }
}

class _Runtime extends PushNotificationRuntime {
  _Runtime(this.current, this.device);
  SupabaseClient current;
  final _Messaging device;
  @override
  bool get isSupported => true;
  @override
  SupabaseClient get client => current;
  @override
  FirebaseMessaging get messaging => device;
}

Future<void> _until(bool Function() condition) async {
  for (var i = 0; i < 200 && !condition(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
  expect(
    condition(),
    isTrue,
    reason: 'Controlled local operation did not start',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<SupabaseClient> clients;
  late List<http.Request> requests;
  late _Messaging device;
  late _Runtime runtime;
  Future<http.Response> Function(http.Request)? responseHook;

  Future<SupabaseClient> createClient(
    String user,
    int generation, {
    String? sessionId,
  }) async {
    final client = SupabaseClient(
      'https://local-push-fixture.invalid',
      'sb_publishable_local_fixture',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        requests.add(request);
        if (responseHook != null) return responseHook!(request);
        if (request.url.path.endsWith('/user_notification_settings')) {
          return http.Response(
            '{"push_enabled":true}',
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        if (request.url.path.endsWith('/user_fcm_tokens')) {
          return http.Response(
            '',
            request.method == 'DELETE' ? 204 : 201,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        throw StateError('Unexpected local push fixture request');
      }),
    );
    clients.add(client);
    await client.auth.setInitialSession(
      _sessionJson(user, generation, sessionId: sessionId),
    );
    await Future<void>.delayed(Duration.zero);
    return client;
  }

  setUp(() async {
    clients = [];
    requests = [];
    responseHook = null;
    device = _Messaging(StreamController<String>.broadcast());
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/firebase_messaging'),
          (call) async {
            if (call.method == 'Messaging#startBackgroundIsolate') return null;
            throw StateError('Unexpected native fixture call');
          },
        );
    final client = await createClient('supporter-a', 1, sessionId: 'session-a');
    runtime = _Runtime(client, device);
    await PushNotificationService.configureRuntimeForTesting(runtime);
  });
  tearDown(() async {
    await PushNotificationService.configureRuntimeForTesting(null);
    await device.refresh.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/firebase_messaging'),
          null,
        );
    for (final client in clients) {
      await client.dispose();
    }
  });

  for (final replacement in ['account', 'same-user session', 'client']) {
    test(
      'cleanup stops after $replacement replacement during native shutdown',
      () async {
        final shutdown = Completer<void>();
        device.autoInitHook = (enabled) =>
            enabled ? Future<void>.value() : shutdown.future;
        final cleanup = PushNotificationService.unregisterCurrentDevice(
          userId: 'supporter-a',
          token: 'device-a',
        );
        await _until(() => device.operations.contains('auto-init-false-start'));
        if (replacement == 'client') {
          runtime.current = await createClient(
            'supporter-a',
            2,
            sessionId: 'session-a',
          );
        } else {
          await runtime.current.auth.setInitialSession(
            _sessionJson(
              replacement == 'account' ? 'supporter-b' : 'supporter-a',
              2,
              sessionId: 'session-b',
            ),
          );
        }
        shutdown.complete();
        await cleanup;
        expect(requests, isEmpty);
        expect(device.operations, isNot(contains('delete-token-start')));
        expect(device.token, 'device-a');
      },
    );
  }

  test(
    'normal cleanup deletes only the captured row and native token',
    () async {
      final token = runtime.current.auth.currentSession!.accessToken;
      await PushNotificationService.unregisterCurrentDevice(
        userId: 'supporter-a',
        token: 'device-a',
      );
      expect(requests.single.method, 'DELETE');
      expect(requests.single.url.queryParameters['user_id'], 'eq.supporter-a');
      expect(requests.single.url.queryParameters['token'], 'eq.device-a');
      expect(requests.single.headers['authorization'], 'Bearer $token');
      expect(device.token, isNull);
      expect(device.autoInit, isFalse);
    },
  );

  test('foreign account cleanup never shuts down the current device', () async {
    await PushNotificationService.unregisterCurrentDevice(
      userId: 'supporter-b',
      token: 'device-a',
    );
    expect(requests, isEmpty);
    expect(device.operations, isEmpty);
  });

  test(
    'new token registration survives obsolete cleanup waiting on shutdown',
    () async {
      await PushNotificationService.syncToken();
      requests.clear();
      device.operations.clear();
      final shutdown = Completer<void>();
      device.autoInitHook = (enabled) =>
          enabled ? Future<void>.value() : shutdown.future;
      final cleanup = PushNotificationService.unregisterCurrentDevice(
        userId: 'supporter-a',
        token: 'device-a',
      );
      await _until(() => device.operations.contains('auto-init-false-start'));
      device.token = 'device-b';
      final registration = PushNotificationService.syncToken();
      await _until(
        () => requests.any(
          (request) => request.url.path.endsWith('/user_notification_settings'),
        ),
      );
      shutdown.complete();
      await Future.wait([cleanup, registration]);
      expect(requests.where((request) => request.method == 'DELETE'), isEmpty);
      final upsert = requests.singleWhere(
        (request) => request.method == 'POST',
      );
      expect(jsonDecode(upsert.body)['token'], 'device-b');
      expect(jsonDecode(upsert.body)['user_id'], 'supporter-a');
      expect(device.token, 'device-b');
      expect(device.autoInit, isTrue);
      expect(device.operations, isNot(contains('delete-token-start')));
    },
  );

  test(
    'in-flight native deletion completes before a newer token is registered',
    () async {
      await PushNotificationService.syncToken();
      requests.clear();
      device.operations.clear();
      final deletion = Completer<void>();
      device.deleteHook = () => deletion.future;
      final cleanup = PushNotificationService.unregisterCurrentDevice(
        userId: 'supporter-a',
        token: 'device-a',
      );
      await _until(() => device.operations.contains('delete-token-start'));
      await runtime.current.auth.setInitialSession(
        _sessionJson('supporter-b', 2, sessionId: 'session-b'),
      );
      device.tokenHook = () async => 'device-b';
      final registration = PushNotificationService.syncToken();
      await _until(
        () => requests.any(
          (request) => request.url.path.endsWith('/user_notification_settings'),
        ),
      );
      expect(device.operations, isNot(contains('get-token')));
      deletion.complete();
      await Future.wait([cleanup, registration]);
      final deleteEnd = device.operations.indexOf('delete-token-end');
      final getToken = device.operations.indexOf('get-token');
      expect(deleteEnd, lessThan(getToken));
      expect(device.autoInit, isTrue);
      final upsert = requests.singleWhere(
        (request) => request.method == 'POST',
      );
      expect(jsonDecode(upsert.body)['user_id'], 'supporter-b');
      expect(jsonDecode(upsert.body)['token'], 'device-b');
      // The newer service fields cannot be cleared by the old completion.
      requests.clear();
      await PushNotificationService.unregisterCurrentDevice(
        userId: 'supporter-b',
      );
      expect(requests.single.url.queryParameters['token'], 'eq.device-b');
    },
  );

  test(
    'registration aborts when its account changes during preference lookup',
    () async {
      final response = Completer<http.Response>();
      responseHook = (_) => response.future;
      final registration = PushNotificationService.syncToken();
      await _until(() => requests.isNotEmpty);
      await runtime.current.auth.setInitialSession(
        _sessionJson('supporter-b', 2, sessionId: 'session-b'),
      );
      response.complete(
        http.Response(
          '{"push_enabled":true}',
          200,
          headers: {'content-type': 'application/json'},
          request: requests.last,
        ),
      );
      await registration;
      expect(requests, hasLength(1));
      expect(device.operations, isEmpty);
    },
  );

  test(
    'registration aborts after same-user session changes during token lookup',
    () async {
      final token = Completer<String?>();
      device.tokenHook = () => token.future;
      final registration = PushNotificationService.syncToken();
      await _until(() => device.operations.contains('get-token'));
      await runtime.current.auth.recoverSession(
        _sessionJson('supporter-a', 2, sessionId: 'session-b'),
      );
      token.complete('obsolete-device');
      await registration;
      expect(requests.where((request) => request.method == 'POST'), isEmpty);
    },
  );

  test(
    'same-session silent token refresh remains eligible for cleanup',
    () async {
      final shutdown = Completer<void>();
      device.autoInitHook = (enabled) =>
          enabled ? Future<void>.value() : shutdown.future;
      final cleanup = PushNotificationService.unregisterCurrentDevice(
        userId: 'supporter-a',
        token: 'device-a',
      );
      await _until(() => device.operations.contains('auto-init-false-start'));
      await runtime.current.auth.recoverSession(
        _sessionJson('supporter-a', 2, sessionId: 'session-a'),
      );
      shutdown.complete();
      await cleanup;
      expect(requests.single.method, 'DELETE');
      expect(device.token, isNull);
    },
  );
  test(
    'obsolete permission dialog result cannot register a replacement account',
    () async {
      final permission = Completer<NotificationSettings>();
      device.permissionHook = () => permission.future;
      final future = PushNotificationService.requestPermission();
      await runtime.current.auth.recoverSession(
        _sessionJson('supporter-b', 2, sessionId: 'session-b'),
      );
      permission.complete(_settings(AuthorizationStatus.authorized));
      expect(await future, PushPermissionStatus.authorized);
      expect(device.operations, isEmpty);
      expect(requests, isEmpty);
    },
  );

  test(
    'foreign cleanup cannot invalidate a legitimate pending registration',
    () async {
      final token = Completer<String?>();
      device.tokenHook = () => token.future;
      final registration = PushNotificationService.syncToken();
      await _until(() => device.operations.contains('get-token'));
      await PushNotificationService.unregisterCurrentDevice(
        userId: 'supporter-b',
        token: 'foreign-device',
      );
      token.complete('device-a');
      await registration;
      expect(
        requests.where((request) => request.method == 'POST'),
        hasLength(1),
      );
      expect(device.operations, isNot(contains('auto-init-false-start')));
    },
  );

  test(
    'topic subscription stops after ownership changes during preference lookup',
    () async {
      final response = Completer<http.Response>();
      responseHook = (_) => response.future;
      final subscription = PushNotificationService.subscribeToTopic(
        'club-local',
      );
      await _until(() => requests.isNotEmpty);
      await runtime.current.auth.recoverSession(
        _sessionJson('supporter-b', 2, sessionId: 'session-b'),
      );
      response.complete(
        http.Response(
          '{"push_enabled":true}',
          200,
          request: requests.single,
          headers: {'content-type': 'application/json'},
        ),
      );
      await subscription;
      expect(device.operations, isEmpty);
    },
  );

  test(
    'obsolete in-flight topic join is revoked before the newer join runs',
    () async {
      final joined = Completer<void>();
      var count = 0;
      device.subscribeHook = (_) =>
          count++ == 0 ? joined.future : Future<void>.value();
      final old = PushNotificationService.subscribeToTopic('club-local');
      await _until(
        () => device.operations.contains('subscribe-club-local-start'),
      );
      await runtime.current.auth.recoverSession(
        _sessionJson('supporter-b', 2, sessionId: 'session-b'),
      );
      final newer = PushNotificationService.subscribeToTopic('club-local');
      await _until(() => requests.length == 2);
      joined.complete();
      await Future.wait([old, newer]);
      expect(device.operations, [
        'subscribe-club-local-start',
        'subscribe-club-local-end',
        'unsubscribe-club-local',
        'subscribe-club-local-start',
        'subscribe-club-local-end',
      ]);
    },
  );
}
