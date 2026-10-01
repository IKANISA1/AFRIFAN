import 'dart:async';
import 'dart:collection';

import 'package:core_auth/core_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

void main() {
  _authorityTransitionTests();
  _completeAuthorityGuardTests();
  _adminStageRaceTests();
  _clubAuthorityTests();
  _pendingSdkHydrationTests();
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

void _authorityTransitionTests() {
  group('AuthNotifier authority transition', () {
    test('late startup restoration cannot resurrect explicit logout', () async {
      final restore = Completer<UserProfile?>();
      final repository = _DelayedAuthRepository(restore: () => restore.future);
      final container = _authContainer(repository);
      addTearDown(container.dispose);
      final notifier = container.read(authStateProvider.notifier);
      final pending = notifier.restore();
      await notifier.signOut();
      restore.complete(_profile('old'));
      await pending;
      expect(container.read(authStateProvider), isA<AuthUnauthenticated>());
      expect(repository.adminUsers, isEmpty);
    });

    test(
      'late restore error never signs out a replacement repository',
      () async {
        final restore = Completer<UserProfile?>();
        final oldRepository = _DelayedAuthRepository(
          restore: () => restore.future,
        );
        final newRepository = _DelayedAuthRepository(profile: _profile('new'));
        final container = _authContainer(oldRepository);
        addTearDown(container.dispose);
        final notifier = container.read(authStateProvider.notifier);
        final pending = notifier.restore();
        container.updateOverrides(<Override>[
          authRepositoryProvider.overrideWithValue(newRepository),
        ]);
        container.read(authStateProvider);
        restore.completeError(StateError('SYNTHETIC stale restore failure'));
        await pending;
        expect(newRepository.signOutCalls, 0);
        expect(oldRepository.signOutCalls, 0);
        expect(container.read(authStateProvider), isA<AuthInitial>());
      },
    );

    test(
      'late admin access cannot replace the newer authenticated user',
      () async {
        final access = Completer<AdminWorkspaceAccess>();
        final repository = _DelayedAuthRepository(profile: _profile('old'));
        final container = _authContainer(repository);
        addTearDown(container.dispose);
        final notifier = container.read(authStateProvider.notifier);
        await notifier.restore();
        repository.admin = (_) => access.future;
        final pending = notifier.refreshAdminAccess();
        repository.profile = _profile('new');
        repository.admin = (_) async => AdminWorkspaceAccess.none;
        await notifier.syncWithAuthChange(
          supabase.AuthState(
            supabase.AuthChangeEvent.signedIn,
            _sessionForUser('new'),
          ),
        );
        access.complete(const AdminWorkspaceAccess(hasPlatformAccess: true));
        await pending;
        final state = container.read(authStateProvider) as AuthAuthenticated;
        expect(state.profile.id, 'new');
        expect(state.workspace.hasPlatformAccess, isFalse);
      },
    );

    test(
      'logout closes local authority before the repository replies',
      () async {
        final signOut = Completer<void>();
        final repository = _DelayedAuthRepository(
          profile: _profile('old'),
          signOutResponse: () => signOut.future,
        );
        final container = _authContainer(repository);
        addTearDown(container.dispose);
        final notifier = container.read(authStateProvider.notifier);
        await notifier.restore();
        final pending = notifier.signOut();
        final immediately = container.read(authStateProvider);
        signOut.complete();
        await pending;
        expect(immediately, isA<AuthUnauthenticated>());
      },
    );
  });
}

UserProfile _profile(
  String id, {
  String name = 'Supporter',
  String clubId = '1',
}) => UserProfile(
  id: id,
  clubId: clubId,
  publicUserId: '100001',
  displayName: name,
);
ProviderContainer _authContainer(AuthRepository repository) {
  if (repository is _DelayedAuthRepository) {
    addTearDown(repository.close);
  }
  return ProviderContainer(
    overrides: <Override>[authRepositoryProvider.overrideWithValue(repository)],
  );
}

class _DelayedAuthRepository extends AuthRepository {
  _DelayedAuthRepository({
    this.profile,
    this.restore,
    this.signOutResponse,
    super.clubId = '1',
  }) {
    events = StreamController<supabase.AuthState>.broadcast(
      sync: true,
      onListen: () => subscriptions++,
      onCancel: () => cancellations++,
    );
  }
  UserProfile? profile;
  Future<UserProfile?> Function()? restore;
  Future<AdminWorkspaceAccess> Function(String)? admin;
  Future<void> Function()? signOutResponse;
  Future<UserProfile> Function()? anonymous;
  Future<UserProfile> Function()? signInVerification;
  Future<UserProfile> Function()? phoneVerification;
  Future<void> Function()? otpRequest;
  Future<void> Function()? phoneRequest;
  Future<void> Function()? otherSessions;
  Future<void> Function()? deletion;
  Future<UserProfile> Function(UserProfile)? profileUpdate;
  late final StreamController<supabase.AuthState> events;
  final adminUsers = <String>[];
  final updatedUsers = <String>[];
  final deletedUsers = <String>[];
  int signOutCalls = 0;
  int subscriptions = 0;
  int cancellations = 0;
  int restores = 0;
  int requests = 0;
  @override
  Future<UserProfile?> restoreCurrentUser() {
    restores++;
    return restore?.call() ?? Future.value(profile);
  }

  @override
  Future<AdminWorkspaceAccess> resolveAdminAccess(String userId) {
    adminUsers.add(userId);
    return admin?.call(userId) ?? Future.value(AdminWorkspaceAccess.none);
  }

  @override
  Future<void> signOut() {
    signOutCalls++;
    return signOutResponse?.call() ?? Future.value();
  }

  @override
  Future<UserProfile> signInAnonymously() =>
      anonymous?.call() ?? Future.value(profile!);
  @override
  Future<void> requestPhoneSignInOtp({
    required String phone,
    supabase.OtpChannel channel = supabase.OtpChannel.whatsapp,
    bool shouldCreateUser = true,
  }) {
    requests++;
    return otpRequest?.call() ?? Future.value();
  }

  @override
  Future<UserProfile> verifyPhoneSignInOtp({
    required String phone,
    required String token,
  }) => signInVerification?.call() ?? Future.value(profile!);
  @override
  Future<void> requestPhoneVerificationOtp({required String phone}) =>
      phoneRequest?.call() ?? Future.value();
  @override
  Future<UserProfile> verifyPhoneVerificationOtp({
    required String phone,
    required String token,
  }) => phoneVerification?.call() ?? Future.value(profile!);
  @override
  Future<UserProfile> updateProfile(UserProfile profile) {
    updatedUsers.add(profile.id);
    return profileUpdate?.call(profile) ?? Future.value(profile);
  }

  @override
  Future<void> signOutOtherSessions() =>
      otherSessions?.call() ?? Future.value();
  @override
  Future<void> deleteAccount(String userId) {
    deletedUsers.add(userId);
    return deletion?.call() ?? Future.value();
  }

  Future<void> close() => events.close();
  @override
  Stream<supabase.AuthState> get authStateChanges => events.stream;
}

void _completeAuthorityGuardTests() {
  const actions = <String>[
    'OTP request',
    'OTP verification',
    'phone request',
    'phone verification',
    'profile update',
    'profile refresh',
    'other sessions',
    'delete account',
  ];
  group('AuthNotifier complete authority guards', () {
    for (final action in actions) {
      for (final fails in <bool>[false, true]) {
        test(
          '$action late ${fails ? 'error' : 'success'} stays outside a newer session',
          () async {
            final repository = _DelayedAuthRepository(profile: _profile('old'));
            final container = _authContainer(repository);
            addTearDown(container.dispose);
            final notifier = container.read(authStateProvider.notifier);
            await notifier.restore();
            final operation = _DelayedAction(action, repository, notifier);
            final pending = operation.start();
            repository.restore = null;
            repository.profile = _profile('new');
            await notifier.syncWithAuthChange(_signedIn('new'));
            operation.complete(fails: fails);
            final result = await pending;
            _expectChangedAction(result);
            final state =
                container.read(authStateProvider) as AuthAuthenticated;
            expect(state.profile.id, 'new');
            expect(state.workspace.hasAnyAdminAccess, isFalse);
            expect(repository.adminUsers, <String>['old', 'new']);
          },
        );

        test(
          '$action late ${fails ? 'error' : 'success'} cannot access a disposed provider',
          () async {
            final repository = _DelayedAuthRepository(profile: _profile('old'));
            final container = _authContainer(repository);
            final notifier = container.read(authStateProvider.notifier);
            await notifier.restore();
            final operation = _DelayedAction(action, repository, notifier);
            final pending = operation.start();
            container.dispose();
            operation.complete(fails: fails);
            _expectChangedAction(await pending);
            expect(repository.adminUsers, <String>['old']);
            expect(repository.cancellations, 1);
          },
        );
      }
    }

    for (final method in <String>[
      'restore',
      'session hydration',
      'anonymous sign-in',
      'admin refresh',
    ]) {
      for (final boundary in <String>['repository replacement', 'disposal']) {
        for (final fails in <bool>[false, true]) {
          test(
            '$method ${fails ? 'error' : 'success'} is fenced by $boundary',
            () async {
              final repository = _DelayedAuthRepository(
                profile: _profile('old'),
              );
              final replacement = _DelayedAuthRepository(
                profile: _profile('new'),
              );
              final container = _authContainer(repository);
              addTearDown(replacement.close);
              final notifier = container.read(authStateProvider.notifier);
              if (method == 'admin refresh') await notifier.restore();
              final response = Completer<UserProfile?>();
              final signedIn = Completer<UserProfile>();
              final admin = Completer<AdminWorkspaceAccess>();
              Future<void> pending;
              if (method == 'admin refresh') {
                repository.admin = (_) => admin.future;
                pending = notifier.refreshAdminAccess();
              } else if (method == 'anonymous sign-in') {
                repository.anonymous = () => signedIn.future;
                pending = notifier.signInAnonymously();
              } else {
                repository.restore = () => response.future;
                pending = method == 'restore'
                    ? notifier.restore()
                    : notifier.syncWithAuthChange(_signedIn('old'));
              }
              if (boundary == 'disposal') {
                container.dispose();
              } else {
                addTearDown(container.dispose);
                container.updateOverrides(<Override>[
                  authRepositoryProvider.overrideWithValue(replacement),
                ]);
                expect(container.read(authStateProvider), isA<AuthInitial>());
              }
              final error = StateError('SYNTHETIC stale operation failure');
              if (method == 'admin refresh') {
                fails
                    ? admin.completeError(error)
                    : admin.complete(
                        const AdminWorkspaceAccess(hasPlatformAccess: true),
                      );
              } else if (method == 'anonymous sign-in') {
                fails
                    ? signedIn.completeError(error)
                    : signedIn.complete(_profile('old'));
              } else {
                fails
                    ? response.completeError(error)
                    : response.complete(_profile('old'));
              }
              await pending;
              expect(repository.signOutCalls, 0);
              expect(replacement.signOutCalls, 0);
              if (boundary != 'disposal') {
                expect(container.read(authStateProvider), isA<AuthInitial>());
              }
            },
          );
        }
      }
    }

    test(
      'repository replacement cancels the old stream and ignores its later events',
      () async {
        final old = _DelayedAuthRepository(profile: _profile('old'));
        final replacement = _DelayedAuthRepository(profile: _profile('new'));
        final container = _authContainer(old);
        addTearDown(container.dispose);
        addTearDown(replacement.close);
        final notifier = container.read(authStateProvider.notifier);
        await notifier.restore();
        container.updateOverrides(<Override>[
          authRepositoryProvider.overrideWithValue(replacement),
        ]);
        container.read(authStateProvider);
        expect(old.cancellations, 1);
        expect(replacement.subscriptions, 1);
        old.events.add(_signedIn('old'));
        replacement.events.add(_signedIn('new'));
        await _settle();
        expect(
          (container.read(authStateProvider) as AuthAuthenticated).profile.id,
          'new',
        );
        expect(old.restores, 1);
        expect(replacement.restores, 1);
      },
    );

    test(
      'new session removes old private profile and admin authority before hydration',
      () async {
        final delayed = Completer<UserProfile?>();
        final repository = _DelayedAuthRepository(profile: _profile('old'));
        final container = _authContainer(repository);
        addTearDown(container.dispose);
        final notifier = container.read(authStateProvider.notifier);
        await notifier.restore();
        repository.restore = () => delayed.future;
        final pending = notifier.syncWithAuthChange(_signedIn('new'));
        expect(container.read(authStateProvider).user, isNull);
        expect(
          container.read(authStateProvider).adminAccess.hasAnyAdminAccess,
          isFalse,
        );
        delayed.complete(_profile('new'));
        await pending;
      },
    );

    test(
      'logout reply cannot clear a newer session on the same repository',
      () async {
        final reply = Completer<void>();
        final repository = _DelayedAuthRepository(
          profile: _profile('old'),
          signOutResponse: () => reply.future,
        );
        final container = _authContainer(repository);
        addTearDown(container.dispose);
        final notifier = container.read(authStateProvider.notifier);
        await notifier.restore();
        final pending = notifier.signOut();
        repository.profile = _profile('new');
        await notifier.syncWithAuthChange(_signedIn('new'));
        reply.complete();
        await pending;
        expect(
          (container.read(authStateProvider) as AuthAuthenticated).profile.id,
          'new',
        );
      },
    );

    for (final kind in <String>['OTP sign-in', 'phone verification']) {
      test(
        '$kind succeeds when its matching SDK event already owns hydration',
        () async {
          final reply = Completer<UserProfile>();
          final repository = _DelayedAuthRepository(profile: _profile('old'));
          final container = _authContainer(repository);
          addTearDown(container.dispose);
          final notifier = container.read(authStateProvider.notifier);
          await notifier.restore();
          Future<Object?> pending;
          if (kind == 'OTP sign-in') {
            repository.signInVerification = () => reply.future;
            pending = notifier.verifyPhoneSignInOtpResult(
              phone: 'SYNTHETIC',
              token: 'SYNTHETIC',
            );
            repository.profile = _profile('new');
          } else {
            repository.phoneVerification = () => reply.future;
            pending = notifier.verifyPhoneVerificationOtp(
              phone: 'SYNTHETIC',
              token: 'SYNTHETIC',
            );
            repository.profile = _profile('old', name: 'Verified');
          }
          await notifier.syncWithAuthChange(_signedIn(repository.profile!.id));
          reply.complete(repository.profile!);
          expect(await pending, isNull);
          expect(
            (container.read(authStateProvider) as AuthAuthenticated).profile,
            repository.profile,
          );
          expect(repository.adminUsers.length, 2);
        },
      );
    }

    test(
      'matching user ID after logout and sign-in cannot revive an older OTP attempt',
      () async {
        final reply = Completer<UserProfile>();
        final repository = _DelayedAuthRepository(profile: _profile('old'));
        final container = _authContainer(repository);
        addTearDown(container.dispose);
        final notifier = container.read(authStateProvider.notifier);
        await notifier.restore();
        repository.signInVerification = () => reply.future;
        final pending = notifier.verifyPhoneSignInOtpResult(
          phone: 'SYNTHETIC',
          token: 'SYNTHETIC',
        );
        await notifier.signOut();
        await notifier.syncWithAuthChange(_signedIn('old'));
        reply.complete(_profile('old'));
        _expectChangedAction(await pending);
        expect(repository.adminUsers.length, 2);
      },
    );

    test(
      'delete success preserves its own earlier intentional signed-out event',
      () async {
        final reply = Completer<void>();
        final repository = _DelayedAuthRepository(profile: _profile('old'));
        final container = _authContainer(repository);
        addTearDown(container.dispose);
        final notifier = container.read(authStateProvider.notifier);
        await notifier.restore();
        repository.deletion = () => reply.future;
        final pending = notifier.deleteAccount();
        await notifier.syncWithAuthChange(
          const supabase.AuthState(supabase.AuthChangeEvent.signedOut, null),
        );
        reply.complete();
        expect(await pending, isNull);
        expect(container.read(authStateProvider), isA<AuthUnauthenticated>());
        expect(repository.deletedUsers, <String>['old']);
      },
    );

    test(
      'restore failure keeps recovery when its cleanup emits signed out',
      () async {
        final repository = _DelayedAuthRepository(
          restore: () async => throw StateError('SYNTHETIC restore failure'),
        );
        final container = _authContainer(repository);
        addTearDown(container.dispose);
        final notifier = container.read(authStateProvider.notifier);
        repository.signOutResponse = () async {
          repository.events.add(
            const supabase.AuthState(supabase.AuthChangeEvent.signedOut, null),
          );
        };
        await notifier.restore();
        expect(container.read(authStateProvider), isA<AuthRecoveryRequired>());
        expect(repository.signOutCalls, 1);
      },
    );

    test(
      'last-started profile write wins and retains newly refreshed admin access',
      () async {
        final first = Completer<UserProfile>();
        final repository = _DelayedAuthRepository(profile: _profile('old'));
        final container = _authContainer(repository);
        addTearDown(container.dispose);
        final notifier = container.read(authStateProvider.notifier);
        await notifier.restore();
        repository.profileUpdate = (_) => first.future;
        final pending = notifier.updateProfile(_profile('old', name: 'First'));
        repository.profileUpdate = (_) async => _profile('old', name: 'Second');
        expect(
          await notifier.updateProfile(_profile('old', name: 'Second')),
          isNull,
        );
        repository.admin = (_) async =>
            const AdminWorkspaceAccess(hasPlatformAccess: true);
        await notifier.refreshAdminAccess();
        first.complete(_profile('old', name: 'First'));
        _expectChangedAction(await pending);
        final state = container.read(authStateProvider) as AuthAuthenticated;
        expect(state.profile.displayName, 'Second');
        expect(state.workspace.hasPlatformAccess, isTrue);
      },
    );

    test(
      'admin response merges the current profile instead of its captured profile',
      () async {
        final access = Completer<AdminWorkspaceAccess>();
        final repository = _DelayedAuthRepository(profile: _profile('old'));
        final container = _authContainer(repository);
        addTearDown(container.dispose);
        final notifier = container.read(authStateProvider.notifier);
        await notifier.restore();
        repository.admin = (_) => access.future;
        final pending = notifier.refreshAdminAccess();
        expect(
          await notifier.updateProfile(_profile('old', name: 'Updated')),
          isNull,
        );
        access.complete(const AdminWorkspaceAccess(hasPlatformAccess: true));
        await pending;
        final state = container.read(authStateProvider) as AuthAuthenticated;
        expect(state.profile.displayName, 'Updated');
        expect(state.workspace.hasPlatformAccess, isTrue);
      },
    );

    test(
      'last-started admin refresh wins without restoring old access',
      () async {
        final first = Completer<AdminWorkspaceAccess>();
        final repository = _DelayedAuthRepository(profile: _profile('old'));
        final container = _authContainer(repository);
        addTearDown(container.dispose);
        final notifier = container.read(authStateProvider.notifier);
        await notifier.restore();
        repository.admin = (_) => first.future;
        final pending = notifier.refreshAdminAccess();
        repository.admin = (_) async => AdminWorkspaceAccess.none;
        await notifier.refreshAdminAccess();
        first.complete(const AdminWorkspaceAccess(hasPlatformAccess: true));
        await pending;
        expect(
          container.read(authStateProvider).adminAccess.hasAnyAdminAccess,
          isFalse,
        );
      },
    );

    for (final method in <String>[
      'restore',
      'session hydration',
      'anonymous sign-in',
      'OTP verification',
      'phone verification',
    ]) {
      test(
        '$method rejects foreign-club profile before admin or private state',
        () async {
          final repository = _DelayedAuthRepository(profile: _profile('old'));
          final container = _authContainer(repository);
          addTearDown(container.dispose);
          final notifier = container.read(authStateProvider.notifier);
          if (method == 'phone verification') await notifier.restore();
          final baselineAdminCalls = repository.adminUsers.length;
          repository.profile = _profile('old', clubId: '26');
          switch (method) {
            case 'restore':
              await notifier.restore();
            case 'session hydration':
              await notifier.syncWithAuthChange(_signedIn('old'));
            case 'anonymous sign-in':
              await notifier.signInAnonymously();
            case 'OTP verification':
              _expectChangedAction(
                await notifier.verifyPhoneSignInOtpResult(
                  phone: 'SYNTHETIC',
                  token: 'SYNTHETIC',
                ),
              );
            case 'phone verification':
              _expectChangedAction(
                await notifier.verifyPhoneVerificationOtp(
                  phone: 'SYNTHETIC',
                  token: 'SYNTHETIC',
                ),
              );
          }
          expect(
            container.read(authStateProvider),
            isA<AuthRecoveryRequired>(),
          );
          expect(container.read(authStateProvider).user, isNull);
          expect(repository.adminUsers.length, baselineAdminCalls);
        },
      );
    }

    test(
      'numeric club normalization accepts the same canonical club',
      () async {
        final repository = _DelayedAuthRepository(
          profile: _profile('old', clubId: '01'),
          clubId: '1',
        );
        final container = _authContainer(repository);
        addTearDown(container.dispose);
        await container.read(authStateProvider.notifier).restore();
        expect(container.read(authStateProvider), isA<AuthAuthenticated>());
      },
    );

    for (final club in <String>['other', '0', '-1', '2147483648']) {
      test(
        'invalid configured club $club never obtains admin authority',
        () async {
          final repository = _DelayedAuthRepository(
            profile: _profile('old', clubId: club),
            clubId: club,
          );
          final container = _authContainer(repository);
          addTearDown(container.dispose);
          await container.read(authStateProvider.notifier).restore();
          expect(
            container.read(authStateProvider),
            isA<AuthRecoveryRequired>(),
          );
          expect(repository.adminUsers, isEmpty);
        },
      );
    }

    test(
      'foreign or wrong-user profile updates are never sent or committed',
      () async {
        final repository = _DelayedAuthRepository(profile: _profile('old'));
        final container = _authContainer(repository);
        addTearDown(container.dispose);
        final notifier = container.read(authStateProvider.notifier);
        await notifier.restore();
        _expectChangedAction(await notifier.updateProfile(_profile('other')));
        _expectChangedAction(
          await notifier.updateProfile(_profile('old', clubId: '26')),
        );
        expect(repository.updatedUsers, isEmpty);
        repository.profileUpdate = (_) async => _profile('other', clubId: '26');
        _expectChangedAction(await notifier.updateProfile(_profile('old')));
        expect(
          (container.read(authStateProvider) as AuthAuthenticated).profile.id,
          'old',
        );
      },
    );

    test(
      'profile refresh never adopts a foreign-club or wrong-user profile',
      () async {
        final repository = _DelayedAuthRepository(profile: _profile('old'));
        final container = _authContainer(repository);
        addTearDown(container.dispose);
        final notifier = container.read(authStateProvider.notifier);
        await notifier.restore();
        for (final profile in <UserProfile>[
          _profile('other'),
          _profile('old', clubId: '26'),
        ]) {
          repository.profile = profile;
          expect(
            await notifier.refreshProfile(),
            'The latest profile could not be loaded.',
          );
          expect(
            (container.read(authStateProvider) as AuthAuthenticated).profile.id,
            'old',
          );
          expect(container.read(authStateProvider).user!.clubId, '1');
        }
      },
    );

    test(
      'session hydration validates returned user before resolving admin authority',
      () async {
        final repository = _DelayedAuthRepository(profile: _profile('other'));
        final container = _authContainer(repository);
        addTearDown(container.dispose);
        await container
            .read(authStateProvider.notifier)
            .syncWithAuthChange(_signedIn('new'));
        expect(container.read(authStateProvider), isA<AuthError>());
        expect(repository.adminUsers, isEmpty);
        expect(container.read(authStateProvider).user, isNull);
      },
    );

    test(
      'token refresh for the current user does not start duplicate hydration',
      () async {
        final repository = _DelayedAuthRepository(profile: _profile('old'));
        final container = _authContainer(repository);
        addTearDown(container.dispose);
        final notifier = container.read(authStateProvider.notifier);
        await notifier.restore();
        await notifier.syncWithAuthChange(
          supabase.AuthState(
            supabase.AuthChangeEvent.tokenRefreshed,
            _sessionForUser('old'),
          ),
        );
        expect(repository.restores, 1);
        expect(repository.adminUsers, <String>['old']);
      },
    );
  });
}

supabase.AuthState _signedIn(String id) =>
    supabase.AuthState(supabase.AuthChangeEvent.signedIn, _sessionForUser(id));
Future<void> _settle() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void _expectChangedAction(Object? result) {
  if (result is AuthActionFailure) {
    expect(result.kind, AuthActionFailureKind.conflict);
    expect(result.message, 'Your session changed. Start this action again.');
  } else {
    expect(result, 'Your session changed. Start this action again.');
  }
}

class _DelayedAction {
  _DelayedAction(this.name, this.repository, this.notifier);
  final String name;
  final _DelayedAuthRepository repository;
  final AuthNotifier notifier;
  final action = Completer<void>();
  final profile = Completer<UserProfile>();
  final restore = Completer<UserProfile?>();
  Future<Object?> start() {
    switch (name) {
      case 'OTP request':
        repository.otpRequest = () => action.future;
        return notifier.requestPhoneSignInOtpResult(phone: 'SYNTHETIC');
      case 'OTP verification':
        repository.signInVerification = () => profile.future;
        return notifier.verifyPhoneSignInOtpResult(
          phone: 'SYNTHETIC',
          token: 'SYNTHETIC',
        );
      case 'phone request':
        repository.phoneRequest = () => action.future;
        return notifier.requestPhoneVerificationOtp(phone: 'SYNTHETIC');
      case 'phone verification':
        repository.phoneVerification = () => profile.future;
        return notifier.verifyPhoneVerificationOtp(
          phone: 'SYNTHETIC',
          token: 'SYNTHETIC',
        );
      case 'profile update':
        repository.profileUpdate = (_) => profile.future;
        return notifier.updateProfile(_profile('old'));
      case 'profile refresh':
        repository.restore = () => restore.future;
        return notifier.refreshProfile();
      case 'other sessions':
        repository.otherSessions = () => action.future;
        return notifier.signOutOtherSessions();
      case 'delete account':
        repository.deletion = () => action.future;
        return notifier.deleteAccount();
    }
    throw StateError('Unknown controlled action');
  }

  void complete({required bool fails}) {
    final error = StateError('SYNTHETIC stale failure');
    if (name == 'profile refresh') {
      fails ? restore.completeError(error) : restore.complete(_profile('old'));
    } else if (<String>[
      'OTP verification',
      'phone verification',
      'profile update',
    ].contains(name)) {
      fails ? profile.completeError(error) : profile.complete(_profile('old'));
    } else {
      fails ? action.completeError(error) : action.complete();
    }
  }
}

void _adminStageRaceTests() {
  group('AuthNotifier second-await and reentrant guards', () {
    for (final method in <String>[
      'restore',
      'session hydration',
      'anonymous sign-in',
      'OTP verification',
      'phone verification',
    ]) {
      for (final fails in <bool>[false, true]) {
        test(
          '$method late admin ${fails ? 'error' : 'success'} cannot restore old authority',
          () async {
            final access = Completer<AdminWorkspaceAccess>();
            final repository = _DelayedAuthRepository(profile: _profile('old'));
            final container = _authContainer(repository);
            addTearDown(container.dispose);
            final notifier = container.read(authStateProvider.notifier);
            await notifier.restore();
            repository.admin = (_) => access.future;
            Future<Object?> pending;
            switch (method) {
              case 'restore':
                pending = notifier.restore();
              case 'session hydration':
                pending = notifier.syncWithAuthChange(_signedIn('old'));
              case 'anonymous sign-in':
                pending = notifier.signInAnonymously();
              case 'OTP verification':
                pending = notifier.verifyPhoneSignInOtpResult(
                  phone: 'SYNTHETIC',
                  token: 'SYNTHETIC',
                );
              case 'phone verification':
                pending = notifier.verifyPhoneVerificationOtp(
                  phone: 'SYNTHETIC',
                  token: 'SYNTHETIC',
                );
              default:
                throw StateError('Unknown controlled hydration');
            }
            await _settle();
            expect(repository.adminUsers, <String>['old', 'old']);
            repository.profile = _profile('new');
            repository.admin = (_) async => AdminWorkspaceAccess.none;
            await notifier.syncWithAuthChange(_signedIn('new'));
            fails
                ? access.completeError(
                    StateError('SYNTHETIC stale admin failure'),
                  )
                : access.complete(
                    const AdminWorkspaceAccess(hasPlatformAccess: true),
                  );
            final result = await pending;
            if (method == 'OTP verification' ||
                method == 'phone verification') {
              _expectChangedAction(result);
            }
            final state =
                container.read(authStateProvider) as AuthAuthenticated;
            expect(state.profile.id, 'new');
            expect(state.workspace.hasAnyAdminAccess, isFalse);
            expect(repository.adminUsers, <String>['old', 'old', 'new']);
          },
        );
      }
    }

    test(
      'a synchronous logout listener wins over the authenticated commit',
      () async {
        final repository = _DelayedAuthRepository(profile: _profile('old'));
        final container = _authContainer(repository);
        addTearDown(container.dispose);
        final notifier = container.read(authStateProvider.notifier);
        container.listen(authStateProvider, (_, next) {
          if (next is AuthAuthenticated) unawaited(notifier.signOut());
        });
        await notifier.restore();
        await _settle();
        expect(container.read(authStateProvider), isA<AuthUnauthenticated>());
        expect(repository.signOutCalls, 1);
      },
    );

    test('local guest never resolves a server admin principal', () async {
      final repository = _DelayedAuthRepository();
      repository.anonymous = () async => throw StateError('Unable to connect');
      final container = _authContainer(repository);
      addTearDown(container.dispose);
      final notifier = container.read(authStateProvider.notifier);
      await notifier.signInAnonymously();
      await notifier.refreshAdminAccess();
      expect(container.read(authStateProvider), isA<AuthAuthenticated>());
      expect(container.read(authStateProvider).user!.id, isEmpty);
      expect(repository.adminUsers, isEmpty);
    });

    test(
      'methods invoked after disposal perform no repository or state work',
      () async {
        final repository = _DelayedAuthRepository(profile: _profile('old'));
        final container = _authContainer(repository);
        final notifier = container.read(authStateProvider.notifier);
        container.dispose();
        await notifier.restore();
        await notifier.signInAnonymously();
        await notifier.syncWithAuthChange(_signedIn('old'));
        await notifier.refreshAdminAccess();
        await notifier.signOut();
        _expectChangedAction(
          await notifier.requestPhoneSignInOtpResult(phone: 'SYNTHETIC'),
        );
        _expectChangedAction(
          await notifier.verifyPhoneSignInOtpResult(
            phone: 'SYNTHETIC',
            token: 'SYNTHETIC',
          ),
        );
        _expectChangedAction(
          await notifier.requestPhoneVerificationOtp(phone: 'SYNTHETIC'),
        );
        _expectChangedAction(
          await notifier.verifyPhoneVerificationOtp(
            phone: 'SYNTHETIC',
            token: 'SYNTHETIC',
          ),
        );
        _expectChangedAction(await notifier.updateProfile(_profile('old')));
        _expectChangedAction(await notifier.refreshProfile());
        _expectChangedAction(await notifier.signOutOtherSessions());
        _expectChangedAction(await notifier.deleteAccount());
        expect(repository.restores, 0);
        expect(repository.requests, 0);
        expect(repository.adminUsers, isEmpty);
        expect(repository.updatedUsers, isEmpty);
        expect(repository.deletedUsers, isEmpty);
        expect(repository.signOutCalls, 0);
      },
    );
  });
}

void _clubAuthorityTests() {
  group('AuthNotifier five configured club authorities', () {
    const clubIds = <String>['6', '24', '26', '44', '1001'];
    for (final configured in clubIds) {
      for (final returned in clubIds) {
        test(
          'repository $configured only commits profile club $configured (returned $returned)',
          () async {
            final repository = _DelayedAuthRepository(
              profile: _profile('supporter', clubId: returned),
              clubId: configured,
            );
            final container = _authContainer(repository);
            addTearDown(container.dispose);
            await container.read(authStateProvider.notifier).restore();
            if (configured == returned) {
              expect(
                container.read(authStateProvider),
                isA<AuthAuthenticated>(),
              );
              expect(
                container.read(authStateProvider).user!.clubId,
                configured,
              );
              expect(repository.adminUsers, <String>['supporter']);
            } else {
              expect(
                container.read(authStateProvider),
                isA<AuthRecoveryRequired>(),
              );
              expect(container.read(authStateProvider).user, isNull);
              expect(
                container.read(authStateProvider).adminAccess.hasAnyAdminAccess,
                isFalse,
              );
              expect(repository.adminUsers, isEmpty);
            }
          },
        );
      }
    }

    for (final failure in <String>[
      'null profile',
      'foreign profile',
      'restore error',
    ]) {
      test(
        'OTP response cannot report success after SDK hydration $failure',
        () async {
          final verified = Completer<UserProfile>();
          final repository = _DelayedAuthRepository(profile: _profile('old'));
          final container = _authContainer(repository);
          addTearDown(container.dispose);
          final notifier = container.read(authStateProvider.notifier);
          await notifier.restore();
          repository.signInVerification = () => verified.future;
          final pending = notifier.verifyPhoneSignInOtpResult(
            phone: 'SYNTHETIC',
            token: 'SYNTHETIC',
          );
          switch (failure) {
            case 'null profile':
              repository.profile = null;
            case 'foreign profile':
              repository.profile = _profile('old', clubId: '26');
            case 'restore error':
              repository.restore = () async =>
                  throw StateError('SYNTHETIC hydration failure');
          }
          await notifier.syncWithAuthChange(_signedIn('old'));
          verified.complete(_profile('old'));
          _expectChangedAction(await pending);
          expect(container.read(authStateProvider).user, isNull);
          expect(repository.adminUsers, <String>['old']);
        },
      );
    }
  });
}

void _pendingSdkHydrationTests() {
  group('AuthNotifier matching SDK hydration completion', () {
    test(
      'OTP completion waits for matching SDK profile and admin hydration',
      () async {
        final verified = Completer<UserProfile>();
        final restored = Completer<UserProfile?>();
        final repository = _DelayedAuthRepository(profile: _profile('old'));
        final container = _authContainer(repository);
        addTearDown(container.dispose);
        final notifier = container.read(authStateProvider.notifier);
        await notifier.restore();
        repository.signInVerification = () => verified.future;
        final otp = notifier.verifyPhoneSignInOtpResult(
          phone: 'SYNTHETIC',
          token: 'SYNTHETIC',
        );
        repository.restore = () => restored.future;
        final event = notifier.syncWithAuthChange(_signedIn('new'));
        var completed = false;
        unawaited(otp.then((_) => completed = true));
        verified.complete(_profile('new'));
        await _settle();
        expect(completed, isFalse);
        expect(container.read(authStateProvider), isA<AuthLoading>());
        restored.complete(_profile('new'));
        await event;
        expect(await otp, isNull);
        expect(
          (container.read(authStateProvider) as AuthAuthenticated).profile.id,
          'new',
        );
        expect(repository.adminUsers, <String>['old', 'new']);
      },
    );

    for (final boundary in <String>[
      'logout',
      'repository replacement',
      'disposal',
    ]) {
      test(
        '$boundary promptly releases an OTP waiting for invalidated SDK hydration',
        () async {
          final verified = Completer<UserProfile>();
          final restored = Completer<UserProfile?>();
          final repository = _DelayedAuthRepository(profile: _profile('old'));
          final replacement = _DelayedAuthRepository(
            profile: _profile('replacement'),
          );
          final container = _authContainer(repository);
          addTearDown(replacement.close);
          final notifier = container.read(authStateProvider.notifier);
          await notifier.restore();
          repository.signInVerification = () => verified.future;
          final otp = notifier.verifyPhoneSignInOtpResult(
            phone: 'SYNTHETIC',
            token: 'SYNTHETIC',
          );
          repository.restore = () => restored.future;
          final event = notifier.syncWithAuthChange(_signedIn('new'));
          verified.complete(_profile('new'));
          await _settle();
          switch (boundary) {
            case 'logout':
              addTearDown(container.dispose);
              await notifier.signOut();
            case 'repository replacement':
              addTearDown(container.dispose);
              container.updateOverrides(<Override>[
                authRepositoryProvider.overrideWithValue(replacement),
              ]);
              expect(container.read(authStateProvider), isA<AuthInitial>());
            case 'disposal':
              container.dispose();
          }
          _expectChangedAction(await otp.timeout(const Duration(seconds: 1)));
          restored.complete(_profile('new'));
          await event;
          expect(repository.adminUsers, <String>['old']);
          if (boundary == 'logout') {
            expect(
              container.read(authStateProvider),
              isA<AuthUnauthenticated>(),
            );
          }
          if (boundary == 'repository replacement') {
            expect(container.read(authStateProvider), isA<AuthInitial>());
          }
        },
      );
    }
  });
}
