/// Shared JSON value helpers used across repositories and services.
///
/// These functions safely coerce untyped Supabase payloads into Dart-friendly
/// typed values. Every repository and model in the system depends on these.
library;

typedef JsonMap = Map<String, Object?>;
typedef JsonList = List<Object?>;

/// Coerce [value] to a JSON object map.
/// Throws [StateError] if [value] is not a [Map].
JsonMap asMap(Object? value) {
  if (value is JsonMap) return value;
  if (value is Map) return Map<String, Object?>.from(value);
  throw StateError('Expected a JSON object but received ${value.runtimeType}.');
}

/// Returns [value] as a JSON object map, or `null` when it is not a map.
JsonMap? asMapOrNull(Object? value) {
  if (value is JsonMap) return value;
  if (value is Map) return Map<String, Object?>.from(value);
  return null;
}

/// Returns [value] as a JSON object map, or an empty map if it is not.
JsonMap asMapOrEmpty(Object? value) {
  return asMapOrNull(value) ?? const <String, Object?>{};
}

/// Coerce [value] to a list of JSON object maps.
/// Throws [StateError] if [value] is not a [List].
List<JsonMap> asListOfMaps(Object? value) {
  if (value is! List) {
    throw StateError(
      'Expected a JSON array but received ${value.runtimeType}.',
    );
  }
  return value
      .whereType<Map<dynamic, dynamic>>()
      .map((item) => Map<String, Object?>.from(item))
      .toList(growable: false);
}

/// Safely cast [value] to [bool]. Returns [fallback] for non-boolean values.
bool asBool(Object? value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalized = value.toLowerCase().trim();
    return normalized == 'true' || normalized == '1';
  }
  return fallback;
}

/// Safely cast [value] to [double]. Returns [fallback] for `null`.
double asDouble(Object? value, {double fallback = 0}) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

/// Safely cast [value] to [int]. Returns [fallback] for `null`.
int asInt(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

/// Safely cast [value] to [String]. Returns `null` for `null`.
String? asStringOrNull(Object? value) {
  if (value == null) return null;
  final str = value.toString().trim();
  return str.isEmpty ? null : str;
}

/// Safely parse an ISO-8601 date string. Returns `null` for `null` or invalid.
DateTime? parseDateTime(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}
