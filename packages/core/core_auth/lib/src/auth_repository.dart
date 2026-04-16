import 'package:core_network/core_network.dart';
import 'package:core_utils/core_utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/admin_workspace_access.dart';
import 'models/user_profile.dart';

class AuthRestoreFailure implements Exception {
  const AuthRestoreFailure(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

/// Handles Supabase authentication with numeric club_id injection and profile CRUD.
///
/// Supports anonymous sign-in, profile restoration, update, and RBAC resolution.
class AuthRepository {
  AuthRepository({
    required this.clubId,
    Future<dynamic> Function(String userId)? adminAssignmentsLoader,
    Map<String, dynamic> Function()? appMetadataLoader,
  }) : _adminAssignmentsLoader = adminAssignmentsLoader,
       _appMetadataLoader = appMetadataLoader;

  static const _tag = 'AuthRepository';

  final String clubId; // This must now be a numeric string matching DB `id`
  final Future<dynamic> Function(String userId)? _adminAssignmentsLoader;
  final Map<String, dynamic> Function()? _appMetadataLoader;

  SupabaseClient get _client => SupabaseClientFactory.client;

  // ─── Authentication ─────────────────────────────────────────

  /// Sign in anonymously, injecting club_id into metadata.
  /// Creates a profile row in the `profiles` table automatically.
  Future<UserProfile> signInAnonymously() async {
    final response = await _runOperation<AuthResponse>(
      () => _client.auth.signInAnonymously(data: {'club_id': clubId}),
      description: 'signInAnonymously',
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

  /// Send a one-time code for a supporter phone sign-in flow.
  Future<void> requestPhoneSignInOtp({
    required String phone,
    OtpChannel channel = OtpChannel.whatsapp,
    bool shouldCreateUser = true,
  }) async {
    await _runAction(
      () => _client.auth.signInWithOtp(
        phone: phone,
        shouldCreateUser: shouldCreateUser,
        data: {'club_id': clubId},
        channel: channel,
      ),
      description: 'requestPhoneSignInOtp',
    );
  }

  /// Verify a supporter phone sign-in code and hydrate the profile row.
  Future<UserProfile> verifyPhoneSignInOtp({
    required String phone,
    required String token,
  }) async {
    final response = await _runOperation<AuthResponse>(
      () =>
          _client.auth.verifyOTP(phone: phone, token: token, type: OtpType.sms),
      description: 'verifyPhoneSignInOtp',
    );

    final user = response.user ?? _client.auth.currentUser;
    if (user == null) {
      throw Exception('Phone verification did not produce an active session.');
    }

    await _ensureProfileRow(user);

    final profile = await _loadProfile(user.id);
    if (profile == null) {
      throw Exception(
        'Server did not return a profile row following OTP verification.',
      );
    }

    return profile;
  }

  /// Start a phone change / verification flow for the current authenticated user.
  Future<void> requestPhoneVerificationOtp({required String phone}) async {
    await _runAction(
      () => _client.auth.updateUser(UserAttributes(phone: phone)),
      description: 'requestPhoneVerificationOtp',
    );
  }

  /// Confirm the OTP for a pending authenticated phone change.
  Future<UserProfile> verifyPhoneVerificationOtp({
    required String phone,
    required String token,
  }) async {
    final response = await _runOperation<AuthResponse>(
      () => _client.auth.verifyOTP(
        phone: phone,
        token: token,
        type: OtpType.phoneChange,
      ),
      description: 'verifyPhoneVerificationOtp',
    );

    final user = response.user ?? _client.auth.currentUser;
    if (user == null) {
      throw Exception('Phone verification could not be confirmed.');
    }

    await _ensureProfileRow(user);

    final profile = await _loadProfile(user.id);
    if (profile == null) {
      throw Exception('Server did not return the verified profile.');
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
    } catch (error, stackTrace) {
      AfriLogger.error(
        'AuthRepository',
        'Session restore failed and local recovery was blocked.',
        error,
        stackTrace,
      );
      throw AuthRestoreFailure(
        'Existing session could not be restored safely.',
        error,
      );
    }
  }

  // ─── Profile CRUD ───────────────────────────────────────────

  /// Update the user profile in Supabase.
  Future<UserProfile> updateProfile(UserProfile profile) async {
    await _runAction(
      () => _client
          .from('profiles')
          .upsert(profile.toProfileRow(includeId: true), onConflict: 'id'),
      description: 'updateProfile.upsertProfile',
    );
    await _upsertPrivateContact(profile);

    final refreshed = await _loadProfile(profile.id);
    if (refreshed == null) {
      throw StateError('Profile update failed: Server returned null profile.');
    }

    return refreshed;
  }

  /// Delete the user account and cascade delete via edge function.
  Future<void> deleteAccount(String userId) async {
    await PushNotificationService.unregisterCurrentDevice(userId: userId);

    final response = await _runOperation<FunctionResponse>(
      () => _client.functions.invoke(
        'delete-account',
        body: <String, dynamic>{'user_id': userId},
      ),
      description: 'deleteAccount',
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
      final rowsResult = await SafeRpc.query<dynamic>(
        () => _loadAdminAssignments(userId),
        tag: _tag,
        description: 'resolveAdminAccess',
        maxAttempts: 3,
      );
      if (!rowsResult.isSuccess) {
        AfriLogger.warn(
          _tag,
          'Admin access resolution failed: ${rowsResult.error}',
        );
        return AdminWorkspaceAccess.none;
      }
      return _resolveAdminAccessFromRows(rowsResult.requireData);
    } catch (error, stackTrace) {
      // Non-network error: log and return no access.
      AfriLogger.error(
        _tag,
        'Admin access resolution failed.',
        error,
        stackTrace,
      );
      return AdminWorkspaceAccess.none;
    }
  }

  // ─── Session ────────────────────────────────────────────────

  /// Sign out locally.
  Future<void> signOut() async {
    await PushNotificationService.unregisterCurrentDevice();
    await _runAction(() => _client.auth.signOut(), description: 'signOut');
  }

  /// Sign out all other active sessions for the current user.
  Future<void> signOutOtherSessions() async {
    await _runAction(
      () => _client.auth.signOut(scope: SignOutScope.others),
      description: 'signOutOtherSessions',
    );
  }

  /// Listen to auth state changes.
  Stream<AuthState> get authStateChanges =>
      SupabaseClientFactory.authStateChanges;

  // ─── Helpers ────────────────────────────────────────────────

  Future<dynamic> _loadAdminAssignments(String userId) {
    final injectedLoader = _adminAssignmentsLoader;
    if (injectedLoader != null) {
      return injectedLoader(userId);
    }

    return _client
        .from('admin_role_assignments')
        .select(
          'id, user_id, role, club_id, assigned_by, created_at, is_active',
        )
        .eq('user_id', userId)
        .eq('is_active', true);
  }

  AdminWorkspaceAccess _resolveAdminAccessFromRows(dynamic rows) {
    final assignments = <Map<String, dynamic>>[];
    if (rows is List) {
      for (final raw in rows) {
        final row = raw is Map<String, dynamic>
            ? raw
            : raw is Map
            ? Map<String, dynamic>.from(raw)
            : null;
        if (row == null) {
          continue;
        }

        final role = AdminRole.fromString(row['role']?.toString());
        assignments.add(<String, dynamic>{
          'id': row['id'],
          'user_id': row['user_id'],
          'role': switch (role) {
            AdminRole.admin => 'admin',
            AdminRole.bank => 'bank',
            AdminRole.partner || null => 'partner',
          },
          'club_id': row['club_id'],
          'partner_scope_id': row['club_id']?.toString(),
          'granted_by': row['assigned_by'],
          'created_at': row['created_at'],
          'is_active': row['is_active'],
        });
      }
    }

    if (assignments.isEmpty) {
      final metadata = _appMetadataLoader?.call() ?? _client.auth.currentUser?.appMetadata ?? const <String, dynamic>{};
      return AdminWorkspaceAccess.fromAppMetadata(metadata);
    }

    final partnerIds = assignments
        .where((assignment) => assignment['role'] == 'partner')
        .map((assignment) => assignment['partner_scope_id']?.toString() ?? '')
        .where((value) => value.isNotEmpty)
        .toSet();
    final bankIds = assignments
        .where((assignment) => assignment['role'] == 'bank')
        .map((assignment) => assignment['partner_scope_id']?.toString() ?? '')
        .where((value) => value.isNotEmpty)
        .toSet();

    return AdminWorkspaceAccess.fromRpcResponse(<String, dynamic>{
      'has_platform_access': assignments.any(
        (assignment) => assignment['role'] == 'admin',
      ),
      'has_bank_access': bankIds.isNotEmpty,
      'has_partner_access': false,
      'bank_partner_ids': bankIds.toList(growable: false),
      'partner_admin_ids': partnerIds.toList(growable: false),
      'role_assignments': assignments,
    });
  }

  Future<void> _ensureProfileRow(User user) async {
    final seededProfile = _buildSeededProfile(user);

    // Profile row is critical — must succeed for sign-in.
    await _runAction(
      () => _client
          .from('profiles')
          .upsert(
            seededProfile.toProfileRow(includeId: true),
            onConflict: 'id',
          ),
      description: '_ensureProfileRow.upsertProfile',
    );

    // Private contact is best-effort — table may not exist yet.
    try {
      await _upsertPrivateContact(seededProfile);
    } catch (error) {
      AfriLogger.warn(
        'AuthRepository',
        'Private contact upsert skipped: $error',
      );
    }
  }

  Future<UserProfile?> _loadProfile(String userId) async {
    final rowResult = await SafeRpc.query<dynamic>(
      () => _client.from('profiles').select().eq('id', userId).maybeSingle(),
      tag: _tag,
      description: '_loadProfile.profile',
      maxAttempts: 3,
    );
    if (!rowResult.isSuccess) {
      throw StateError(rowResult.error ?? 'Could not load the user profile.');
    }
    final row = rowResult.data;
    if (row == null) return null;

    Map<String, dynamic>? privateContact;
    try {
      final privateContactResult = await SafeRpc.query<dynamic>(
        () => _client
            .from('user_private_contacts')
            .select()
            .eq('user_id', userId)
            .maybeSingle(),
        tag: _tag,
        description: '_loadProfile.privateContact',
        maxAttempts: 2,
      );
      if (privateContactResult.isSuccess) {
        privateContact = privateContactResult.data == null
            ? null
            : Map<String, dynamic>.from(privateContactResult.data as Map);
      }
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
    await _runAction(
      () => _client
          .from('user_private_contacts')
          .upsert(
            profile.toPrivateContactRow(includeId: true),
            onConflict: 'user_id',
          ),
      description: '_upsertPrivateContact',
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

  Future<T> _runOperation<T>(
    Future<T> Function() operation, {
    required String description,
    int maxAttempts = 1,
  }) async {
    final result = await SafeRpc.query<T>(
      operation,
      tag: _tag,
      description: description,
      maxAttempts: maxAttempts,
    );
    if (result.isSuccess) {
      return result.requireData;
    }
    throw StateError(result.error ?? '$description failed.');
  }

  Future<void> _runAction(
    Future<void> Function() operation, {
    required String description,
    int maxAttempts = 1,
  }) async {
    final result = await SafeRpc.query<bool>(
      () async {
        await operation();
        return true;
      },
      tag: _tag,
      description: description,
      maxAttempts: maxAttempts,
    );
    if (!result.isSuccess) {
      throw StateError(result.error ?? '$description failed.');
    }
  }
}
