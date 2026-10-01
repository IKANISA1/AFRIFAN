import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:core_network/core_network.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _PrivateObject {
  bool read = false;
  Object toJson() {
    read = true;
    throw StateError('private object must not be serialized');
  }

  @override
  String toString() {
    read = true;
    throw StateError('private object must not be stringified');
  }
}

class _ThrowingMap extends MapBase<String, Object?> {
  @override
  Object? operator [](Object? key) => throw StateError('private getter');
  @override
  void operator []=(String key, Object? value) =>
      throw UnsupportedError('immutable');
  @override
  void clear() => throw UnsupportedError('immutable');
  @override
  Iterable<String> get keys => throw StateError('private keys');
  @override
  Object? remove(Object? key) => throw UnsupportedError('immutable');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const marker = 'opaque_private_supporter_alias';
  Map<String, dynamic> rawPayload() => <String, dynamic>{
    'service': marker,
    'component': marker,
    'status': 'error',
    'severity': 'critical',
    'message': marker,
    'issueCode': marker,
    'functionName': marker,
    'userId': marker,
    'subjectType': marker,
    'subjectId': marker,
    'metadata': <String, Object?>{
      'private_name': marker,
      'mode': 'preview',
      'count': 2,
      'error_name': marker,
    },
    'occurredAt': '2026-09-30T00:00:00.000Z',
  };
  void expectSafe(Map payload) {
    expect(jsonEncode(payload), isNot(contains(marker)));
    expect(payload['service'], 'client');
    expect(payload['component'], 'general');
    expect(payload['message'], 'Operational health failure.');
    expect(payload['userId'], isNull);
    expect(payload['subjectType'], isNull);
    expect(payload['subjectId'], isNull);
    expect(payload['issueCode'], 'operational_event');
    expect(payload['functionName'], isNull);
    expect(payload['metadata'], <String, Object?>{
      'mode': 'preview',
      'count': 2,
    });
  }

  late SupabaseClient client;
  late OperationalHealthService service;
  late List<http.Request> requests;
  late Directory temp;

  setUp(() async {
    requests = <http.Request>[];
    client = SupabaseClient(
      'https://native-health-fixture.invalid',
      'sb_publishable_local_fixture',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response(
          '{"success":true}',
          200,
          headers: <String, String>{'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    service = OperationalHealthService(client: client);
    temp = await Directory.systemTemp.createTemp('native_health_privacy_');
    Hive.init(temp.path);
    ConnectivityService.setOnlineForTest(false);
    await OfflineEventQueue.resetForTest(deleteBox: true);
  });
  tearDown(() async {
    await OfflineEventQueue.resetForTest(deleteBox: true);
    ConnectivityService.setOnlineForTest(true);
    await client.dispose();
    await temp.delete(recursive: true);
  });

  test('native health preserves reviewed facts and UTC milliseconds', () {
    final payload = service.buildPayload(
      service: 'edge_function',
      component: 'send-notification',
      functionName: 'send-notification',
      issueCode: 'function_invocation_failed',
      message: marker,
      status: OperationalHealthStatus.warn,
      occurredAt: DateTime.parse('2026-09-30T12:34:56.123456Z'),
      metadata: <String, Object?>{
        'parser_provider': 'gemini',
        'parse_status': 'needs_review',
        'match_status': 'manual_review',
        'ingestion_source': 'android_sms_listener_background',
        'source_provider': 'api_football',
        'mode': 'sync',
        'error_name': 'TimeoutError',
        'count': 1000000000,
        'attempt': 2.0,
        'duration_ms': 15,
        'http_status': 429,
        'retryable': true,
        'dry_run': false,
      },
    );
    expect(payload['service'], 'edge_function');
    expect(payload['component'], 'send-notification');
    expect(payload['functionName'], 'send-notification');
    expect(payload['issueCode'], 'function_invocation_failed');
    expect(payload['severity'], 'warning');
    expect(payload['message'], 'Operational health requires review.');
    expect(payload['occurredAt'], '2026-09-30T12:34:56.123Z');
    expect((payload['metadata'] as Map).length, 13);
    expect(jsonEncode(payload), isNot(contains(marker)));
  });

  test(
    'native health rejects invalid metrics, nested values, and opaque enums',
    () {
      final private = _PrivateObject();
      final safe = NativeHealthPayload.normalize(<String, Object?>{
        'service': private,
        'message': private,
        'component': private,
        'status': marker,
        'severity': marker,
        'occurredAt': marker,
        'unknown': private,
        'metadata': <String, Object?>{
          'count': -1,
          'attempt': 1.5,
          'duration_ms': double.infinity,
          'retry_after_seconds': double.nan,
          'error_count': 1000000001,
          'http_status': 600,
          'retryable': 'true',
          'dry_run': 1,
          'mode': marker,
          'parse_status': marker,
          'private': private,
          'source_provider': <String, Object?>{'name': marker},
        },
      });
      expect(safe['metadata'], isEmpty);
      expect(safe['status'], 'ok');
      expect(safe['severity'], 'info');
      expect(safe['message'], 'Operational health event.');
      expect(DateTime.tryParse(safe['occurredAt'] as String), isNotNull);
      jsonEncode(safe);
      expect(private.read, isFalse);
      expect(NativeHealthPayload.diagnosticMetadata(_ThrowingMap()), isEmpty);
    },
  );

  test(
    'native health never falls back to the current SDK account identity',
    () async {
      String part(Object value) =>
          base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
      await client.auth.setInitialSession(
        jsonEncode(<String, Object?>{
          'access_token':
              '${part({'alg': 'none'})}.${part({'sub': marker, 'exp': 4102444800})}.local-fixture',
          'refresh_token': 'local-refresh',
          'token_type': 'bearer',
          'expires_in': 3600,
          'user': <String, Object?>{
            'id': marker,
            'aud': 'authenticated',
            'app_metadata': <String, Object?>{},
            'user_metadata': <String, Object?>{},
            'created_at': '2026-09-30T00:00:00Z',
          },
        }),
      );
      expect(client.auth.currentUser?.id, marker);
      final payload = service.buildPayload(
        service: 'client',
        component: 'general',
        message: marker,
      );
      expect(payload['userId'], isNull);
      expect(jsonEncode(payload), isNot(contains(marker)));
    },
  );

  test(
    'legacy malformed records are removed without blocking clean telemetry',
    () async {
      final legacy = await Hive.openBox<String>(
        'africlub_event_queue',
        encryptionCipher: HiveEncryptionService.cipher,
      );
      await legacy.put('malformed', marker);
      await legacy.put('list', jsonEncode(<String>[marker]));
      await legacy.put('valid', jsonEncode(rawPayload()));
      await legacy.close();
      await OfflineEventQueue.initialize((payload) async {});
      final box = Hive.box<String>('africlub_event_queue');
      expect(box.keys, <String>['valid']);
      expectSafe(jsonDecode(box.values.single) as Map);
    },
  );

  test('same-tick queued events retain separate safe records', () async {
    await OfflineEventQueue.initialize((payload) async {});
    await Future.wait(
      List<Future<void>>.generate(
        10,
        (_) => OfflineEventQueue.enqueuePayload(
          rawPayload(),
          sendImmediately: false,
        ),
      ),
    );
    final box = Hive.box<String>('africlub_event_queue');
    expect(box.length, 10);
    for (final raw in box.values) {
      expectSafe(jsonDecode(raw) as Map);
    }
  });

  test('native health buildPayload removes raw caller identity and text', () {
    final payload = service.buildPayload(
      service: marker,
      component: marker,
      message: marker,
      status: OperationalHealthStatus.error,
      issueCode: marker,
      functionName: marker,
      userId: marker,
      subjectType: marker,
      subjectId: marker,
      metadata: <String, Object?>{
        'private_name': marker,
        'mode': 'preview',
        'count': 2,
        'error_name': marker,
      },
    );
    expectSafe(payload);
  });

  test(
    'native health actual SDK request sanitizes direct arbitrary payload',
    () async {
      await service.recordPayloadOrThrow(rawPayload());
      expect(requests, hasLength(1));
      expect(
        requests.single.url.path,
        '/functions/v1/record-operational-health',
      );
      expectSafe(jsonDecode(requests.single.body) as Map);
    },
  );

  test(
    'native health queue stores only normalized payload before replay',
    () async {
      await OfflineEventQueue.initialize((payload) async {});
      await OfflineEventQueue.enqueuePayload(
        rawPayload(),
        sendImmediately: false,
      );
      final box = Hive.box<String>('africlub_event_queue');
      expect(box.length, 1);
      expectSafe(jsonDecode(box.values.single) as Map);
    },
  );

  for (final succeeds in <bool>[true, false]) {
    test(
      'native health normalizes legacy disk payload before offline replay $succeeds',
      () async {
        final legacy = await Hive.openBox<String>(
          'africlub_event_queue',
          encryptionCipher: HiveEncryptionService.cipher,
        );
        await legacy.put('legacy-key', jsonEncode(rawPayload()));
        await legacy.close();
        final sent = <Map<String, dynamic>>[];
        await OfflineEventQueue.initialize((payload) async {
          sent.add(payload);
          if (!succeeds) throw StateError('controlled unavailable sender');
        });
        final box = Hive.box<String>('africlub_event_queue');
        expectSafe(jsonDecode(box.values.single) as Map);
        ConnectivityService.setOnlineForTest(true);
        for (var attempt = 0; attempt < 200 && sent.isEmpty; attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
        expect(sent, hasLength(1));
        expectSafe(sent.single);
        for (
          var attempt = 0;
          attempt < 200 && succeeds && box.isNotEmpty;
          attempt++
        ) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
        if (succeeds) {
          expect(box.isEmpty, isTrue);
        } else {
          expect(box.length, 1);
          expectSafe(jsonDecode(box.values.single) as Map);
        }
      },
    );
  }

  test(
    'native health immediate queue sender receives only normalized payload',
    () async {
      final sent = <Map<String, dynamic>>[];
      await OfflineEventQueue.initialize((payload) async => sent.add(payload));
      ConnectivityService.setOnlineForTest(true);
      await OfflineEventQueue.enqueuePayload(rawPayload());
      expectSafe(sent.single);
      expect(OfflineEventQueue.pendingCount, 0);
    },
  );
}
