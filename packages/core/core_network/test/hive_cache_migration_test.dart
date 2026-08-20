import 'dart:convert';
import 'dart:io';

import 'package:core_network/core_network.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

/// Fake secure storage for testing.
class FakeSecureStorage extends FlutterSecureStorage {
  FakeSecureStorage() : super();
  final Map<String, String> store = <String, String>{};

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => store[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value != null) {
      store[key] = value;
    } else {
      store.remove(key);
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_migration_test_');
    Hive.init(tempDir.path);
    HiveEncryptionService.resetForTest();
    await HiveCacheService.resetForTest(deleteBox: true);
  });

  tearDown(() async {
    await HiveCacheService.resetForTest(deleteBox: true);
    HiveEncryptionService.resetForTest();
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('HiveCacheService encryption migration', () {
    test('initializes fresh encrypted box when no prior data exists', () async {
      await HiveEncryptionService.initialize(
        secureStorageOverride: FakeSecureStorage(),
      );
      await HiveCacheService.initialize();

      await HiveCacheService.putJson('test_key', <String, dynamic>{
        'value': 42,
      });

      final result = HiveCacheService.getJson<Map>('test_key');
      expect(result, isNotNull);
      expect(result?['value'], 42);
    });

    test(
      'migrates existing unencrypted box to encrypted (data cleared)',
      () async {
        // Phase 1: Create an unencrypted box with data.
        final unencryptedBox = await Hive.openBox<String>('africlub_cache');
        await unencryptedBox.put('old_data', jsonEncode({'legacy': true}));
        expect(unencryptedBox.length, greaterThan(0));
        await unencryptedBox.close();

        // Phase 2: Initialize encryption, then try to open the cache.
        await HiveEncryptionService.initialize(
          secureStorageOverride: FakeSecureStorage(),
        );
        await HiveCacheService.initialize();

        // Old data should be gone (migrated = cleared).
        final cached = HiveCacheService.getJson<Map>('old_data');
        expect(cached, isNull);

        // But the box should still work for new data.
        await HiveCacheService.putJson('new_data', <String, dynamic>{
          'migrated': true,
        });
        final newResult = HiveCacheService.getJson<Map>('new_data');
        expect(newResult, isNotNull);
        expect(newResult?['migrated'], true);
      },
    );

    test(
      'cache works correctly without encryption (graceful degradation)',
      () async {
        // Don't initialize encryption — cipher will be null.
        await HiveCacheService.initialize();

        await HiveCacheService.putJson('unencrypted', <String, dynamic>{
          'safe': false,
        });

        final result = HiveCacheService.getJson<Map>('unencrypted');
        expect(result, isNotNull);
        expect(result?['safe'], false);
      },
    );
  });
}
