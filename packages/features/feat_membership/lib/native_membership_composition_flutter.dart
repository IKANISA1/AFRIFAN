/// Protected marker storage and lifecycle fencing for the native checkout ports.
/// This composition does not select or replace the existing membership gateway.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'native_membership_flutter.dart';
import 'native_membership_storage_flutter.dart';
import 'native_membership_storage_ios.dart';

export 'native_membership.dart';

/// Own one instance for an authenticated app/account scope. A caller must dispose
/// or call [invalidateIdentity] on logout, account/club change or credential
/// rotation; these events invalidate reviews while preserving uncertain markers.
///
/// [api] is an explicit backend choice. The Cloudflare client accepts its native
/// token format only; a Supabase JWT must never be passed to that credential port.
final class NativeMembershipComposition with WidgetsBindingObserver {
  NativeMembershipComposition({
    required NativeMembershipApi api,
    required this.clubId,
    this.enabled = false,
    RecoveryPlatformChannel? channel,
    MembershipDialer? dialer,
    int Function()? monotonicNow,
  }) {
    requireContract(
      clubId > 0 && clubId <= 9007199254740991,
      'invalid_configuration',
    );
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    final recoveryChannel =
        channel ??
        (enabled ? _platformChannel() : const _DisabledRecoveryChannel());
    recoveryStore = PlatformNativeRecoveryStore(
      recoveryChannel,
      enabled: enabled,
    );
    final fencedApi = _LifecycleMembershipApi(api, this);
    checkout = NativeCheckoutCoordinator(
      fencedApi,
      recoveryStore,
      enabled: enabled,
    );
    handoff = NativePaymentHandoff(
      fencedApi,
      recoveryStore,
      _ForegroundDialer(
        dialer ?? ExternalMembershipDialer(enabled: enabled),
        this,
      ),
      enabled: enabled,
      monotonicNow: monotonicNow,
    );
    WidgetsBinding.instance.addObserver(this);
  }

  final int clubId;
  final bool enabled;
  late final PlatformNativeRecoveryStore recoveryStore;
  late final NativeCheckoutCoordinator checkout;
  late final NativePaymentHandoff handoff;
  bool _disposed = false;
  bool _foreground = false;
  int _generation = 0;

  RecoveryPlatformChannel _platformChannel() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return AndroidCheckoutRecoveryChannel(enabled: enabled);
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return IOSCheckoutRecoveryChannel(enabled: enabled);
    }
    throw const RecoveryPlatformFailure('recovery_platform_unsupported');
  }

  void _check(int generation, {bool mutationSent = false}) {
    if (!enabled || _disposed || !_foreground || generation != _generation) {
      throw NativeMembershipException(
        'session_changed',
        mutationSent ? RequestOutcome.unknown : RequestOutcome.notSent,
      );
    }
  }

  /// Route exits and every identity change cancel in-memory confirmations.
  /// No local marker, original operation key, keychain item or ciphertext is reset.
  void invalidateIdentity() {
    _generation++;
    handoff.invalidateReview();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) invalidateIdentity();
    // Resume does not submit, retry, release a reservation or open the dialer.
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    invalidateIdentity();
    WidgetsBinding.instance.removeObserver(this);
  }
}

final class _ForegroundDialer implements MembershipDialer {
  const _ForegroundDialer(this.delegate, this.owner);
  final MembershipDialer delegate;
  final NativeMembershipComposition owner;
  @override
  Future<bool> open(String ussdCode) {
    owner._check(owner._generation);
    // Opening another application normally backgrounds this one. The original
    // marker and server claim remain authoritative even if that reply is lost.
    return delegate.open(ussdCode);
  }
}

final class _LifecycleMembershipApi implements NativeMembershipApi {
  const _LifecycleMembershipApi(this.delegate, this.owner);
  final NativeMembershipApi delegate;
  final NativeMembershipComposition owner;

  void _scope(MembershipSession actor) {
    requireContract(
      actor.clubId == owner.clubId &&
          isUuid(actor.userId) &&
          isUuid(actor.sessionId),
      'session_changed',
    );
  }

  Future<T> _run<T>(
    Future<T> Function() command, {
    MembershipSession? actor,
    bool mutation = false,
  }) async {
    final generation = owner._generation;
    owner._check(generation);
    if (actor != null) {
      _scope(actor);
      final current = await delegate.session();
      owner._check(generation);
      requireContract(actor.sameSession(current), 'session_changed');
    }
    final result = await command();
    owner._check(generation, mutationSent: mutation);
    if (actor != null) {
      MembershipSession current;
      try {
        current = await delegate.session();
      } catch (_) {
        // The write may have committed even if its identity recheck is lost.
        throw NativeMembershipException(
          'session_changed',
          mutation ? RequestOutcome.unknown : RequestOutcome.notSent,
        );
      }
      owner._check(generation, mutationSent: mutation);
      if (!actor.sameSession(current)) {
        throw NativeMembershipException(
          'session_changed',
          mutation ? RequestOutcome.unknown : RequestOutcome.notSent,
        );
      }
    }
    return result;
  }

  @override
  Future<MembershipSession> session() async {
    final result = await _run(delegate.session);
    _scope(result);
    return result;
  }

  @override
  Future<PreparedCheckout> prepare(
    MembershipSession actor,
    String requestId,
    String tier,
  ) => _run(
    () => delegate.prepare(actor, requestId, tier),
    actor: actor,
    mutation: true,
  );
  @override
  Future<CurrentCheckout> read(MembershipSession actor, String orderId) =>
      _run(() => delegate.read(actor, orderId), actor: actor);
  @override
  Future<ServerHandoffStatus> handoffCurrent(MembershipSession actor) =>
      _run(() => delegate.handoffCurrent(actor), actor: actor);
  @override
  Future<ServerHandoffStatus> reserveHandoff(
    MembershipSession actor,
    String orderId,
    String requestId,
  ) => _run(
    () => delegate.reserveHandoff(actor, orderId, requestId),
    actor: actor,
    mutation: true,
  );
  @override
  Future<ServerHandoffStatus> releaseHandoff(
    MembershipSession actor,
    String handoffId,
    String requestId,
  ) => _run(
    () => delegate.releaseHandoff(actor, handoffId, requestId),
    actor: actor,
    mutation: true,
  );
  @override
  Future<ServerHandoffStatus> claimHandoff(
    MembershipSession actor,
    String handoffId,
    String requestId,
  ) => _run(
    () => delegate.claimHandoff(actor, handoffId, requestId),
    actor: actor,
    mutation: true,
  );
  @override
  Future<HistoricalMembershipReceipt> receipt(
    MembershipSession actor,
    String orderId,
  ) => _run(() => delegate.receipt(actor, orderId), actor: actor);
}

final class _DisabledRecoveryChannel implements RecoveryPlatformChannel {
  const _DisabledRecoveryChannel();
  @override
  Future<Object?> invoke(String method, Map<String, Object?> arguments) async {
    throw const RecoveryPlatformFailure('recovery_disabled');
  }
}
