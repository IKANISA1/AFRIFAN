import 'dart:convert';

import 'package:core_utils/core_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import 'hive_encryption_service.dart';

/// Generic key-value cache backed by Hive with TTL support.
///
/// Designed for offline-first scenarios on African mobile networks where
/// connectivity is intermittent. Cached data enables graceful degradation
/// (stale data > blank screen).
///
/// Usage:
/// ```dart
/// // Cache fixtures for 10 minutes
/// await HiveCacheService.putJson(
///   'fixtures_scheduled',
///   fixtureListJson,
///   ttl: const Duration(minutes: 10),
/// );
///
/// // Retrieve (returns null if expired or missing)
/// final cached = HiveCacheService.getJson('fixtures_scheduled');
/// ```
class HiveCacheService {
  HiveCacheService._();

  static const _tag = 'HiveCache';
  static const _boxName = 'africlub_cache';
  static const _metaPrefix = '__meta__';

  /// Bump this whenever the cache schema changes (new keys, removed keys,
  /// different serialization format). On mismatch the entire cache is purged
  /// and rebuilt from the network — cache is ephemeral, data loss is fine.
  static const _cacheVersion = 2;
  static const _versionKey = '__cache_version__';

  /// Maximum number of data entries (excluding metadata keys).
  /// When exceeded, the oldest 20% of entries are evicted on next write.
  static const maxEntries = 500;

  static Box<String>? _box;
  static bool _initialized = false;

  /// Initialize the cache box. Must be called after [Hive.initFlutter()]
  /// and [HiveEncryptionService.initialize()].
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      _box = await Hive.openBox<String>(
        _boxName,
        encryptionCipher: HiveEncryptionService.cipher,
      );
      await _migrateIfVersionChanged();
      _initialized = true;
      AfriLogger.info(_tag, 'Cache initialized (${_box!.length} entries).');
    } catch (error, stackTrace) {
      // Migration path: existing unencrypted box cannot be opened with cipher.
      // Delete and recreate — cache is ephemeral, data loss is acceptable.
      try {
        await Hive.deleteBoxFromDisk(_boxName);
        _box = await Hive.openBox<String>(
          _boxName,
          encryptionCipher: HiveEncryptionService.cipher,
        );
        await _stampVersion();
        _initialized = true;
        AfriLogger.info(
          _tag,
          'Cache migrated to encrypted storage (old data cleared).',
        );
        return;
      } catch (_) {
        // Intentional fallthrough to original error handling.
      }
      AfriLogger.error(_tag, 'Failed to initialize cache.', error, stackTrace);
      // Cache failure is non-fatal — the app works without it.
    }
  }

  /// Purge all cached data if the stored version doesn't match the current
  /// compile-time version. This prevents deserialization crashes when the
  /// cache schema evolves between app releases.
  static Future<void> _migrateIfVersionChanged() async {
    final box = _box;
    if (box == null) return;

    final storedVersion = int.tryParse(box.get(_versionKey) ?? '');
    if (storedVersion == _cacheVersion) return;

    final entryCount = box.length;
    await box.clear();
    await _stampVersion();
    AfriLogger.info(
      _tag,
      'Cache version changed ($storedVersion → $_cacheVersion), '
      'purged $entryCount stale entries.',
    );
  }

  static Future<void> _stampVersion() async {
    await _box?.put(_versionKey, _cacheVersion.toString());
  }

  /// Store a JSON-serializable value with optional TTL.
  ///
  /// If [ttl] is null, the entry never expires.
  static Future<void> putJson(String key, Object value, {Duration? ttl}) async {
    final box = _box;
    if (box == null) return;

    try {
      final encoded = jsonEncode(value);
      await box.put(key, encoded);

      if (ttl != null) {
        final expiresAt = DateTime.now().toUtc().add(ttl).toIso8601String();
        await box.put('$_metaPrefix$key', expiresAt);
      } else {
        await box.delete('$_metaPrefix$key');
      }

      // Evict oldest entries if cache exceeds size limit.
      await _evictIfNeeded();
    } catch (error) {
      AfriLogger.warn(_tag, 'Failed to cache "$key": $error');
    }
  }

  /// Retrieve a cached JSON value.
  ///
  /// Returns `null` if the key doesn't exist or has expired.
  /// Expired entries are cleaned up lazily on read.
  static T? getJson<T>(String key, {bool allowExpired = false}) {
    final box = _box;
    if (box == null) return null;

    try {
      // Check TTL first.
      final metaKey = '$_metaPrefix$key';
      final expiresAtStr = box.get(metaKey);
      if (expiresAtStr != null) {
        final expiresAt = DateTime.tryParse(expiresAtStr);
        if (expiresAt != null && DateTime.now().toUtc().isAfter(expiresAt)) {
          if (!allowExpired) {
            return null;
          }
        }
      }

      final raw = box.get(key);
      if (raw == null) return null;
      return jsonDecode(raw) as T;
    } catch (error) {
      AfriLogger.warn(_tag, 'Failed to read "$key": $error');
      return null;
    }
  }

  /// Check if a non-expired cache entry exists.
  static bool has(String key) => getJson<Object>(key) != null;

  /// Remove a specific cache entry.
  static Future<void> remove(String key) async {
    final box = _box;
    if (box == null) return;

    await box.delete(key);
    await box.delete('$_metaPrefix$key');
  }

  /// Clear all cached entries.
  static Future<void> clear() async {
    final box = _box;
    if (box == null) return;

    await box.clear();
    AfriLogger.info(_tag, 'Cache cleared.');
  }

  /// Number of entries (including metadata).
  static int get length => _box?.length ?? 0;

  /// Number of data entries (excluding metadata and version keys).
  static int get dataEntryCount {
    final box = _box;
    if (box == null) return 0;
    return box.keys
        .where((k) => k is String && !k.startsWith(_metaPrefix) && k != _versionKey)
        .length;
  }

  /// Evict oldest entries if the cache exceeds [maxEntries].
  static Future<void> _evictIfNeeded() async {
    final box = _box;
    if (box == null) return;

    final dataKeys = box.keys
        .whereType<String>()
        .where((k) => !k.startsWith(_metaPrefix) && k != _versionKey)
        .toList();
    if (dataKeys.length <= maxEntries) return;

    // Evict oldest 20% — keys are insertion-ordered in Hive.
    final evictCount = (dataKeys.length * 0.2).ceil();
    final toEvict = dataKeys.take(evictCount).toList();
    for (final key in toEvict) {
      await box.delete(key);
      await box.delete('$_metaPrefix$key');
    }
    AfriLogger.info(
      _tag,
      'Evicted $evictCount oldest cache entries (was ${dataKeys.length}, '
      'limit $maxEntries).',
    );
  }

  /// Remove all expired entries. Call periodically (e.g. on app resume)
  /// to reclaim storage.
  static Future<int> purgeExpired() async {
    final box = _box;
    if (box == null) return 0;

    final now = DateTime.now().toUtc();
    var purged = 0;

    final metaKeys = box.keys
        .whereType<String>()
        .where((k) => k.startsWith(_metaPrefix))
        .toList();

    for (final metaKey in metaKeys) {
      final expiresAtStr = box.get(metaKey);
      if (expiresAtStr == null) continue;
      final expiresAt = DateTime.tryParse(expiresAtStr);
      if (expiresAt != null && now.isAfter(expiresAt)) {
        final dataKey = metaKey.substring(_metaPrefix.length);
        await box.delete(dataKey);
        await box.delete(metaKey);
        purged++;
      }
    }

    if (purged > 0) {
      AfriLogger.info(_tag, 'Purged $purged expired cache entries.');
    }
    return purged;
  }

  @visibleForTesting
  static Future<void> resetForTest({bool deleteBox = false}) async {
    final box = _box;
    _box = null;
    _initialized = false;
    if (box != null && box.isOpen) {
      await box.close();
    }
    if (deleteBox) {
      await Hive.deleteBoxFromDisk(_boxName);
    }
  }
}
