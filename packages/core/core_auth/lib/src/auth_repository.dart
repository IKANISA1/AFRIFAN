import 'package:core_network/core_network.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/admin_workspace_access.dart';
import 'models/user_profile.dart';

/// Handles Supabase authentication with numeric club_id injection and profile CRUD.
///
/// Supports anonymous sign-in, profile restoration, update, and RBAC resolution.
class AuthRepository {
  AuthRepository({required this.clubId});

  final String clubId; // This must now be a numeric string matching DB `id`

  SupabaseClient get _client => SupabaseClientFactory.client;

  // ─── Authentication ─────────────────────────────────────────

  /// Sign in anonymously, injecting club_id into metadata.
  /// Creates a profile row in the `profiles` table automatically.
  Future<UserProfile> signInAnonymously() async {
    final response = await _client.auth.signInAnonymously(
      data: {'club_id': clubId},
    );

    final user = response.user;
    if (user == null) {
      throw Exception('Anonymous sign-in failed');
    }

    await _ensureProfileRow(user);

    final profile = await _loadProfile(user.id);
    if (profile == null) {
      throw Exception('Server did not return a profile row following sign in.');
    }

    return profile;
  }

  // ─── Session Restore ────────────────────────────────────────

  /// Restore the current user profile strictly from Supabase.
  /// No silent upserts to prevent overwriting server data.
  Future<UserProfile?> restoreCurrentUser() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    try {
      final profile = await _loadProfile(user.id);
      if (profile == null) {
        // If the profile row is legitimately missing but session exists, try to recover it
        await _ensureProfileRow(user);
        return _loadProfile(user.id);
      }
      return profile;
    } catch (error) {
      debugPrint(
        '[AuthRepository] Session restore failed, using local session fallback: $error',
      );
      return _buildSeededProfile(user);
    }
  }

  /// Build the safest local fallback profile for an existing session.
  ///
  /// This preserves the existing authenticated identity when network/profile
  /// hydration fails during an app upgrade or transient backend outage.
  Future<UserProfile?> restoreSessionFallbackProfile() async {
    final sessionUser = _client.auth.currentUser;
    if (sessionUser == null) return null;
    return _buildSeededProfile(sessionUser);
  }

  // ─── Profile CRUD ───────────────────────────────────────────

  /// Update the user profile in Supabase.
  Future<UserProfile> updateProfile(UserProfile profile) async {
    await _client
        .from('profiles')
        .upsert(profile.toProfileRow(includeId: true), onConflict: 'id');
    await _upsertPrivateContact(profile);

    final refreshed = await _loadProfile(profile.id);
    if (refreshed == null) {
      throw StateError('Profile update failed: Server returned null profile.');
    }

    return refreshed;
  }

  /// Delete the user account and cascade delete via edge function.
  Future<void> deleteAccount(String userId) async {
    final response = await _client.functions.invoke(
      'delete-account',
      body: <String, dynamic>{'user_id': userId},
    );

    final data = response.data;
    if (data is Map<String, dynamic> && data['success'] == true) {
      return;
    }

    final message = switch (data) {
      {'error': final Object error} => error.toString(),
      {'message': final Object message} => message.toString(),
      _ => 'Account deletion failed on the backend.',
    };
    throw StateError(message);
  }

  // ─── RBAC ───────────────────────────────────────────────────

  /// Resolve admin workspace access for a user.
  Future<AdminWorkspaceAccess> resolveAdminAccess(String userId) async {
    try {
      final rows = await _client
          .from('admin_role_assignments')
          .select(
            'id, user_id, role, club_id, assigned_by, created_at, is_active',
          )
          .eq('user_id', userId)
          .eq('is_active', true);

      final assignments = rows
          .whereType<Map<String, dynamic>>()
          .map((row) {
            final role = row['role']?.toString().toLowerCase();
            return <String, dynamic>{
              'id': row['id'],
              'user_id': row['user_id'],
              'role': role == 'super_admin' ? 'admin' : 'partner',
              'club_id': row['club_id'],
              'partner_scope_id': row['club_id']?.toString(),
              'granted_by': row['assigned_by'],
              'created_at': row['created_at'],
              'is_active': row['is_active'],
            };
          })
          .toList(growable: false);

      if (assignments.isNotEmpty) {
        final partnerIds = assignments
            .where((assignment) => assignment['role'] == 'partner')
            .map(
              (assignment) => assignment['partner_scope_id']?.toString() ?? '',
            )
            .where((value) => value.isNotEmpty)
            .toSet();
        final hasPlatformAccess = assignments.any(
          (assignment) => assignment['role'] == 'admin',
        );
        return AdminWorkspaceAccess.fromRpcResponse(<String, dynamic>{
          'has_platform_access': hasPlatformAccess,
          'has_bank_access': false,
          'has_partner_access': false,
          'partner_admin_ids': partnerIds.toList(growable: false),
          'role_assignments': assignments,
        });
      }

      // Fallback: check app_metadata from JWT
      final metadata = _client.auth.currentUser?.appMetadata ?? {};
      return AdminWorkspaceAccess.fromAppMetadata(metadata);
    } catch (_) {
      // Non-fatal: return no access
      return AdminWorkspaceAccess.none;
    }
  }

  // ─── Session ────────────────────────────────────────────────

  /// Sign out locally.
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Sign out all other active sessions for the current user.
  Future<void> signOutOtherSessions() async {
    await _client.auth.signOut(scope: SignOutScope.others);
  }

  /// Listen to auth state changes.
  Stream<AuthState> get authStateChanges =>
      SupabaseClientFactory.authStateChanges;

  // ─── Helpers ────────────────────────────────────────────────

  Future<void> _ensureProfileRow(User user) async {
    final seededProfile = _buildSeededProfile(user);

    // Profile row is critical — must succeed for sign-in.
    await _client
        .from('profiles')
        .upsert(seededProfile.toProfileRow(includeId: true), onConflict: 'id');

    // Private contact is best-effort — table may not exist yet.
    try {
      await _upsertPrivateContact(seededProfile);
    } catch (error) {
      debugPrint('[AuthRepository] Private contact upsert skipped: $error');
    }
  }

  Future<UserProfile?> _loadProfile(String userId) async {
    final row = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (row == null) return null;

    Map<String, dynamic>? privateContact;
    try {
      privateContact = await _client
          .from('user_private_contacts')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
    } catch (_) {
      privateContact = null;
    }

    return UserProfile.fromJson(<String, dynamic>{
      ...Map<String, dynamic>.from(row),
      if (privateContact != null) ...<String, dynamic>{
        'momo_number': privateContact['momo_number'],
        'momo_provider': privateContact['momo_provider'],
        'country_code': privateContact['country_code'] ?? row['country_code'],
      },
    });
  }

  Future<void> _upsertPrivateContact(UserProfile profile) async {
    await _client
        .from('user_private_contacts')
        .upsert(
          profile.toPrivateContactRow(includeId: true),
          onConflict: 'user_id',
        );
  }

  UserProfile _buildSeededProfile(User user) {
    final metadata = user.userMetadata ?? <String, dynamic>{};
    return UserProfile(
      id: user.id,
      clubId: metadata['club_id']?.toString() ?? clubId,
      momoNumber:
          _asOptionalString(metadata['momo_number']) ??
          _asOptionalString(user.phone),
      displayName:
          _asOptionalString(metadata['display_name']) ??
          _asOptionalString(metadata['full_name']),
      publicUserId: _asOptionalString(metadata['public_user_id']),
      countryCode:
          _asOptionalString(metadata['country_code']) ??
          _asOptionalString(metadata['country']),
      languageCode: _asOptionalString(metadata['language_code']) ?? 'en',
      avatarUrl: _asOptionalString(metadata['avatar_url']),
      momoProvider: _asOptionalString(metadata['momo_provider']),
      isActive: true,
    );
  }

  String? _asOptionalString(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }
}
