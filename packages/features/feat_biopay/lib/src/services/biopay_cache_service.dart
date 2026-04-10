import 'dart:math' show sqrt;

import 'package:hive/hive.dart';

import '../models/biopay_match_result.dart';

/// Typedef for testable Hive box opening.
typedef OpenHiveBox<T> = Future<Box<T>> Function(String name);
typedef DeleteHiveBox = Future<void> Function(String name);

class _CachedMatchEntry {
  const _CachedMatchEntry({
    required this.ownerUserId,
    required this.expiresAt,
    required this.embedding,
    required this.payload,
  });

  final String ownerUserId;
  final DateTime expiresAt;
  final List<double> embedding;
  final Map<String, Object?> payload;
}

/// In-memory cosine-similarity cache for BioPay match results.
///
/// Stores recent results keyed by (ownerUserId, profileId) with TTL expiry.
/// Persistent device storage is intentionally avoided for privacy reasons.
class BiopayCacheService {
  BiopayCacheService({OpenHiveBox<dynamic>? openBox, DeleteHiveBox? deleteBox})
    : _openBox = openBox,
      _deleteBox = deleteBox;

  static const boxName = 'biopay_match_cache_v1';
  static final Map<String, _CachedMatchEntry> _sharedEntries =
      <String, _CachedMatchEntry>{};
  static bool _legacyPersistentCachePurged = false;

  final OpenHiveBox<dynamic>? _openBox;
  final DeleteHiveBox? _deleteBox;

  Future<void> storeMatch(
    String ownerUserId,
    List<double> embedding,
    BiopayMatchResult result, {
    Duration ttl = const Duration(hours: 24),
  }) async {
    final profileId = result.profile?.id;
    if (ownerUserId.trim().isEmpty || profileId == null || profileId.isEmpty) {
      return;
    }
    _pruneExpiredEntries();
    _sharedEntries[_cacheKey(ownerUserId, profileId)] = _CachedMatchEntry(
      ownerUserId: ownerUserId,
      expiresAt: DateTime.now().add(ttl).toUtc(),
      embedding: List<double>.unmodifiable(embedding),
      payload: _buildCachePayload(result),
    );
  }

  Future<BiopayMatchResult?> findNearestMatch(
    List<double> embedding, {
    required String ownerUserId,
    double similarityThreshold = 0.96,
  }) async {
    final now = DateTime.now().toUtc();
    BiopayMatchResult? bestMatch;
    var bestScore = similarityThreshold;

    final expiredKeys = <String>[];
    for (final entry in _sharedEntries.entries) {
      final cached = entry.value;
      if (cached.ownerUserId != ownerUserId) continue;
      if (cached.expiresAt.isBefore(now)) {
        expiredKeys.add(entry.key);
        continue;
      }
      if (cached.embedding.length != embedding.length) {
        expiredKeys.add(entry.key);
        continue;
      }

      final score = _cosineSimilarity(embedding, cached.embedding);
      if (score >= bestScore) {
        bestScore = score;
        bestMatch = BiopayMatchResult.fromCacheJson(cached.payload);
      }
    }

    for (final key in expiredKeys) {
      _sharedEntries.remove(key);
    }

    return bestMatch;
  }

  Future<void> remove(String profileId, {String? ownerUserId}) async {
    if (ownerUserId != null && ownerUserId.trim().isNotEmpty) {
      _sharedEntries.remove(_cacheKey(ownerUserId, profileId));
      return;
    }

    final keysToDelete = _sharedEntries.keys
        .where((key) => key.endsWith(':$profileId'))
        .toList(growable: false);
    for (final key in keysToDelete) {
      _sharedEntries.remove(key);
    }
  }

  Future<void> clear({String? ownerUserId}) async {
    if (ownerUserId != null && ownerUserId.trim().isNotEmpty) {
      final keysToDelete = _sharedEntries.entries
          .where((entry) => entry.value.ownerUserId == ownerUserId)
          .map((entry) => entry.key)
          .toList(growable: false);
      for (final key in keysToDelete) {
        _sharedEntries.remove(key);
      }
      return;
    }
    _sharedEntries.clear();
  }

  Future<void> purgeLegacyPersistentCache({bool force = false}) async {
    if (_legacyPersistentCachePurged && !force) {
      return;
    }
    _legacyPersistentCachePurged = true;

    try {
      if (_deleteBox case final deleteBox?) {
        await deleteBox(boxName);
        return;
      }
      if (_openBox case final openBox?) {
        final box = await openBox(boxName);
        await box.clear();
        await box.close();
      }
    } catch (_) {
      // Best-effort cleanup for older installs that persisted match data.
    }
  }

  // ─── Math ─────────────────────────────────────────────────

  double _cosineSimilarity(List<double> a, List<double> b) {
    var dot = 0.0;
    var normA = 0.0;
    var normB = 0.0;
    for (var i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    if (normA == 0 || normB == 0) return 0;
    return dot / (sqrt(normA) * sqrt(normB));
  }

  // ─── Payload ──────────────────────────────────────────────

  Map<String, Object?> _buildCachePayload(BiopayMatchResult result) {
    final profile = result.profile;
    return <String, Object?>{
      'match': result.match,
      'score': result.score,
      'cached': true,
      'profile': profile == null
          ? null
          : <String, Object?>{
              'id': profile.id,
              'public_id': profile.publicId,
              'user_id': profile.userId,
              'display_name': profile.displayName,
              'route_type': profile.routeType.name,
              'country_code': profile.countryCode,
              'active': profile.active,
              'consent_version': profile.consentVersion,
              'consent_at': profile.consentAt?.toIso8601String(),
              'created_at': profile.createdAt?.toIso8601String(),
              'updated_at': profile.updatedAt?.toIso8601String(),
              'revoked_at': profile.revokedAt?.toIso8601String(),
            },
    };
  }

  String _cacheKey(String ownerUserId, String profileId) {
    return '$ownerUserId:$profileId';
  }

  void _pruneExpiredEntries() {
    final now = DateTime.now().toUtc();
    final expiredKeys = _sharedEntries.entries
        .where((entry) => entry.value.expiresAt.isBefore(now))
        .map((entry) => entry.key)
        .toList(growable: false);
    for (final key in expiredKeys) {
      _sharedEntries.remove(key);
    }
  }
}
