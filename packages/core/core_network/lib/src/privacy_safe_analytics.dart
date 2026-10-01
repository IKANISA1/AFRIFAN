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
    'feature_gated': <String>{'feature'},
    'home_action_selected': <String>{'action', 'layer'},
    'search_entry': <String>{},
    'search_success': <String>{'category', 'result_count_bucket'},
    'ticket_completion': <String>{'ticket_type', 'payment_channel'},
    'contribution_completion': <String>{'payment_channel', 'value_bucket'},
    'predict_engagement': <String>{'surface', 'action'},
    'support_access': <String>{'channel'},
    'error_recovery': <String>{'surface', 'outcome'},
    'task_abandonment': <String>{'task', 'stage'},
  };

  static const _valueBuckets = <String>{
    'zero',
    'under_100',
    '100_999',
    '1000_9999',
    '10000_99999',
    '100000_plus',
  };
  static const _features = <String>{
    'home',
    'club',
    'live',
    'predict',
    'settings',
    'onboarding',
    'membership',
    'contributions',
    'ticketing',
    'fan_clubs',
    'admin',
    'shop',
    'news',
    'squad',
  };

  /// Values are closed per event and parameter. A syntactically coded string
  /// is not sufficient: backend-supplied labels and opaque aliases fail closed.
  static const parameterValues = <String, Map<String, Set<String>>>{
    'sign_in': {
      'method': {'anonymous', 'phone_otp'},
    },
    'onboarding_complete': {},
    'profile_update': {
      'field': {'display_name', 'avatar', 'language', 'phone'},
    },
    'prediction_placed': {
      'market': {'wdw'},
      'outcome': {'home', 'draw', 'away'},
      'value_bucket': _valueBuckets,
    },
    'prediction_settled': {
      'status': {'won', 'lost', 'void', 'refunded'},
      'value_bucket': _valueBuckets,
    },
    'wallet_transfer': {
      'direction': {'sent', 'received'},
      'value_bucket': _valueBuckets,
    },
    'challenge_created': {'value_bucket': _valueBuckets},
    'challenge_joined': {},
    'membership_action': {
      'action': {'created', 'renewed'},
    },
    'feature_gated': {'feature': _features},
    'home_action_selected': {
      'action': {'tickets', 'membership', 'predict', 'shop'},
      'layer': {'primary', 'secondary'},
    },
    'search_entry': {},
    'search_success': {
      'category': {
        'all',
        'club',
        'supporters',
        'fixtures',
        'commerce',
        'services',
      },
      'result_count_bucket': {
        'zero',
        'one',
        'two_to_five',
        'six_to_twenty',
        'twenty_one_plus',
      },
    },
    'ticket_completion': {
      'ticket_type': {'general', 'vip'},
      'payment_channel': {'momo'},
    },
    'contribution_completion': {
      'payment_channel': {'momo'},
      'value_bucket': _valueBuckets,
    },
    'predict_engagement': {
      'surface': {'predict', 'match_detail'},
      'action': {'view', 'select', 'review', 'submit'},
    },
    'support_access': {
      'channel': {'whatsapp'},
    },
    'error_recovery': {
      'surface': {
        'notification_settings',
        'profile_settings',
        'privacy_settings',
        'search',
      },
      'outcome': {'conflict_refresh', 'retry_requested'},
    },
    'task_abandonment': {
      'task': {'predict', 'ticket_checkout'},
      'stage': {'review', 'checkout_review'},
    },
  };

  /// Mobile registry public path shapes; parameter contents are never copied.
  /// The two legacy tickets/orders shapes retain existing coarse SDK labels.
  static const screenTemplates = <String>{
    '/admin',
    '/admin/cms',
    '/admin/competitions',
    '/admin/contributions',
    '/admin/features',
    '/admin/features/:item',
    '/admin/matches',
    '/admin/notifications',
    '/admin/predict',
    '/admin/settle',
    '/auth/otp',
    '/auth/phone',
    '/club',
    '/club/fixtures',
    '/club/fixtures/:item',
    '/club/history',
    '/club/news',
    '/club/news/:item',
    '/club/open-web',
    '/club/partners',
    '/club/partners/:item',
    '/club/projects',
    '/club/projects/:item',
    '/club/results',
    '/club/standings',
    '/club/team',
    '/club/team/:item',
    '/contribute',
    '/contribute/group/:item',
    '/contribute/group/:item/statement',
    '/contribute/groups',
    '/contribute/projects',
    '/e-ticket/:item',
    '/fan-clubs',
    '/fan-clubs/:item',
    '/feature-unavailable',
    '/home',
    '/live',
    '/live-match',
    '/live/news/:item',
    '/membership',
    '/membership/fans',
    '/membership/native',
    '/membership/tier/:item',
    '/my-tickets',
    '/onboarding',
    '/orders/:item',
    '/predict',
    '/predict/match/:item',
    '/predict/picks/:item',
    '/predict/share',
    '/search',
    '/settings',
    '/settings/edit-profile',
    '/settings/notifications',
    '/settings/privacy',
    '/shop',
    '/shop/cart',
    '/shop/product/:item',
    '/splash',
    '/tickets',
    '/tickets/:item',
    '/tickets/detail/:item',
    '/tickets/map/:item',
  };
  static const screenAliases = <String, String>{
    'club': '/club',
    'club-fixture-detail': '/club/fixtures/:item',
    'club-fixtures': '/club/fixtures',
    'club-history': '/club/history',
    'club-news': '/club/news',
    'club-news-detail': '/club/news/:item',
    'club-partner-detail': '/club/partners/:item',
    'club-partners': '/club/partners',
    'club-player-detail': '/club/team/:item',
    'club-project-detail': '/club/projects/:item',
    'club-projects': '/club/projects',
    'club-public-link': '/club/open-web',
    'club-results': '/club/results',
    'club-standings': '/club/standings',
    'club-team': '/club/team',
    'contribute': '/contribute',
    'discovery-search': '/search',
    'group-detail': '/contribute/group/:item',
    'home': '/home',
    'live': '/live',
    'membership': '/membership',
    'membership-fans': '/membership/fans',
    'membership-native': '/membership/native',
    'predict': '/predict',
    'product-detail': '/shop/product/:item',
    'settings': '/settings',
    'shop': '/shop',
    'shop-cart': '/shop/cart',
  };

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
      if (value is! String) return null;
      final normalized = value.trim().toLowerCase();
      if (!(parameterValues[name]?[entry.key]?.contains(normalized) ?? false)) {
        return null;
      }
      sanitized[entry.key] = normalized;
    }

    return PrivacySafeAnalyticsEvent(
      name: name,
      parameters: Map<String, Object>.unmodifiable(sanitized),
    );
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

  /// Emits only a public template or an approved route-name alias.
  static String? sanitizeScreenName(String screenName) {
    final raw = screenName.split(RegExp(r'[?#]')).first.trim();
    final alias = screenAliases[raw];
    if (alias != null) return alias;
    if (!raw.startsWith('/') || raw.contains('@') || raw.contains('\\')) {
      return null;
    }
    final incoming = raw.split('/');
    if (incoming.any((part) => part == '.' || part == '..')) return null;
    for (final template in screenTemplates) {
      final expected = template.split('/');
      if (incoming.length != expected.length) continue;
      var matches = true;
      for (var index = 0; index < expected.length; index++) {
        if (expected[index] == ':item') {
          if (incoming[index].isEmpty) matches = false;
        } else if (expected[index] != incoming[index]) {
          matches = false;
        }
      }
      if (matches) return template;
    }
    return null;
  }

  static String? sanitizeScreenClass(String value) =>
      value == 'Flutter' ? 'Flutter' : null;
}
