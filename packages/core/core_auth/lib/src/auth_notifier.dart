import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import 'auth_providers.dart';
import 'auth_repository.dart';
import 'auth_state.dart';
import 'models/admin_workspace_access.dart';
import 'models/user_profile.dart';

/// Core auth state notifier — manages the auth lifecycle.
///
/// State machine:
///   AuthInitial → AuthLoading → AuthAuthenticated / AuthUnauthenticated / AuthError
///
/// Uses Riverpod v2 `Notifier` (replaces deprecated `StateNotifier`).
class AuthNotifier extends Notifier<AuthState> {
  late AuthRepository _repository;
  String? _hydratingSessionUserId;
  int _authHydrationEpoch = 0;

  /// Tracks whether the current sign-out was intentional (user-initiated).
  /// When false, a signedOut event while previously authenticated indicates
  /// an involuntary session loss (e.g. token refresh failure on a flaky
  /// network), and the app transitions to [AuthRecoveryRequired] instead
  /// of [AuthUnauthenticated] so the UI can prompt re-authentication.
  bool _intentionalSignOut = false;

  @override
  AuthState build() {
    _repository = ref.watch(authRepositoryProvider);
    final subscription = _repository.authStateChanges.listen(
      syncWithAuthChange,
    );
    ref.onDispose(subscription.cancel);
    return const AuthInitial();
  }

  /// Restore the current session on app start.
  ///
  /// If a session exists, loads the profile from the server.
  /// Preserves the current authenticated identity with a local fallback profile
  /// if remote hydration fails.
  Future<void> restore() async {
    state = const AuthLoading();

    try {
      final profile = await _repository.restoreCurrentUser();
      if (profile != null) {
        unawaited(FirebaseAnalyticsService.setUserId(profile.id));
        unawaited(CrashlyticsService.setUserId(profile.id));
        final adminAccess = await _repository.resolveAdminAccess(profile.id);
        state = AuthAuthenticated(profile: profile, workspace: adminAccess);
      } else {
        unawaited(FirebaseAnalyticsService.setUserId(null));
        unawaited(CrashlyticsService.setUserId(null));
        state = const AuthUnauthenticated();
      }
    } catch (e) {
      try {
        await _repository.signOut();
      } catch (signOutError) {
        // Best-effort cleanup of a stale or partially restored session.
        AfriLogger.warn(
          'AuthNotifier',
          'Best-effort sign-out during recovery failed: $signOutError',
        );
      }
      state = AuthRecoveryRequired(
        'Existing session could not be restored and was cleared.',
        e,
      );
    }
  }

  /// Keep local auth state aligned with the underlying Supabase session.
  Future<void> syncWithAuthChange(supabase.AuthState change) async {
    final session = change.session;
    if (change.event == supabase.AuthChangeEvent.signedOut || session == null) {
      _authHydrationEpoch += 1;
      _hydratingSessionUserId = null;
      unawaited(FirebaseAnalyticsService.setUserId(null));
      unawaited(CrashlyticsService.setUserId(null));

      // Distinguish intentional sign-out from involuntary session loss.
      final wasAuthenticated = state is AuthAuthenticated;
      if (wasAuthenticated && !_intentionalSignOut) {
        // Involuntary session loss — token refresh failed or backend revoked
        // the session. Transition to recovery state so the UI can offer a
        // "session expired" prompt instead of silently dropping to onboarding.
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
    final current = state;

    if (change.event == supabase.AuthChangeEvent.tokenRefreshed &&
        current is AuthAuthenticated &&
        current.profile.id == sessionUserId) {
      return;
    }

    if (_hydratingSessionUserId == sessionUserId) {
      return;
    }

    final hydrationEpoch = ++_authHydrationEpoch;
    _hydratingSessionUserId = sessionUserId;
    try {
      final profile = await _repository.restoreCurrentUser();
      if (hydrationEpoch != _authHydrationEpoch) {
        return;
      }
      if (profile == null) {
        unawaited(FirebaseAnalyticsService.setUserId(null));
        unawaited(CrashlyticsService.setUserId(null));
        state = const AuthUnauthenticated();
        return;
      }
      unawaited(FirebaseAnalyticsService.setUserId(profile.id));
      unawaited(CrashlyticsService.setUserId(profile.id));
      final adminAccess = await _repository.resolveAdminAccess(profile.id);
      if (hydrationEpoch != _authHydrationEpoch) {
        return;
      }
      state = AuthAuthenticated(profile: profile, workspace: adminAccess);
    } catch (error) {
      if (hydrationEpoch != _authHydrationEpoch) {
        return;
      }
      if (current is AuthAuthenticated && current.profile.id == sessionUserId) {
        state = current;
      } else {
        state = AuthError('Session refresh failed', error);
      }
    } finally {
      if (hydrationEpoch == _authHydrationEpoch &&
          _hydratingSessionUserId == sessionUserId) {
        _hydratingSessionUserId = null;
      }
    }
  }

  /// Sign in anonymously, injecting club_id into metadata.
  Future<void> signInAnonymously() async {
    state = const AuthLoading();

    try {
      final profile = await _repository.signInAnonymously();
      unawaited(FirebaseAnalyticsService.setUserId(profile.id));
      unawaited(CrashlyticsService.setUserId(profile.id));
      final adminAccess = await _repository.resolveAdminAccess(profile.id);
      state = AuthAuthenticated(profile: profile, workspace: adminAccess);
    } catch (e) {
      if (_isAnonymousGuestFallbackError(e)) {
        final profile = UserProfile.guest(clubId: _repository.clubId);
        AfriLogger.warn(
          'AuthNotifier',
          'Anonymous sign-in could not reach the backend; continuing with a local guest session: $e',
        );
        unawaited(FirebaseAnalyticsService.setUserId(null));
        unawaited(CrashlyticsService.setUserId(null));
        state = AuthAuthenticated(
          profile: profile,
          workspace: AdminWorkspaceAccess.none,
        );
        return;
      }
      state = AuthError('Sign-in failed', e);
    }
  }

  /// Send a one-time code for supporter phone sign-in.
  Future<String?> requestPhoneSignInOtp({
    required String phone,
    supabase.OtpChannel channel = supabase.OtpChannel.whatsapp,
  }) async {
    try {
      await _repository.requestPhoneSignInOtp(phone: phone, channel: channel);
      return null;
    } catch (e) {
      return _describeError(e, 'Could not send the verification code.');
    }
  }

  /// Confirm a supporter phone sign-in code and complete session hydration.
  Future<String?> verifyPhoneSignInOtp({
    required String phone,
    required String token,
  }) async {
    final previous = state;
    state = const AuthLoading();

    try {
      final profile = await _repository.verifyPhoneSignInOtp(
        phone: phone,
        token: token,
      );
      unawaited(FirebaseAnalyticsService.setUserId(profile.id));
      unawaited(CrashlyticsService.setUserId(profile.id));
      final adminAccess = await _repository.resolveAdminAccess(profile.id);
      state = AuthAuthenticated(profile: profile, workspace: adminAccess);
      return null;
    } catch (e) {
      state = _recoverState(previous);
      return _describeError(e, 'Could not verify the code.');
    }
  }

  /// Send a phone verification code for the current authenticated user.
  Future<String?> requestPhoneVerificationOtp({required String phone}) async {
    final current = state;
    if (current is! AuthAuthenticated) {
      return 'You must be signed in to verify a phone number.';
    }

    try {
      await _repository.requestPhoneVerificationOtp(phone: phone);
      state = AuthAuthenticated(
        profile: current.profile,
        workspace: current.workspace,
      );
      return null;
    } catch (e) {
      state = AuthAuthenticated(
        profile: current.profile,
        workspace: current.workspace,
      );
      return _describeError(e, 'Could not send the verification code.');
    }
  }

  /// Confirm a phone verification code for the current authenticated user.
  Future<String?> verifyPhoneVerificationOtp({
    required String phone,
    required String token,
  }) async {
    final previous = state;
    if (previous is! AuthAuthenticated) {
      return 'You must be signed in to verify a phone number.';
    }

    state = const AuthLoading();
    try {
      final profile = await _repository.verifyPhoneVerificationOtp(
        phone: phone,
        token: token,
      );
      unawaited(FirebaseAnalyticsService.setUserId(profile.id));
      unawaited(CrashlyticsService.setUserId(profile.id));
      final adminAccess = await _repository.resolveAdminAccess(profile.id);
      state = AuthAuthenticated(profile: profile, workspace: adminAccess);
      return null;
    } catch (e) {
      state = previous;
      return _describeError(e, 'Could not confirm the verification code.');
    }
  }

  /// Create or update the user profile.
  Future<String?> updateProfile(UserProfile profile) async {
    final current = state;
    if (current is! AuthAuthenticated) {
      return 'You must be signed in to update your profile.';
    }

    try {
      final updated = await _repository.updateProfile(profile);
      state = AuthAuthenticated(profile: updated, workspace: current.workspace);
      return null;
    } catch (e) {
      state = AuthAuthenticated(
        profile: current.profile,
        workspace: current.workspace,
      );
      return _describeError(e, 'Profile update failed.');
    }
  }

  /// Refresh admin access (e.g. after roles change).
  Future<void> refreshAdminAccess() async {
    final current = state;
    if (current is! AuthAuthenticated) return;

    try {
      final adminAccess = await _repository.resolveAdminAccess(
        current.profile.id,
      );
      state = AuthAuthenticated(
        profile: current.profile,
        workspace: adminAccess,
      );
    } catch (e) {
      // Non-fatal — keep current access level but log for diagnostics.
      AfriLogger.warn(
        'AuthNotifier',
        'Admin access refresh failed (keeping current level): $e',
      );
    }
  }

  /// Sign out and clear session.
  Future<void> signOut() async {
    _intentionalSignOut = true;
    try {
      await _repository.signOut();
    } catch (signOutError) {
      // Best-effort sign-out — log but do not propagate.
      AfriLogger.warn(
        'AuthNotifier',
        'Best-effort sign-out failed: $signOutError',
      );
    }
    unawaited(FirebaseAnalyticsService.setUserId(null));
    unawaited(CrashlyticsService.setUserId(null));
    state = const AuthUnauthenticated();
  }

  /// Revoke all other active sessions while keeping the current device signed in.
  Future<String?> signOutOtherSessions() async {
    final current = state;
    if (current is! AuthAuthenticated) {
      return 'You must be signed in to manage sessions.';
    }

    try {
      await _repository.signOutOtherSessions();
      state = AuthAuthenticated(
        profile: current.profile,
        workspace: current.workspace,
      );
      return null;
    } catch (e) {
      state = AuthAuthenticated(
        profile: current.profile,
        workspace: current.workspace,
      );
      return _describeError(e, 'Sign out other sessions failed.');
    }
  }

  /// Delete account and all associated data.
  Future<String?> deleteAccount() async {
    final current = state;
    if (current is! AuthAuthenticated) {
      return 'You must be signed in to delete your account.';
    }

    _intentionalSignOut = true;
    state = const AuthLoading();

    try {
      await _repository.deleteAccount(current.profile.id);
      unawaited(FirebaseAnalyticsService.setUserId(null));
      unawaited(CrashlyticsService.setUserId(null));
      state = const AuthUnauthenticated();
      return null;
    } catch (e) {
      _intentionalSignOut = false;
      state = AuthAuthenticated(
        profile: current.profile,
        workspace: current.workspace,
      );
      return _describeError(e, 'Account deletion failed.');
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
    if (message.startsWith('PostgrestException(')) {
      return fallback;
    }
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
        message.contains('connection timed out') ||
        message.contains('network is unreachable') ||
        message.contains('connection refused');
  }
}
