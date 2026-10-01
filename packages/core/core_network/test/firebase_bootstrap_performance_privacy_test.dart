import 'package:core_network/core_network.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// Replies use the installed Core6.0.3 and Performance0.1.6+6 Pigeon schemas.
// Only the native boundary is intercepted; the installed Dart SDK is executed.
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
        <String, Object?>{},
      ]);
    } else {
      super.writeValue(buffer, value);
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final collectionRequests = <Object?>[];
  var nativeInitializeCalls = 0;
  var rejectPerformanceRequest = false;
  const options = FirebaseOptions(
    apiKey: 'local-sdk-fixture',
    appId: 'local-fixture-app',
    messagingSenderId: 'local-fixture-sender',
    projectId: 'local-fixture-project',
  );

  setUpAll(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMessageHandler(
      'dev.flutter.pigeon.firebase_core_platform_interface.FirebaseCoreHostApi.initializeCore',
      (_) async =>
          const _CoreReplyCodec().encodeMessage(<Object?>[<Object?>[]]),
    );
    messenger.setMockMessageHandler(
      'dev.flutter.pigeon.firebase_core_platform_interface.FirebaseCoreHostApi.initializeApp',
      (_) async {
        nativeInitializeCalls++;
        return const _CoreReplyCodec().encodeMessage(<Object?>[_AppReply()]);
      },
    );
    messenger.setMockMessageHandler(
      'dev.flutter.pigeon.firebase_performance_platform_interface.FirebasePerformanceHostApi.setPerformanceCollectionEnabled',
      (message) async {
        final arguments =
            const StandardMessageCodec().decodeMessage(message)
                as List<Object?>;
        collectionRequests.add(arguments.single);
        if (rejectPerformanceRequest) {
          return const StandardMessageCodec().encodeMessage(<Object?>[
            'local-disabled-sdk',
            'local fixture rejects setter',
            null,
          ]);
        }
        return const StandardMessageCodec().encodeMessage(<Object?>[null]);
      },
    );
  });

  setUp(() {
    collectionRequests.clear();
    rejectPerformanceRequest = false;
  });

  test(
    'new native Firebase app requests disabled Performance collection',
    () async {
      expect(Firebase.apps, isEmpty);
      expect(
        await FirebaseBootstrapService.initialize(options: options),
        isTrue,
      );
      expect(nativeInitializeCalls, 1);
      expect(collectionRequests, <Object?>[false]);
    },
  );

  test(
    'already initialized native app still disables Performance collection',
    () async {
      expect(Firebase.apps, isNotEmpty);
      expect(await FirebaseBootstrapService.initialize(), isTrue);
      expect(nativeInitializeCalls, 1);
      expect(collectionRequests, <Object?>[false]);
    },
  );

  test(
    'disable setter failure preserves best effort initialized startup',
    () async {
      rejectPerformanceRequest = true;
      expect(await FirebaseBootstrapService.initialize(), isTrue);
      expect(FirebaseBootstrapService.isInitialized, isTrue);
      expect(collectionRequests, <Object?>[false]);
    },
  );

  test(
    'next bootstrap retries disabling collection after setter failure',
    () async {
      expect(await FirebaseBootstrapService.initialize(), isTrue);
      expect(nativeInitializeCalls, 1);
      expect(collectionRequests, <Object?>[false]);
    },
  );
}
