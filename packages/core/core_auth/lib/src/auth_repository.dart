import 'package:core_network/core_network.dart';
import 'package:core_utils/core_utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/admin_workspace_access.dart';
import 'models/user_profile.dart';
import 'rbac_resolver.dart';

class AuthRestoreFailure implements Exception {
  const AuthRestoreFailure(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

class ProfileConflictException implements Exception {
  const ProfileConflictException();

  @override
  String toString() =>
      'Profile changed on another device. Refresh the latest profile, review it, and save again.';
}

/// Handles Supabase authentication with numeric club_id injection and profile CRUD.
///
/// Supports anonymous sign-in, profile restoration, update, and RBAC resolution.
class AuthRepository {
  AuthRepository({
    required this.clubId,
    Future<dynamic> Function(String userId)? adminAssignmentsLoader,
    Map<String, dynamic> Function()? appMetadataLoader,
  }) : rbacResolver = RbacResolver(
         tag: _tag,
         adminAssignmentsLoader: adminAssignmentsLoader,
         appMetadataLoader: appMetadataLoader,
       );

  static const _tag = 'AuthRepository';

  final String clubId; // This must now be a numeric string matching DB `id`

  /// Exposed for direct RBAC resolution without going through AuthRepository.
  final RbacResolver rbacResolver;

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
  /// Silent upserts are avoided to prevent overwriting server data.
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
    final expectedUpdatedAt = profile.updatedAt;
    if (expectedUpdatedAt == null) {
      await _runAction(
        () => _client
            .from('profiles')
            .upsert(profile.toProfileRow(includeId: true), onConflict: 'id'),
        description: 'updateProfile.insertProfile',
      );
    } else {
      final updateResult = await SafeRpc.query<dynamic>(
        () => _client
            .from('profiles')
            .update(profile.toProfileRow(includeId: false))
            .eq('id', profile.id)
            .eq('updated_at', expectedUpdatedAt)
            .select('id')
            .maybeSingle(),
        tag: _tag,
        description: 'updateProfile.compareAndSetProfile',
        maxAttempts: 1,
      );
      if (!updateResult.isSuccess) {
        throw StateError(
          updateResult.error ?? 'Profile update could not be completed.',
        );
      }
      final updated = updateResult.data;
      if (updated == null) {
        AfriLogger.warn(
          _tag,
          'Profile update rejected because the server row changed.',
        );
        throw const ProfileConflictException();
      }
    }

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
  ///
  /// Delegates to [RbacResolver] for separation of concerns.
  Future<AdminWorkspaceAccess> resolveAdminAccess(String userId) =>
      rbacResolver.resolve(userId);

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
    // Parallelize the two independent queries to halve latency.
    final results = await Future.wait(<Future<RpcResult<dynamic>>>[
      SafeRpc.query<dynamic>(
        () => _client.from('profiles').select().eq('id', userId).maybeSingle(),
        tag: _tag,
        description: '_loadProfile.profile',
        maxAttempts: 3,
      ),
      SafeRpc.query<dynamic>(
        () => _client
            .from('user_private_contacts')
            .select()
            .eq('user_id', userId)
            .maybeSingle(),
        tag: _tag,
        description: '_loadProfile.privateContact',
        maxAttempts: 2,
      ),
    ]);

    final profileResult = results[0];
    final privateContactResult = results[1];

    if (!profileResult.isSuccess) {
      throw StateError(
        profileResult.error ?? 'Could not load the user profile.',
      );
    }
    final row = profileResult.data;
    if (row == null) return null;

    Map<String, dynamic>? privateContact;
    try {
      if (privateContactResult.isSuccess && privateContactResult.data != null) {
        privateContact = Map<String, dynamic>.from(
          privateContactResult.data as Map,
        );
      }
    } catch (e) {
      privateContact = null;
      AfriLogger.warn(
        'AuthRepository',
        'Private contact fetch failed (non-fatal): $e',
      );
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
