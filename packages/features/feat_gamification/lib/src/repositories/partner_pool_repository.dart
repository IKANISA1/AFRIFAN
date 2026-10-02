import 'package:core_feature_config/core_feature_config.dart';
import 'package:core_network/core_network.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/partner_pool_models.dart';

class PartnerPoolRepository {
  PartnerPoolRepository({
    required SupabaseClient client,
    StoreReleasePolicy? storeReleasePolicy,
  }) : _client = client,
       _storeReleasePolicy =
           storeReleasePolicy ??
           StoreReleasePolicy.forCurrentBuild(const PlatformConfigSnapshot());

  final SupabaseClient _client;
  final StoreReleasePolicy _storeReleasePolicy;
  late final ClubScopeResolver _scopeResolver = ClubScopeResolver(
    client: _client,
  );

  static const _tag = 'PartnerPoolRepo';

  Future<List<PartnerPredictionPool>> loadPools({
    List<String>? statuses,
    int limit = 20,
    int offset = 0,
  }) async {
    if (!_storeReleasePolicy.allowsStakedCompetitions) {
      return const <PartnerPredictionPool>[];
    }
    final scope = await _scopeResolver.requireResolved();
    if (scope.clubId == null) {
      return const <PartnerPredictionPool>[];
    }

    final result = await SafeRpc.call(
      'partner_prediction_pool_feed',
      params: <String, dynamic>{
        'p_club_id': scope.clubId,
        'p_statuses': statuses ?? const <String>['open', 'locked'],
        'p_limit': limit,
        'p_offset': offset,
      },
      tag: _tag,
    );

    if (!result.isSuccess || result.data is! List) {
      return const <PartnerPredictionPool>[];
    }

    return (result.data as List)
        .whereType<Map>()
        .map(
          (row) =>
              PartnerPredictionPool.fromJson(Map<String, dynamic>.from(row)),
        )
        .toList(growable: false);
  }

  Future<PartnerPoolMutationResult> joinPool({
    required String poolId,
    required String selectedOutcome,
    String? idempotencyKey,
  }) async {
    throw UnsupportedError('Historical paid pools are closed to new entries.');
  }
}
