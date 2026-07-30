import 'package:core_feature_config/core_feature_config.dart';
import 'package:core_network/core_network.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ManagedFeatureChannelConfig {
  const ManagedFeatureChannelConfig({
    required this.id,
    required this.channel,
    required this.isEnabled,
    required this.isVisible,
    required this.showInNavigation,
    required this.showOnHome,
    required this.sortOrder,
    required this.routeKey,
    required this.placementKey,
  });

  final String? id;
  final String channel;
  final bool isEnabled;
  final bool isVisible;
  final bool showInNavigation;
  final bool showOnHome;
  final int? sortOrder;
  final String? routeKey;
  final String? placementKey;

  factory ManagedFeatureChannelConfig.fromJson(Map<String, dynamic> json) {
    return ManagedFeatureChannelConfig(
      id: json['id']?.toString(),
      channel: json['channel']?.toString().trim().toLowerCase() == 'web'
          ? 'web'
          : 'mobile',
      isEnabled: json['is_enabled'] as bool? ?? true,
      isVisible: json['is_visible'] as bool? ?? true,
      showInNavigation: json['show_in_navigation'] as bool? ?? false,
      showOnHome: json['show_on_home'] as bool? ?? false,
      sortOrder: (json['sort_order'] as num?)?.toInt(),
      routeKey: json['route_key']?.toString(),
      placementKey: json['placement_key']?.toString(),
    );
  }
}

class ManagedFeatureRuleConfig {
  const ManagedFeatureRuleConfig({
    required this.id,
    required this.authRequired,
    required this.roleRestrictions,
    required this.dependencyRules,
    required this.rolloutRules,
    required this.metadata,
    required this.scheduleStartAt,
    required this.scheduleEndAt,
  });

  final String? id;
  final bool authRequired;
  final List<String> roleRestrictions;
  final Map<String, dynamic> dependencyRules;
  final Map<String, dynamic> rolloutRules;
  final Map<String, dynamic> metadata;
  final DateTime? scheduleStartAt;
  final DateTime? scheduleEndAt;

  factory ManagedFeatureRuleConfig.fromJson(Map<String, dynamic> json) {
    return ManagedFeatureRuleConfig(
      id: json['id']?.toString(),
      authRequired: json['auth_required'] as bool? ?? false,
      roleRestrictions: _stringList(json['role_restrictions']),
      dependencyRules: _asStringDynamicMap(json['dependency_rules']),
      rolloutRules: _asStringDynamicMap(json['rollout_rules']),
      metadata: _asStringDynamicMap(json['metadata']),
      scheduleStartAt: _tryParseDateTime(json['schedule_start_at']),
      scheduleEndAt: _tryParseDateTime(json['schedule_end_at']),
    );
  }
}

class ManagedPlatformFeature {
  const ManagedPlatformFeature({
    required this.id,
    required this.clubId,
    required this.featureKey,
    required this.displayName,
    required this.description,
    required this.category,
    required this.isEnabled,
    required this.visibilityState,
    required this.channels,
    required this.rules,
  });

  final String id;
  final int? clubId;
  final String featureKey;
  final String displayName;
  final String? description;
  final String? category;
  final bool isEnabled;
  final String visibilityState;
  final List<ManagedFeatureChannelConfig> channels;
  final ManagedFeatureRuleConfig? rules;

  bool get isScopedOverride => clubId != null;

  ManagedFeatureChannelConfig? channelFor(String channel) {
    final normalized = channel.trim().toLowerCase();
    for (final entry in channels) {
      if (entry.channel == normalized) {
        return entry;
      }
    }
    return null;
  }

  factory ManagedPlatformFeature.fromJson(Map<String, dynamic> json) {
    final rawChannels = json['channels'];
    final rawRules = json['rules'];

    final channels = rawChannels is List
        ? rawChannels
              .whereType<Map>()
              .map(
                (entry) => ManagedFeatureChannelConfig.fromJson(
                  entry.cast<String, dynamic>(),
                ),
              )
              .toList(growable: false)
        : const <ManagedFeatureChannelConfig>[];

    ManagedFeatureRuleConfig? rules;
    if (rawRules is List && rawRules.isNotEmpty) {
      final first = rawRules.first;
      if (first is Map) {
        rules = ManagedFeatureRuleConfig.fromJson(
          first.cast<String, dynamic>(),
        );
      }
    } else if (rawRules is Map) {
      rules = ManagedFeatureRuleConfig.fromJson(
        rawRules.cast<String, dynamic>(),
      );
    }

    return ManagedPlatformFeature(
      id: json['id']?.toString() ?? '',
      clubId: _asInt(json['club_id']),
      featureKey: json['feature_key']?.toString() ?? '',
      displayName: json['display_name']?.toString() ?? '',
      description: json['description']?.toString(),
      category: json['category']?.toString(),
      isEnabled: json['is_enabled'] as bool? ?? true,
      visibilityState: json['visibility_state']?.toString() ?? 'visible',
      channels: channels,
      rules: rules,
    );
  }
}

class FeatureManagementRepository {
  FeatureManagementRepository({required SupabaseClient client})
    : _client = client,
      _scopeResolver = ClubScopeResolver(client: client);

  final SupabaseClient _client;
  final ClubScopeResolver _scopeResolver;

  static const _tag = 'FeatureMgmtRepo';

  Future<List<ManagedPlatformFeature>> loadAllFeatures({int? clubId}) async {
    final scopedClubId = clubId ?? _scopeResolver.currentClubId;
    final result = await SafeRpc.query<List<ManagedPlatformFeature>>(
      () async {
        final rows = await _listFeatureRows(scopedClubId);
        return _resolveScopedFeatures(
          rows,
          scopedClubId,
        ).map(ManagedPlatformFeature.fromJson).toList(growable: false);
      },
      tag: _tag,
      description: 'Load feature registry',
    );
    return result.requireData;
  }

  Future<ManagedPlatformFeature?> loadFeature(
    String featureKey, {
    int? clubId,
  }) async {
    final scopedClubId = clubId ?? _scopeResolver.currentClubId;
    final rows = await _listFeatureRows(scopedClubId, featureKey: featureKey);
    final resolved = _resolveScopedFeatures(rows, scopedClubId);
    if (resolved.isEmpty) {
      return null;
    }
    return ManagedPlatformFeature.fromJson(resolved.first);
  }

  Future<bool> updateFeatureGlobalStatus(
    String featureId,
    bool isEnabled, {
    int? clubId,
  }) {
    return _updateFeatureRow(featureId, <String, dynamic>{
      'is_enabled': isEnabled,
    }, clubId: clubId);
  }

  Future<bool> updateFeatureVisibility(
    String featureId,
    String visibility, {
    int? clubId,
  }) {
    return _updateFeatureRow(featureId, <String, dynamic>{
      'visibility_state': visibility,
    }, clubId: clubId);
  }

  Future<bool> updateChannelConfig(
    String featureId,
    String channel,
    Map<String, dynamic> data, {
    int? clubId,
  }) async {
    final scopedClubId = clubId ?? _scopeResolver.currentClubId;
    final normalizedChannel = channel.trim().toLowerCase() == 'web'
        ? 'web'
        : 'mobile';
    final result = await SafeRpc.query<bool>(
      () async {
        final source = await _getFeatureRowById(featureId);
        final targetId = await _ensureScopedFeatureTarget(
          source,
          clubId: scopedClubId,
        );
        final existingChannels = await _loadChannelsByFeatureId(targetId);
        ManagedFeatureChannelConfig? current;
        for (final entry in existingChannels) {
          if (entry.channel == normalizedChannel) {
            current = entry;
            break;
          }
        }
        final payload = <String, dynamic>{
          'feature_id': targetId,
          'channel': normalizedChannel,
          ...data,
        };

        if ((current?.id ?? '').isNotEmpty) {
          await _client
              .from('platform_feature_channels')
              .update(payload)
              .eq('id', current!.id!);
        } else {
          await _client.from('platform_feature_channels').insert(payload);
        }

        return true;
      },
      tag: _tag,
      description: 'Update feature channel config',
    );
    return result.isSuccess;
  }

  Future<bool> updateFeatureRules(
    String featureId,
    Map<String, dynamic> data, {
    int? clubId,
  }) async {
    final scopedClubId = clubId ?? _scopeResolver.currentClubId;
    final result = await SafeRpc.query<bool>(
      () async {
        final source = await _getFeatureRowById(featureId);
        final targetId = await _ensureScopedFeatureTarget(
          source,
          clubId: scopedClubId,
        );
        final currentRule = await _loadRulesByFeatureId(targetId);
        final payload = <String, dynamic>{'feature_id': targetId, ...data};

        if ((currentRule?.id ?? '').isNotEmpty) {
          await _client
              .from('platform_feature_rules')
              .update(payload)
              .eq('id', currentRule!.id!);
        } else {
          await _client.from('platform_feature_rules').insert(payload);
        }

        return true;
      },
      tag: _tag,
      description: 'Update feature rules',
    );
    return result.isSuccess;
  }

  Future<List<ContentBlock>> loadContentBlocks({int? clubId}) async {
    final scopedClubId = clubId ?? _scopeResolver.currentClubId;
    final result = await SafeRpc.query<List<ContentBlock>>(() async {
      var query = _client.from('platform_content_blocks').select();
      if (scopedClubId != null) {
        query = query.or('club_id.eq.$scopedClubId,club_id.is.null');
      } else {
        query = query.isFilter('club_id', null);
      }
      final rows = List<Map<String, dynamic>>.from(
        (await query.order('placement_key').order('sort_order') as List).map(
          (row) => Map<String, dynamic>.from(row as Map),
        ),
      );
      return _resolveScopedContentBlocks(
        rows,
        scopedClubId,
      ).map(ContentBlock.fromJson).toList(growable: false);
    }, tag: _tag);
    return result.requireData;
  }

  Future<bool> updateContentBlockStatus(
    String id,
    bool isActive, {
    int? clubId,
  }) async {
    final scopedClubId = clubId ?? _scopeResolver.currentClubId;
    final result = await SafeRpc.query<bool>(() async {
      final source = await _getContentBlockRowById(id);
      final targetId = await _ensureScopedContentBlockTarget(
        source,
        clubId: scopedClubId,
      );
      await _client
          .from('platform_content_blocks')
          .update(<String, dynamic>{'is_active': isActive})
          .eq('id', targetId);
      return true;
    }, tag: _tag);
    return result.isSuccess;
  }

  Future<bool> _updateFeatureRow(
    String featureId,
    Map<String, dynamic> data, {
    int? clubId,
  }) async {
    final scopedClubId = clubId ?? _scopeResolver.currentClubId;
    final result = await SafeRpc.query<bool>(
      () async {
        final source = await _getFeatureRowById(featureId);
        final targetId = await _ensureScopedFeatureTarget(
          source,
          clubId: scopedClubId,
        );
        await _client.from('platform_features').update(data).eq('id', targetId);
        return true;
      },
      tag: _tag,
      description: 'Update feature row',
    );
    return result.isSuccess;
  }

  Future<List<Map<String, dynamic>>> _listFeatureRows(
    int? clubId, {
    String? featureKey,
  }) async {
    var query = _client.from('platform_features').select('''
      id,
      feature_key,
      display_name,
      description,
      category,
      club_id,
      is_enabled,
      visibility_state,
      channels:platform_feature_channels (
        id,
        channel,
        is_enabled,
        is_visible,
        show_in_navigation,
        show_on_home,
        sort_order,
        route_key,
        placement_key
      ),
      rules:platform_feature_rules (
        id,
        auth_required,
        role_restrictions,
        dependency_rules,
        rollout_rules,
        metadata,
        schedule_start_at,
        schedule_end_at
      )
    ''');

    if (featureKey != null && featureKey.trim().isNotEmpty) {
      query = query.eq('feature_key', featureKey.trim());
    }

    if (clubId != null) {
      query = query.or('club_id.eq.$clubId,club_id.is.null');
    } else {
      query = query.isFilter('club_id', null);
    }

    final rows = await query.order('feature_key');
    return List<Map<String, dynamic>>.from(
      (rows as List).map((row) => Map<String, dynamic>.from(row as Map)),
    );
  }

  List<Map<String, dynamic>> _resolveScopedFeatures(
    List<Map<String, dynamic>> rows,
    int? clubId,
  ) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final row in rows) {
      final key = row['feature_key']?.toString() ?? '';
      grouped.putIfAbsent(key, () => <Map<String, dynamic>>[]).add(row);
    }

    final resolved = grouped.values
        .map((variants) {
          if (clubId == null) {
            return variants.firstWhere(
              (row) => row['club_id'] == null,
              orElse: () => variants.first,
            );
          }

          for (final row in variants) {
            if (_asInt(row['club_id']) == clubId) {
              return row;
            }
          }

          for (final row in variants) {
            if (row['club_id'] == null) {
              return row;
            }
          }

          return variants.first;
        })
        .toList(growable: false);

    resolved.sort((left, right) {
      final leftCategory = left['category']?.toString() ?? '';
      final rightCategory = right['category']?.toString() ?? '';
      final categoryCompare = leftCategory.compareTo(rightCategory);
      if (categoryCompare != 0) {
        return categoryCompare;
      }
      return (left['feature_key']?.toString() ?? '').compareTo(
        right['feature_key']?.toString() ?? '',
      );
    });

    return resolved;
  }

  Future<Map<String, dynamic>> _getFeatureRowById(String id) async {
    final rows = await _client
        .from('platform_features')
        .select('''
          id,
          feature_key,
          display_name,
          description,
          category,
          club_id,
          is_enabled,
          visibility_state,
          channels:platform_feature_channels (
            id,
            channel,
            is_enabled,
            is_visible,
            show_in_navigation,
            show_on_home,
            sort_order,
            route_key,
            placement_key
          ),
          rules:platform_feature_rules (
            id,
            auth_required,
            role_restrictions,
            dependency_rules,
            rollout_rules,
            metadata,
            schedule_start_at,
            schedule_end_at
          )
        ''')
        .eq('id', id)
        .single();

    return Map<String, dynamic>.from(rows as Map);
  }

  Future<String> _ensureScopedFeatureTarget(
    Map<String, dynamic> source, {
    required int? clubId,
  }) async {
    final sourceClubId = _asInt(source['club_id']);
    if (clubId == null || sourceClubId == clubId) {
      return source['id']?.toString() ?? '';
    }

    final featureKey = source['feature_key']?.toString() ?? '';
    final existing = await _client
        .from('platform_features')
        .select('id')
        .eq('feature_key', featureKey)
        .eq('club_id', clubId)
        .maybeSingle();
    final existingId = existing?['id']?.toString();
    if (existingId != null && existingId.isNotEmpty) {
      return existingId;
    }

    final inserted = await _client
        .from('platform_features')
        .insert(<String, dynamic>{
          'feature_key': featureKey,
          'display_name': source['display_name'],
          'description': source['description'],
          'category': source['category'],
          'club_id': clubId,
          'is_enabled': source['is_enabled'] as bool? ?? true,
          'visibility_state':
              source['visibility_state']?.toString() ?? 'visible',
        })
        .select('id')
        .single();

    final targetId = inserted['id']?.toString() ?? '';
    if (targetId.isEmpty) {
      throw StateError('Could not create scoped feature override.');
    }

    final sourceChannels = _rawChildRows(source['channels']);
    if (sourceChannels.isNotEmpty) {
      await _client
          .from('platform_feature_channels')
          .insert(
            sourceChannels
                .map(
                  (channel) => <String, dynamic>{
                    'feature_id': targetId,
                    'channel': channel['channel'],
                    'is_enabled': channel['is_enabled'] as bool? ?? true,
                    'is_visible': channel['is_visible'] as bool? ?? true,
                    'show_in_navigation':
                        channel['show_in_navigation'] as bool? ?? false,
                    'show_on_home': channel['show_on_home'] as bool? ?? false,
                    'sort_order': (channel['sort_order'] as num?)?.toInt(),
                    'route_key': channel['route_key'],
                    'placement_key': channel['placement_key'],
                  },
                )
                .toList(growable: false),
          );
    }

    final sourceRules = _rawChildRows(source['rules']);
    if (sourceRules.isNotEmpty) {
      final rule = sourceRules.first;
      await _client.from('platform_feature_rules').insert(<String, dynamic>{
        'feature_id': targetId,
        'auth_required': rule['auth_required'] as bool? ?? false,
        'role_restrictions': _stringList(rule['role_restrictions']),
        'dependency_rules': _asStringDynamicMap(rule['dependency_rules']),
        'rollout_rules': _asStringDynamicMap(rule['rollout_rules']),
        'metadata': _asStringDynamicMap(rule['metadata']),
        'schedule_start_at': rule['schedule_start_at'],
        'schedule_end_at': rule['schedule_end_at'],
      });
    }

    return targetId;
  }

  Future<List<ManagedFeatureChannelConfig>> _loadChannelsByFeatureId(
    String featureId,
  ) async {
    final rows = await _client
        .from('platform_feature_channels')
        .select('''
          id,
          channel,
          is_enabled,
          is_visible,
          show_in_navigation,
          show_on_home,
          sort_order,
          route_key,
          placement_key
        ''')
        .eq('feature_id', featureId);

    return List<Map<String, dynamic>>.from(
      (rows as List).map((row) => Map<String, dynamic>.from(row as Map)),
    ).map(ManagedFeatureChannelConfig.fromJson).toList(growable: false);
  }

  Future<ManagedFeatureRuleConfig?> _loadRulesByFeatureId(
    String featureId,
  ) async {
    final row = await _client
        .from('platform_feature_rules')
        .select('''
          id,
          auth_required,
          role_restrictions,
          dependency_rules,
          rollout_rules,
          metadata,
          schedule_start_at,
          schedule_end_at
        ''')
        .eq('feature_id', featureId)
        .maybeSingle();
    if (row == null) {
      return null;
    }
    return ManagedFeatureRuleConfig.fromJson(
      Map<String, dynamic>.from(row as Map),
    );
  }

  Future<Map<String, dynamic>> _getContentBlockRowById(String id) async {
    final row = await _client
        .from('platform_content_blocks')
        .select()
        .eq('id', id)
        .single();
    return Map<String, dynamic>.from(row as Map);
  }

  Future<String> _ensureScopedContentBlockTarget(
    Map<String, dynamic> source, {
    required int? clubId,
  }) async {
    final sourceClubId = _asInt(source['club_id']);
    if (clubId == null || sourceClubId == clubId) {
      return source['id']?.toString() ?? '';
    }

    final blockKey = source['block_key']?.toString() ?? '';
    final existing = await _client
        .from('platform_content_blocks')
        .select('id')
        .eq('block_key', blockKey)
        .eq('club_id', clubId)
        .maybeSingle();
    final existingId = existing?['id']?.toString();
    if (existingId != null && existingId.isNotEmpty) {
      return existingId;
    }

    final inserted = await _client
        .from('platform_content_blocks')
        .insert(<String, dynamic>{
          'club_id': clubId,
          'block_key': blockKey,
          'block_type': source['block_type'],
          'title': source['title'],
          'subtitle': source['subtitle'],
          'content': _asStringDynamicMap(source['content']),
          'target_channel': source['target_channel'],
          'placement_key': source['placement_key'],
          'feature_id': source['feature_id'],
          'is_active': source['is_active'] as bool? ?? true,
          'sort_order': (source['sort_order'] as num?)?.toInt(),
          'metadata': _asStringDynamicMap(source['metadata']),
        })
        .select('id')
        .single();

    final targetId = inserted['id']?.toString() ?? '';
    if (targetId.isEmpty) {
      throw StateError('Could not create scoped content-block override.');
    }
    return targetId;
  }

  List<Map<String, dynamic>> _resolveScopedContentBlocks(
    List<Map<String, dynamic>> rows,
    int? clubId,
  ) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final row in rows) {
      final key = row['block_key']?.toString() ?? '';
      grouped.putIfAbsent(key, () => <Map<String, dynamic>>[]).add(row);
    }

    final resolved = grouped.values
        .map((variants) {
          if (clubId == null) {
            return variants.firstWhere(
              (row) => row['club_id'] == null,
              orElse: () => variants.first,
            );
          }

          for (final row in variants) {
            if (_asInt(row['club_id']) == clubId) {
              return row;
            }
          }

          for (final row in variants) {
            if (row['club_id'] == null) {
              return row;
            }
          }

          return variants.first;
        })
        .toList(growable: false);

    resolved.sort((left, right) {
      final placementCompare = (left['placement_key']?.toString() ?? '')
          .compareTo(right['placement_key']?.toString() ?? '');
      if (placementCompare != 0) {
        return placementCompare;
      }
      return ((left['sort_order'] as num?)?.toInt() ?? 999).compareTo(
        (right['sort_order'] as num?)?.toInt() ?? 999,
      );
    });

    return resolved;
  }
}

Map<String, dynamic> _asStringDynamicMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((key, val) => MapEntry('$key', val));
  return const <String, dynamic>{};
}

List<String> _stringList(Object? value) {
  if (value is List) {
    return value
        .map((entry) => entry?.toString().trim() ?? '')
        .where((entry) => entry.isNotEmpty)
        .toList(growable: false);
  }
  return const <String>[];
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString().trim() ?? '');
}

DateTime? _tryParseDateTime(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}

List<Map<String, dynamic>> _rawChildRows(Object? value) {
  if (value is List) {
    return value
        .whereType<Map>()
        .map((entry) => entry.cast<String, dynamic>())
        .toList(growable: false);
  }
  if (value is Map) {
    return <Map<String, dynamic>>[value.cast<String, dynamic>()];
  }
  return const <Map<String, dynamic>>[];
}
