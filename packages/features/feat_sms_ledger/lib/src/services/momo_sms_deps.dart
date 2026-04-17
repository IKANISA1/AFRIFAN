import 'package:core_network/core_network.dart' as core_network;
import 'package:core_utils/core_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

class EnvConfig {
  static const bool enableAndroidMomoSmsAutoread = bool.fromEnvironment(
    'ENABLE_ANDROID_MOMO_SMS_AUTOREAD',
    defaultValue: false,
  );
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  /// Country code from the club config (e.g. 'RW' for Rayon Sports).
  /// In production this is injected from dart-define-from-file.
  static const String? countryCode = String.fromEnvironment(
            'COUNTRY_CODE',
            defaultValue: '',
          ) ==
          ''
      ? null
      : String.fromEnvironment('COUNTRY_CODE');

  static String? get criticalConfigurationError {
    final missing = <String>[
      if (supabaseUrl.trim().isEmpty) 'SUPABASE_URL',
      if (supabaseAnonKey.trim().isEmpty) 'SUPABASE_ANON_KEY',
    ];
    if (missing.isEmpty) {
      return null;
    }
    return 'Missing required dart defines: ${missing.join(', ')}';
  }
}

enum AppAccessPermission {
  sms;

  String get storageKey => switch (this) {
        AppAccessPermission.sms => 'sms',
      };
}

class AppAccessService {
  AppAccessService({required OpenHiveBox<bool> openBox}) : _openBox = openBox;

  static const String _boxName = 'app_access_permissions';

  final OpenHiveBox<bool> _openBox;

  Future<bool> isEnabled(AppAccessPermission permission) async {
    try {
      final box = await _openBox(_boxName);
      return box.get(permission.storageKey) ?? false;
    } catch (error, stackTrace) {
      AfriLogger.warn(
        'AppAccess',
        'Failed to read ${permission.storageKey} permission state; defaulting to disabled.',
      );
      if (kDebugMode) {
        AfriLogger.error(
          'AppAccess',
          'Permission state lookup failed.',
          error,
          stackTrace,
        );
      }
      return false;
    }
  }

  Future<void> setEnabled(
    AppAccessPermission permission,
    bool isEnabled,
  ) async {
    try {
      final box = await _openBox(_boxName);
      await box.put(permission.storageKey, isEnabled);
    } catch (error, stackTrace) {
      AfriLogger.error(
        'AppAccess',
        'Failed to persist ${permission.storageKey} permission state.',
        error,
        stackTrace,
      );
    }
  }
}

class CrashlyticsService {
  Future<void> log(String message) async {
    AfriLogger.info('Crashlytics', message);
  }

  Future<void> recordError(
    Object error, {
    StackTrace? stackTrace,
    String? reason,
  }) async {
    AfriLogger.error(
      'Crashlytics',
      reason ?? 'Unhandled error',
      error,
      stackTrace,
    );
  }
}

typedef OperationalHealthStatus = core_network.OperationalHealthStatus;
typedef OperationalHealthSeverity = core_network.OperationalHealthSeverity;
typedef OperationalHealthService = core_network.OperationalHealthService;

typedef OpenHiveBox<T> = Future<Box<T>> Function(String boxName);

/// Opens a Hive box with encryption if available.
///
/// Boxes containing PII or financial data (e.g. MoMo SMS retry queue)
/// are encrypted at rest using the key stored in the OS keychain.
///
/// On first launch after the encryption upgrade, existing unencrypted boxes
/// are deleted and recreated — queued retries are lost as a one-time cost.
Future<Box<T>> openHiveBox<T>(String boxName) async {
  final cipher = core_network.HiveEncryptionService.cipher;
  if (!Hive.isBoxOpen(boxName)) {
    try {
      return await Hive.openBox<T>(boxName, encryptionCipher: cipher);
    } catch (error, stackTrace) {
      AfriLogger.warn('MomoSmsDeps', 'Operation failed (non-critical).', error, stackTrace);
      // Migration: existing unencrypted box → delete and re-open encrypted.
      try {
        await Hive.deleteBoxFromDisk(boxName);
      } catch (error, stackTrace) {
      AfriLogger.warn('MomoSmsDeps', 'Operation failed (non-critical).', error, stackTrace);
        // Best-effort cleanup.
      }
      return await Hive.openBox<T>(boxName, encryptionCipher: cipher);
    }
  }
  return Hive.box<T>(boxName);
}

typedef InitializeHive = Future<void> Function();

Future<void> initializeHiveRuntime() async {
  await Hive.initFlutter();
}
