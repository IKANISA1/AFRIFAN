/// Explicit native identity and payment composition for one immutable app scope.
library;

import 'package:core_auth/native_identity.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'native_membership_composition_flutter.dart';

export 'package:core_auth/native_identity.dart';
export 'native_membership.dart';

enum NativeMembershipStage {
  unavailable,
  signedOut,
  codeRequested,
  ready,
  prepared,
  review,
  confirmation,
  unresolved,
  allocationRecorded,
}

enum NativeJourneyProblem {
  unavailable,
  invalidInput,
  signInRequired,
  changed,
  denied,
  unresolved,
  storage,
  retry,
}

/// Labels come from the selected club's approved catalogue. Amounts and payment
/// counterparties always come from the server's current checkout instruction.
final class NativeMembershipPlan {
  NativeMembershipPlan(this.tier, this.label) {
    requireContract(
      isTier(tier) && label.trim().isNotEmpty && label.length <= 80,
    );
  }
  final String tier, label;
}

/// Default selection is absent. An app must explicitly supply its reviewed
/// origin, numeric club, application binding, protected store and catalogue.
/// Supabase sessions are never used as native credentials.
final nativeSupporterJourneyProvider = Provider<NativeSupporterJourney?>(
  (ref) => null,
);

final class NativeSupporterJourney extends ChangeNotifier
    with WidgetsBindingObserver {
  NativeSupporterJourney({
    required NativeIdentityWireClient identityClient,
    required NativeCredentialStore credentialStore,
    required NativeMembershipTransport membershipTransport,
    required List<NativeMembershipPlan> plans,
    this.enabled = false,
    RecoveryPlatformChannel? recoveryChannel,
    MembershipDialer? dialer,
    NativeIdentityEntropy? identityEntropy,
  }) : scope = identityClient.scope,
       plans = List.unmodifiable(plans) {
    requireContract(
      plans.length <= 32 &&
          plans.map((p) => p.tier).toSet().length == plans.length,
      'invalid_configuration',
    );
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _identity = NativeIdentityController(
      client: identityClient,
      store: credentialStore,
      enabled: enabled,
      entropy: identityEntropy,
      onIdentityInvalidated: () => membership.invalidateIdentity(),
    );
    _client = NativeMembershipClient(
      origin: scope.origin.origin,
      clubId: scope.clubId,
      transport: membershipTransport,
      credentials: () async {
        final generation = _generation;
        _gate(generation);
        final token = await _identity.readAccessCredential();
        _gate(generation);
        requireContract(token != null, 'credentials_unavailable');
        return token!;
      },
      enabled: enabled,
    );
    _boundApi = _IdentityBoundMembershipApi(_client, this);
    membership = NativeMembershipComposition(
      api: _boundApi,
      clubId: scope.clubId,
      enabled: enabled,
      channel: recoveryChannel,
      dialer: dialer,
    );
    _stage =
        enabled && identityClient.enabled && credentialStore.capabilities.usable
        ? NativeMembershipStage.signedOut
        : NativeMembershipStage.unavailable;
    WidgetsBinding.instance.addObserver(this);
  }

  final NativeIdentityScope scope;
  final List<NativeMembershipPlan> plans;
  final bool enabled;
  late final NativeIdentityController _identity;
  late final NativeMembershipClient _client;
  late final _IdentityBoundMembershipApi _boundApi;
  late final NativeMembershipComposition membership;
  late NativeMembershipStage _stage;
  NativeMembershipStage get stage => _stage;
  NativeJourneyProblem? get problem => _problem;
  NativeJourneyProblem? _problem;
  bool get busy => _busy;
  bool _busy = false, _disposed = false, _foreground = false;
  int _generation = 0;
  PaymentReview? _review;
  PaymentReview? get paymentReview => _review;
  CurrentCheckout? _checkout;
  CurrentCheckout? get checkout => _checkout;
  PendingNativeCheckout? _pending;
  PendingNativeCheckout? get pending => _pending;
  HandoffRecovery? _recovery;
  HandoffRecovery? get recovery => _recovery;
  HistoricalMembershipReceipt? _receipt;
  HistoricalMembershipReceipt? get receipt => _receipt;
  NativeSupporterIdentity? get identity => _identity.identity;
  bool _identityRecoveryNeedsRestart = false;
  bool get canRestartSignIn =>
      !_busy &&
      identity == null &&
      (_identityRecoveryNeedsRestart ||
          stage == NativeMembershipStage.codeRequested);

  bool matchesClub(String configuredClub) =>
      configuredClub == scope.clubId.toString();

  void _gate(int generation, {bool sent = false}) {
    if (!(enabled &&
        !_disposed &&
        _foreground &&
        generation == _generation &&
        _stage != NativeMembershipStage.unavailable)) {
      throw NativeMembershipException(
        'session_changed',
        sent ? RequestOutcome.unknown : RequestOutcome.notSent,
      );
    }
  }

  Future<T> _await<T>(Future<T> operation, {bool mutation = false}) async {
    final generation = _generation;
    final result = await operation;
    _gate(generation, sent: mutation);
    return result;
  }

  void _hideReview() {
    _review = null;
    _receipt = null;
    membership.invalidateIdentity();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy || _disposed) return;
    final generation = _generation;
    try {
      _gate(generation);
      _busy = true;
      _problem = null;
      notifyListeners();
      await action();
      _gate(generation);
    } catch (error) {
      if (!_disposed && generation == _generation) {
        _hideReview();
        if (error is NativeIdentityFailure &&
            [
              NativeIdentityError.recoveryExpired,
              NativeIdentityError.revocationUnknown,
            ].contains(error.code)) {
          _identityRecoveryNeedsRestart = true;
        }
        _problem = _classify(error);
        if (_problem == NativeJourneyProblem.signInRequired) {
          _identity.invalidateIdentity();
          _checkout = null;
          _stage = NativeMembershipStage.signedOut;
        } else if (_problem == NativeJourneyProblem.unresolved) {
          _stage = NativeMembershipStage.unresolved;
        }
      }
    } finally {
      _busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  NativeJourneyProblem _classify(Object error) {
    if (error is NativeIdentityFailure) {
      if (error.outcome == NativeIdentityOutcome.unknown) {
        return NativeJourneyProblem.unresolved;
      }
      return switch (error.code) {
        NativeIdentityError.invalidInput ||
        NativeIdentityError.invalidCode => NativeJourneyProblem.invalidInput,
        NativeIdentityError.storageUnavailable ||
        NativeIdentityError.storageConflict ||
        NativeIdentityError.storageReadbackFailed =>
          NativeJourneyProblem.storage,
        NativeIdentityError.unauthenticated ||
        NativeIdentityError.reauthenticationRequired ||
        NativeIdentityError.locallySignedOut =>
          NativeJourneyProblem.signInRequired,
        NativeIdentityError.identityChanged => NativeJourneyProblem.changed,
        NativeIdentityError.pendingOperation ||
        NativeIdentityError.recoveryExpired ||
        NativeIdentityError.revocationUnknown =>
          NativeJourneyProblem.unresolved,
        NativeIdentityError.disabled => NativeJourneyProblem.unavailable,
        _ => NativeJourneyProblem.retry,
      };
    }
    if (error is NativeMembershipException) {
      if (error.outcome == RequestOutcome.unknown) {
        return NativeJourneyProblem.unresolved;
      }
      return switch (error.code) {
        'unauthenticated' ||
        'credentials_unavailable' => NativeJourneyProblem.signInRequired,
        'permission_denied' => NativeJourneyProblem.denied,
        'session_changed' ||
        'payment_instruction_changed' => NativeJourneyProblem.changed,
        'unresolved_checkout' ||
        'unresolved_payment_handoff' ||
        'checkout_outcome_unknown' ||
        'handoff_outcome_unknown' => NativeJourneyProblem.unresolved,
        'recovery_store_unavailable' ||
        'recovery_store_conflict' ||
        'recovery_store_invalid' ||
        'handoff_storage_invalid' => NativeJourneyProblem.storage,
        'invalid_request' ||
        'explicit_confirmation_required' => NativeJourneyProblem.invalidInput,
        _ => NativeJourneyProblem.retry,
      };
    }
    return NativeJourneyProblem.retry;
  }

  /// User-requested session inspection. Construction and app resume do nothing.
  Future<void> checkSession() => _run(() async {
    _hideReview();
    await _await(_identity.inspectCurrentSession());
    _stage = NativeMembershipStage.ready;
  });

  Future<void> requestCode(String phone) => _run(() async {
    _hideReview();
    await _await(_identity.issueChallenge(phone), mutation: true);
    _stage = NativeMembershipStage.codeRequested;
  });

  Future<void> verifyCode(String code) => _run(() async {
    _hideReview();
    await _await(_identity.verifyCode(code), mutation: true);
    _stage = NativeMembershipStage.ready;
  });

  Future<void> recoverIdentity() => _run(() async {
    _hideReview();
    final result = await _await(_identity.recoverPending(), mutation: true);
    _stage = result == null
        ? NativeMembershipStage.codeRequested
        : NativeMembershipStage.ready;
  });

  /// Explicitly discard only the old sign-in recovery after acknowledgement.
  /// Financial operation keys and handoff markers stay in their separate store.
  /// This does not claim that a possibly issued server session was revoked.
  Future<void> restartSignIn({required bool acknowledgement}) => _run(() async {
    requireContract(
      acknowledgement && identity == null,
      'explicit_confirmation_required',
    );
    _hideReview();
    await _await(_identity.abandonPendingForFreshVerification());
    _checkout = null;
    _pending = null;
    _recovery = null;
    _identityRecoveryNeedsRestart = false;
    _stage = NativeMembershipStage.signedOut;
  });

  Future<void> rotateCredentials() => _run(() async {
    _hideReview();
    await _await(_identity.rotateCredentials(), mutation: true);
    _stage = NativeMembershipStage.ready;
  });

  Future<void> prepare(String tier) => _run(() async {
    requireContract(plans.any((p) => p.tier == tier), 'invalid_request');
    _hideReview();
    _pending = null;
    _checkout = null;
    final priorHandoff = await _await(membership.handoff.recover());
    requireContract(
      priorHandoff == null ||
          priorHandoff.checkout.paymentEvidenceAllocated ||
          priorHandoff.server.handoff?.phase == 'released',
      'unresolved_payment_handoff',
    );
    final prepared = await _await(
      membership.checkout.begin(tier),
      mutation: true,
    );
    _pending = await _await(membership.checkout.restore());
    requireContract(
      _pending?.orderId == prepared.orderId,
      'recovery_store_invalid',
    );
    _stage = NativeMembershipStage.prepared;
  });

  Future<void> reviewPayment() => _run(() async {
    _hideReview();
    final order = _pending?.orderId ?? _checkout?.orderId;
    requireContract(order != null, 'invalid_order');
    _review = await _await(membership.handoff.review(order!));
    _checkout = _review!.checkout;
    _stage = NativeMembershipStage.review;
  });

  void showConfirmation() {
    _gate(_generation);
    requireContract(
      !_busy && _review != null && stage == NativeMembershipStage.review,
      'explicit_confirmation_required',
    );
    _stage = NativeMembershipStage.confirmation;
    notifyListeners();
  }

  void cancelReview() {
    if (_disposed) return;
    _hideReview();
    _stage = _pending?.orderId != null
        ? NativeMembershipStage.prepared
        : NativeMembershipStage.ready;
    notifyListeners();
  }

  Future<void> confirmPayment({
    required bool acknowledgement,
  }) => _run(() async {
    requireContract(
      stage == NativeMembershipStage.confirmation &&
          _review != null &&
          acknowledgement,
      'explicit_confirmation_required',
    );
    final review = _review!;
    _review = null;
    // The response and opening of the system dialer are never payment evidence.
    _stage = NativeMembershipStage.unresolved;
    await _await(
      membership.handoff.confirm(review.reviewId, acknowledgement: true),
      mutation: true,
    );
  });

  /// Explicit read-only reconciliation: no prepare/reserve/claim/release POST.
  Future<void> inspectRecovery() => _run(() async {
    _hideReview();
    await _await(_identity.inspectCurrentSession());
    _pending = await _await(membership.checkout.restore());
    _recovery = await _await(membership.handoff.recover());
    final order = _recovery?.checkout.orderId ?? _pending?.orderId;
    _checkout = order == null
        ? null
        : await _await(
            _boundApi.read(await _await(_boundApi.session()), order),
          );
    _stage = _checkout?.paymentEvidenceAllocated == true
        ? NativeMembershipStage.allocationRecorded
        : _pending == null && _recovery == null
        ? NativeMembershipStage.ready
        : NativeMembershipStage.unresolved;
  });

  /// Keeps the stored original checkout request key. Explicit button only.
  Future<void> retryOriginalCheckout() => _run(() async {
    _hideReview();
    await _await(_identity.inspectCurrentSession());
    await _await(membership.checkout.resume(), mutation: true);
    _pending = await _await(membership.checkout.restore());
    _stage = NativeMembershipStage.prepared;
  });

  Future<void> releaseUnclaimed({required bool acknowledgement}) =>
      _run(() async {
        final id = _recovery?.server.handoff?.handoffId;
        requireContract(
          id != null && acknowledgement,
          'explicit_confirmation_required',
        );
        await _await(
          membership.handoff.releaseUnclaimed(id!, acknowledgement: true),
          mutation: true,
        );
        _recovery = null;
        _hideReview();
        _stage = NativeMembershipStage.prepared;
      });

  Future<void> readReceipt() => _run(() async {
    final order = _checkout?.orderId;
    requireContract(
      order != null && _checkout!.paymentEvidenceAllocated,
      'receipt_not_available',
    );
    _receipt = await _await(
      _boundApi.receipt(await _await(_boundApi.session()), order!),
    );
  });

  /// Explicit server signout. An unknown reply remains visibly unresolved.
  Future<void> signOut() => _run(() async {
    _hideReview();
    _checkout = null;
    _pending = null;
    _recovery = null;
    _stage = NativeMembershipStage.signedOut;
    final result = await _await(
      _identity.revoke(NativeIdentityRevokeScope.current),
      mutation: true,
    );
    if (result.serverRevocation != NativeIdentityRevocation.confirmed) {
      _problem = NativeJourneyProblem.unresolved;
      _identityRecoveryNeedsRestart = true;
    }
  });

  /// Account/club changes, route exit and lifecycle changes hide private views
  /// synchronously. Protected uncertain journals and operation keys are retained.
  void invalidate() {
    if (_disposed) return;
    _generation++;
    _identity.invalidateIdentity();
    _hideReview();
    _checkout = null;
    _pending = null;
    _recovery = null;
    _stage = stage == NativeMembershipStage.unavailable
        ? stage
        : NativeMembershipStage.signedOut;
    _problem = NativeJourneyProblem.changed;
    _identityRecoveryNeedsRestart = false;
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) invalidate();
  }

  @override
  void dispose() {
    if (_disposed) return;
    invalidate();
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _identity.dispose();
    membership.dispose();
    super.dispose();
  }
}

/// The separate four-field membership session must match the protected,
/// seven-field identity observation. No caller can invent a role or user scope.
final class _IdentityBoundMembershipApi implements NativeMembershipApi {
  const _IdentityBoundMembershipApi(this.delegate, this.owner);
  final NativeMembershipApi delegate;
  final NativeSupporterJourney owner;
  MembershipSession _actor() {
    owner._gate(owner._generation);
    final identity = owner.identity;
    requireContract(
      identity != null && identity.clubId == owner.scope.clubId,
      'credentials_unavailable',
    );
    return MembershipSession(
      identity!.userId,
      identity.clubId,
      identity.sessionId,
    );
  }

  Future<T> _run<T>(
    Future<T> Function() work, {
    MembershipSession? actor,
    bool mutation = false,
  }) async {
    final before = _actor(), generation = owner._generation;
    requireContract(
      actor == null || before.sameSession(actor),
      'session_changed',
    );
    final value = await work();
    try {
      owner._gate(generation);
      requireContract(before.sameSession(_actor()), 'session_changed');
    } catch (_) {
      throw NativeMembershipException(
        'session_changed',
        mutation ? RequestOutcome.unknown : RequestOutcome.notSent,
      );
    }
    return value;
  }

  @override
  Future<MembershipSession> session() async {
    final result = await _run(delegate.session);
    requireContract(result.sameSession(_actor()), 'session_changed');
    return result;
  }

  @override
  Future<PreparedCheckout> prepare(
    MembershipSession actor,
    String key,
    String tier,
  ) => _run(
    () => delegate.prepare(actor, key, tier),
    actor: actor,
    mutation: true,
  );
  @override
  Future<CurrentCheckout> read(MembershipSession actor, String order) =>
      _run(() => delegate.read(actor, order), actor: actor);
  @override
  Future<ServerHandoffStatus> handoffCurrent(MembershipSession actor) =>
      _run(() => delegate.handoffCurrent(actor), actor: actor);
  @override
  Future<ServerHandoffStatus> reserveHandoff(
    MembershipSession actor,
    String order,
    String key,
  ) => _run(
    () => delegate.reserveHandoff(actor, order, key),
    actor: actor,
    mutation: true,
  );
  @override
  Future<ServerHandoffStatus> releaseHandoff(
    MembershipSession actor,
    String handoff,
    String key,
  ) => _run(
    () => delegate.releaseHandoff(actor, handoff, key),
    actor: actor,
    mutation: true,
  );
  @override
  Future<ServerHandoffStatus> claimHandoff(
    MembershipSession actor,
    String handoff,
    String key,
  ) => _run(
    () => delegate.claimHandoff(actor, handoff, key),
    actor: actor,
    mutation: true,
  );
  @override
  Future<HistoricalMembershipReceipt> receipt(
    MembershipSession actor,
    String order,
  ) => _run(() => delegate.receipt(actor, order), actor: actor);
}
