import 'dart:async';

import 'journal.dart';
import 'models.dart';
import 'ports.dart';
import 'wire_client.dart';

/// Explicit native commands with a durable, exclusive, protected journal.
/// Nothing runs on construction, restart, timeout or credential reads.
///
/// Call [invalidateIdentity] on lifecycle/account/scope changes, with the
/// supplied callback invoking the membership composition's invalidateIdentity.
/// Each immutable scope needs a separate controller and OS protected binding.
final class NativeIdentityController {
  NativeIdentityController({
    required this.client,
    this.store = const UnavailableNativeCredentialStore(),
    this.enabled = false,
    NativeIdentityEntropy? entropy,
    this.storeTimeout = const Duration(seconds: 2),
    this.operationTimeout = const Duration(seconds: 60),
    this.onIdentityInvalidated,
  }) : _entropy = entropy {
    identityRequire(
      storeTimeout.inMilliseconds > 0 &&
          storeTimeout.inMilliseconds <= 5000 &&
          operationTimeout.inMilliseconds > 0 &&
          operationTimeout.inSeconds <= 180,
      NativeIdentityError.invalidConfiguration,
    );
  }
  final NativeIdentityWireClient client;
  final NativeCredentialStore store;
  final bool enabled;
  NativeIdentityEntropy? _entropy;
  final Duration storeTimeout, operationTimeout;
  final void Function()? onIdentityInvalidated;
  var _generation = 0;
  var _disposed = false;
  var _invalidationFailed = false;
  NativeSupporterIdentity? _identity;

  /// Last matching server observation in this controller's local generation.
  /// This is point-in-time identity, never an irrevocable cross-process grant.
  NativeSupporterIdentity? get identity => _identity;

  /// Synchronously hides old identity before any asynchronous work can start.
  void invalidateIdentity() {
    _generation++;
    _identity = null;
    try {
      onIdentityInvalidated?.call();
    } catch (_) {
      _invalidationFailed = true;
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    invalidateIdentity();
  }

  void _check(_IdentityFence fence, {bool sent = false}) {
    final outcome = sent
        ? NativeIdentityOutcome.unknown
        : NativeIdentityOutcome.notSent;
    if (!enabled || !client.enabled) {
      throw NativeIdentityFailure(NativeIdentityError.disabled, outcome);
    }
    if (_invalidationFailed) {
      throw NativeIdentityFailure(
        NativeIdentityError.invalidationUnavailable,
        outcome,
      );
    }
    if (_disposed || !fence.active || fence.generation != _generation) {
      throw NativeIdentityFailure(NativeIdentityError.identityChanged, outcome);
    }
  }

  _IdentityFence _begin({bool invalidate = true}) {
    final initial = _IdentityFence(_generation);
    _check(initial);
    if (invalidate) invalidateIdentity();
    final fence = _IdentityFence(_generation);
    _check(fence);
    return fence;
  }

  Future<T> _exclusive<T>(
    _IdentityFence fence,
    Future<T> Function(_JournalCursor cursor) work,
  ) async {
    _check(fence);
    if (!store.capabilities.usable) {
      throw const NativeIdentityFailure(NativeIdentityError.storageUnavailable);
    }
    try {
      return await store
          .runExclusive(client.scope, storeTimeout, (transaction) async {
            _check(fence);
            final cursor = _JournalCursor(this, transaction, fence);
            await cursor.load();
            cursor.check();
            return work(cursor);
          })
          .timeout(operationTimeout);
    } on NativeIdentityFailure {
      rethrow;
    } catch (_) {
      throw NativeIdentityFailure(
        NativeIdentityError.storageUnavailable,
        fence.sent
            ? NativeIdentityOutcome.unknown
            : NativeIdentityOutcome.notSent,
      );
    } finally {
      // A faulty adapter invoking its callback after the deadline cannot send.
      fence.active = false;
    }
  }

  String _key() {
    try {
      final key = (_entropy ??= SecureNativeIdentityEntropy()).requestKey();
      identityRequire(identityKey(key), NativeIdentityError.invalidInput);
      return key;
    } catch (_) {
      throw const NativeIdentityFailure(NativeIdentityError.invalidInput);
    }
  }

  String _secret() {
    try {
      final secret = (_entropy ??= SecureNativeIdentityEntropy())
          .clientSecret();
      identityRequire(identitySecret(secret), NativeIdentityError.invalidInput);
      return secret;
    } catch (_) {
      throw const NativeIdentityFailure(NativeIdentityError.invalidInput);
    }
  }

  /// Durably records the original phone, secret and issuance key before sending.
  Future<NativeIdentityChallenge> issueChallenge(String phone) {
    identityRequire(
      identityMatches(r'^\+[1-9]\d{7,14}$', phone),
      NativeIdentityError.invalidInput,
    );
    final fence = _begin();
    return _exclusive(fence, (cursor) async {
      _noPending(cursor);
      final pending = NativeIdentityPending(
        operation: NativeIdentityOperation.challenge,
        requestKey: _key(),
        preparedAt: client.nowMilliseconds(),
        firstSentAt: null,
        body: {'phone': phone, 'clientSecret': _secret()},
      );
      await cursor.write(
        cursor.journal.next(locallySignedOut: false, pending: pending),
      );
      return _sendChallenge(cursor);
    });
  }

  Future<NativeSupporterIdentity> verifyCode(String code) {
    identityRequire(
      identityMatches(r'^\d{6}$', code),
      NativeIdentityError.invalidInput,
    );
    final fence = _begin();
    return _exclusive(fence, (cursor) async {
      _noPending(cursor);
      final challenge = cursor.journal.challenge;
      identityRequire(
        !cursor.journal.locallySignedOut &&
            challenge != null &&
            challenge.expiresAt > client.nowMilliseconds(),
        NativeIdentityError.reauthenticationRequired,
      );
      final pending = NativeIdentityPending(
        operation: NativeIdentityOperation.verification,
        requestKey: _key(),
        preparedAt: client.nowMilliseconds(),
        firstSentAt: null,
        body: {
          'challengeId': challenge!.challengeId,
          'code': code,
          'clientSecret': cursor.journal.challengeSecret,
        },
      );
      await cursor.write(
        cursor.journal.next(
          locallySignedOut: false,
          challenge: challenge,
          challengeSecret: cursor.journal.challengeSecret,
          pending: pending,
        ),
      );
      return _sendCredentials(cursor);
    });
  }

  /// Explicit rotation only. Persists the old pair and original rotation key.
  Future<NativeSupporterIdentity> rotateCredentials() {
    final fence = _begin();
    return _exclusive(fence, (cursor) async {
      _noPending(cursor);
      final previous = _credentials(cursor, allowExpiredAccess: true);
      final pending = NativeIdentityPending(
        operation: NativeIdentityOperation.refresh,
        requestKey: _key(),
        preparedAt: client.nowMilliseconds(),
        firstSentAt: null,
        body: {'credentials': previous.toProtectedJson()},
      );
      await cursor.write(
        cursor.journal.next(
          locallySignedOut: false,
          credentials: previous,
          pending: pending,
        ),
      );
      return _sendCredentials(cursor);
    });
  }

  /// Explicit recovery after crash/lost acknowledgement, with no new key/code.
  /// A null return means a challenge was recovered, ready for code entry.
  /// Revoke has no replay receipt and is never automatically or manually retried
  /// by this method. A fresh verification can later confirm/revoke separately.
  Future<NativeSupporterIdentity?> recoverPending() {
    final fence = _begin();
    return _exclusive(fence, (cursor) async {
      final pending = cursor.journal.pending;
      if (pending == null) return _inspect(cursor);
      if (pending.operation == NativeIdentityOperation.revoke) {
        throw const NativeIdentityFailure(
          NativeIdentityError.revocationUnknown,
          NativeIdentityOutcome.unknown,
        );
      }
      identityRequire(
        !cursor.journal.locallySignedOut,
        NativeIdentityError.locallySignedOut,
      );
      _recoveryWindow(pending);
      if (pending.operation == NativeIdentityOperation.challenge) {
        await _sendChallenge(cursor);
        return null;
      }
      return _sendCredentials(cursor);
    });
  }

  void _recoveryWindow(NativeIdentityPending pending) {
    final first = pending.firstSentAt;
    if (first == null) return;
    final elapsed = client.nowMilliseconds() - first;
    if (elapsed < 0 || elapsed >= 60000) {
      throw const NativeIdentityFailure(
        NativeIdentityError.recoveryExpired,
        NativeIdentityOutcome.unknown,
      );
    }
  }

  /// GET only. Refuses unresolved writes rather than guessing or rotating.
  Future<NativeSupporterIdentity> inspectCurrentSession() {
    final fence = _begin();
    return _exclusive(fence, _inspect);
  }

  /// Suitable for an explicitly selected NativeMembershipClient token callback.
  /// Reads protected storage only, makes ZERO network requests/mutations, and
  /// returns null when disabled, signed out, expired or recovery is unresolved.
  Future<String?> readAccessCredential() async {
    if (!enabled || !client.enabled) return null;
    final fence = _begin(invalidate: false);
    return _exclusive(fence, (cursor) async {
      if (cursor.journal.locallySignedOut || cursor.journal.pending != null) {
        return null;
      }
      final credentials = cursor.journal.credentials;
      if (credentials == null ||
          credentials.accessExpiresAt <= client.nowMilliseconds()) {
        return null;
      }
      cursor.check();
      return credentials.accessToken;
    });
  }

  /// Signs out locally before the server command. All scopes hide local identity.
  /// A lost server acknowledgement remains unknown; local signout is separate.
  Future<NativeIdentityRevocationResult> revoke(
    NativeIdentityRevokeScope scope,
  ) {
    final fence = _begin();
    return _exclusive(fence, (cursor) async {
      _noPending(cursor);
      final previous = _credentials(cursor);
      if (scope != NativeIdentityRevokeScope.current) {
        identityRequire(
          client.nowMilliseconds() - previous.authenticatedAt <= 300000 &&
              client.nowMilliseconds() >= previous.authenticatedAt,
          NativeIdentityError.recentVerificationRequired,
        );
      }
      final pending = NativeIdentityPending(
        operation: NativeIdentityOperation.revoke,
        requestKey: null,
        preparedAt: client.nowMilliseconds(),
        firstSentAt: null,
        body: {'accessToken': previous.accessToken, 'scope': scope.name},
      );
      await cursor.write(
        cursor.journal.next(
          locallySignedOut: true,
          pending: pending,
          revocation: NativeIdentityRevocation.unknown,
        ),
      );
      await _markSending(cursor);
      cursor.sent = true;
      try {
        await client.revoke(previous.accessToken, scope);
        cursor.check();
        await cursor.write(
          cursor.journal.next(
            locallySignedOut: true,
            revocation: NativeIdentityRevocation.confirmed,
          ),
        );
        return const NativeIdentityRevocationResult(
          NativeIdentityRevocation.confirmed,
        );
      } on NativeIdentityFailure catch (error) {
        cursor.check();
        if (error.outcome == NativeIdentityOutcome.rejected) rethrow;
        return const NativeIdentityRevocationResult(
          NativeIdentityRevocation.unknown,
        );
      }
    });
  }

  /// No network call and no claim of server revocation. Retains pending recovery
  /// material so a storage acknowledgement loss cannot silently replace its key.
  Future<void> signOutLocally() {
    final fence = _begin();
    return _exclusive(
      fence,
      (cursor) => cursor.write(
        cursor.journal.next(
          locallySignedOut: true,
          credentials: cursor.journal.credentials,
          challenge: cursor.journal.challenge,
          challengeSecret: cursor.journal.challengeSecret,
          pending: cursor.journal.pending,
          revocation: cursor.journal.revocation,
        ),
      ),
    );
  }

  /// User explicitly abandons an unresolved operation to verify a phone afresh.
  /// This discards local recovery only; it does not revoke a possibly issued
  /// server session. Full account-session management remains separate work.
  Future<void> abandonPendingForFreshVerification() {
    final fence = _begin();
    return _exclusive(
      fence,
      (cursor) => cursor.write(
        cursor.journal.next(
          locallySignedOut: true,
          revocation: cursor.journal.revocation,
        ),
      ),
    );
  }

  void _noPending(_JournalCursor cursor) {
    identityRequire(
      cursor.journal.pending == null,
      NativeIdentityError.pendingOperation,
    );
  }

  NativeIdentityCredentials _credentials(
    _JournalCursor cursor, {
    bool allowExpiredAccess = false,
  }) {
    identityRequire(
      !cursor.journal.locallySignedOut,
      NativeIdentityError.locallySignedOut,
    );
    final credentials = cursor.journal.credentials;
    identityRequire(
      credentials != null &&
          credentials.refreshExpiresAt > client.nowMilliseconds() &&
          (allowExpiredAccess ||
              credentials.accessExpiresAt > client.nowMilliseconds()),
      NativeIdentityError.reauthenticationRequired,
    );
    return credentials!;
  }

  Future<void> _markSending(_JournalCursor cursor) async {
    cursor.check();
    final journal = cursor.journal;
    final pending = journal.pending!;
    if (pending.firstSentAt != null) {
      _recoveryWindow(pending);
      return;
    }
    await cursor.write(
      journal.next(
        locallySignedOut: journal.locallySignedOut,
        credentials: journal.credentials,
        challenge: journal.challenge,
        challengeSecret: journal.challengeSecret,
        pending: pending.markSending(client.nowMilliseconds()),
        revocation: journal.revocation,
      ),
    );
  }

  Future<NativeIdentityChallenge> _sendChallenge(_JournalCursor cursor) async {
    await _markSending(cursor);
    cursor.check();
    final pending = cursor.journal.pending!;
    cursor.sent = true;
    try {
      final challenge = await client.challenge(
        pending.body['phone']! as String,
        pending.body['clientSecret']! as String,
        pending.requestKey!,
      );
      cursor.check();
      await cursor.write(
        cursor.journal.next(
          locallySignedOut: false,
          challenge: challenge,
          challengeSecret: pending.body['clientSecret']! as String,
        ),
      );
      return challenge;
    } on NativeIdentityFailure catch (error) {
      cursor.check();
      if (error.outcome == NativeIdentityOutcome.rejected) {
        await cursor.write(cursor.journal.next(locallySignedOut: true));
      }
      rethrow;
    }
  }

  Future<NativeSupporterIdentity> _sendCredentials(
    _JournalCursor cursor,
  ) async {
    final prepared = cursor.journal.pending!;
    final stillUsable =
        prepared.operation == NativeIdentityOperation.verification
        ? cursor.journal.challenge!.expiresAt > client.nowMilliseconds()
        : NativeIdentityCredentials.parse(
                prepared.body['credentials'],
                client.scope.clubId,
              ).refreshExpiresAt >
              client.nowMilliseconds();
    if (!stillUsable) {
      throw NativeIdentityFailure(
        NativeIdentityError.reauthenticationRequired,
        cursor.sent
            ? NativeIdentityOutcome.unknown
            : NativeIdentityOutcome.notSent,
      );
    }
    await _markSending(cursor);
    cursor.check();
    final pending = cursor.journal.pending!;
    cursor.sent = true;
    try {
      final next = pending.operation == NativeIdentityOperation.verification
          ? await client.verify(
              pending.body['challengeId']! as String,
              pending.body['code']! as String,
              pending.body['clientSecret']! as String,
              pending.requestKey!,
            )
          : await client.refresh(
              NativeIdentityCredentials.parse(
                pending.body['credentials'],
                client.scope.clubId,
              ),
              pending.requestKey!,
            );
      cursor.check();
      await cursor.write(
        cursor.journal.next(locallySignedOut: false, credentials: next),
      );
      return await _inspect(cursor);
    } on NativeIdentityFailure catch (error) {
      cursor.check();
      if (error.outcome == NativeIdentityOutcome.rejected &&
          cursor.journal.pending != null) {
        final journal = cursor.journal;
        await cursor.write(
          journal.next(
            locallySignedOut:
                pending.operation == NativeIdentityOperation.refresh,
            challenge: journal.challenge,
            challengeSecret: journal.challengeSecret,
          ),
        );
        rethrow;
      }
      // Credentials may already be committed when identity readback fails.
      // Preserve their journal and require an explicit GET recovery; this is
      // not permission to replace the original verification/rotation key.
      throw NativeIdentityFailure(error.code, NativeIdentityOutcome.unknown);
    }
  }

  Future<NativeSupporterIdentity> _inspect(_JournalCursor cursor) async {
    _noPending(cursor);
    final credentials = _credentials(cursor);
    final current = await client.session(credentials);
    cursor.check();
    // An adapter violating exclusivity/CAS cannot publish replaced credentials.
    await cursor.assertReadback();
    cursor.check();
    _identity = current;
    return current;
  }
}

final class _IdentityFence {
  _IdentityFence(this.generation);
  final int generation;
  var active = true;
  var sent = false;
}

final class _JournalCursor {
  _JournalCursor(this.owner, this.transaction, this.fence);
  final NativeIdentityController owner;
  final NativeCredentialTransaction transaction;
  final _IdentityFence fence;
  String? raw;
  late NativeIdentityJournal journal;
  bool get sent => fence.sent;
  set sent(bool value) => fence.sent = value;
  void check() => owner._check(fence, sent: sent);
  Future<T> _store<T>(Future<T> Function() operation) async {
    check();
    try {
      final result = await operation().timeout(owner.storeTimeout);
      check();
      return result;
    } on NativeIdentityFailure catch (error) {
      if (error.code == NativeIdentityError.identityChanged ||
          error.code == NativeIdentityError.invalidationUnavailable) {
        rethrow;
      }
      throw NativeIdentityFailure(
        NativeIdentityError.storageUnavailable,
        sent ? NativeIdentityOutcome.unknown : NativeIdentityOutcome.notSent,
      );
    } catch (_) {
      throw NativeIdentityFailure(
        NativeIdentityError.storageUnavailable,
        sent ? NativeIdentityOutcome.unknown : NativeIdentityOutcome.notSent,
      );
    }
  }

  Future<void> load() async {
    raw = await _store(transaction.read);
    check();
    journal = raw == null
        ? NativeIdentityJournal(scope: owner.client.scope)
        : NativeIdentityJournal.decodeProtected(raw!, owner.client.scope);
    sent = journal.pending?.firstSentAt != null;
  }

  Future<void> assertReadback() async {
    final found = await _store(transaction.read);
    if (found != raw) {
      throw NativeIdentityFailure(
        NativeIdentityError.storageReadbackFailed,
        sent ? NativeIdentityOutcome.unknown : NativeIdentityOutcome.notSent,
      );
    }
  }

  Future<void> write(NativeIdentityJournal next) async {
    check();
    final replacement = next.encodeProtected();
    // Validate our durable format before submitting it to an OS adapter.
    NativeIdentityJournal.decodeProtected(replacement, owner.client.scope);
    final accepted = await _store(
      () => transaction.compareAndSet(raw, replacement),
    );
    if (!accepted) {
      throw NativeIdentityFailure(
        NativeIdentityError.storageConflict,
        sent ? NativeIdentityOutcome.unknown : NativeIdentityOutcome.notSent,
      );
    }
    raw = replacement;
    await assertReadback();
    check();
    journal = next;
  }
}
