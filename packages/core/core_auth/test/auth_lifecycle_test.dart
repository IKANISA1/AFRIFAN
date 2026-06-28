import 'dart:async';

import 'package:core_auth/core_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

void main() {
  group('AuthNotifier — restore()', () {
    test('transitions Initial → Loading → Authenticated on success', () async {
      final container = _createContainer(restoreResult: _testUser('u1'));
      addTearDown(container.dispose);

      expect(container.read(authStateProvider), isA<AuthInitial>());

      final notifier = container.read(authStateProvider.notifier);
      final states = <AuthState>[];
      container.listen(authStateProvider, (_, next) => states.add(next));

      await notifier.restore();

      expect(states.first, isA<AuthLoading>());
      expect(states.last, isA<AuthAuthenticated>());
      expect((states.last as AuthAuthenticated).user.id, 'u1');
    });

    test('transitions to Unauthenticated when no session exists', () async {
      final container = _createContainer(restoreResult: null);
      addTearDown(container.dispose);

      final notifier = container.read(authStateProvider.notifier);
      await notifier.restore();

      expect(container.read(authStateProvider), isA<AuthUnauthenticated>());
    });

    test('transitions to RecoveryRequired on restore error', () async {
      final container = _createContainer(
        restoreError: Exception('DB connection lost'),
      );
      addTearDown(container.dispose);

      final notifier = container.read(authStateProvider.notifier);
      await notifier.restore();

      final state = container.read(authStateProvider);
      expect(state, isA<AuthRecoveryRequired>());
      expect(
        (state as AuthRecoveryRequired).message,
        contains('could not be restored'),
      );
    });
  });

  group('AuthNotifier — signOut()', () {
    test('clears session and returns to Unauthenticated', () async {
      final container = _createContainer(restoreResult: _testUser('u1'));
      addTearDown(container.dispose);

      final notifier = container.read(authStateProvider.notifier);
      await notifier.restore();
      expect(container.read(authStateProvider), isA<AuthAuthenticated>());

      await notifier.signOut();
      expect(container.read(authStateProvider), isA<AuthUnauthenticated>());
    });

    test('gracefully handles signOut errors', () async {
      final container = _createContainer(
        restoreResult: _testUser('u1'),
        signOutError: Exception('network error'),
      );
      addTearDown(container.dispose);

      final notifier = container.read(authStateProvider.notifier);
      await notifier.restore();

      // Should not throw.
      await notifier.signOut();
      expect(container.read(authStateProvider), isA<AuthUnauthenticated>());
    });
  });

  group('AuthNotifier — signInAnonymously()', () {
    test('sets Authenticated state on success', () async {
      final container = _createContainer(anonymousResult: _testUser('anon-1'));
      addTearDown(container.dispose);

      final notifier = container.read(authStateProvider.notifier);
      await notifier.signInAnonymously();

      final state = container.read(authStateProvider);
      expect(state, isA<AuthAuthenticated>());
      expect((state as AuthAuthenticated).user.id, 'anon-1');
    });

    test('sets AuthError on failure', () async {
      final container = _createContainer(
        anonymousError: Exception('quota exceeded'),
      );
      addTearDown(container.dispose);

      final notifier = container.read(authStateProvider.notifier);
      await notifier.signInAnonymously();

      expect(container.read(authStateProvider), isA<AuthError>());
    });

    test(
      'uses a local guest session when anonymous backend is unreachable',
      () async {
        final container = _createContainer(
          anonymousError: Exception(
            "AuthRetryableFetchException(message: ClientException with SocketException: Failed host lookup: 'example.supabase.co')",
          ),
        );
        addTearDown(container.dispose);

        final notifier = container.read(authStateProvider.notifier);
        await notifier.signInAnonymously();

        final state = container.read(authStateProvider);
        expect(state, isA<AuthAuthenticated>());
        final authenticated = state as AuthAuthenticated;
        expect(authenticated.user.id, isEmpty);
        expect(authenticated.user.clubId, '1');
        expect(authenticated.workspace, AdminWorkspaceAccess.none);
      },
    );
  });

  group('AuthNotifier — deleteAccount()', () {
    test('returns null and sets Unauthenticated on success', () async {
      final container = _createContainer(restoreResult: _testUser('u1'));
      addTearDown(container.dispose);

      final notifier = container.read(authStateProvider.notifier);
      await notifier.restore();

      final error = await notifier.deleteAccount();
      expect(error, isNull);
      expect(container.read(authStateProvider), isA<AuthUnauthenticated>());
    });

    test('returns error message and recovers state on failure', () async {
      final container = _createContainer(
        restoreResult: _testUser('u1'),
        deleteError: Exception('edge function error'),
      );
      addTearDown(container.dispose);

      final notifier = container.read(authStateProvider.notifier);
      await notifier.restore();

      final error = await notifier.deleteAccount();
      expect(error, isNotNull);
      expect(error, contains('edge function error'));

      // Should recover to Authenticated.
      expect(container.read(authStateProvider), isA<AuthAuthenticated>());
    });

    test('returns error when not authenticated', () async {
      final container = _createContainer(restoreResult: null);
      addTearDown(container.dispose);

      final notifier = container.read(authStateProvider.notifier);
      await notifier.restore();

      final error = await notifier.deleteAccount();
      expect(error, 'You must be signed in to delete your account.');
    });
  });

  group('AuthNotifier — updateProfile()', () {
    test('updates profile in state on success', () async {
      final container = _createContainer(
        restoreResult: _testUser('u1', name: 'Old Name'),
        updateResult: _testUser('u1', name: 'New Name'),
      );
      addTearDown(container.dispose);

      final notifier = container.read(authStateProvider.notifier);
      await notifier.restore();

      final updated = _testUser('u1', name: 'New Name');
      final error = await notifier.updateProfile(updated);
      expect(error, isNull);

      final state = container.read(authStateProvider) as AuthAuthenticated;
      expect(state.user.displayName, 'New Name');
    });
  });

  group('AuthState — sealed class properties', () {
    test('AuthInitial has expected defaults', () {
      const state = AuthInitial();
      expect(state.user, isNull);
      expect(state.isAuthenticated, isFalse);
      expect(state.isLoading, isFalse);
      expect(state.adminAccess, AdminWorkspaceAccess.none);
    });

    test('AuthLoading reports isLoading', () {
      const state = AuthLoading();
      expect(state.isLoading, isTrue);
      expect(state.isAuthenticated, isFalse);
    });

    test('AuthAuthenticated reports isAuthenticated with user', () {
      const access = AdminWorkspaceAccess(hasPlatformAccess: true);
      final state = AuthAuthenticated(
        profile: _testUser('u1'),
        workspace: access,
      );
      expect(state.isAuthenticated, isTrue);
      expect(state.isLoading, isFalse);
      expect(state.user, isNotNull);
      expect(state.user.id, 'u1');
      expect(state.adminAccess.hasPlatformAccess, isTrue);
    });

    test('AuthUnauthenticated has expected defaults', () {
      const state = AuthUnauthenticated();
      expect(state.user, isNull);
      expect(state.isAuthenticated, isFalse);
    });

    test('AuthError carries message and optional error', () {
      const state = AuthError('test error', 42);
      expect(state.message, 'test error');
      expect(state.error, 42);
      expect(state.isAuthenticated, isFalse);
    });

    test('AuthRecoveryRequired carries session recovery context', () {
      const state = AuthRecoveryRequired('session cleared');
      expect(state.message, 'session cleared');
      expect(state.error, isNull);
    });
  });

  group('AuthNotifier — refreshAdminAccess()', () {
    test('updates admin access for authenticated user', () async {
      const access = AdminWorkspaceAccess(hasGlobalPartnerAccess: true);
      final container = _createContainer(
        restoreResult: _testUser('u1'),
        adminAccess: access,
      );
      addTearDown(container.dispose);

      final notifier = container.read(authStateProvider.notifier);
      await notifier.restore();

      final state = container.read(authStateProvider) as AuthAuthenticated;
      expect(state.adminAccess.hasGlobalPartnerAccess, isTrue);
    });

    test('no-ops when unauthenticated', () async {
      final container = _createContainer(restoreResult: null);
      addTearDown(container.dispose);

      final notifier = container.read(authStateProvider.notifier);
      await notifier.restore();
      await notifier.refreshAdminAccess();

      expect(container.read(authStateProvider), isA<AuthUnauthenticated>());
    });
  });
}

// ─────────────────────────────── Helpers ──────────────────────────────── //

UserProfile _testUser(String id, {String name = 'Test User'}) {
  return UserProfile(
    id: id,
    clubId: '1',
    publicUserId: '1000',
    displayName: name,
  );
}

ProviderContainer _createContainer({
  UserProfile? restoreResult,
  Object? restoreError,
  Object? signOutError,
  UserProfile? anonymousResult,
  Object? anonymousError,
  UserProfile? updateResult,
  Object? deleteError,
  AdminWorkspaceAccess adminAccess = AdminWorkspaceAccess.none,
}) {
  return ProviderContainer(
    overrides: <Override>[
      authRepositoryProvider.overrideWithValue(
        _FakeAuthRepository(
          restoreResult: restoreResult,
          restoreError: restoreError,
          signOutError: signOutError,
          anonymousResult: anonymousResult,
          anonymousError: anonymousError,
          updateResult: updateResult,
          deleteError: deleteError,
          adminAccess: adminAccess,
        ),
      ),
    ],
  );
}

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository({
    this.restoreResult,
    this.restoreError,
    this.signOutError,
    this.anonymousResult,
    this.anonymousError,
    this.updateResult,
    this.deleteError,
    this.adminAccess = AdminWorkspaceAccess.none,
  }) : super(clubId: '1');

  final UserProfile? restoreResult;
  final Object? restoreError;
  final Object? signOutError;
  final UserProfile? anonymousResult;
  final Object? anonymousError;
  final UserProfile? updateResult;
  final Object? deleteError;
  final AdminWorkspaceAccess adminAccess;

  @override
  Future<UserProfile?> restoreCurrentUser() async {
    if (restoreError != null) throw restoreError!;
    return restoreResult;
  }

  @override
  Future<void> signOut() async {
    if (signOutError != null) throw signOutError!;
  }

  @override
  Future<UserProfile> signInAnonymously() async {
    if (anonymousError != null) throw anonymousError!;
    return anonymousResult!;
  }

  @override
  Future<UserProfile> updateProfile(UserProfile profile) async {
    return updateResult ?? profile;
  }

  @override
  Future<void> deleteAccount(String userId) async {
    if (deleteError != null) throw deleteError!;
  }

  @override
  Future<AdminWorkspaceAccess> resolveAdminAccess(String userId) async {
    return adminAccess;
  }

  @override
  Stream<supabase.AuthState> get authStateChanges =>
      const Stream<supabase.AuthState>.empty();
}
