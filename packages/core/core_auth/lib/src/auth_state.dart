import 'models/admin_workspace_access.dart';
import 'models/user_profile.dart';

/// Auth state machine: initial → loading → authenticated / unauthenticated / error.
///
/// Ported from cool's `AuthState` — uses sealed class for exhaustive matching
/// instead of runtime type checks.
sealed class AuthState {
  const AuthState();

  /// The current user profile, if authenticated.
  UserProfile? get user => null;

  /// Admin workspace access for the current user.
  AdminWorkspaceAccess get adminAccess => AdminWorkspaceAccess.none;

  /// Whether the user has an active session.
  bool get isAuthenticated => false;

  /// Whether auth is in a loading/transitional state.
  bool get isLoading => false;
}

/// Initial state — no auth activity yet.
class AuthInitial extends AuthState {
  const AuthInitial();
}

/// Auth operation in progress (sign-in, profile load, etc.).
class AuthLoading extends AuthState {
  const AuthLoading();

  @override
  bool get isLoading => true;
}

/// Authenticated with a valid user profile.
class AuthAuthenticated extends AuthState {
  const AuthAuthenticated({
    required this.profile,
    this.workspace = AdminWorkspaceAccess.none,
  });

  final UserProfile profile;
  final AdminWorkspaceAccess workspace;

  @override
  UserProfile get user => profile;

  @override
  AdminWorkspaceAccess get adminAccess => workspace;

  @override
  bool get isAuthenticated => true;
}

/// Not authenticated — no session or session expired.
class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

/// Auth error — sign-in or profile load failed.
class AuthError extends AuthState {
  const AuthError(this.message, [this.error]);

  final String message;
  final Object? error;
}
