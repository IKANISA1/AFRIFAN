import 'dart:async';

import 'package:core_auth/core_auth.dart';
import 'package:core_feature_config/core_feature_config.dart';
import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'predict_models.dart';
import 'predict_repository.dart';

final predictGatewayProvider = Provider<PredictGateway>((ref) {
  if (!ref.watch(featureConfigServiceProvider).isRouteAvailable('/predict')) {
    return const _UnavailablePredictGateway();
  }
  return PredictRepository(
    ref.watch(supabaseClientProvider),
    storeReleasePolicy: ref.watch(storeReleasePolicyProvider),
  );
});

class _UnavailablePredictGateway implements PredictGateway {
  const _UnavailablePredictGateway();

  @override
  Future<PredictDashboard> load() async => const PredictDashboard();

  @override
  Future<PredictConfirmation> place(
    String fixtureId,
    PredictSelection selection,
  ) async => throw PredictFailure.unavailable;
}

final predictControllerProvider =
    StateNotifierProvider<PredictController, PredictState>((ref) {
      ref.watch(currentUserProvider);
      return PredictController(ref.watch(predictGatewayProvider));
    });

class PredictState {
  const PredictState({
    this.dashboard,
    this.loading = false,
    this.pendingFixture,
    this.pendingSelection,
    this.failure,
    this.needsReconciliation = false,
  });
  final PredictDashboard? dashboard;
  final bool loading;
  final String? pendingFixture;
  final PredictSelection? pendingSelection;
  final PredictFailure? failure;
  final bool needsReconciliation;
}

class PredictController extends StateNotifier<PredictState> {
  PredictController(
    this.gateway, {
    this.timeout = const Duration(seconds: 12),
    bool autoLoad = true,
  }) : super(const PredictState(loading: true)) {
    ConnectivityService.onlineNotifier.addListener(_connectivityChanged);
    if (autoLoad) unawaited(refresh());
  }
  final PredictGateway gateway;
  final Duration timeout;
  int _revision = 0;
  bool _wasOnline = ConnectivityService.isOnline;

  void _connectivityChanged() {
    final online = ConnectivityService.isOnline;
    final restored = online && !_wasOnline;
    _wasOnline = online;
    if (restored && mounted) unawaited(refresh());
  }

  @override
  void dispose() {
    ConnectivityService.onlineNotifier.removeListener(_connectivityChanged);
    super.dispose();
  }

  Future<void> refresh() async {
    if (state.pendingFixture != null) return;
    if (!ConnectivityService.isOnline) {
      ++_revision;
      state = PredictState(
        dashboard: state.dashboard,
        needsReconciliation: true,
      );
      return;
    }
    final revision = ++_revision;
    state = PredictState(
      dashboard: state.dashboard,
      loading: true,
      needsReconciliation: state.needsReconciliation,
    );
    try {
      final dashboard = await gateway.load().timeout(timeout);
      if (mounted && revision == _revision) {
        state = PredictState(dashboard: dashboard);
      }
    } catch (error) {
      if (mounted && revision == _revision) {
        state = PredictState(
          dashboard: error == PredictFailure.signIn ? null : state.dashboard,
          failure: error == PredictFailure.signIn
              ? PredictFailure.signIn
              : PredictFailure.unavailable,
          needsReconciliation: true,
        );
      }
    }
  }

  Future<void> place(PredictFixture fixture, PredictSelection selection) async {
    final dashboard = state.dashboard;
    if (dashboard == null ||
        !dashboard.enabled ||
        !ConnectivityService.isOnline ||
        state.pendingFixture != null ||
        state.loading ||
        state.needsReconciliation) {
      return;
    }
    if (!dashboard.memberSession) {
      state = PredictState(
        dashboard: dashboard,
        failure: PredictFailure.signIn,
      );
      return;
    }
    final current = dashboard.fixtures
        .where((row) => row.id == fixture.id)
        .firstOrNull;
    if (current == null ||
        current.selection != null ||
        fixture.selection != null) {
      return;
    }
    if (!current.isOpen(DateTime.now())) {
      state = PredictState(
        dashboard: dashboard,
        failure: PredictFailure.closed,
      );
      return;
    }
    ++_revision;
    state = PredictState(
      dashboard: dashboard,
      pendingFixture: fixture.id,
      pendingSelection: selection,
    );
    try {
      final confirmation = await gateway
          .place(fixture.id, selection)
          .timeout(timeout);
      if (!mounted) return;
      state = PredictState(
        dashboard: dashboard.withConfirmed(
          confirmation.fixture,
          confirmation.balanceFet,
        ),
      );
      unawaited(
        FirebaseAnalyticsService.logPredictionPlaced(
          marketSlug: 'wdw',
          selectedOutcome: selection.name,
          fetStaked: fixture.stakeFet,
        ),
      );
      await refresh();
    } catch (error) {
      if (!mounted) return;
      final failure = error is PredictFailure
          ? error
          : PredictFailure.uncertain;
      state = PredictState(
        dashboard: dashboard,
        failure: failure,
        needsReconciliation:
            failure == PredictFailure.uncertain ||
            failure == PredictFailure.alreadyEntered,
      );
    }
  }
}
