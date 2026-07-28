import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Firebase startup contract', () {
    test('Android manifest disables automatic Firebase network collection', () {
      final manifest = File(
        '${_workspacePrefix()}apps/rayon_sports/android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();

      expect(manifest, contains('firebase_data_collection_default_enabled'));
      expect(manifest, contains('firebase_messaging_auto_init_enabled'));
      expect(manifest, contains('firebase_analytics_collection_enabled'));
      expect(manifest, contains('firebase_crashlytics_collection_enabled'));
      expect(manifest, contains('firebase_performance_collection_enabled'));
      expect(manifest, contains('firebase_sessions_enabled'));
      expect(manifest, contains('ComponentDiscoveryService'));
      expect(
        manifest,
        contains(
          'com.google.firebase.components:com.google.firebase.sessions.FirebaseSessionsRegistrar',
        ),
      );
      expect(manifest, contains('tools:node="remove"'));
      expect(
        manifest,
        contains(
          '<meta-data\n'
          '            android:name="firebase_data_collection_default_enabled"\n'
          '            android:value="false" />',
        ),
      );
      expect(
        manifest,
        contains(
          '<meta-data\n'
          '            android:name="firebase_messaging_auto_init_enabled"\n'
          '            android:value="false" />',
        ),
      );
      expect(
        manifest,
        contains(
          '<meta-data\n'
          '            android:name="firebase_analytics_collection_enabled"\n'
          '            android:value="false" />',
        ),
      );
      expect(
        manifest,
        contains(
          '<meta-data\n'
          '            android:name="firebase_crashlytics_collection_enabled"\n'
          '            android:value="false" />',
        ),
      );
      expect(
        manifest,
        contains(
          '<meta-data\n'
          '            android:name="firebase_performance_collection_enabled"\n'
          '            android:value="false" />',
        ),
      );
      expect(
        manifest,
        contains(
          '<meta-data\n'
          '            android:name="firebase_sessions_enabled"\n'
          '            android:value="false" />',
        ),
      );
    });

    test('push service does not enable FCM auto-init during startup', () {
      final source = File(
        '${_workspacePrefix()}packages/core/core_network/lib/src/push_notification_service.dart',
      ).readAsStringSync();
      final initializeBody = RegExp(
        r'static Future<void> initialize\(\{required String clubId\}\) async \{([\s\S]*?)\n  static Future<PushPermissionStatus> getPermissionStatus',
      ).firstMatch(source)?.group(1);

      expect(initializeBody, isNotNull);
      expect(initializeBody, contains("reason: 'startup'"));
      expect(initializeBody, isNot(contains('setAutoInitEnabled(true)')));
      expect(initializeBody, isNot(contains('onBackgroundMessage')));
      expect(initializeBody, isNot(contains('onTokenRefresh')));
      expect(initializeBody, isNot(contains('onMessage.listen')));
      expect(
        initializeBody,
        isNot(contains('_initialized = true;\n    await syncToken();')),
      );
      expect(
        initializeBody,
        contains(
          'if (_lastKnownToken != null) {\n            unawaited(syncToken());',
        ),
      );
    });

    test('Android application disables persisted FCM auto-init before Dart', () {
      final manifest = File(
        '${_workspacePrefix()}apps/rayon_sports/android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      final application = File(
        '${_workspacePrefix()}apps/rayon_sports/android/app/src/main/kotlin/rw/gikundiro/app/RayonSportsApplication.kt',
      ).readAsStringSync();

      expect(manifest, contains('android:name=".RayonSportsApplication"'));
      expect(
        application,
        contains(
          'Class.forName("com.google.firebase.messaging.FirebaseMessaging")',
        ),
      );
      expect(application, contains('setAutoInitEnabled'));
      expect(application, contains('invoke(messaging, false)'));
    });

    test('Dart observability SDKs are compile-time gated by default', () {
      final config = File(
        '${_workspacePrefix()}packages/core/core_network/lib/src/firebase_observability_config.dart',
      ).readAsStringSync();
      final bootstrap = File(
        '${_workspacePrefix()}packages/core/core_network/lib/src/firebase_bootstrap_service.dart',
      ).readAsStringSync();
      final appCheck = File(
        '${_workspacePrefix()}packages/core/core_network/lib/src/app_check_service.dart',
      ).readAsStringSync();
      final crashlytics = File(
        '${_workspacePrefix()}packages/core/core_network/lib/src/crashlytics_service.dart',
      ).readAsStringSync();
      final analytics = File(
        '${_workspacePrefix()}packages/core/core_network/lib/src/firebase_analytics_service.dart',
      ).readAsStringSync();

      expect(config, contains('ENABLE_FIREBASE_OBSERVABILITY'));
      expect(config, contains('ENABLE_FIREBASE_APP_CHECK'));
      expect(bootstrap, contains('FirebaseObservabilityConfig.enabled'));
      expect(
        bootstrap,
        contains('!kIsWeb && FirebaseObservabilityConfig.enabled'),
      );
      expect(appCheck, contains('FirebaseObservabilityConfig.appCheckEnabled'));
      expect(crashlytics, contains('FirebaseObservabilityConfig.enabled'));
      expect(
        crashlytics,
        contains('if (!FirebaseObservabilityConfig.enabled)'),
      );
      expect(analytics, contains('FirebaseObservabilityConfig.enabled'));
    });
  });
}

String _workspacePrefix() {
  final current = Directory.current.path.replaceAll('\\', '/');
  return current.endsWith('/apps/rayon_sports') ? '../../' : '';
}
