import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import 'auth_action_failure.dart';
import 'auth_providers.dart';
import 'auth_repository.dart';
import 'auth_state.dart';
import 'models/admin_workspace_access.dart';
import 'models/user_profile.dart';

/// Auth work belongs to the repository and session that started it. A delayed
/// response cannot restore authority after logout, a repository change or dispose.
class AuthNotifier extends Notifier<AuthState> {
  late AuthRepository _repository;
  bool _active = false;
  int _lifetime = 0;
  int _generation = 0;
  int _transition = 0;
  int _profileRevision = 0;
  int _adminRevision = 0;
  String? _hydratingSessionUserId;
  String? _sessionUserId;
  bool _intentionalSignOut = false;
  AuthRecoveryRequired? _recoveryCleanup;
  int? _completedIntentionalSignOut;
  Completer<void>? _sessionHydrationCompletion;

  static const _changedSessionMessage =
      'Your session changed. Start this action again.';
  static const _changedSessionFailure = AuthActionFailure(
    kind: AuthActionFailureKind.conflict,
    message: _changedSessionMessage,
  );

  @override
  AuthState build() {
    if (_active) _repository.invalidatePendingAuthentication();
    _invalidate(transition: true);
    final lifetime = ++_lifetime;
    final repository = ref.watch(authRepositoryProvider);
    _repository = repository;
    _active = true;
    _intentionalSignOut = false;
    final subscription = repository.authStateChanges.listen((change) {
      // Cancellation may itself complete asynchronously. An old stream never
      // acquires the authority of a rebuilt notifier with the same instance.
      if (_active &&
          lifetime == _lifetime &&
          identical(repository, _repository)) {
        unawaited(syncWithAuthChange(change));
      }
    });
    ref.onDispose(() {
      repository.invalidatePendingAuthentication();
      _active = false;
      _lifetime++;
      _invalidate(transition: true);
      unawaited(subscription.cancel());
    });
    return const AuthInitial();
  }

  void _invalidate({bool transition = false}) {
    final completion = _sessionHydrationCompletion;
    _sessionHydrationCompletion = null;
    if (completion != null && !completion.isCompleted) completion.complete();
    _generation++;
    _hydratingSessionUserId = null;
    if (transition) {
      _transition++;
      _sessionUserId = null;
      _recoveryCleanup = null;
      _completedIntentionalSignOut = null;
    }
  }

  _AuthWork _capture() => _AuthWork(_repository, _generation, _transition);

  _AuthWork _beginTransition() {
    _invalidate(transition: true);
    _intentionalSignOut = false;
    return _capture();
  }

  bool _sameTransition(_AuthWork work) =>
      _active &&
      work.transition == _transition &&
      identical(work.repository, _repository);

  bool _current(_AuthWork work) =>
      _sameTransition(work) && work.generation == _generation;

  /// SDK sign-in can announce its new session before the initiating future
  /// returns. Its independent hydration owns state; the matching result may
  /// finish the UI action, without any stale state, admin query or telemetry.
  Future<bool> _currentSessionMatches(
    _AuthWork work,
    UserProfile profile,
  ) async {
    if (!_sameTransition(work) ||
        _sessionUserId != profile.id ||
        !_profileMatchesRepository(work, profile)) {
      return false;
    }
    final completion = _sessionHydrationCompletion;
    if (completion != null) await completion.future;
    if (!_sameTransition(work) || _sessionUserId != profile.id) return false;
    final current = state;
    return current is AuthAuthenticated && _sameUser(current.profile, profile);
  }

  int? _numericClub(String value) {
    final text = value.trim();
    if (!RegExp(r'^[0-9]+$').hasMatch(text)) return null;
    final id = int.tryParse(text);
    return id != null && id > 0 && id <= 2147483647 ? id : null;
  }

  bool _profileMatchesRepository(_AuthWork work, UserProfile profile) {
    final club = _numericClub(work.repository.clubId);
    return profile.id.isNotEmpty &&
        club != null &&
        _numericClub(profile.clubId) == club;
  }

  bool _sameUser(UserProfile left, UserProfile right) =>
      left.id == right.id &&
      _numericClub(left.clubId) != null &&
      _numericClub(left.clubId) == _numericClub(right.clubId);

  void _rejectProfileScope(_AuthWork work) {
    if (!_current(work)) return;
    _sessionUserId = null;
    state = const AuthRecoveryRequired(
      'Your session is unavailable for this club. Please sign in again.',
    );
    _observeIdentity(null, work: work);
  }

  AuthAuthenticated? _authenticatedFor(_AuthWork work, UserProfile profile) {
    if (!_current(work)) return null;
    final current = state;
    return current is AuthAuthenticated && _sameUser(current.profile, profile)
        ? current
        : null;
  }

  void _observeIdentity(String? userId, {_AuthWork? work}) {
    if (!_active || (work != null && !_current(work))) return;
    unawaited(FirebaseAnalyticsService.setUserId(userId));
    unawaited(CrashlyticsService.setUserId(userId));
  }

  void _commitAuthenticated(
    _AuthWork work,
    UserProfile profile,
    AdminWorkspaceAccess access,
  ) {
    if (!_current(work)) return;
    if (!_profileMatchesRepository(work, profile)) {
      _rejectProfileScope(work);
      return;
    }
    _sessionUserId = profile.id;
    state = AuthAuthenticated(profile: profile, workspace: access);
    _observeIdentity(profile.id, work: work);
  }

  /// Restore the current session on app start.
  Future<void> restore() async {
    if (!_active) return;
    final work = _beginTransition();
    state = const AuthLoading();
    try {
      final profile = await work.repository.restoreCurrentUser();
      if (!_current(work)) return;
      if (profile == null) {
        _observeIdentity(null, work: work);
        state = const AuthUnauthenticated();
        return;
      }
      if (!_profileMatchesRepository(work, profile)) {
        _rejectProfileScope(work);
        return;
      }
      final adminAccess = await work.repository.resolveAdminAccess(profile.id);
      _commitAuthenticated(work, profile, adminAccess);
    } catch (error) {
      if (!_current(work)) return;
      final recovery = AuthRecoveryRequired(
        'Existing session could not be restored and was cleared.',
        error,
      );
      _recoveryCleanup = recovery;
      state = recovery;
      _observeIdentity(null, work: work);
      try {
        await work.repository.signOut();
      } catch (_) {
        if (_sameTransition(work)) {
          AfriLogger.warn(
            'AuthNotifier',
            'Best-effort sign-out during recovery failed.',
          );
        }
      } finally {
        if (_sameTransition(work)) _recoveryCleanup = null;
      }
    }
  }

  /// Keep local auth state aligned with the underlying Supabase session.
  Future<void> syncWithAuthChange(supabase.AuthState change) async {
    if (!_active) return;
    final session = change.session;
    if (change.event == supabase.AuthChangeEvent.signedOut || session == null) {
      final recovery = _recoveryCleanup;
      final wasAuthenticated = state is AuthAuthenticated;
      final intentional = _intentionalSignOut;
      final closingTransition = _transition;
      _invalidate(transition: true);
      if (intentional) _completedIntentionalSignOut = closingTransition;
      _observeIdentity(null, work: _capture());
      if (recovery != null) {
        state = recovery;
      } else if (wasAuthenticated && !intentional) {
        state = const AuthRecoveryRequired(
          'Your session expired. Please sign in again.',
        );
      } else {
        state = const AuthUnauthenticated();
      }
      _intentionalSignOut = false;
      return;
    }

    final sessionUserId = session.user.id;
    final previous = state;
    if (change.event == supabase.AuthChangeEvent.tokenRefreshed &&
        previous is AuthAuthenticated &&
        previous.profile.id == sessionUserId) {
      return;
    }
    if (_hydratingSessionUserId == sessionUserId) return;

    _invalidate();
    _intentionalSignOut = false;
    _recoveryCleanup = null;
    _completedIntentionalSignOut = null;
    _sessionUserId = sessionUserId;
    _hydratingSessionUserId = sessionUserId;
    final completion = Completer<void>();
    _sessionHydrationCompletion = completion;
    final work = _capture();
    if (previous is! AuthAuthenticated ||
        previous.profile.id != sessionUserId) {
      // Remove the preceding user's profile and admin authority immediately.
      state = const AuthLoading();
    }
    try {
      final profile = await work.repository.restoreCurrentUser();
      if (!_current(work)) return;
      if (profile == null) {
        _observeIdentity(null, work: work);
        state = const AuthUnauthenticated();
        return;
      }
      if (profile.id != sessionUserId) {
        throw StateError(
          'Session profile did not match the authenticated user.',
        );
      }
      if (!_profileMatchesRepository(work, profile)) {
        _rejectProfileScope(work);
        return;
      }
      final adminAccess = await work.repository.resolveAdminAccess(profile.id);
      _commitAuthenticated(work, profile, adminAccess);
    } catch (error) {
      if (!_current(work)) return;
      if (previous is AuthAuthenticated &&
          previous.profile.id == sessionUserId) {
        state = previous;
      } else {
        state = AuthError('Session refresh failed', error);
      }
    } finally {
      if (!completion.isCompleted) completion.complete();
      if (identical(_sessionHydrationCompletion, completion)) {
        _sessionHydrationCompletion = null;
      }
      if (_current(work) && _hydratingSessionUserId == sessionUserId) {
        _hydratingSessionUserId = null;
      }
    }
  }

  /// Sign in anonymously, with the repository's configured club.
  Future<void> signInAnonymously() async {
    if (!_active) return;
    final work = _beginTransition();
    state = const AuthLoading();
    try {
      final profile = await work.repository.signInAnonymously();
      if (!_current(work)) return;
      if (!_profileMatchesRepository(work, profile)) {
        _rejectProfileScope(work);
        return;
      }
      final adminAccess = await work.repository.resolveAdminAccess(profile.id);
      _commitAuthenticated(work, profile, adminAccess);
    } catch (error) {
      if (!_current(work)) return;
      if (_isAnonymousGuestFallbackError(error)) {
        final profile = UserProfile.guest(clubId: work.repository.clubId);
        AfriLogger.warn(
          'AuthNotifier',
          'Anonymous sign-in could not reach the backend; using a local guest session.',
        );
        _observeIdentity(null, work: work);
        state = AuthAuthenticated(profile: profile);
      } else {
        state = AuthError('Sign-in failed', error);
      }
    }
  }

  Future<String?> requestPhoneSignInOtp({
    required String phone,
    supabase.OtpChannel channel = supabase.OtpChannel.whatsapp,
  }) async => (await requestPhoneSignInOtpResult(
    phone: phone,
    channel: channel,
  ))?.message;

  /// Send a one-time code with a stable failure category for stateful UI.
  Future<AuthActionFailure?> requestPhoneSignInOtpResult({
    required String phone,
    supabase.OtpChannel channel = supabase.OtpChannel.whatsapp,
  }) async {
    if (!_active) return _changedSessionFailure;
    final work = _capture();
    try {
      await work.repository.requestPhoneSignInOtp(
        phone: phone,
        channel: channel,
      );
      return _current(work) ? null : _changedSessionFailure;
    } catch (error) {
      return _current(work)
          ? AuthActionFailure.fromRequestError(error)
          : _changedSessionFailure;
    }
  }

  Future<String?> verifyPhoneSignInOtp({
    required String phone,
    required String token,
  }) async =>
      (await verifyPhoneSignInOtpResult(phone: phone, token: token))?.message;

  /// Confirm a phone code with a stable failure category for stateful UI.
  Future<AuthActionFailure?> verifyPhoneSignInOtpResult({
    required String phone,
    required String token,
  }) async {
    if (!_active) return _changedSessionFailure;
    final previous = state;
    final work = _beginTransition();
    state = const AuthLoading();
    try {
      final profile = await work.repository.verifyPhoneSignInOtp(
        phone: phone,
        token: token,
      );
      if (!_current(work)) {
        return await _currentSessionMatches(work, profile)
            ? null
            : _changedSessionFailure;
      }
      if (!_profileMatchesRepository(work, profile)) {
        _rejectProfileScope(work);
        return _changedSessionFailure;
      }
      final adminAccess = await work.repository.resolveAdminAccess(profile.id);
      if (!_current(work)) {
        return await _currentSessionMatches(work, profile)
            ? null
            : _changedSessionFailure;
      }
      _commitAuthenticated(work, profile, adminAccess);
      return null;
    } catch (error) {
      if (!_current(work)) return _changedSessionFailure;
      state = _recoverState(previous);
      return AuthActionFailure.fromVerificationError(error);
    }
  }

  /// Request phone verification without rewriting a captured profile later.
  Future<String?> requestPhoneVerificationOtp({required String phone}) async {
    if (!_active) return _changedSessionMessage;
    if (state is! AuthAuthenticated) {
      return 'You must be signed in to verify a phone number.';
    }
    final work = _capture();
    try {
      await work.repository.requestPhoneVerificationOtp(phone: phone);
      return _current(work) ? null : _changedSessionMessage;
    } catch (error) {
      return _current(work)
          ? _describeError(error, 'Could not send the verification code.')
          : _changedSessionMessage;
    }
  }

  Future<String?> verifyPhoneVerificationOtp({
    required String phone,
    required String token,
  }) async {
    if (!_active) return _changedSessionMessage;
    final previous = state;
    if (previous is! AuthAuthenticated) {
      return 'You must be signed in to verify a phone number.';
    }
    final work = _beginTransition();
    state = const AuthLoading();
    try {
      final profile = await work.repository.verifyPhoneVerificationOtp(
        phone: phone,
        token: token,
      );
      if (!_current(work)) {
        return _sameUser(profile, previous.profile) &&
                await _currentSessionMatches(work, profile)
            ? null
            : _changedSessionMessage;
      }
      if (!_sameUser(profile, previous.profile) ||
          !_profileMatchesRepository(work, profile)) {
        _rejectProfileScope(work);
        return _changedSessionMessage;
      }
      final adminAccess = await work.repository.resolveAdminAccess(profile.id);
      if (!_current(work)) {
        return await _currentSessionMatches(work, profile)
            ? null
            : _changedSessionMessage;
      }
      _commitAuthenticated(work, profile, adminAccess);
      return null;
    } catch (error) {
      if (!_current(work)) return _changedSessionMessage;
      state = previous;
      return _describeError(error, 'Could not confirm the verification code.');
    }
  }

  Future<String?> updateProfile(UserProfile profile) async {
    if (!_active) return _changedSessionMessage;
    final previous = state;
    if (previous is! AuthAuthenticated) {
      return 'You must be signed in to update your profile.';
    }
    if (!_sameUser(profile, previous.profile) ||
        !_profileMatchesRepository(_capture(), profile)) {
      return _changedSessionMessage;
    }
    final work = _capture();
    final revision = ++_profileRevision;
    try {
      final updated = await work.repository.updateProfile(profile);
      final current = _authenticatedFor(work, previous.profile);
      if (current == null ||
          revision != _profileRevision ||
          (!_sameUser(updated, previous.profile) ||
              !_profileMatchesRepository(work, updated))) {
        return _changedSessionMessage;
      }
      state = AuthAuthenticated(profile: updated, workspace: current.workspace);
      return null;
    } catch (error) {
      if (_authenticatedFor(work, previous.profile) == null ||
          revision != _profileRevision) {
        return _changedSessionMessage;
      }
      return _describeError(error, 'Profile update failed.');
    }
  }

  Future<String?> refreshProfile() async {
    if (!_active) return _changedSessionMessage;
    final previous = state;
    if (previous is! AuthAuthenticated) {
      return 'You must be signed in to refresh your profile.';
    }
    final work = _capture();
    final revision = ++_profileRevision;
    try {
      final refreshed = await work.repository.restoreCurrentUser();
      final current = _authenticatedFor(work, previous.profile);
      if (current == null || revision != _profileRevision) {
        return _changedSessionMessage;
      }
      if (refreshed == null ||
          !_sameUser(refreshed, previous.profile) ||
          !_profileMatchesRepository(work, refreshed)) {
        return 'The latest profile could not be loaded.';
      }
      state = AuthAuthenticated(
        profile: refreshed,
        workspace: current.workspace,
      );
      return null;
    } catch (error) {
      if (_authenticatedFor(work, previous.profile) == null ||
          revision != _profileRevision) {
        return _changedSessionMessage;
      }
      return _describeError(error, 'The latest profile could not be loaded.');
    }
  }

  Future<void> refreshAdminAccess() async {
    if (!_active) return;
    final previous = state;
    if (previous is! AuthAuthenticated) return;
    final work = _capture();
    if (!_profileMatchesRepository(work, previous.profile)) return;
    final revision = ++_adminRevision;
    try {
      final access = await work.repository.resolveAdminAccess(
        previous.profile.id,
      );
      final current = _authenticatedFor(work, previous.profile);
      if (current == null || revision != _adminRevision) return;
      state = AuthAuthenticated(profile: current.profile, workspace: access);
    } catch (_) {
      if (_authenticatedFor(work, previous.profile) != null &&
          revision == _adminRevision) {
        AfriLogger.warn(
          'AuthNotifier',
          'Admin access refresh failed (keeping current level).',
        );
      }
    }
  }

  /// Close local authority synchronously; cleanup may be slow or fail.
  Future<void> signOut() async {
    if (!_active) return;
    final work = _beginTransition();
    _intentionalSignOut = true;
    state = const AuthUnauthenticated();
    _observeIdentity(null, work: work);
    try {
      await work.repository.signOut();
    } catch (_) {
      if (_current(work)) {
        AfriLogger.warn('AuthNotifier', 'Best-effort sign-out failed.');
      }
    }
    // No post-await state or identity write can erase a newer session.
  }

  Future<String?> signOutOtherSessions() async {
    if (!_active) return _changedSessionMessage;
    if (state is! AuthAuthenticated) {
      return 'You must be signed in to manage sessions.';
    }
    final work = _capture();
    try {
      await work.repository.signOutOtherSessions();
      return _current(work) ? null : _changedSessionMessage;
    } catch (error) {
      return _current(work)
          ? _describeError(error, 'Sign out other sessions failed.')
          : _changedSessionMessage;
    }
  }

  Future<String?> deleteAccount() async {
    if (!_active) return _changedSessionMessage;
    final previous = state;
    if (previous is! AuthAuthenticated) {
      return 'You must be signed in to delete your account.';
    }
    final work = _beginTransition();
    _intentionalSignOut = true;
    state = const AuthLoading();
    try {
      await work.repository.deleteAccount(previous.profile.id);
      if (!_current(work)) {
        // The SDK may announce this deletion's intentional logout before the
        // successful deletion response. No state or telemetry is written here.
        if (_active &&
            identical(work.repository, _repository) &&
            _completedIntentionalSignOut == work.transition &&
            state is AuthUnauthenticated) {
          return null;
        }
        return _changedSessionMessage;
      }
      _observeIdentity(null, work: work);
      state = const AuthUnauthenticated();
      return null;
    } catch (error) {
      if (!_current(work)) return _changedSessionMessage;
      _intentionalSignOut = false;
      state = previous;
      return _describeError(error, 'Account deletion failed.');
    }
  }

  String _describeError(Object error, String fallback) {
    final message = error.toString().trim();
    if (message.isEmpty) return fallback;
    if (message.startsWith('Exception: ')) {
      return message.substring('Exception: '.length);
    }
    if (message.startsWith('Bad state: ')) {
      return message.substring('Bad state: '.length);
    }
    if (message.startsWith('PostgrestException(')) return fallback;
    return message;
  }

  AuthState _recoverState(AuthState previous) {
    if (previous is AuthLoading || previous is AuthInitial) {
      return const AuthUnauthenticated();
    }
    return previous;
  }

  bool _isAnonymousGuestFallbackError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('failed host lookup') ||
        message.contains('socketexception') ||
        message.contains('authretryablefetchexception') ||
        message.contains('unable to connect') ||
        message.contains('check your internet connection') ||
        message.contains('connection timed out') ||
        message.contains('network is unreachable') ||
        message.contains('connection refused');
  }
}

class _AuthWork {
  const _AuthWork(this.repository, this.generation, this.transition);
  final AuthRepository repository;
  final int generation;
  final int transition;
}
