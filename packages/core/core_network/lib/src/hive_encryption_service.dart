import 'dart:convert';
import 'dart:math';

import 'package:core_utils/core_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';

/// Manages Hive AES-256 encryption keys stored in the OS keychain.
///
/// The encryption key is generated once and persisted in platform-secure
/// storage (`flutter_secure_storage`). Hive boxes opened with this cipher
/// have their contents encrypted at rest, protecting PII and financial data
/// on the device.
///
/// Usage:
/// ```dart
/// await HiveEncryptionService.initialize();
/// final cipher = HiveEncryptionService.cipher;
/// final box = await Hive.openBox<String>('my_box', encryptionCipher: cipher);
/// ```
class HiveEncryptionService {
  HiveEncryptionService._();

  static const _tag = 'HiveEncryption';
  static const _secureKey = 'africlub_hive_encryption_key_v1';

  static HiveAesCipher? _cipher;
  static bool _initialized = false;

  /// Whether the encryption service has been initialized.
  static bool get isInitialized => _initialized;

  /// Returns the Hive AES cipher for encrypting boxes.
  ///
  /// Returns `null` if initialization failed (graceful degradation).
  static HiveAesCipher? get cipher => _cipher;

  /// Initialize the encryption service.
  ///
  /// Retrieves or generates a 256-bit AES key and stores it in the
  /// platform keychain. Must be called after [Hive.initFlutter()]
  /// and before opening any encrypted boxes.
  static Future<void> initialize({
    FlutterSecureStorage? secureStorageOverride,
  }) async {
    if (_initialized) return;

    try {
      final storage = secureStorageOverride ?? _defaultSecureStorage();
      final existingKey = await storage.read(key: _secureKey);

      List<int> keyBytes;
      if (existingKey != null) {
        keyBytes = base64Decode(existingKey);
      } else {
        keyBytes = _generateSecureKey();
        await storage.write(
          key: _secureKey,
          value: base64Encode(keyBytes),
        );
        AfriLogger.info(_tag, 'Generated new Hive encryption key.');
      }

      if (keyBytes.length != 32) {
        throw StateError(
          'Invalid encryption key length: ${keyBytes.length} (expected 32).',
        );
      }

      _cipher = HiveAesCipher(keyBytes);
      _initialized = true;
      AfriLogger.info(_tag, 'Hive encryption ready.');
    } catch (error, stackTrace) {
      AfriLogger.error(
        _tag,
        'Failed to initialize Hive encryption. '
        'Boxes will open unencrypted as a fallback.',
        error,
        stackTrace,
      );
      // Encryption failure is non-fatal:
      // unencrypted storage is better than a non-functional app.
      _initialized = true; // Prevent re-attempts.
    }
  }

  /// Generates a cryptographically secure 256-bit (32-byte) key.
  static List<int> _generateSecureKey() {
    final random = Random.secure();
    return List<int>.generate(32, (_) => random.nextInt(256));
  }

  static FlutterSecureStorage _defaultSecureStorage() {
    return const FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device,
      ),
    );
  }

  @visibleForTesting
  static void resetForTest() {
    _cipher = null;
    _initialized = false;
  }
}
