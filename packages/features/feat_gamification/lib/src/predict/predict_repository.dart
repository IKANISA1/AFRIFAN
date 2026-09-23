import 'package:core_feature_config/core_feature_config.dart';
import 'package:core_network/core_network.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'predict_models.dart';

enum PredictFailure {
  unavailable,
  signIn,
  closed,
  alreadyEntered,
  insufficient,
  uncertain,
}

class PredictConfirmation {
  const PredictConfirmation(this.fixture, this.balanceFet);
  final PredictFixture fixture;
  final int? balanceFet;
}

abstract interface class PredictGateway {
  Future<PredictDashboard> load();
  Future<PredictConfirmation> place(
    String fixtureId,
    PredictSelection selection,
  );
}

class PredictRepository implements PredictGateway {
  PredictRepository(
    this.client, {
    this.storeReleasePolicy = const StoreReleasePolicy(isEnforced: true),
  }) : _scope = ClubScopeResolver(client: client);
  final SupabaseClient client;
  final StoreReleasePolicy storeReleasePolicy;
  final ClubScopeResolver _scope;

  Future<int> _club() async {
    final scope = await _scope.requireResolved();
    return scope.clubId ?? (throw PredictFailure.unavailable);
  }

  @override
  Future<PredictDashboard> load() async {
    if (!storeReleasePolicy.allowsStakedCompetitions) {
      throw PredictFailure.unavailable;
    }
    try {
      final data = await client.rpc(
        'predict_dashboard',
        params: {'p_club_id': await _club()},
      );
      return PredictDashboard.fromJson(Map<String, dynamic>.from(data as Map));
    } on PostgrestException catch (error) {
      throw error.code == '42501'
          ? PredictFailure.signIn
          : PredictFailure.unavailable;
    }
  }

  @override
  Future<PredictConfirmation> place(
    String fixtureId,
    PredictSelection selection,
  ) async {
    if (!storeReleasePolicy.allowsStakedCompetitions) {
      throw PredictFailure.unavailable;
    }
    try {
      final data = Map<String, dynamic>.from(
        await client.rpc(
              'predict_place',
              params: {
                'p_club_id': await _club(),
                'p_fixture_id': fixtureId,
                'p_selection': selection.name,
              },
            )
            as Map,
      );
      return PredictConfirmation(
        PredictFixture.fromJson(data),
        (data['balance_fet'] as num?)?.toInt(),
      );
    } on PostgrestException catch (error) {
      throw switch (error.message) {
        'PREDICT_SIGN_IN_REQUIRED' => PredictFailure.signIn,
        'PREDICT_POOL_CLOSED' ||
        'PREDICT_POOL_UNAVAILABLE' ||
        'PREDICT_FIXTURE_UNAVAILABLE' => PredictFailure.closed,
        'PREDICT_ALREADY_ENTERED' => PredictFailure.alreadyEntered,
        'PREDICT_INSUFFICIENT_FET' => PredictFailure.insufficient,
        _ => PredictFailure.uncertain,
      };
    }
  }
}
