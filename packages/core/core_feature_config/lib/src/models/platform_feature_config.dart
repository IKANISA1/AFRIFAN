import 'dart:convert';

// ── PlatformConfigSnapshot ──

/// The full platform config payload returned by the RPC.
class PlatformConfigSnapshot {
  const PlatformConfigSnapshot({
    this.features = const <PlatformFeature>[],
    this.contentBlocks = const <ContentBlock>[],
    this.configVersion,
    this.channel = 'mobile',
  });

  final List<PlatformFeature> features;
  final List<ContentBlock> contentBlocks;
  final DateTime? configVersion;
  final String channel;

  /// Quick lookup for a feature by key.
  PlatformFeature? featureByKey(String key) {
    for (final feature in features) {
      if (feature.featureKey == key) {
        return feature;
      }
    }
    return null;
  }

  bool get isEmpty => features.isEmpty;
  bool get isNotEmpty => features.isNotEmpty;

  factory PlatformConfigSnapshot.fromJson(Map<String, dynamic> json) {
    final rawFeatures = json['features'];
    final rawBlocks = json['content_blocks'];

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
      configVersion: _tryParseDateTime(json['config_version']),
      channel: json['channel'] as String? ?? 'mobile',
    );
  }

  Map<String, dynamic> toJson() => {
    'features': features.map((f) => f.toJson()).toList(growable: false),
    'content_blocks':
        contentBlocks.map((b) => b.toJson()).toList(growable: false),
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

  /// Whether this feature is effectively available for the current channel,
  /// considering global enable, channel enable, visibility state, and schedule.
  bool get isEffectivelyEnabled {
    if (!isEnabled) return false;
    if (visibilityState == 'hidden') return false;
    if (channel != null) {
      if (!channel!.isEnabled || !channel!.isVisible) return false;
    }
    if (rules != null) {
      final isWithin = rules!.isWithinSchedule;
      if (!isWithin) return false;
    }
    return true;
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
          ? FeatureRuleConfig.fromJson(
              json['rules'] as Map<String, dynamic>,
            )
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

// ── Private helpers ──

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
