import 'dart:convert';
import 'dart:io';

import 'package:core_network/core_network.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    HiveEncryptionService.resetForTest();
  });

  group('HiveEncryptionService', () {
    test('initializes with a new key when none exists', () async {
      final storage = _FakeSecureStorage();

      await HiveEncryptionService.initialize(
        secureStorageOverride: storage,
      );

      expect(HiveEncryptionService.isInitialized, isTrue);
      expect(HiveEncryptionService.cipher, isNotNull);

      // Key was persisted.
      final storedKey = storage.store['africlub_hive_encryption_key_v1'];
      expect(storedKey, isNotNull);

      // Key decodes to 32 bytes.
      final keyBytes = base64Decode(storedKey!);
      expect(keyBytes.length, 32);
    });

    test('reuses existing key on subsequent initializations', () async {
      final storage = _FakeSecureStorage();

      // First init — generates key.
      await HiveEncryptionService.initialize(
        secureStorageOverride: storage,
      );
      final firstKey = storage.store['africlub_hive_encryption_key_v1'];

      // Reset and re-init — should reuse.
      HiveEncryptionService.resetForTest();
      await HiveEncryptionService.initialize(
        secureStorageOverride: storage,
      );
      final secondKey = storage.store['africlub_hive_encryption_key_v1'];

      expect(firstKey, equals(secondKey));
      expect(HiveEncryptionService.cipher, isNotNull);
    });

    test('is idempotent — second call is a no-op', () async {
      final storage = _FakeSecureStorage();

      await HiveEncryptionService.initialize(
        secureStorageOverride: storage,
      );
      final cipherA = HiveEncryptionService.cipher;

      await HiveEncryptionService.initialize(
        secureStorageOverride: storage,
      );
      final cipherB = HiveEncryptionService.cipher;

      expect(identical(cipherA, cipherB), isTrue);
    });

    test('degrades gracefully when secure storage throws', () async {
      await HiveEncryptionService.initialize(
        secureStorageOverride: _ThrowingSecureStorage(),
      );

      // Should be initialized but with no cipher.
      expect(HiveEncryptionService.isInitialized, isTrue);
      expect(HiveEncryptionService.cipher, isNull);
    });

    test('rejects invalid key length', () async {
      final storage = _FakeSecureStorage();
      // Store a key with wrong length (16 bytes instead of 32).
      storage.store['africlub_hive_encryption_key_v1'] = base64Encode(
        List<int>.generate(16, (i) => i),
      );

      await HiveEncryptionService.initialize(
        secureStorageOverride: storage,
      );

      // Should degrade — invalid key detected.
      expect(HiveEncryptionService.isInitialized, isTrue);
      expect(HiveEncryptionService.cipher, isNull);
    });

    test('resetForTest clears cipher and initialization flag', () async {
      final storage = _FakeSecureStorage();
      await HiveEncryptionService.initialize(
        secureStorageOverride: storage,
      );

      expect(HiveEncryptionService.cipher, isNotNull);

      HiveEncryptionService.resetForTest();

      expect(HiveEncryptionService.isInitialized, isFalse);
      expect(HiveEncryptionService.cipher, isNull);
    });
  });

  group('HiveEncryptionService integration', () {
    late String tempPath;

    setUp(() async {
      tempPath =
          '${Directory.systemTemp.path}/hive_encryption_test_${DateTime.now().millisecondsSinceEpoch}';
      Hive.init(tempPath);
    });

    tearDown(() async {
      await Hive.close();
      try {
        await Hive.deleteBoxFromDisk('test_encrypted_box');
      } catch (_) {}
    });

    test('encrypted box can store and retrieve data', () async {
      final storage = _FakeSecureStorage();
      await HiveEncryptionService.initialize(
        secureStorageOverride: storage,
      );

      final cipher = HiveEncryptionService.cipher;
      expect(cipher, isNotNull);

      final box = await Hive.openBox<String>(
        'test_encrypted_box',
        encryptionCipher: cipher,
      );

      await box.put('key', 'secret_value');
      expect(box.get('key'), 'secret_value');

      await box.close();

      // Re-open with same cipher — data should persist.
      final reopened = await Hive.openBox<String>(
        'test_encrypted_box',
        encryptionCipher: cipher,
      );

      expect(reopened.get('key'), 'secret_value');
      await reopened.close();
    });
  });
}

/// In-memory fake for [FlutterSecureStorage].
class _FakeSecureStorage extends FlutterSecureStorage {
  _FakeSecureStorage() : super();

  final Map<String, String> store = <String, String>{};

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return store[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value != null) {
      store[key] = value;
    } else {
      store.remove(key);
    }
  }
}

/// Secure storage that always throws (simulates platform failure).
class _ThrowingSecureStorage extends FlutterSecureStorage {
  _ThrowingSecureStorage() : super();

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    throw Exception('Secure storage unavailable');
  }
}
