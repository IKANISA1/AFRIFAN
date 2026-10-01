import 'dart:async';
import 'dart:convert';

import 'package:core_network/core_network.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// Local native replies follow the installed Firebase Core6.0.3 Pigeon schema.
// No provider configuration, native device or external service is contacted.
class _OptionsReply {}

class _AppReply {}

class _CoreReplyCodec extends StandardMessageCodec {
  const _CoreReplyCodec();

  @override
  void writeValue(WriteBuffer buffer, Object? value) {
    if (value is _OptionsReply) {
      buffer.putUint8(129);
      writeValue(buffer, <Object?>[
        'local-sdk-fixture',
        'local-fixture-app',
        'local-fixture-sender',
        'local-fixture-project',
        ...List<Object?>.filled(10, null),
      ]);
    } else if (value is _AppReply) {
      buffer.putUint8(130);
      writeValue(buffer, <Object?>[
        '[DEFAULT]',
        _OptionsReply(),
        false,
        <String, Object?>{
          'plugins.flutter.io/firebase_crashlytics': <String, Object?>{
            'isCrashlyticsCollectionEnabled': false,
          },
        },
      ]);
    } else {
      super.writeValue(buffer, value);
    }
  }
}

class _OpaqueError {
  bool stringified = false;
  @override
  String toString() {
    stringified = true;
    throw StateError('caller error must not be read');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const enabled = FirebaseObservabilityConfig.enabled;
  const marker = 'opaque_private_supporter_alias';
  const crash = MethodChannel('plugins.flutter.io/firebase_crashlytics');
  final calls = <MethodCall>[];

  setUpAll(() async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMessageHandler(
      'dev.flutter.pigeon.firebase_core_platform_interface.FirebaseCoreHostApi.initializeCore',
      (_) async => const _CoreReplyCodec().encodeMessage(<Object?>[
        <Object?>[_AppReply()],
      ]),
    );
    for (final method in <String>[
      'logEvent',
      'setAnalyticsCollectionEnabled',
      'setUserId',
    ]) {
      messenger.setMockMessageHandler(
        'dev.flutter.pigeon.firebase_analytics_platform_interface.FirebaseAnalyticsHostApi.$method',
        (message) async {
          final arguments =
              const StandardMessageCodec().decodeMessage(message)
                  as List<Object?>;
          calls.add(MethodCall('Analytics#$method', arguments.single));
          return const StandardMessageCodec().encodeMessage(<Object?>[null]);
        },
      );
    }
    messenger.setMockMethodCallHandler(crash, (call) async {
      calls.add(call);
      if (call.method == 'Crashlytics#setCrashlyticsCollectionEnabled') {
        return <String, Object?>{'isCrashlyticsCollectionEnabled': false};
      }
      return null;
    });
    await Firebase.initializeApp();
    expect(await CrashlyticsService.initialize(), enabled);
    await FirebaseAnalyticsService.configureConsent(enabled: true);
    expect(FirebaseAnalyticsService.consentGranted, enabled);
  });
  setUp(calls.clear);

  test('SDK screen payload rejects a caller-controlled class', () async {
    await FirebaseAnalyticsService.setCurrentScreen(
      '/home',
      screenClassOverride: marker,
    );
    expect(calls.where((call) => call.method == 'Analytics#logEvent'), isEmpty);
    expect(
      jsonEncode(calls.map((call) => call.arguments).toList()),
      isNot(contains(marker)),
    );
  });

  test(
    'SDK screen payload uses reviewed route template and Flutter class',
    () async {
      await FirebaseAnalyticsService.setCurrentScreen(
        '/orders/$marker?private=$marker',
      );
      final payloads = calls
          .where((call) => call.method == 'Analytics#logEvent')
          .toList();
      if (!enabled) {
        expect(payloads, isEmpty);
        return;
      }
      expect(payloads, hasLength(1));
      final payload = Map<String, Object?>.from(
        payloads.single.arguments as Map,
      );
      expect(jsonEncode(payload), isNot(contains(marker)));
      expect(payload['eventName'], 'screen_view');
      final parameters = Map<String, Object?>.from(
        payload['parameters'] as Map,
      );
      expect(parameters['screen_name'], '/orders/:item');
      expect(parameters['screen_class'], 'Flutter');
    },
  );

  test(
    'SDK crash payload contains finite reason and no caller stack/text',
    () async {
      await CrashlyticsService.recordError(
        StateError(marker),
        StackTrace.fromString('#0 $marker (file:///$marker.dart:9:9)'),
        reason: marker,
        fatal: true,
      );
      final payloads = calls
          .where((call) => call.method == 'Crashlytics#recordError')
          .toList();
      if (!enabled) {
        expect(payloads, isEmpty);
        return;
      }
      expect(payloads, hasLength(1));
      final payload = Map<String, Object?>.from(
        payloads.single.arguments as Map,
      );
      expect(jsonEncode(payload), isNot(contains(marker)));
      expect(payload['exception'], 'runtime_failure:state');
      expect(payload['reason'], 'runtime_error');
      expect(payload['fatal'], isTrue);
      expect(payload['information'], '');
      expect(payload['stackTraceElements'], isEmpty);
      expect(payload['buildId'], '');
      expect(payload['loadingUnits'], isEmpty);
    },
  );

  test(
    'SDK framework payload never reads arbitrary details or collectors',
    () async {
      var collectorRead = false;
      await CrashlyticsService.recordFlutterError(
        FlutterErrorDetails(
          exception: StateError(marker),
          stack: StackTrace.fromString('#0 $marker (file:///$marker.dart:9:9)'),
          context: ErrorDescription(marker),
          library: marker,
          informationCollector: () {
            collectorRead = true;
            return <DiagnosticsNode>[ErrorDescription(marker)];
          },
        ),
      );
      expect(collectorRead, isFalse);
      final payloads = calls
          .where((call) => call.method == 'Crashlytics#recordError')
          .toList();
      if (!enabled) {
        expect(payloads, isEmpty);
        return;
      }
      final payload = Map<String, Object?>.from(
        payloads.single.arguments as Map,
      );
      expect(jsonEncode(payload), isNot(contains(marker)));
      expect(payload['exception'], 'runtime_failure:framework');
      expect(payload['reason'], 'flutter_framework_error');
      expect(payload['stackTraceElements'], isEmpty);
    },
  );

  test(
    'SDK rejects opaque diagnostic breadcrumbs and coded event values',
    () async {
      await CrashlyticsService.log(marker);
      await FirebaseAnalyticsService.logSupportAccess(channel: marker);
      expect(calls, isEmpty);
    },
  );

  test(
    'SDK finite error categories ignore null/empty and caller-controlled stacks',
    () async {
      final opaque = _OpaqueError();
      final errors = <Object, String>{
        TimeoutException(marker): 'timeout',
        const FormatException(marker): 'format',
        ArgumentError(marker): 'argument',
        UnsupportedError(marker): 'unsupported',
        opaque: 'failure',
      };
      for (final entry in errors.entries) {
        await CrashlyticsService.recordError(entry.key, StackTrace.empty);
        final payloads = calls
            .where((call) => call.method == 'Crashlytics#recordError')
            .toList();
        if (enabled) {
          final payload = Map<String, Object?>.from(
            payloads.last.arguments as Map,
          );
          expect(payload['exception'], 'runtime_failure:${entry.value}');
          expect(payload['reason'], 'runtime_error');
          expect(payload['stackTraceElements'], isEmpty);
          expect(jsonEncode(payload), isNot(contains(marker)));
        } else {
          expect(payloads, isEmpty);
        }
      }
      expect(opaque.stringified, isFalse);
    },
  );

  test(
    'SDK sends approved breadcrumb and approved reason without free text',
    () async {
      await CrashlyticsService.log('operation_failed');
      await CrashlyticsService.recordError(
        StateError(marker),
        null,
        reason: 'network_error',
      );
      if (!enabled) {
        expect(calls, isEmpty);
        return;
      }
      final log = calls.singleWhere((call) => call.method == 'Crashlytics#log');
      expect(log.arguments, <String, Object?>{'message': 'operation_failed'});
      final record = calls.singleWhere(
        (call) => call.method == 'Crashlytics#recordError',
      );
      final payload = Map<String, Object?>.from(record.arguments as Map);
      expect(payload['reason'], 'network_error');
      expect(payload['stackTraceElements'], isEmpty);
      expect(jsonEncode(payload), isNot(contains(marker)));
    },
  );

  test('SDK emits only declared coarse event values under consent', () async {
    await FirebaseAnalyticsService.logSupportAccess(channel: 'whatsapp');
    final payloads = calls
        .where((call) => call.method == 'Analytics#logEvent')
        .toList();
    if (!enabled) {
      expect(payloads, isEmpty);
      return;
    }
    final payload = Map<String, Object?>.from(payloads.single.arguments as Map);
    expect(payload['eventName'], 'support_access');
    expect(payload['parameters'], <String, Object?>{'channel': 'whatsapp'});
  });
}
