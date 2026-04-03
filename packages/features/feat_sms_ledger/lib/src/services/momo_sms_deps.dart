import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EnvConfig {
  static const bool enableAndroidMomoSmsAutoread = bool.fromEnvironment(
    'ENABLE_ANDROID_MOMO_SMS_AUTOREAD',
    defaultValue: true,
  );
  static const String? criticalConfigurationError = null;
  static const String supabaseUrl = 'mock_url';
  static const String supabaseAnonKey = 'mock_key';

  /// Country code from the club config (e.g. 'RW' for Rayon Sports).
  /// In production this is injected from dart-define-from-file.
  static const String? countryCode = String.fromEnvironment(
            'COUNTRY_CODE',
            defaultValue: '',
          ) ==
          ''
      ? null
      : String.fromEnvironment('COUNTRY_CODE');
}

enum AppAccessPermission { sms }

class AppAccessService {
  AppAccessService({required OpenHiveBox<bool> openBox});

  Future<bool> isEnabled(AppAccessPermission permission) async {
    return true; // Enabled by default for rayon_sports
  }
}

class CrashlyticsService {
  Future<void> log(String message) async {
    debugPrint('[Crashlytics Log]: $message');
  }

  Future<void> recordError(
    Object error, {
    StackTrace? stackTrace,
    String? reason,
  }) async {
    debugPrint('[Crashlytics Error]: $reason -> $error');
  }
}

enum OperationalHealthStatus { ok, warn, error }

enum OperationalHealthSeverity { info, warning, critical }

class OperationalHealthService {
  OperationalHealthService({required this.client});
  final SupabaseClient client;

  Future<void> recordEvent({
    required String service,
    required String component,
    required OperationalHealthStatus status,
    OperationalHealthSeverity? severity,
    String? issueCode,
    required String message,
    Map<String, dynamic>? metadata,
  }) async {
    debugPrint('[OperationalHealth]: $issueCode - $message');
  }
}

typedef OpenHiveBox<T> = Future<Box<T>> Function(String boxName);

Future<Box<T>> openHiveBox<T>(String boxName) async {
  if (!Hive.isBoxOpen(boxName)) {
    return await Hive.openBox<T>(boxName);
  }
  return Hive.box<T>(boxName);
}

typedef InitializeHive = Future<void> Function();

Future<void> initializeHiveRuntime() async {
  await Hive.initFlutter();
}
