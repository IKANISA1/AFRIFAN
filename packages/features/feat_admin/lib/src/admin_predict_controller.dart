import 'dart:async';
import 'package:core_auth/core_auth.dart';
import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum PredictAdminAction { settings, prepare, settle, refund }

class AdminPredictFixture {
  AdminPredictFixture(Map<String, dynamic> row)
    : id = row['id'] as String,
      poolId = row['pool_id'] as String?,
      home = row['home_team'] as String,
      away = row['away_team'] as String,
      competition = row['competition'] as String,
      status = row['status'] as String,
      kickoff = row['kickoff_at'] == null
          ? null
          : DateTime.parse(row['kickoff_at'] as String),
      fixtureStatus = row['fixture_status'] as String,
      entries = (row['entry_count'] as num).toInt(),
      staked = (row['staked_fet'] as num).toInt(),
      paid = (row['paid_fet'] as num).toInt(),
      stake = (row['stake_fet'] as num?)?.toInt(),
      homeScore = (row['home_score'] as num?)?.toInt(),
      awayScore = (row['away_score'] as num?)?.toInt(),
      confirmed = row['result_confirmed'] as bool;
  final String id, home, away, competition, status, fixtureStatus;
  final String? poolId;
  final DateTime? kickoff;
  final int entries, staked, paid;
  final int? stake, homeScore, awayScore;
  final bool confirmed;
  bool get completed => status == 'settled' || status == 'refunded';
  bool get hasFinalScore =>
      !completed &&
      fixtureStatus == 'finished' &&
      homeScore != null &&
      awayScore != null;
}

class AdminPredictData {
  const AdminPredictData({
    this.fixtures = const [],
    this.enabled = false,
    this.entryFet = 100,
  });
  factory AdminPredictData.fromJson(Map<String, dynamic> data) =>
      AdminPredictData(
        fixtures: (data['fixtures'] as List)
            .map(
              (r) => AdminPredictFixture(Map<String, dynamic>.from(r as Map)),
            )
            .toList(),
        enabled: (data['settings'] as Map)['enabled'] as bool,
        entryFet: ((data['settings'] as Map)['entry_fet'] as num).toInt(),
      );
  final List<AdminPredictFixture> fixtures;
  final bool enabled;
  final int entryFet;
}

abstract interface class AdminPredictGateway {
  Future<AdminPredictData> load();
  Future<void> command(
    PredictAdminAction action,
    Map<String, Object?> parameters,
  );
}

class AdminPredictRepository implements AdminPredictGateway {
  AdminPredictRepository(this.client)
    : scope = ClubScopeResolver(client: client);
  final SupabaseClient client;
  final ClubScopeResolver scope;
  @override
  Future<AdminPredictData> load() async => AdminPredictData.fromJson(
    Map<String, dynamic>.from(
      await client.rpc(
            'predict_admin_dashboard',
            params: {'p_club_id': (await scope.requireResolved()).clubId},
          )
          as Map,
    ),
  );
  @override
  Future<void> command(
    PredictAdminAction action,
    Map<String, Object?> parameters,
  ) async {
    final rpc = switch (action) {
      PredictAdminAction.settings => 'predict_admin_settings',
      PredictAdminAction.prepare => 'predict_admin_prepare',
      PredictAdminAction.settle ||
      PredictAdminAction.refund => 'predict_admin_settle',
    };
    await client.rpc(
      rpc,
      params: {
        ...parameters,
        if (action == PredictAdminAction.settings ||
            action == PredictAdminAction.prepare)
          'p_club_id': (await scope.requireResolved()).clubId,
      },
    );
  }
}

class AdminPredictState {
  const AdminPredictState({
    this.data,
    this.loading = false,
    this.busy = false,
    this.failed = false,
    this.denied = false,
  });
  final AdminPredictData? data;
  final bool loading, busy, failed, denied;
  bool get canAct => data != null && !loading && !busy && !failed && !denied;
}

final adminPredictGatewayProvider = Provider<AdminPredictGateway>(
  (ref) => AdminPredictRepository(ref.watch(supabaseClientProvider)),
);
final adminPredictProvider =
    StateNotifierProvider<AdminPredictController, AdminPredictState>((ref) {
      ref.watch(currentUserProvider);
      return AdminPredictController(ref.watch(adminPredictGatewayProvider));
    });

class AdminPredictController extends StateNotifier<AdminPredictState> {
  AdminPredictController(
    this.gateway, {
    this.timeout = const Duration(seconds: 12),
    bool autoLoad = true,
  }) : super(const AdminPredictState(loading: true)) {
    if (autoLoad) unawaited(refresh());
  }
  final AdminPredictGateway gateway;
  final Duration timeout;
  int revision = 0;
  Future<void> refresh() async {
    if (state.busy) return;
    final current = ++revision;
    state = AdminPredictState(data: state.data, loading: true);
    try {
      final data = await gateway.load().timeout(timeout);
      if (mounted && current == revision) state = AdminPredictState(data: data);
    } catch (e) {
      if (mounted && current == revision) {
        final denied = e is PostgrestException && e.code == '42501';
        state = AdminPredictState(
          data: denied ? null : state.data,
          failed: true,
          denied: denied,
        );
      }
    }
  }

  Future<void> command(
    PredictAdminAction action,
    Map<String, Object?> params,
  ) async {
    if (!state.canAct) return;
    ++revision;
    state = AdminPredictState(data: state.data, busy: true);
    try {
      await gateway.command(action, params).timeout(timeout);
      if (!mounted) return;
      state = AdminPredictState(data: state.data);
      await refresh();
    } catch (e) {
      if (!mounted) return;
      final denied = e is PostgrestException && e.code == '42501';
      state = AdminPredictState(
        data: denied ? null : state.data,
        failed: true,
        denied: denied,
      );
    }
  }
}
