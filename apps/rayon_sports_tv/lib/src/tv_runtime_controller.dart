import 'dart:async';

import 'package:flutter/foundation.dart';

import 'tv_runtime.dart';

enum TvRuntimeStatus {
  starting,
  creatingChallenge,
  awaitingOwner,
  syncing,
  ready,
  empty,
  offline,
  securityTimeout,
  revoked,
  configurationMissing,
  secureStorageFailure,
  failure,
}

class TvRuntimeState {
  const TvRuntimeState({
    this.status = TvRuntimeStatus.starting,
    this.challenge,
    this.projection,
    this.lastUpdated,
    this.failure,
  });

  final TvRuntimeStatus status;
  final TvBootstrapChallenge? challenge;
  final TvGameProjection? projection;
  final DateTime? lastUpdated;
  final TvRuntimeFailure? failure;

  bool get hasConfirmedProjection => projection != null;
}

class TvRuntimeController extends ChangeNotifier {
  TvRuntimeController({
    required TvRuntimeGateway gateway,
    required TvCredentialStore store,
    required bool configurationAvailable,
    this.enableTimers = true,
    this.operationTimeout = const Duration(seconds: 12),
    this.projectionRefreshInterval = const Duration(seconds: 5),
    this.pairingPollInterval = const Duration(seconds: 3),
    DateTime Function()? now,
  }) : _gateway = gateway,
       _store = store,
       _configurationAvailable = configurationAvailable,
       _now = now ?? DateTime.now;

  final TvRuntimeGateway _gateway;
  final TvCredentialStore _store;
  final bool _configurationAvailable;
  final bool enableTimers;
  final Duration operationTimeout;
  final Duration projectionRefreshInterval;
  final Duration pairingPollInterval;
  final DateTime Function() _now;
  final TvProjectionReconciler _reconciler = TvProjectionReconciler();

  TvRuntimeState _state = const TvRuntimeState();
  TvRuntimeState get state => _state;

  Timer? _timer;
  StreamSubscription<TvRealtimeSignal>? _realtimeSubscription;
  String? _realtimeKey;
  String? _installationNonce;
  String? _credential;
  String? _pendingCredential;
  bool _busy = false;
  bool _realtimeConnected = false;
  bool _queuedRealtimeRefresh = false;
  bool _recoveringRealtime = false;
  bool _disposed = false;
  int _failureCount = 0;

  bool get realtimeConnected => _realtimeConnected;
  String? get realtimeSubscriptionKey => _realtimeKey;

  Future<void> start() async {
    if (!_configurationAvailable) {
      _setState(
        const TvRuntimeState(status: TvRuntimeStatus.configurationMissing),
      );
      return;
    }
    if (_busy) return;
    _busy = true;
    _setState(const TvRuntimeState(status: TvRuntimeStatus.starting));
    try {
      await _gateway.prepareDeviceIdentity().timeout(operationTimeout);
      await _restoreInstallationIdentity();
      _credential = await _store
          .read(tvCredentialStorageKey)
          .timeout(operationTimeout);
      if (!isValidTvCredential(_credential)) {
        if (_credential != null) {
          await _store.delete(tvCredentialStorageKey).timeout(operationTimeout);
        }
        _credential = null;
        await _createChallengeInternal();
      } else {
        await _gateway
            .bindRealtimeIdentity(_credential!)
            .timeout(operationTimeout);
        await _refreshProjectionInternal(showSyncing: false);
      }
    } on TimeoutException catch (error) {
      _setFailure(TvRuntimeFailureKind.securityTimeout, error);
    } on TvRuntimeFailure catch (failure) {
      _handleFailure(failure);
    } catch (error) {
      _setFailure(TvRuntimeFailureKind.secureStorage, error);
    } finally {
      _busy = false;
      unawaited(_drainQueuedRealtimeRefresh());
    }
  }

  Future<void> retry() async {
    if (_busy) return;
    if (_state.status == TvRuntimeStatus.configurationMissing) return;
    _busy = true;
    _timer?.cancel();
    try {
      await _gateway.prepareDeviceIdentity().timeout(operationTimeout);
      if (_pendingCredential != null) {
        await _persistCredential(_pendingCredential!);
        await _gateway
            .bindRealtimeIdentity(_credential!)
            .timeout(operationTimeout);
        await _refreshProjectionInternal(showSyncing: false);
      } else if (_credential != null) {
        await _gateway
            .bindRealtimeIdentity(_credential!)
            .timeout(operationTimeout);
        await _refreshProjectionInternal();
      } else if (_state.challenge != null &&
          _state.challenge!.expiresAt.isAfter(_now().toUtc())) {
        await _exchangeChallengeInternal();
      } else {
        await _restoreInstallationIdentity();
        await _createChallengeInternal();
      }
    } on TimeoutException catch (error) {
      _setFailure(TvRuntimeFailureKind.securityTimeout, error);
    } on TvRuntimeFailure catch (failure) {
      _handleFailure(failure);
    } catch (error) {
      _setFailure(TvRuntimeFailureKind.secureStorage, error);
    } finally {
      _busy = false;
      unawaited(_drainQueuedRealtimeRefresh());
    }
  }

  Future<void> renewPairingChallenge() async {
    if (_busy || !_configurationAvailable) return;
    _busy = true;
    _timer?.cancel();
    try {
      await _gateway.prepareDeviceIdentity().timeout(operationTimeout);
      await _restoreInstallationIdentity();
      await _createChallengeInternal();
    } on TimeoutException catch (error) {
      _setFailure(TvRuntimeFailureKind.securityTimeout, error);
    } on TvRuntimeFailure catch (failure) {
      _handleFailure(failure);
    } catch (error) {
      _setFailure(TvRuntimeFailureKind.secureStorage, error);
    } finally {
      _busy = false;
      unawaited(_drainQueuedRealtimeRefresh());
    }
  }

  Future<void> pollPairing() async {
    if (_busy || _state.challenge == null) return;
    _busy = true;
    _timer?.cancel();
    try {
      if (!_state.challenge!.expiresAt.isAfter(_now().toUtc())) {
        await _createChallengeInternal();
      } else {
        await _exchangeChallengeInternal();
      }
    } on TimeoutException catch (error) {
      _setFailure(TvRuntimeFailureKind.securityTimeout, error);
      _schedule(pairingPollInterval, pollPairing);
    } on TvRuntimeFailure catch (failure) {
      _handleFailure(failure);
    } finally {
      _busy = false;
      unawaited(_drainQueuedRealtimeRefresh());
    }
  }

  Future<void> refreshProjection() async {
    if (_busy || _credential == null) return;
    _busy = true;
    _timer?.cancel();
    try {
      await _refreshProjectionInternal();
    } on TimeoutException catch (error) {
      _setFailure(TvRuntimeFailureKind.securityTimeout, error);
      _scheduleBackoff();
    } on TvRuntimeFailure catch (failure) {
      _handleFailure(failure);
    } finally {
      _busy = false;
      unawaited(_drainQueuedRealtimeRefresh());
    }
  }

  Future<void> _restoreInstallationIdentity() async {
    var nonce = await _store
        .read(tvInstallationNonceStorageKey)
        .timeout(operationTimeout);
    if (nonce == null || nonce.length < 32 || nonce.length > 256) {
      nonce = createInstallationNonce();
      await _store
          .write(tvInstallationNonceStorageKey, nonce)
          .timeout(operationTimeout);
    }
    _installationNonce = nonce;
  }

  Future<void> _createChallengeInternal() async {
    final nonce = _installationNonce;
    if (nonce == null) {
      throw const TvRuntimeFailure(TvRuntimeFailureKind.secureStorage);
    }
    _setState(
      TvRuntimeState(
        status: TvRuntimeStatus.creatingChallenge,
        projection: _state.projection,
      ),
    );
    final challenge = await _gateway
        .createPairingChallenge(installationNonce: nonce)
        .timeout(operationTimeout);
    _failureCount = 0;
    _setState(
      TvRuntimeState(
        status: TvRuntimeStatus.awaitingOwner,
        challenge: challenge,
        projection: _state.projection,
      ),
    );
    _schedule(pairingPollInterval, pollPairing);
  }

  Future<void> _exchangeChallengeInternal() async {
    final challenge = _state.challenge;
    final nonce = _installationNonce;
    if (challenge == null || nonce == null) {
      await _createChallengeInternal();
      return;
    }
    final exchange = await _gateway
        .exchangePairingChallenge(
          challenge: challenge.challenge,
          installationNonce: nonce,
        )
        .timeout(operationTimeout);
    if (exchange.status == TvCredentialExchangeStatus.pendingOwnerClaim) {
      _setState(
        TvRuntimeState(
          status: TvRuntimeStatus.awaitingOwner,
          challenge: challenge,
          projection: _state.projection,
        ),
      );
      _schedule(pairingPollInterval, pollPairing);
      return;
    }
    final credential = exchange.credential;
    if (!isValidTvCredential(credential)) {
      throw const TvRuntimeFailure(TvRuntimeFailureKind.invalidResponse);
    }
    if (exchange.clubId == null || exchange.displayId == null) {
      throw const TvRuntimeFailure(TvRuntimeFailureKind.invalidResponse);
    }
    _pendingCredential = credential;
    await _persistCredential(credential!);
    await _gateway.bindRealtimeIdentity(credential).timeout(operationTimeout);
    await _refreshProjectionInternal(showSyncing: false);
  }

  Future<void> _persistCredential(String credential) async {
    try {
      await _store
          .write(tvCredentialStorageKey, credential)
          .timeout(operationTimeout);
      _credential = credential;
      _pendingCredential = null;
    } on TimeoutException {
      rethrow;
    } catch (error) {
      throw TvRuntimeFailure(TvRuntimeFailureKind.secureStorage, error);
    }
  }

  Future<void> _refreshProjectionInternal({bool showSyncing = true}) async {
    final credential = _credential;
    if (credential == null) {
      await _createChallengeInternal();
      return;
    }
    if (showSyncing) {
      _setState(
        TvRuntimeState(
          status: TvRuntimeStatus.syncing,
          projection: _state.projection,
          lastUpdated: _state.lastUpdated,
        ),
      );
    }
    final incoming = await _gateway
        .fetchProjection(credential)
        .timeout(operationTimeout);
    final projection = _reconciler.accept(incoming);
    _failureCount = 0;
    _setState(
      TvRuntimeState(
        status: projection.isEmpty
            ? TvRuntimeStatus.empty
            : TvRuntimeStatus.ready,
        projection: projection,
        lastUpdated: _now().toUtc(),
      ),
    );
    await _syncRealtimeSubscription(projection);
    if (!_realtimeConnected) {
      _schedule(projectionRefreshInterval, refreshProjection);
    }
  }

  Future<void> _syncRealtimeSubscription(TvGameProjection projection) async {
    final sessionId = projection.sessionId;
    if (projection.isEmpty || sessionId == null || sessionId.isEmpty) {
      await _cancelRealtimeSubscription();
      return;
    }
    final key = '${projection.clubId}:game_session:$sessionId';
    if (_realtimeKey == key && _realtimeSubscription != null) return;

    await _cancelRealtimeSubscription();
    _realtimeKey = key;
    _realtimeConnected = false;
    _realtimeSubscription = _gateway
        .watchInvalidations(clubId: projection.clubId, sessionId: sessionId)
        .listen(
          _handleRealtimeSignal,
          onError: (Object error, StackTrace stackTrace) {
            unawaited(_recoverFromRealtimeFailure());
          },
        );
  }

  void _handleRealtimeSignal(TvRealtimeSignal signal) {
    if (_disposed ||
        _realtimeKey != '${signal.clubId}:game_session:${signal.sessionId}') {
      return;
    }
    if (signal.kind == TvRealtimeSignalKind.subscribed) {
      _realtimeConnected = true;
      _failureCount = 0;
      _timer?.cancel();
      return;
    }

    final projection = _state.projection;
    if (projection == null || projection.sessionId != signal.sessionId) return;
    final isStrictlyNewer =
        signal.sessionVersion > projection.sessionVersion ||
        signal.questionVersion > projection.questionVersion ||
        signal.eventSequence > projection.eventSequence;
    if (!isStrictlyNewer) return;
    _queuedRealtimeRefresh = true;
    unawaited(_drainQueuedRealtimeRefresh());
  }

  Future<void> _recoverFromRealtimeFailure() async {
    if (_disposed || _recoveringRealtime) return;
    _recoveringRealtime = true;
    try {
      _realtimeConnected = false;
      _timer?.cancel();
      await _cancelRealtimeSubscription();
      _queuedRealtimeRefresh = true;
      await _drainQueuedRealtimeRefresh();
    } finally {
      _recoveringRealtime = false;
    }
  }

  Future<void> _drainQueuedRealtimeRefresh() async {
    if (_disposed || _busy || !_queuedRealtimeRefresh || _credential == null) {
      return;
    }
    _queuedRealtimeRefresh = false;
    await refreshProjection();
  }

  Future<void> _cancelRealtimeSubscription() async {
    final subscription = _realtimeSubscription;
    _realtimeSubscription = null;
    _realtimeKey = null;
    _realtimeConnected = false;
    if (subscription != null) await subscription.cancel();
  }

  void _handleFailure(TvRuntimeFailure failure) {
    if (failure.kind == TvRuntimeFailureKind.revoked) {
      unawaited(_clearRevokedCredential());
      return;
    }
    if (failure.kind == TvRuntimeFailureKind.challengeExpired) {
      _setState(
        TvRuntimeState(
          status: TvRuntimeStatus.failure,
          projection: _state.projection,
          failure: failure,
        ),
      );
      _schedule(pairingPollInterval, retry);
      return;
    }
    _failureCount += 1;
    final retained = _state.projection;
    _setState(
      TvRuntimeState(
        status: switch ((failure.kind, retained)) {
          (TvRuntimeFailureKind.secureStorage, _) =>
            TvRuntimeStatus.secureStorageFailure,
          (TvRuntimeFailureKind.securityTimeout, null) =>
            TvRuntimeStatus.securityTimeout,
          (_, null) => TvRuntimeStatus.failure,
          _ => TvRuntimeStatus.offline,
        },
        challenge: _state.challenge,
        projection: retained,
        lastUpdated: _state.lastUpdated,
        failure: failure,
      ),
    );
    if (_credential != null) _scheduleBackoff();
  }

  Future<void> _clearRevokedCredential() async {
    _timer?.cancel();
    await _cancelRealtimeSubscription();
    _credential = null;
    _pendingCredential = null;
    _reconciler.clear();
    try {
      await _store.delete(tvCredentialStorageKey).timeout(operationTimeout);
    } catch (_) {
      // Revocation remains fail-closed even if local cleanup needs retry.
    }
    _setState(
      const TvRuntimeState(
        status: TvRuntimeStatus.revoked,
        failure: TvRuntimeFailure(TvRuntimeFailureKind.revoked),
      ),
    );
  }

  void _setFailure(TvRuntimeFailureKind kind, Object error) {
    _handleFailure(TvRuntimeFailure(kind, error));
  }

  void _scheduleBackoff() {
    final exponent = (_failureCount - 1).clamp(0, 4);
    final seconds = (5 * (1 << exponent)).clamp(5, 80);
    _schedule(Duration(seconds: seconds), refreshProjection);
  }

  void _schedule(Duration delay, Future<void> Function() action) {
    _timer?.cancel();
    if (!enableTimers) return;
    _timer = Timer(delay, () => unawaited(action()));
  }

  void _setState(TvRuntimeState next) {
    if (_disposed) return;
    _state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    unawaited(_cancelRealtimeSubscription());
    super.dispose();
  }
}
