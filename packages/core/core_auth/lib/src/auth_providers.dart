import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import 'auth_notifier.dart';
import 'auth_repository.dart';
import 'auth_state.dart';
import 'models/admin_workspace_access.dart';
import 'models/user_profile.dart';

/// Auth repository provider — requires clubId at app startup.
///
/// Override this in ProviderScope with the club's AuthRepository.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => throw UnimplementedError(
    'authRepositoryProvider must be overridden with a club-specific instance',
  ),
);

/// Core auth state — drives the entire app's auth flow.
final authStateProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});

/// Current authenticated user profile, or null.
final currentUserProvider = Provider<UserProfile?>((ref) {
  final auth = ref.watch(authStateProvider);
  final user = auth.user;
  if (user == null) return null;

  // Only create a new UserProfile when the isAdmin flag actually needs to change.
  // This prevents unnecessary downstream rebuilds from identity changes.
  final shouldBeAdmin = auth.adminAccess.hasAnyAdminAccess;
  if (user.isAdmin == shouldBeAdmin) {
    return user;
  }

  return user.copyWith(isAdmin: shouldBeAdmin);
});

/// Whether the user is currently authenticated.
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authStateProvider).isAuthenticated;
});

/// Admin workspace access for the current user.
final adminAccessProvider = Provider<AdminWorkspaceAccess>((ref) {
  return ref.watch(authStateProvider).adminAccess;
});

/// Whether the current user has any admin access.
final hasAdminAccessProvider = Provider<bool>((ref) {
  return ref.watch(adminAccessProvider).hasAnyAdminAccess;
});

/// Raw Supabase auth user for phone verification state and identity checks.
final authUserProvider = Provider<supabase.User?>((ref) {
  ref.watch(authStateProvider);
  return SupabaseClientFactory.client.auth.currentUser;
});

/// Whether the current session has a confirmed phone identity.
final isPhoneVerifiedProvider = Provider<bool>((ref) {
  final user = ref.watch(authUserProvider);
  return user?.phoneConfirmedAt?.trim().isNotEmpty ?? false;
});

/// Whether the current session is still anonymous.
final isAnonymousAuthProvider = Provider<bool>((ref) {
  final user = ref.watch(authUserProvider);
  return user?.isAnonymous ?? false;
});
