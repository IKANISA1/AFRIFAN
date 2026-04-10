import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_repository.dart';
import 'auth_state.dart';
import 'models/user_profile.dart';

/// Core auth state notifier — manages the auth lifecycle.
///
/// State machine:
///   AuthInitial → AuthLoading → AuthAuthenticated / AuthUnauthenticated / AuthError
///
/// Ported from cool's `AuthNotifier` and adapted for multi-tenant use.
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier({required AuthRepository repository})
    : _repository = repository,
      super(const AuthInitial());

  final AuthRepository _repository;

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
        final adminAccess = await _repository.resolveAdminAccess(profile.id);
        state = AuthAuthenticated(profile: profile, workspace: adminAccess);
      } else {
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

  /// Sign in anonymously, injecting club_id into metadata.
  Future<void> signInAnonymously() async {
    state = const AuthLoading();

    try {
      final profile = await _repository.signInAnonymously();
      final adminAccess = await _repository.resolveAdminAccess(profile.id);
      state = AuthAuthenticated(profile: profile, workspace: adminAccess);
    } catch (e) {
      state = AuthError('Sign-in failed', e);
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
}
