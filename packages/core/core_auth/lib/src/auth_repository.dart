import 'package:core_network/core_network.dart';
import 'package:core_utils/core_utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'account_closure_store.dart';
import 'models/account_closure_receipt.dart';
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
    AccountClosureStore? closureStore,
    Future<dynamic> Function(String userId)? adminAssignmentsLoader,
    Map<String, dynamic> Function()? appMetadataLoader,
    SupabaseClient Function()? clientProvider,
    Future<void> Function({String? userId})? unregisterDevice,
  }) : _closureStore = closureStore ?? AccountClosureStore(),
       _clientProvider = clientProvider ?? (() => SupabaseClientFactory.client),
       _unregisterDevice =
           unregisterDevice ??
           (({String? userId}) =>
               PushNotificationService.unregisterCurrentDevice(userId: userId)),
       rbacResolver = RbacResolver(
         tag: _tag,
         adminAssignmentsLoader: adminAssignmentsLoader,
         appMetadataLoader: appMetadataLoader,
         clientProvider: clientProvider,
       );

  static const _tag = 'AuthRepository';

  final String clubId; // This must now be a numeric string matching DB `id`
  final SupabaseClient Function() _clientProvider;
  final Future<void> Function({String? userId}) _unregisterDevice;
  int _scopeGeneration = 0;
  final Set<GoTrueSessionMutationScope> _ownedMutations = {};

  /// Exposed for direct RBAC resolution without going through AuthRepository.
  final RbacResolver rbacResolver;

  SupabaseClient get _client => _clientProvider();

  /// Invalidate replies owned by a disposed or replaced app/account scope.
  /// This is a synchronous local fence, not a server session revocation.
  void invalidatePendingAuthentication() {
    _scopeGeneration++;
    for (final operation in _ownedMutations) {
      operation.invalidate();
    }
  }

  SupabaseSessionAuthority _captureAuthority() {
    final generation = _scopeGeneration;
    return SupabaseSessionAuthority.capture(
      clientProvider: _clientProvider,
      isOwnerCurrent: () => generation == _scopeGeneration,
    );
  }

  Future<(SupabaseClient, int, T)> _runSessionMutation<T>(
    Future<T> Function(SupabaseClient client) operation, {
    required String description,
  }) async {
    invalidatePendingAuthentication();
    final generation = _scopeGeneration;
    final client = _client;
    final owner = client.auth.createSessionMutationScope();
    _ownedMutations.add(owner);
    try {
      final response = await _runOperation<T>(
        () => owner.run(() => operation(client)),
        description: description,
      );
      if (generation != _scopeGeneration) {
        throw const SupabaseSessionChangedException();
      }
      return (client, generation, response);
    } finally {
      _ownedMutations.remove(owner);
    }
  }

  // ─── Authentication ─────────────────────────────────────────

  /// Sign in anonymously, then bind the supporter to the configured club
  /// through the governed bootstrap RPC. User metadata is never tenant
  /// authority.
  Future<UserProfile> signInAnonymously() async {
    final (
      client,
      generation,
      response,
    ) = await _runSessionMutation<AuthResponse>(
      (client) => client.auth.signInAnonymously(),
      description: 'signInAnonymously',
    );

    final user = response.user;
    if (user == null) {
      throw Exception('Anonymous sign-in failed');
    }

    return _hydrateAuthenticatedUser(client, generation, user);
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
    // Supabase uses its phone-verification type for WhatsApp delivery too.
    final (
      client,
      generation,
      response,
    ) = await _runSessionMutation<AuthResponse>(
      (client) =>
          client.auth.verifyOTP(phone: phone, token: token, type: OtpType.sms),
      description: 'verifyPhoneSignInOtp',
    );

    final user = response.user ?? client.auth.currentUser;
    if (user == null) {
      throw Exception('Phone verification did not produce an active session.');
    }

    return _hydrateAuthenticatedUser(client, generation, user);
  }

  /// Start a phone change / verification flow for the current authenticated user.
  Future<void> requestPhoneVerificationOtp({required String phone}) async {
    await _runSessionMutation<UserResponse>(
      (client) => client.auth.updateUser(UserAttributes(phone: phone)),
      description: 'requestPhoneVerificationOtp',
    );
  }

  /// Confirm the OTP for a pending authenticated phone change.
  Future<UserProfile> verifyPhoneVerificationOtp({
    required String phone,
    required String token,
  }) async {
    final (
      client,
      generation,
      response,
    ) = await _runSessionMutation<AuthResponse>(
      (client) => client.auth.verifyOTP(
        phone: phone,
        token: token,
        type: OtpType.phoneChange,
      ),
      description: 'verifyPhoneVerificationOtp',
    );

    final user = response.user ?? client.auth.currentUser;
    if (user == null) {
      throw Exception('Phone verification could not be confirmed.');
    }

    return _hydrateAuthenticatedUser(client, generation, user);
  }

  // ─── Session Restore ────────────────────────────────────────

  /// Restore the current user profile strictly from Supabase.
  /// Silent upserts are avoided to prevent overwriting server data.
  Future<UserProfile?> restoreCurrentUser() async {
    final authority = _captureAuthority();
    final user = authority.session?.user;
    try {
      if (user == null) return null;
      final profile = await _loadProfile(user.id, authority: authority);
      if (profile == null) {
        await _ensureProfileRow(user, authority: authority);
        return await _loadProfile(user.id, authority: authority);
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
    } finally {
      await authority.dispose();
    }
  }

  // ─── Profile CRUD ───────────────────────────────────────────

  /// Update the user profile in Supabase.
  Future<UserProfile> updateProfile(UserProfile profile) async {
    final authority = _captureAuthority();
    try {
      if (authority.session?.user.id != profile.id ||
          int.tryParse(clubId) == null ||
          int.tryParse(profile.clubId) != int.tryParse(clubId)) {
        throw StateError(
          'Profile update requires the current account and club.',
        );
      }
      final expectedUpdatedAt = profile.updatedAt;
      if (expectedUpdatedAt == null) {
        await _bootstrapProfile(profile, authority: authority);
      } else {
        final updateResult = await SafeRpc.query<dynamic>(
          () {
            authority.requireCurrent();
            return authority.client
                .from('profiles')
                .update(_editableProfileRow(profile))
                .eq('id', profile.id)
                .eq('updated_at', expectedUpdatedAt)
                .select('id')
                .maybeSingle()
                .retry(enabled: false)
                .setHeader('Authorization', _requestBearer(authority));
          },
          tag: _tag,
          description: 'updateProfile.compareAndSetProfile',
          maxAttempts: 1,
        );
        authority.requireCurrent();
        if (!updateResult.isSuccess) {
          throw StateError(
            updateResult.error ?? 'Profile update could not be completed.',
          );
        }
        if (updateResult.data == null) {
          AfriLogger.warn(
            _tag,
            'Profile update rejected because the server row changed.',
          );
          throw const ProfileConflictException();
        }
      }
      final refreshed = await _loadProfile(profile.id, authority: authority);
      if (refreshed == null) {
        throw StateError(
          'Profile update failed: Server returned null profile.',
        );
      }
      return refreshed;
    } finally {
      await authority.dispose();
    }
  }

  final AccountClosureStore _closureStore;
  AccountClosureReceipt? _latestAccountClosureReceipt;
  AccountClosureReceipt? get latestAccountClosureReceipt =>
      _latestAccountClosureReceipt;

  /// Request accountable closure while preserving the financial subject.
  /// The pending receipt is distinct from completion of personal data removal.
  Future<void> deleteAccount(String userId) async {
    if (_client.auth.currentSession?.user.id != userId) {
      throw StateError('Account deletion requires the current account.');
    }
    _latestAccountClosureReceipt = null;
    invalidatePendingAuthentication();
    final authority = _captureAuthority();
    try {
      if (authority.session?.user.id != userId) {
        throw StateError('Account deletion requires the current account.');
      }
      authority.client.auth.invalidatePendingSessionMutations();
      final prepared = await _closureStore.prepare();
      authority.requireCurrent();
      _latestAccountClosureReceipt = prepared;
      await _unregisterDevice(userId: userId);
      authority.requireCurrent();

      // FunctionsClient awaits JSON encoding and AuthHttpClient awaits token
      // resolution. An explicit bearer keeps that request bound to the checked
      // session even if a new login occurs during either SDK await.
      final accessToken = authority.client.auth.currentSession!.accessToken;
      final response = await _runOperation<FunctionResponse>(() {
        authority.requireCurrent();
        return authority.client.functions.invoke(
          'delete-account',
          headers: <String, String>{'Authorization': 'Bearer $accessToken'},
          body: <String, dynamic>{
            'user_id': userId,
            'request_id': prepared.requestId,
          },
        );
      }, description: 'deleteAccount');

      final data = response.data;
      if (response.status == 202 &&
          data is Map<String, dynamic> &&
          data['success'] == true) {
        final receipt = data['data'];
        if (receipt is Map<String, dynamic> &&
            receipt['request_id'] is String &&
            AccountClosureStore.capabilityPattern.hasMatch(
              receipt['request_id'] as String,
            ) &&
            receipt['access_revoked'] == true &&
            const {
              'deletion_pending',
              'failed',
              'completed',
            }.contains(receipt['status'])) {
          authority.requireCurrent();
          _latestAccountClosureReceipt = AccountClosureReceipt(
            requestId: receipt['request_id'] as String,
            status: receipt['status'] as String,
          );
          await _closureStore.save(_latestAccountClosureReceipt!);
          authority.requireCurrent();
          return;
        }
      }

      final message = switch (data) {
        {'error': final Object error} => error.toString(),
        {'message': final Object message} => message.toString(),
        _ => 'Account deletion failed on the backend.',
      };
      throw StateError(message);
    } on SupabaseSessionChangedException catch (error) {
      throw StateError(error.toString());
    } finally {
      await authority.dispose();
    }
  }

  Future<AccountClosureReceipt?> loadAccountClosureReceipt() =>
      _closureStore.read();
  Future<void> forgetAccountClosureReceipt() => _closureStore.forget();
  Future<AccountClosureReceipt> refreshAccountClosureStatus(
    AccountClosureReceipt receipt,
  ) async {
    final response = await _client.functions.invoke(
      'delete-account?action=status',
      body: <String, dynamic>{'request_id': receipt.requestId},
    );
    final body = response.data;
    if (response.status != 200 ||
        body is! Map<String, dynamic> ||
        body['success'] != true ||
        body['data'] is! Map<String, dynamic>) {
      throw StateError('Account closure status unavailable.');
    }
    final data = body['data'] as Map<String, dynamic>;
    if (data['request_id'] != receipt.requestId ||
        data['access_revoked'] != true ||
        !const {
          'deletion_pending',
          'failed',
          'completed',
        }.contains(data['status'])) {
      throw StateError('Account closure status invalid.');
    }
    final updated = AccountClosureReceipt(
      requestId: receipt.requestId,
      status: data['status'] as String,
    );
    await _closureStore.save(updated);
    return updated;
  }

  /// Clear only the captured closed account. A replacement session stays intact.
  Future<void> signOutClosedAccount(String userId) async {
    final authority = _captureAuthority();
    try {
      authority.requireCurrent();
      if (authority.session?.user.id != userId) {
        throw StateError('Account closure session changed.');
      }
      await authority.client.auth.signOut(scope: SignOutScope.local);
    } finally {
      await authority.dispose();
    }
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
    invalidatePendingAuthentication();
    final authority = _captureAuthority();
    try {
      authority.client.auth.invalidatePendingSessionMutations();
      final userId = authority.session?.user.id;
      if (userId != null) await _unregisterDevice(userId: userId);
      authority.requireCurrent();
      // GoTrue captures the bearer and clears its local session synchronously
      // before its first await. Never retry this destructive SDK operation.
      await _runAction(() {
        authority.requireCurrent();
        return authority.client.auth.signOut();
      }, description: 'signOut');
    } on SupabaseSessionChangedException catch (error) {
      throw StateError(error.toString());
    } finally {
      await authority.dispose();
    }
  }

  /// Sign out all other active sessions for the current user.
  Future<void> signOutOtherSessions() async {
    final authority = _captureAuthority();
    try {
      await _runAction(() {
        authority.requireCurrent();
        return authority.client.auth.signOut(scope: SignOutScope.others);
      }, description: 'signOutOtherSessions');
    } finally {
      await authority.dispose();
    }
  }

  /// Listen to auth state changes.
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  // ─── Helpers ────────────────────────────────────────────────

  Future<UserProfile> _hydrateAuthenticatedUser(
    SupabaseClient client,
    int generation,
    User user,
  ) async {
    if (generation != _scopeGeneration || !identical(client, _client)) {
      throw const SupabaseSessionChangedException();
    }
    final authority = _captureAuthority();
    try {
      if (authority.session?.user.id != user.id) {
        throw const SupabaseSessionChangedException();
      }
      await _ensureProfileRow(user, authority: authority);
      final profile = await _loadProfile(user.id, authority: authority);
      if (profile == null) {
        throw StateError('Server did not return a profile following sign in.');
      }
      return profile;
    } finally {
      await authority.dispose();
    }
  }

  String _requestBearer(SupabaseSessionAuthority authority) {
    authority.requireCurrent();
    final session = authority.client.auth.currentSession;
    if (session == null) throw const SupabaseSessionChangedException();
    return 'Bearer ${session.accessToken}';
  }

  Future<void> _ensureProfileRow(
    User user, {
    required SupabaseSessionAuthority authority,
  }) async {
    final seededProfile = _buildSeededProfile(user);

    // Profile bootstrap is critical and server-authoritative for club scope.
    await _bootstrapProfile(seededProfile, authority: authority);

    // Private contact is best-effort — table may not exist yet.
    try {
      await _upsertPrivateContact(seededProfile, authority: authority);
    } on SupabaseSessionChangedException {
      rethrow;
    } catch (error) {
      AfriLogger.warn(
        'AuthRepository',
        'Private contact upsert skipped: $error',
      );
    }
  }

  Future<UserProfile?> _loadProfile(
    String userId, {
    required SupabaseSessionAuthority authority,
  }) async {
    // Parallelize the two independent queries to halve latency.
    final results = await Future.wait(<Future<RpcResult<dynamic>>>[
      SafeRpc.query<dynamic>(
        () {
          authority.requireCurrent();
          return authority.client
              .from('profiles')
              .select(
                'id, club_id, full_name, public_user_id, country, '
                'language_code, avatar_url, is_admin, theme_preference, '
                'created_at, updated_at, display_name, country_code, is_active, '
                'favorite_team_slug, privacy_show_real_name, '
                'privacy_findable_by_phone',
              )
              .eq('id', userId)
              .maybeSingle()
              .retry(enabled: false)
              .setHeader('Authorization', _requestBearer(authority));
        },
        tag: _tag,
        description: '_loadProfile.profile',
        maxAttempts: 3,
      ),
      SafeRpc.query<dynamic>(
        () {
          authority.requireCurrent();
          return authority.client
              .from('user_private_contacts')
              .select()
              .eq('user_id', userId)
              .maybeSingle()
              .retry(enabled: false)
              .setHeader('Authorization', _requestBearer(authority));
        },
        tag: _tag,
        description: '_loadProfile.privateContact',
        maxAttempts: 2,
      ),
    ]);

    authority.requireCurrent();
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

    final profile = UserProfile.fromJson(<String, dynamic>{
      ...Map<String, dynamic>.from(row),
      if (privateContact != null) ...<String, dynamic>{
        'momo_number': privateContact['momo_number'],
        'momo_provider': privateContact['momo_provider'],
        'country_code': privateContact['country_code'] ?? row['country_code'],
      },
    });
    if (profile.id != userId ||
        int.tryParse(clubId) == null ||
        int.tryParse(profile.clubId) != int.tryParse(clubId)) {
      throw StateError(
        'Restored profile does not belong to this account and club.',
      );
    }
    return profile;
  }

  Future<void> _upsertPrivateContact(
    UserProfile profile, {
    required SupabaseSessionAuthority authority,
  }) async {
    await _runAction(
      () => authority.client
          .from('user_private_contacts')
          .upsert(
            profile.toPrivateContactRow(includeId: true),
            onConflict: 'user_id',
          )
          .retry(enabled: false)
          .setHeader('Authorization', _requestBearer(authority)),
      description: '_upsertPrivateContact',
      authority: authority,
    );
  }

  Future<void> _bootstrapProfile(
    UserProfile profile, {
    required SupabaseSessionAuthority authority,
  }) async {
    final normalizedClubId = int.tryParse(clubId);
    if (normalizedClubId == null) {
      throw StateError('Configured club id must be numeric.');
    }

    await _runOperation<dynamic>(
      () => authority.client
          .rpc(
            'bootstrap_supporter_profile',
            params: <String, dynamic>{
              'p_club_id': normalizedClubId,
              'p_display_name': _asOptionalString(profile.displayName),
              'p_country_code':
                  _asOptionalString(profile.countryCode)?.toUpperCase() ?? 'RW',
              'p_language_code': 'en',
              'p_avatar_url': _asOptionalString(profile.avatarUrl),
            },
          )
          .retry(enabled: false)
          .setHeader('Authorization', _requestBearer(authority)),
      description: 'bootstrap_supporter_profile',
      authority: authority,
    );
  }

  Map<String, dynamic> _editableProfileRow(UserProfile profile) =>
      <String, dynamic>{
        'display_name': _asOptionalString(profile.displayName),
        'full_name': _asOptionalString(profile.displayName),
        'country_code': _asOptionalString(profile.countryCode)?.toUpperCase(),
        'country': _asOptionalString(profile.countryCode)?.toUpperCase(),
        'language_code': 'en',
        'avatar_url': _asOptionalString(profile.avatarUrl),
        'favorite_team_slug': _asOptionalString(profile.favoriteTeamSlug),
      };

  UserProfile _buildSeededProfile(User user) {
    final metadata = user.userMetadata ?? <String, dynamic>{};
    return UserProfile(
      id: user.id,
      clubId: clubId,
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
      languageCode: 'en',
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
    SupabaseSessionAuthority? authority,
  }) async {
    final result = await SafeRpc.query<T>(
      () {
        authority?.requireCurrent();
        return operation();
      },
      tag: _tag,
      description: description,
      maxAttempts: maxAttempts,
    );
    authority?.requireCurrent();
    if (result.isSuccess) {
      return result.requireData;
    }
    throw StateError(result.error ?? '$description failed.');
  }

  Future<void> _runAction(
    Future<void> Function() operation, {
    required String description,
    int maxAttempts = 1,
    SupabaseSessionAuthority? authority,
  }) async {
    final result = await SafeRpc.query<bool>(
      () async {
        authority?.requireCurrent();
        await operation();
        return true;
      },
      tag: _tag,
      description: description,
      maxAttempts: maxAttempts,
    );
    authority?.requireCurrent();
    if (!result.isSuccess) {
      throw StateError(result.error ?? '$description failed.');
    }
  }
}
