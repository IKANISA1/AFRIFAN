/// Pure module-registration policy. This is not backend authorization.
///
/// A runtime flag can narrow club capability, never expand an explicitly
/// disabled ClubConfig feature. Hidden modules remain registered for graceful
/// deep-link handling. Null snapshots and absent feature entries retain the
/// existing offline/bootstrap fallback; malformed supplied values fail closed.
String normalizeFeatureKey(String value) => value
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
    .replaceAll(RegExp(r'^_+|_+$'), '');

bool isFeatureOperational({
  required String featureKey,
  required bool clubEnabled,
  Map<String, dynamic>? snapshot,
}) {
  if (!clubEnabled) return false;
  if (snapshot == null) return true;
  final features = snapshot['features'];
  // Preserve bootstrap compatibility when no feature collection is supplied.
  if (!snapshot.containsKey('features')) return true;
  if (features is! List<dynamic>) return false;
  final key = normalizeFeatureKey(featureKey);
  if (key.isEmpty) return false;
  Map<dynamic, dynamic>? matched;
  for (final raw in features) {
    if (raw is! Map<dynamic, dynamic> || raw['feature_key'] is! String) return false;
    if (normalizeFeatureKey(raw['feature_key'] as String) == key) {
      if (matched != null) return false; // Conflicting duplicate entries.
      matched = raw;
    }
  }
  if (matched == null) return true;
  bool enabled(Map<dynamic, dynamic> record, String field) =>
      !record.containsKey(field) || record[field] == true;
  if (!enabled(matched, 'is_enabled')) return false;
  final visibility = matched['visibility_state'];
  if (matched.containsKey('visibility_state') && visibility is! String) {
    return false;
  }
  if (visibility == 'maintenance') return false;
  for (final field in ['channel', 'rules']) {
    final value = matched[field];
    if (value == null && !matched.containsKey(field)) continue;
    // Null optional sub-objects were accepted by the prior model.
    if (value == null) continue;
    if (value is! Map<dynamic, dynamic>) return false;
    if (!enabled(value, field == 'channel' ? 'is_enabled' : 'is_within_schedule')) {
      return false;
    }
  }
  return true;
}
