import 'package:core_network/core_network.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/partner_pool_models.dart';

class PartnerPoolRepository {
  PartnerPoolRepository({required SupabaseClient client}) : _client = client;

  final SupabaseClient _client;
  late final ClubScopeResolver _scopeResolver = ClubScopeResolver(
    client: _client,
  );

  static const _tag = 'PartnerPoolRepo';

  Future<List<PartnerPredictionPool>> loadPools({
    List<String>? statuses,
    int limit = 20,
    int offset = 0,
  }) async {
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
    final result = await SafeRpc.call(
      'partner_prediction_pool_join',
      params: <String, dynamic>{
        'p_pool_id': poolId,
        'p_selected_outcome': selectedOutcome,
        'p_idempotency_key': idempotencyKey,
      },
      tag: _tag,
      maxAttempts: 1,
    );

    if (!result.isSuccess || result.data is! Map) {
      return const PartnerPoolMutationResult(status: 'error');
    }

    return PartnerPoolMutationResult.fromJson(
      Map<String, dynamic>.from(result.data as Map),
    );
  }
}
