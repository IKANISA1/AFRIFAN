/// A validated analytics event that contains only coarse, non-identifying
/// product signals.
class PrivacySafeAnalyticsEvent {
  const PrivacySafeAnalyticsEvent({
    required this.name,
    required this.parameters,
  });

  final String name;
  final Map<String, Object> parameters;

  Map<String, Object> toJson() => <String, Object>{
    'name': name,
    'parameters': parameters,
  };
}

/// Closed, reviewable contract for product analytics.
///
/// Unknown events, unknown parameters, identifiers, free text, contact
/// details, secrets, precise transaction values, and malformed values are
/// rejected rather than forwarded to an analytics SDK.
class PrivacySafeAnalyticsPolicy {
  const PrivacySafeAnalyticsPolicy._();

  static const Map<String, Set<String>> taxonomy = <String, Set<String>>{
    'sign_in': <String>{'method'},
    'onboarding_complete': <String>{},
    'profile_update': <String>{'field'},
    'prediction_placed': <String>{'market', 'outcome', 'value_bucket'},
    'prediction_settled': <String>{'status', 'value_bucket'},
    'wallet_transfer': <String>{'direction', 'value_bucket'},
    'challenge_created': <String>{'value_bucket'},
    'challenge_joined': <String>{},
    'membership_action': <String>{'action'},
    'momo_sms_parsed': <String>{'provider', 'value_bucket'},
    'feature_gated': <String>{'feature'},
    'home_action_selected': <String>{'action', 'layer'},
    'search_entry': <String>{},
    'search_success': <String>{'category', 'result_count_bucket'},
    'ticket_completion': <String>{'ticket_type', 'payment_channel'},
    'contribution_completion': <String>{'payment_channel', 'value_bucket'},
    'fanzone_engagement': <String>{'surface', 'action'},
    'support_access': <String>{'channel'},
    'error_recovery': <String>{'surface', 'outcome'},
    'task_abandonment': <String>{'task', 'stage'},
  };

  static final RegExp _safeValue = RegExp(r'^[a-z0-9][a-z0-9_:/.-]{0,47}$');
  static final RegExp _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    caseSensitive: false,
  );
  static final RegExp _longDigits = RegExp(r'\d{6,}');
  static final RegExp _routeNumericSegment = RegExp(r'^\d+$');

  static PrivacySafeAnalyticsEvent? prepare(
    String name, {
    Map<String, Object>? parameters,
  }) {
    final allowedKeys = taxonomy[name];
    if (allowedKeys == null) return null;

    final incoming = parameters ?? const <String, Object>{};
    if (incoming.keys.any((key) => !allowedKeys.contains(key))) {
      return null;
    }

    final sanitized = <String, Object>{};
    for (final entry in incoming.entries) {
      final value = entry.value;
      if (value is bool) {
        sanitized[entry.key] = value;
        continue;
      }
      if (value is! String) return null;

      final normalized = value.trim().toLowerCase();
      if (!_isSafeCodedValue(normalized)) return null;
      sanitized[entry.key] = normalized;
    }

    return PrivacySafeAnalyticsEvent(
      name: name,
      parameters: Map<String, Object>.unmodifiable(sanitized),
    );
  }

  static bool _isSafeCodedValue(String value) {
    if (!_safeValue.hasMatch(value)) return false;
    if (value.contains('@') ||
        _uuid.hasMatch(value) ||
        _longDigits.hasMatch(value) ||
        value.startsWith('eyj') ||
        value.contains('bearer') ||
        value.contains('token')) {
      return false;
    }
    return true;
  }

  /// Converts a precise monetary or points value into a non-identifying band.
  static String valueBucket(int value) {
    final magnitude = value.abs();
    if (magnitude == 0) return 'zero';
    if (magnitude < 100) return 'under_100';
    if (magnitude < 1000) return '100_999';
    if (magnitude < 10000) return '1000_9999';
    if (magnitude < 100000) return '10000_99999';
    return '100000_plus';
  }

  static String resultCountBucket(int count) {
    if (count <= 0) return 'zero';
    if (count == 1) return 'one';
    if (count <= 5) return 'two_to_five';
    if (count <= 20) return 'six_to_twenty';
    return 'twenty_one_plus';
  }

  /// Removes query strings and replaces numeric or UUID path segments before
  /// a screen name can be emitted.
  static String? sanitizeScreenName(String screenName) {
    final rawPath = screenName.split(RegExp(r'[?#]')).first.trim();
    if (rawPath.isEmpty || rawPath.contains('@')) return null;

    final segments = rawPath
        .split('/')
        .map((segment) {
          final normalized = segment.trim().toLowerCase();
          if (_routeNumericSegment.hasMatch(normalized) ||
              _uuid.hasMatch(normalized)) {
            return ':item';
          }
          return normalized;
        })
        .toList(growable: false);
    final sanitized = segments.join('/');
    if (sanitized.length > 80 ||
        _longDigits.hasMatch(sanitized) ||
        sanitized.contains('token')) {
      return null;
    }
    return sanitized;
  }
}
