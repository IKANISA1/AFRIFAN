import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import 'auth_providers.dart';
import 'auth_repository.dart';
import 'auth_state.dart';
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
        FirebaseAnalyticsService.setUserId(profile.id);
        final adminAccess = await _repository.resolveAdminAccess(profile.id);
        state = AuthAuthenticated(profile: profile, workspace: adminAccess);
      } else {
        FirebaseAnalyticsService.setUserId(null);
        state = const AuthUnauthenticated();
      }
    } catch (e) {
      try {
        await _repository.signOut();
      } catch (_) {
        // Best-effort cleanup of a stale or partially restored session.
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
      FirebaseAnalyticsService.setUserId(null);
      state = const AuthUnauthenticated();
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

    _hydratingSessionUserId = sessionUserId;
    try {
      final profile = await _repository.restoreCurrentUser();
      if (profile == null) {
        FirebaseAnalyticsService.setUserId(null);
        state = const AuthUnauthenticated();
        return;
      }
      FirebaseAnalyticsService.setUserId(profile.id);
      final adminAccess = await _repository.resolveAdminAccess(profile.id);
      state = AuthAuthenticated(profile: profile, workspace: adminAccess);
    } catch (error) {
      if (current is AuthAuthenticated && current.profile.id == sessionUserId) {
        state = current;
      } else {
        state = AuthError('Session refresh failed', error);
      }
    } finally {
      if (_hydratingSessionUserId == sessionUserId) {
        _hydratingSessionUserId = null;
      }
    }
  }

  /// Sign in anonymously, injecting club_id into metadata.
  Future<void> signInAnonymously() async {
    state = const AuthLoading();

    try {
      final profile = await _repository.signInAnonymously();
      FirebaseAnalyticsService.setUserId(profile.id);
      final adminAccess = await _repository.resolveAdminAccess(profile.id);
      state = AuthAuthenticated(profile: profile, workspace: adminAccess);
    } catch (e) {
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
      FirebaseAnalyticsService.setUserId(profile.id);
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
      FirebaseAnalyticsService.setUserId(profile.id);
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
    } catch (_) {
      // Non-fatal — keep current access level.
    }
  }

  /// Sign out and clear session.
  Future<void> signOut() async {
    try {
      await _repository.signOut();
    } catch (_) {
      // Best-effort sign-out.
    }
    FirebaseAnalyticsService.setUserId(null);
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

    state = const AuthLoading();

    try {
      await _repository.deleteAccount(current.profile.id);
      FirebaseAnalyticsService.setUserId(null);
      state = const AuthUnauthenticated();
      return null;
    } catch (e) {
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
}
