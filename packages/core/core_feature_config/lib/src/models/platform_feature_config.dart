import 'dart:convert';

String normalizePlatformFeatureKey(String? value) {
  final normalized = (value ?? '').trim().toLowerCase();
  if (normalized.isEmpty) {
    return '';
  }

  return normalized
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
}

class FeatureAccessState {
  const FeatureAccessState({
    required this.featureKey,
    required this.normalizedKey,
    required this.isRegistered,
    required this.isVisible,
    required this.isOperational,
    required this.isAvailable,
    required this.showInNavigation,
    required this.showOnHome,
    required this.routeKey,
    required this.placementKey,
    required this.reason,
    this.feature,
  });

  final PlatformFeature? feature;
  final String featureKey;
  final String normalizedKey;
  final bool isRegistered;
  final bool isVisible;
  final bool isOperational;
  final bool isAvailable;
  final bool showInNavigation;
  final bool showOnHome;
  final String? routeKey;
  final String? placementKey;
  final String reason;
}

// ── PlatformConfigSnapshot ──

/// The full platform config payload returned by the RPC.
class PlatformConfigSnapshot {
  const PlatformConfigSnapshot({
    this.features = const <PlatformFeature>[],
    this.contentBlocks = const <ContentBlock>[],
    this.routeRegistry = const <PlatformRouteConfig>[],
    this.optionSets = const <PlatformOptionSet>[],
    this.runtimeCopy = const <RuntimeCopyEntry>[],
    this.siteNavigation = const <SiteNavigationItem>[],
    this.siteSearch = const <SiteSearchItem>[],
    this.venueGovernanceControls = const <VenueGovernanceControl>[],
    this.configVersion,
    this.channel = 'mobile',
  });

  final List<PlatformFeature> features;
  final List<ContentBlock> contentBlocks;
  final List<PlatformRouteConfig> routeRegistry;
  final List<PlatformOptionSet> optionSets;
  final List<RuntimeCopyEntry> runtimeCopy;
  final List<SiteNavigationItem> siteNavigation;
  final List<SiteSearchItem> siteSearch;
  final List<VenueGovernanceControl> venueGovernanceControls;
  final DateTime? configVersion;
  final String channel;

  /// Quick lookup for a feature by key.
  PlatformFeature? featureByKey(String key) {
    final normalizedKey = normalizePlatformFeatureKey(key);
    for (final feature in features) {
      if (normalizePlatformFeatureKey(feature.featureKey) == normalizedKey) {
        return feature;
      }
    }
    return null;
  }

  PlatformRouteConfig? routeByPath(String path) {
    final normalizedPath = path.trim().toLowerCase();
    final routes =
        routeRegistry
            .where((route) => route.pathPattern.startsWith('/'))
            .toList(growable: false)
          ..sort(
            (left, right) =>
                right.pathPattern.length.compareTo(left.pathPattern.length),
          );

    for (final route in routes) {
      final pattern = route.pathPattern.trim().toLowerCase();
      if (pattern == normalizedPath || normalizedPath.startsWith('$pattern/')) {
        return route;
      }
    }
    return null;
  }

  PlatformOptionSet? optionSetByKey(String key) {
    final normalizedKey = normalizePlatformFeatureKey(key);
    for (final set in optionSets) {
      if (normalizePlatformFeatureKey(set.optionSetKey) == normalizedKey) {
        return set;
      }
    }
    return null;
  }

  List<int> intOptions(String key) {
    final set = optionSetByKey(key);
    if (set == null) return const <int>[];
    return set.values
        .map((entry) => entry.value)
        .map((value) {
          if (value is num) return value.toInt();
          return int.tryParse(value.toString());
        })
        .whereType<int>()
        .toList(growable: false);
  }

  List<String> stringOptions(String key) {
    final set = optionSetByKey(key);
    if (set == null) return const <String>[];
    return set.values
        .map((entry) {
          final value = entry.value;
          if (value == null) return '';
          return value.toString().trim();
        })
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
  }

  String? copyValue(String key, {String locale = 'en'}) {
    final normalizedKey = normalizePlatformFeatureKey(key);
    // Runtime configuration cannot override the English-only product policy.
    const localeFallbacks = <String>{'en'};
    for (final candidateLocale in localeFallbacks) {
      for (final entry in runtimeCopy) {
        if (normalizePlatformFeatureKey(entry.copyKey) == normalizedKey &&
            _normalizeRuntimeCopyLocale(entry.locale) == candidateLocale &&
            entry.textValue.trim().isNotEmpty) {
          return entry.textValue;
        }
      }
    }
    return null;
  }

  bool get isEmpty => features.isEmpty;
  bool get isNotEmpty => features.isNotEmpty;

  factory PlatformConfigSnapshot.fromJson(Map<String, dynamic> json) {
    final rawFeatures = json['features'];
    final rawBlocks = json['content_blocks'];
    final rawRoutes = json['route_registry'];
    final rawOptionSets = json['option_sets'];
    final rawRuntimeCopy = json['runtime_copy'];
    final rawSiteNavigation = json['site_navigation'];
    final rawSiteSearch = json['site_search'];
    final rawVenueGovernance = json['venue_governance_controls'];

    return PlatformConfigSnapshot(
      features: rawFeatures is List
          ? rawFeatures
                .whereType<Map<String, dynamic>>()
                .map(PlatformFeature.fromJson)
                .toList(growable: false)
          : const <PlatformFeature>[],
      contentBlocks: rawBlocks is List
          ? rawBlocks
                .whereType<Map<String, dynamic>>()
                .map(ContentBlock.fromJson)
                .toList(growable: false)
          : const <ContentBlock>[],
      routeRegistry: rawRoutes is List
          ? rawRoutes
                .whereType<Map<String, dynamic>>()
                .map(PlatformRouteConfig.fromJson)
                .toList(growable: false)
          : const <PlatformRouteConfig>[],
      optionSets: rawOptionSets is List
          ? rawOptionSets
                .whereType<Map<String, dynamic>>()
                .map(PlatformOptionSet.fromJson)
                .toList(growable: false)
          : const <PlatformOptionSet>[],
      runtimeCopy: rawRuntimeCopy is List
          ? rawRuntimeCopy
                .whereType<Map<String, dynamic>>()
                .map(RuntimeCopyEntry.fromJson)
                .toList(growable: false)
          : const <RuntimeCopyEntry>[],
      siteNavigation: rawSiteNavigation is List
          ? rawSiteNavigation
                .whereType<Map<String, dynamic>>()
                .map(SiteNavigationItem.fromJson)
                .toList(growable: false)
          : const <SiteNavigationItem>[],
      siteSearch: rawSiteSearch is List
          ? rawSiteSearch
                .whereType<Map<String, dynamic>>()
                .map(SiteSearchItem.fromJson)
                .toList(growable: false)
          : const <SiteSearchItem>[],
      venueGovernanceControls: rawVenueGovernance is List
          ? rawVenueGovernance
                .whereType<Map<String, dynamic>>()
                .map(VenueGovernanceControl.fromJson)
                .toList(growable: false)
          : const <VenueGovernanceControl>[],
      configVersion: _tryParseDateTime(json['config_version']),
      channel: json['channel'] as String? ?? 'mobile',
    );
  }

  Map<String, dynamic> toJson() => {
    'features': features.map((f) => f.toJson()).toList(growable: false),
    'content_blocks': contentBlocks
        .map((b) => b.toJson())
        .toList(growable: false),
    'route_registry': routeRegistry
        .map((route) => route.toJson())
        .toList(growable: false),
    'option_sets': optionSets
        .map((set) => set.toJson())
        .toList(growable: false),
    'runtime_copy': runtimeCopy
        .map((entry) => entry.toJson())
        .toList(growable: false),
    'site_navigation': siteNavigation
        .map((entry) => entry.toJson())
        .toList(growable: false),
    'site_search': siteSearch
        .map((entry) => entry.toJson())
        .toList(growable: false),
    'venue_governance_controls': venueGovernanceControls
        .map((entry) => entry.toJson())
        .toList(growable: false),
    'config_version': configVersion?.toIso8601String(),
    'channel': channel,
  };

  String toJsonString() => jsonEncode(toJson());

  factory PlatformConfigSnapshot.fromJsonString(String json) {
    return PlatformConfigSnapshot.fromJson(
      jsonDecode(json) as Map<String, dynamic>,
    );
  }

  /// Empty snapshot used as a safe fallback.
  static const PlatformConfigSnapshot empty = PlatformConfigSnapshot();
}

String _normalizeRuntimeCopyLocale(String value) {
  final normalized = value.trim().replaceAll('_', '-').toLowerCase();
  return normalized.isEmpty ? 'en' : normalized;
}

// ── PlatformFeature ──

/// A single platform feature with its channel and rule configuration.
class PlatformFeature {
  const PlatformFeature({
    required this.featureKey,
    required this.displayName,
    this.description,
    this.category,
    this.isEnabled = true,
    this.visibilityState = 'visible',
    this.channel,
    this.rules,
  });

  final String featureKey;
  final String displayName;
  final String? description;
  final String? category;
  final bool isEnabled;
  final String visibilityState;
  final FeatureChannelConfig? channel;
  final FeatureRuleConfig? rules;

  bool get isOperationallyEnabled {
    if (!isEnabled) return false;
    if (!(channel?.isEnabled ?? true)) return false;
    if (visibilityState == 'maintenance') return false;
    if (!(rules?.isWithinSchedule ?? true)) return false;
    return true;
  }

  bool get isVisibleByConfig {
    if (visibilityState == 'hidden') return false;
    if (!(channel?.isVisible ?? true)) return false;
    return true;
  }

  /// Whether this feature is effectively available for the current channel,
  /// considering global enable, channel enable, visibility state, and schedule.
  bool get isEffectivelyEnabled {
    return isOperationallyEnabled && isVisibleByConfig;
  }

  factory PlatformFeature.fromJson(Map<String, dynamic> json) {
    return PlatformFeature(
      featureKey: json['feature_key'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
      description: json['description'] as String?,
      category: json['category'] as String?,
      isEnabled: json['is_enabled'] as bool? ?? true,
      visibilityState: json['visibility_state'] as String? ?? 'visible',
      channel: json['channel'] != null
          ? FeatureChannelConfig.fromJson(
              json['channel'] as Map<String, dynamic>,
            )
          : null,
      rules: json['rules'] != null
          ? FeatureRuleConfig.fromJson(json['rules'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'feature_key': featureKey,
    'display_name': displayName,
    'description': description,
    'category': category,
    'is_enabled': isEnabled,
    'visibility_state': visibilityState,
    'channel': channel?.toJson(),
    'rules': rules?.toJson(),
  };
}

// ── FeatureChannelConfig ──

/// A single feature's channel-specific configuration.
class FeatureChannelConfig {
  const FeatureChannelConfig({
    this.isEnabled = true,
    this.isVisible = true,
    this.showInNavigation = false,
    this.showOnHome = false,
    this.sortOrder,
    this.routeKey,
    this.placementKey,
  });

  final bool isEnabled;
  final bool isVisible;
  final bool showInNavigation;
  final bool showOnHome;
  final int? sortOrder;
  final String? routeKey;
  final String? placementKey;

  factory FeatureChannelConfig.fromJson(Map<String, dynamic> json) {
    return FeatureChannelConfig(
      isEnabled: json['is_enabled'] as bool? ?? true,
      isVisible: json['is_visible'] as bool? ?? true,
      showInNavigation: json['show_in_navigation'] as bool? ?? false,
      showOnHome: json['show_on_home'] as bool? ?? false,
      sortOrder: (json['sort_order'] as num?)?.toInt(),
      routeKey: json['route_key'] as String?,
      placementKey: json['placement_key'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'is_enabled': isEnabled,
    'is_visible': isVisible,
    'show_in_navigation': showInNavigation,
    'show_on_home': showOnHome,
    'sort_order': sortOrder,
    'route_key': routeKey,
    'placement_key': placementKey,
  };
}

// ── FeatureRuleConfig ──

/// Feature access rules (auth, roles, scheduling, dependencies).
class FeatureRuleConfig {
  const FeatureRuleConfig({
    this.authRequired = false,
    this.roleRestrictions = const <String>[],
    this.dependencyRules = const <String, dynamic>{},
    this.rolloutRules = const <String, dynamic>{},
    this.scheduleStartAt,
    this.scheduleEndAt,
    this.isWithinSchedule = true,
  });

  final bool authRequired;
  final List<String> roleRestrictions;
  final Map<String, dynamic> dependencyRules;
  final Map<String, dynamic> rolloutRules;
  final DateTime? scheduleStartAt;
  final DateTime? scheduleEndAt;
  final bool isWithinSchedule;

  factory FeatureRuleConfig.fromJson(Map<String, dynamic> json) {
    final roleRestrictions = <String>[];
    final rawRoles = json['role_restrictions'];
    if (rawRoles is List) {
      for (final role in rawRoles) {
        if (role is String) roleRestrictions.add(role);
      }
    }

    return FeatureRuleConfig(
      authRequired: json['auth_required'] as bool? ?? false,
      roleRestrictions: roleRestrictions,
      dependencyRules: _asStringDynamicMap(json['dependency_rules']),
      rolloutRules: _asStringDynamicMap(json['rollout_rules']),
      scheduleStartAt: _tryParseDateTime(json['schedule_start_at']),
      scheduleEndAt: _tryParseDateTime(json['schedule_end_at']),
      isWithinSchedule: json['is_within_schedule'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'auth_required': authRequired,
    'role_restrictions': roleRestrictions,
    'dependency_rules': dependencyRules,
    'rollout_rules': rolloutRules,
    'schedule_start_at': scheduleStartAt?.toIso8601String(),
    'schedule_end_at': scheduleEndAt?.toIso8601String(),
    'is_within_schedule': isWithinSchedule,
  };
}

// ── ContentBlock ──

/// An admin-managed content block (homepage section, banner, promo).
class ContentBlock {
  const ContentBlock({
    required this.blockKey,
    required this.blockType,
    this.title,
    this.subtitle,
    this.content = const <String, dynamic>{},
    required this.placementKey,
    this.featureKey,
    this.isActive = true,
    this.sortOrder,
    this.metadata = const <String, dynamic>{},
  });

  final String blockKey;
  final String blockType;
  final String? title;
  final String? subtitle;
  final Map<String, dynamic> content;
  final String placementKey;
  final String? featureKey;
  final bool isActive;
  final int? sortOrder;
  final Map<String, dynamic> metadata;

  factory ContentBlock.fromJson(Map<String, dynamic> json) {
    return ContentBlock(
      blockKey: json['block_key'] as String? ?? '',
      blockType: json['block_type'] as String? ?? '',
      title: json['title'] as String?,
      subtitle: json['subtitle'] as String?,
      content: _asStringDynamicMap(json['content']),
      placementKey: json['placement_key'] as String? ?? '',
      featureKey: json['feature_key'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      sortOrder: (json['sort_order'] as num?)?.toInt(),
      metadata: _asStringDynamicMap(json['metadata']),
    );
  }

  Map<String, dynamic> toJson() => {
    'block_key': blockKey,
    'block_type': blockType,
    'title': title,
    'subtitle': subtitle,
    'content': content,
    'placement_key': placementKey,
    'feature_key': featureKey,
    'is_active': isActive,
    'sort_order': sortOrder,
    'metadata': metadata,
  };
}

class PlatformRouteConfig {
  const PlatformRouteConfig({
    required this.routeKey,
    required this.pathPattern,
    required this.surface,
    required this.featureKey,
    this.label,
    this.authRequired = false,
    this.requiredRoles = const <String>[],
    this.presentation = 'screen',
    this.showInNavigation = false,
    this.showOnHome = false,
    this.sortOrder,
    this.metadata = const <String, dynamic>{},
  });

  final String routeKey;
  final String pathPattern;
  final String surface;
  final String featureKey;
  final String? label;
  final bool authRequired;
  final List<String> requiredRoles;
  final String presentation;
  final bool showInNavigation;
  final bool showOnHome;
  final int? sortOrder;
  final Map<String, dynamic> metadata;

  factory PlatformRouteConfig.fromJson(Map<String, dynamic> json) {
    return PlatformRouteConfig(
      routeKey: json['route_key'] as String? ?? '',
      pathPattern: json['path_pattern'] as String? ?? '',
      surface: json['surface'] as String? ?? 'mobile',
      featureKey: json['feature_key'] as String? ?? '',
      label: json['label'] as String?,
      authRequired: json['auth_required'] as bool? ?? false,
      requiredRoles: _asStringList(json['required_roles']),
      presentation: json['presentation'] as String? ?? 'screen',
      showInNavigation: json['show_in_navigation'] as bool? ?? false,
      showOnHome: json['show_on_home'] as bool? ?? false,
      sortOrder: (json['sort_order'] as num?)?.toInt(),
      metadata: _asStringDynamicMap(json['metadata']),
    );
  }

  Map<String, dynamic> toJson() => {
    'route_key': routeKey,
    'path_pattern': pathPattern,
    'surface': surface,
    'feature_key': featureKey,
    'label': label,
    'auth_required': authRequired,
    'required_roles': requiredRoles,
    'presentation': presentation,
    'show_in_navigation': showInNavigation,
    'show_on_home': showOnHome,
    'sort_order': sortOrder,
    'metadata': metadata,
  };
}

class PlatformOptionSet {
  const PlatformOptionSet({
    required this.optionSetKey,
    required this.label,
    this.description,
    this.valueType = 'text',
    this.surface = 'both',
    this.values = const <PlatformOptionValue>[],
    this.metadata = const <String, dynamic>{},
  });

  final String optionSetKey;
  final String label;
  final String? description;
  final String valueType;
  final String surface;
  final List<PlatformOptionValue> values;
  final Map<String, dynamic> metadata;

  factory PlatformOptionSet.fromJson(Map<String, dynamic> json) {
    final rawValues = json['values'];
    return PlatformOptionSet(
      optionSetKey: json['option_set_key'] as String? ?? '',
      label: json['label'] as String? ?? '',
      description: json['description'] as String?,
      valueType: json['value_type'] as String? ?? 'text',
      surface: json['surface'] as String? ?? 'both',
      values: rawValues is List
          ? rawValues
                .whereType<Map<String, dynamic>>()
                .map(PlatformOptionValue.fromJson)
                .toList(growable: false)
          : const <PlatformOptionValue>[],
      metadata: _asStringDynamicMap(json['metadata']),
    );
  }

  Map<String, dynamic> toJson() => {
    'option_set_key': optionSetKey,
    'label': label,
    'description': description,
    'value_type': valueType,
    'surface': surface,
    'values': values.map((value) => value.toJson()).toList(growable: false),
    'metadata': metadata,
  };
}

class PlatformOptionValue {
  const PlatformOptionValue({
    required this.optionKey,
    required this.label,
    this.value,
    this.sortOrder,
    this.isDefault = false,
    this.metadata = const <String, dynamic>{},
  });

  final String optionKey;
  final String label;
  final Object? value;
  final int? sortOrder;
  final bool isDefault;
  final Map<String, dynamic> metadata;

  factory PlatformOptionValue.fromJson(Map<String, dynamic> json) {
    return PlatformOptionValue(
      optionKey: json['option_key'] as String? ?? '',
      label: json['label'] as String? ?? '',
      value: json['value'],
      sortOrder: (json['sort_order'] as num?)?.toInt(),
      isDefault: json['is_default'] as bool? ?? false,
      metadata: _asStringDynamicMap(json['metadata']),
    );
  }

  Map<String, dynamic> toJson() => {
    'option_key': optionKey,
    'label': label,
    'value': value,
    'sort_order': sortOrder,
    'is_default': isDefault,
    'metadata': metadata,
  };
}

class RuntimeCopyEntry {
  const RuntimeCopyEntry({
    required this.copyKey,
    required this.surface,
    required this.locale,
    required this.textValue,
    this.description,
    this.metadata = const <String, dynamic>{},
  });

  final String copyKey;
  final String surface;
  final String locale;
  final String textValue;
  final String? description;
  final Map<String, dynamic> metadata;

  factory RuntimeCopyEntry.fromJson(Map<String, dynamic> json) {
    return RuntimeCopyEntry(
      copyKey: json['copy_key'] as String? ?? '',
      surface: json['surface'] as String? ?? 'both',
      locale: json['locale'] as String? ?? 'en',
      textValue: json['text_value'] as String? ?? '',
      description: json['description'] as String?,
      metadata: _asStringDynamicMap(json['metadata']),
    );
  }

  Map<String, dynamic> toJson() => {
    'copy_key': copyKey,
    'surface': surface,
    'locale': locale,
    'text_value': textValue,
    'description': description,
    'metadata': metadata,
  };
}

class SiteNavigationItem {
  const SiteNavigationItem({
    required this.navKey,
    required this.label,
    required this.href,
    this.navGroup = 'primary',
    this.surface = 'web',
    this.featureKey,
    this.sortOrder,
    this.metadata = const <String, dynamic>{},
  });

  final String navKey;
  final String label;
  final String href;
  final String navGroup;
  final String surface;
  final String? featureKey;
  final int? sortOrder;
  final Map<String, dynamic> metadata;

  factory SiteNavigationItem.fromJson(Map<String, dynamic> json) {
    return SiteNavigationItem(
      navKey: json['nav_key'] as String? ?? '',
      label: json['label'] as String? ?? '',
      href: json['href'] as String? ?? '',
      navGroup: json['nav_group'] as String? ?? 'primary',
      surface: json['surface'] as String? ?? 'web',
      featureKey: json['feature_key'] as String?,
      sortOrder: (json['sort_order'] as num?)?.toInt(),
      metadata: _asStringDynamicMap(json['metadata']),
    );
  }

  Map<String, dynamic> toJson() => {
    'nav_key': navKey,
    'label': label,
    'href': href,
    'nav_group': navGroup,
    'surface': surface,
    'feature_key': featureKey,
    'sort_order': sortOrder,
    'metadata': metadata,
  };
}

class SiteSearchItem {
  const SiteSearchItem({
    required this.searchKey,
    required this.title,
    required this.description,
    required this.href,
    this.category = 'Page',
    this.metaLabel,
    this.surface = 'web',
    this.featureKey,
    this.sortOrder,
    this.metadata = const <String, dynamic>{},
  });

  final String searchKey;
  final String title;
  final String description;
  final String href;
  final String category;
  final String? metaLabel;
  final String surface;
  final String? featureKey;
  final int? sortOrder;
  final Map<String, dynamic> metadata;

  factory SiteSearchItem.fromJson(Map<String, dynamic> json) {
    return SiteSearchItem(
      searchKey: json['search_key'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      href: json['href'] as String? ?? '',
      category: json['category'] as String? ?? 'Page',
      metaLabel: json['meta_label'] as String?,
      surface: json['surface'] as String? ?? 'web',
      featureKey: json['feature_key'] as String?,
      sortOrder: (json['sort_order'] as num?)?.toInt(),
      metadata: _asStringDynamicMap(json['metadata']),
    );
  }

  Map<String, dynamic> toJson() => {
    'search_key': searchKey,
    'title': title,
    'description': description,
    'href': href,
    'category': category,
    'meta_label': metaLabel,
    'surface': surface,
    'feature_key': featureKey,
    'sort_order': sortOrder,
    'metadata': metadata,
  };
}

class VenueGovernanceControl {
  const VenueGovernanceControl({
    required this.controlKey,
    required this.label,
    required this.detail,
    this.statusLabel = 'review_required',
    this.actionLabel,
    this.controlGroup = 'general',
    this.sortOrder,
    this.metadata = const <String, dynamic>{},
  });

  final String controlKey;
  final String label;
  final String detail;
  final String statusLabel;
  final String? actionLabel;
  final String controlGroup;
  final int? sortOrder;
  final Map<String, dynamic> metadata;

  factory VenueGovernanceControl.fromJson(Map<String, dynamic> json) {
    return VenueGovernanceControl(
      controlKey: json['control_key'] as String? ?? '',
      label: json['label'] as String? ?? '',
      detail: json['detail'] as String? ?? '',
      statusLabel: json['status_label'] as String? ?? 'review_required',
      actionLabel: json['action_label'] as String?,
      controlGroup: json['control_group'] as String? ?? 'general',
      sortOrder: (json['sort_order'] as num?)?.toInt(),
      metadata: _asStringDynamicMap(json['metadata']),
    );
  }

  Map<String, dynamic> toJson() => {
    'control_key': controlKey,
    'label': label,
    'detail': detail,
    'status_label': statusLabel,
    'action_label': actionLabel,
    'control_group': controlGroup,
    'sort_order': sortOrder,
    'metadata': metadata,
  };
}

// ── Private helpers ──

List<String> _asStringList(Object? value) {
  if (value is! List) return const <String>[];
  return value
      .map((entry) => entry.toString().trim())
      .where((entry) => entry.isNotEmpty)
      .toList(growable: false);
}

Map<String, dynamic> _asStringDynamicMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((k, v) => MapEntry(k.toString(), v));
  return const <String, dynamic>{};
}

DateTime? _tryParseDateTime(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}
