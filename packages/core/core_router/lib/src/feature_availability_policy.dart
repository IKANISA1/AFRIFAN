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

/// Reject explicitly mismatched scope without changing legacy snapshots that
/// omit scope. This does not prove the provenance of an unscoped snapshot;
/// repository fetching/caching remains responsible for request scope.
bool isFeatureSnapshotForClub({
  required String clubId,
  Map<String, dynamic>? snapshot,
}) {
  if (snapshot == null) return true;
  if (snapshot.containsKey('channel') && snapshot['channel'] != 'mobile') {
    return false;
  }
  if (!snapshot.containsKey('club_id')) return true;
  final expected = int.tryParse(clubId.trim());
  final raw = snapshot['club_id'];
  final actual = switch (raw) {
    final int value => value,
    final String value => int.tryParse(value.trim()),
    _ => null,
  };
  return expected != null && expected > 0 && actual == expected;
}

bool isFeatureOperational({
  required String featureKey,
  required bool clubEnabled,
  Map<String, dynamic>? snapshot,
}) {
  final key = normalizeFeatureKey(featureKey);
  if (!clubEnabled || key.isEmpty) return false;
  if (snapshot == null) return true;
  final features = snapshot['features'];
  // Preserve bootstrap compatibility when no feature collection is supplied.
  if (!snapshot.containsKey('features')) return true;
  if (features is! List<dynamic>) return false;
  Map<dynamic, dynamic>? matched;
  final seenKeys = <String>{};
  for (final raw in features) {
    if (raw is! Map<dynamic, dynamic> || raw['feature_key'] is! String) {
      return false;
    }
    final recordKey = normalizeFeatureKey(raw['feature_key'] as String);
    if (recordKey.isEmpty || !seenKeys.add(recordKey)) return false;
    if (recordKey == key) matched = raw;
  }
  if (matched == null) return true;
  bool enabled(Map<dynamic, dynamic> record, String field) =>
      !record.containsKey(field) || record[field] == true;
  if (!enabled(matched, 'is_enabled')) return false;
  if (matched.containsKey('visibility_state') &&
      !const {
        'visible',
        'hidden',
        'maintenance',
      }.contains(matched['visibility_state'])) {
    return false;
  }
  if (matched['visibility_state'] == 'maintenance') return false;
  for (final field in ['channel', 'rules']) {
    final value = matched[field];
    // Null optional sub-objects are supplied by the current typed model.
    if (value == null) continue;
    if (value is! Map<dynamic, dynamic>) return false;
    if (!enabled(
      value,
      field == 'channel' ? 'is_enabled' : 'is_within_schedule',
    )) {
      return false;
    }
  }
  return true;
}
