import 'package:core_network/core_network.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:core_feature_config/core_feature_config.dart';

class FeatureManagementRepository {
  FeatureManagementRepository({required SupabaseClient client}) : _client = client;

  final SupabaseClient _client;
  static const _tag = 'FeatureMgmtRepo';

  /// Loads all features with their full configurations.
  Future<List<PlatformFeature>> loadAllFeatures({int? clubId}) async {
    final result = await SafeRpc.query<List<PlatformFeature>>(
      () async {
        var query = _client.from('platform_features').select('''
          *,
          channel:platform_feature_channels (*),
          rules:platform_feature_rules (*)
        ''');
        
        if (clubId != null) {
          query = query.or('club_id.eq.$clubId,club_id.is.null');
        } else {
          query = query.isFilter('club_id', null);
        }

        final rows = await query.order('feature_key');
        return rows.map((row) => PlatformFeature.fromJson(row)).toList();
      },
      tag: _tag,
      description: 'Load all features',
    );
    return result.requireData;
  }

  /// Toggles the global is_enabled switch.
  Future<bool> updateFeatureGlobalStatus(String key, bool isEnabled) async {
    final result = await SafeRpc.query(
      () => _client.from('platform_features').update({
        'is_enabled': isEnabled,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('feature_key', key),
      tag: _tag,
    );
    return result.isSuccess;
  }

  /// Updates the visibility state.
  Future<bool> updateFeatureVisibility(String key, String visibility) async {
    final result = await SafeRpc.query(
      () => _client.from('platform_features').update({
        'visibility_state': visibility,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('feature_key', key),
      tag: _tag,
    );
    return result.isSuccess;
  }

  /// Updates channel-specific settings.
  Future<bool> updateChannelConfig(String featureId, String channel, Map<String, dynamic> data) async {
    final result = await SafeRpc.query(
      () => _client.from('platform_feature_channels').update({
        ...data,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).match({'feature_id': featureId, 'channel': channel}),
      tag: _tag,
    );
    return result.isSuccess;
  }

  /// Updates rules (auth, scheduling).
  Future<bool> updateFeatureRules(String featureId, Map<String, dynamic> data) async {
    final result = await SafeRpc.query(
      () => _client.from('platform_feature_rules').update({
        ...data,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('feature_id', featureId),
      tag: _tag,
    );
    return result.isSuccess;
  }

  /// Loads content blocks.
  Future<List<ContentBlock>> loadContentBlocks({int? clubId}) async {
    final result = await SafeRpc.query<List<ContentBlock>>(
      () async {
        var query = _client.from('platform_content_blocks').select();
        if (clubId != null) {
          query = query.or('club_id.eq.$clubId,club_id.is.null');
        } else {
          query = query.isFilter('club_id', null);
        }
        final rows = await query.order('sort_order');
        return rows.map((row) => ContentBlock.fromJson(row)).toList();
      },
      tag: _tag,
    );
    return result.requireData;
  }

  /// Toggles content block active status.
  Future<bool> updateContentBlockStatus(String id, bool isActive) async {
    final result = await SafeRpc.query(
      () => _client.from('platform_content_blocks').update({
        'is_active': isActive,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', id),
      tag: _tag,
    );
    return result.isSuccess;
  }
}
