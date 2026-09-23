import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class RecentDiscoverySearchStore {
  Future<List<String>> load();
  Future<void> save(List<String> searches);
  Future<void> clear();
}

/// Persists recent discovery terms in platform-protected local storage.
///
/// Search terms never enter analytics parameters and are removed as a single
/// record when the user clears their history.
class SecureRecentDiscoverySearchStore implements RecentDiscoverySearchStore {
  const SecureRecentDiscoverySearchStore({
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) : _storage = storage;

  static const storageKey = 'africlub.recent_discovery_searches.v1';
  final FlutterSecureStorage _storage;

  @override
  Future<List<String>> load() async {
    try {
      final value = await _storage.read(key: storageKey);
      if (value == null || value.isEmpty) {
        return const <String>[];
      }
      final decoded = jsonDecode(value);
      if (decoded is! List<dynamic>) {
        return const <String>[];
      }
      return decoded
          .whereType<String>()
          .map((item) => item.trim())
          .where((item) => item.length >= 2 && item.length <= 80)
          .toList(growable: false);
    } catch (_) {
      return const <String>[];
    }
  }

  @override
  Future<void> save(List<String> searches) async {
    try {
      await _storage.write(key: storageKey, value: jsonEncode(searches));
    } catch (_) {
      // Search remains usable in memory when protected storage is unavailable.
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _storage.delete(key: storageKey);
    } catch (_) {
      // The in-memory state is still cleared for this session.
    }
  }
}
