import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../fet_providers.dart';
import '../models/fet_models.dart';
import '../repositories/fet_repository.dart';

enum FetWalletPhase { ready, syncing, degraded }

enum FetWalletFailureKind {
  offline,
  permissionDenied,
  conflict,
  securityTimeout,
  unknown,
}

class FetWalletFailure implements Exception {
  const FetWalletFailure(this.kind);

  final FetWalletFailureKind kind;

  static FetWalletFailure fromError(Object error) {
    if (error is FetWalletFailure) return error;
    if (error is TimeoutException) {
      return const FetWalletFailure(FetWalletFailureKind.securityTimeout);
    }
    final normalized = error.toString().toLowerCase();
    if (normalized.contains('permission') ||
        normalized.contains('forbidden') ||
        normalized.contains('unauthorized') ||
        normalized.contains('row-level security') ||
        normalized.contains('rls')) {
      return const FetWalletFailure(FetWalletFailureKind.permissionDenied);
    }
    if (normalized.contains('conflict') ||
        normalized.contains('changed') ||
        normalized.contains('stale') ||
        normalized.contains('revision')) {
      return const FetWalletFailure(FetWalletFailureKind.conflict);
    }
    return const FetWalletFailure(FetWalletFailureKind.unknown);
  }

  @override
  String toString() => 'FetWalletFailure(${kind.name})';
}

/// Read-only wallet projection shown to the authenticated supporter.
class FetWalletSnapshot {
  const FetWalletSnapshot({
    this.wallet,
    this.transactions = const <FetWalletTransaction>[],
    this.phase = FetWalletPhase.ready,
    this.failure,
  });

  final FetWalletSummary? wallet;
  final List<FetWalletTransaction> transactions;
  final FetWalletPhase phase;
  final FetWalletFailure? failure;

  bool get isEmpty => wallet == null && transactions.isEmpty;

  FetWalletSnapshot copyWith({
    FetWalletSummary? wallet,
    List<FetWalletTransaction>? transactions,
    FetWalletPhase? phase,
    FetWalletFailure? failure,
    bool clearFailure = false,
  }) {
    return FetWalletSnapshot(
      wallet: wallet ?? this.wallet,
      transactions: transactions ?? this.transactions,
      phase: phase ?? this.phase,
      failure: clearFailure ? null : failure ?? this.failure,
    );
  }
}

abstract interface class FetWalletGateway {
  Future<FetWalletSummary?> loadWallet();

  Future<List<FetWalletTransaction>> loadTransactions({required int limit});
}

class RepositoryFetWalletGateway implements FetWalletGateway {
  const RepositoryFetWalletGateway(this._repository);

  final FetRepository _repository;

  @override
  Future<FetWalletSummary?> loadWallet() => _repository.loadWalletStrict();

  @override
  Future<List<FetWalletTransaction>> loadTransactions({required int limit}) {
    return _repository.loadWalletTransactionsStrict(limit: limit);
  }
}

/// Bounded, coalesced, retained wallet reader.
///
/// Wallet history is server-authoritative and read-only on this route. A
/// reconnect may refresh confirmed data, but no user mutation is queued or
/// replayed.
class FetWalletController extends StateNotifier<AsyncValue<FetWalletSnapshot>> {
  FetWalletController(
    this._gateway, {
    Duration loadTimeout = const Duration(seconds: 12),
    bool autoLoad = true,
  }) : _loadTimeout = loadTimeout,
       super(const AsyncValue.loading()) {
    if (autoLoad) unawaited(load());
  }

  final FetWalletGateway _gateway;
  final Duration _loadTimeout;
  bool _loading = false;

  Future<void> load() => _load(preserveCurrent: false);

  Future<void> refresh() => _load(preserveCurrent: true);

  Future<void> connectionRestored() async {
    final current = state.valueOrNull;
    final stateError = state.error;
    final failure =
        current?.failure ??
        (stateError == null ? null : FetWalletFailure.fromError(stateError));
    if (failure?.kind != FetWalletFailureKind.offline) return;
    await refresh();
  }

  Future<void> _load({required bool preserveCurrent}) async {
    if (_loading) return;
    _loading = true;
    final previous = state.valueOrNull;
    final retain = preserveCurrent && previous?.isEmpty == false;
    state = retain
        ? AsyncValue.data(
            previous!.copyWith(
              phase: FetWalletPhase.syncing,
              clearFailure: true,
            ),
          )
        : const AsyncValue.loading();
    try {
      if (!ConnectivityService.isOnline) {
        throw const FetWalletFailure(FetWalletFailureKind.offline);
      }
      final results = await Future.wait<Object?>([
        _gateway.loadWallet(),
        _gateway.loadTransactions(limit: 40),
      ]).timeout(_loadTimeout);
      state = AsyncValue.data(
        FetWalletSnapshot(
          wallet: results[0] as FetWalletSummary?,
          transactions: results[1] as List<FetWalletTransaction>,
        ),
      );
    } catch (error, stackTrace) {
      AfriLogger.warn(
        'FetWalletController',
        'Wallet projection failed to load.',
        error,
        stackTrace,
      );
      final failure = FetWalletFailure.fromError(error);
      state =
          previous?.isEmpty == false &&
              failure.kind != FetWalletFailureKind.permissionDenied
          ? AsyncValue.data(
              previous!.copyWith(
                phase: FetWalletPhase.degraded,
                failure: failure,
              ),
            )
          : AsyncValue.error(failure, stackTrace);
    } finally {
      _loading = false;
    }
  }
}

final fetWalletGatewayProvider = Provider<FetWalletGateway>(
  (ref) => RepositoryFetWalletGateway(ref.watch(fetRepositoryProvider)),
);

final fetWalletLoadTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 12),
);

final fetWalletRouteProvider =
    StateNotifierProvider<FetWalletController, AsyncValue<FetWalletSnapshot>>((
      ref,
    ) {
      return FetWalletController(
        ref.watch(fetWalletGatewayProvider),
        loadTimeout: ref.watch(fetWalletLoadTimeoutProvider),
      );
    });

final fetWalletEnabledProvider = Provider<bool>((ref) => true);

/// Shared wallet cache retained for feature surfaces that own their own
/// route-level recovery state.
class FetWalletNotifier extends AsyncNotifier<FetWalletSnapshot> {
  @override
  Future<FetWalletSnapshot> build() => _load();

  Future<void> refresh() async {
    state = const AsyncLoading<FetWalletSnapshot>().copyWithPrevious(state);
    state = await AsyncValue.guard(_load);
  }

  Future<FetWalletSnapshot> _load() async {
    final repository = ref.read(fetRepositoryProvider);
    final results = await Future.wait<Object?>([
      repository.loadWallet(),
      repository.loadWalletTransactions(limit: 40),
    ]);
    return FetWalletSnapshot(
      wallet: results[0] as FetWalletSummary?,
      transactions: results[1] as List<FetWalletTransaction>,
    );
  }
}

final fetWalletProvider =
    AsyncNotifierProvider<FetWalletNotifier, FetWalletSnapshot>(
      FetWalletNotifier.new,
    );
