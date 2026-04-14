import 'dart:async';
import 'dart:collection';

import 'package:core_auth/core_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

void main() {
  group('AuthNotifier', () {
    test(
      'ignores stale hydration results when a newer auth session arrives',
      () async {
        final firstRestore = Completer<UserProfile?>();
        final secondRestore = Completer<UserProfile?>();
        final repository = _FakeAuthRepository(
          restoreResponses: <Future<UserProfile?>>[
            firstRestore.future,
            secondRestore.future,
          ],
        );
        final container = ProviderContainer(
          overrides: <Override>[
            authRepositoryProvider.overrideWithValue(repository),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(authStateProvider.notifier);

        unawaited(
          notifier.syncWithAuthChange(
            supabase.AuthState(
              supabase.AuthChangeEvent.signedIn,
              _sessionForUser('user-a'),
            ),
          ),
        );
        await Future<void>.delayed(Duration.zero);

        unawaited(
          notifier.syncWithAuthChange(
            supabase.AuthState(
              supabase.AuthChangeEvent.signedIn,
              _sessionForUser('user-b'),
            ),
          ),
        );
        await Future<void>.delayed(Duration.zero);

        secondRestore.complete(
          const UserProfile(id: 'user-b', clubId: '1', publicUserId: '200002'),
        );
        await Future<void>.delayed(Duration.zero);

        expect(
          container.read(authStateProvider),
          isA<AuthAuthenticated>().having(
            (state) => state.user.id,
            'authenticated user',
            'user-b',
          ),
        );

        firstRestore.complete(
          const UserProfile(id: 'user-a', clubId: '1', publicUserId: '100001'),
        );
        await Future<void>.delayed(Duration.zero);

        expect(
          container.read(authStateProvider),
          isA<AuthAuthenticated>().having(
            (state) => state.user.id,
            'authenticated user',
            'user-b',
          ),
        );
      },
    );

    test('signed-out events invalidate in-flight hydration work', () async {
      final restore = Completer<UserProfile?>();
      final repository = _FakeAuthRepository(
        restoreResponses: <Future<UserProfile?>>[restore.future],
      );
      final container = ProviderContainer(
        overrides: <Override>[
          authRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(authStateProvider.notifier);

      unawaited(
        notifier.syncWithAuthChange(
          supabase.AuthState(
            supabase.AuthChangeEvent.signedIn,
            _sessionForUser('user-a'),
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      await notifier.syncWithAuthChange(
        const supabase.AuthState(supabase.AuthChangeEvent.signedOut, null),
      );

      restore.complete(
        const UserProfile(id: 'user-a', clubId: '1', publicUserId: '100001'),
      );
      await Future<void>.delayed(Duration.zero);

      expect(container.read(authStateProvider), isA<AuthUnauthenticated>());
    });
  });
}

supabase.Session _sessionForUser(String userId) {
  return supabase.Session(
    accessToken: 'token-$userId',
    tokenType: 'bearer',
    user: supabase.User(
      id: userId,
      appMetadata: const <String, dynamic>{},
      userMetadata: const <String, dynamic>{},
      aud: 'authenticated',
      createdAt: '2026-04-14T00:00:00.000Z',
    ),
  );
}

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository({List<Future<UserProfile?>> restoreResponses = const []})
    : _restoreResponses = Queue<Future<UserProfile?>>.from(restoreResponses),
      super(clubId: '1');

  final Queue<Future<UserProfile?>> _restoreResponses;

  @override
  Future<UserProfile?> restoreCurrentUser() {
    return _restoreResponses.removeFirst();
  }

  @override
  Future<void> signOut() async {}

  @override
  Future<AdminWorkspaceAccess> resolveAdminAccess(String userId) async {
    return AdminWorkspaceAccess.none;
  }

  @override
  Stream<supabase.AuthState> get authStateChanges =>
      const Stream<supabase.AuthState>.empty();
}
