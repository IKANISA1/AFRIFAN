import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:core_app/core_app.dart';
import 'package:core_auth/core_auth.dart';
import 'package:core_router/core_router.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final materialIcons = FontLoader('MaterialIcons')
      ..addFont(_loadFlutterArtifactFont('MaterialIcons-Regular.otf'));
    final roboto = FontLoader('GoldenRoboto')
      ..addFont(_loadFlutterArtifactFont('Roboto-Regular.ttf'));
    await Future.wait<void>([materialIcons.load(), roboto.load()]);
    TypographyTokens.debugUseFallbackFonts = true;
  });
  tearDownAll(() {
    TypographyTokens.debugUseFallbackFonts = false;
  });

  group('AfriClubApp route guards', () {
    late _FakeClubConfig config;

    setUp(() {
      config = const _FakeClubConfig();
      ColorTokens.init();
    });

    testWidgets('root club replacement disposes the previous private scope', (
      tester,
    ) async {
      var created = 0;
      var disposed = 0;
      var closed = 0;
      final owner = Provider<Object>((ref) {
        created++;
        ref.onDispose(() => disposed++);
        return Object();
      });
      final first = FakeAuthRepository(clubId: '1');
      final second = FakeAuthRepository(clubId: '2');
      final modules = [_HomeModule(), _IndependentIdentityModule()];
      AfriClubApp app(ClubConfig club, AuthRepository repository) =>
          AfriClubApp(
            key: const ValueKey('retained-root'),
            config: club,
            modules: modules,
            authRepository: repository,
            eagerProviders: [owner],
            initialLocation: '/native-identity-entry',
            onAccountChanged: () => closed++,
          );
      await tester.pumpWidget(app(config, first));
      await tester.pumpAndSettle();
      final oldContext = tester.element(
        find.text('Independent identity entry'),
      );
      final oldContainer = ProviderScope.containerOf(oldContext);
      final oldRoutes = GoRouter.of(oldContext).routeInformationProvider;
      expect(oldContainer.read(authRepositoryProvider), same(first));
      expect(created, 1);

      await tester.pumpWidget(app(const _FakeClubConfig(clubId: '2'), second));
      await tester.pumpAndSettle();
      final newContext = tester.element(
        find.text('Independent identity entry'),
      );
      final newContainer = ProviderScope.containerOf(newContext);
      expect(closed, 1);
      expect(newContainer, isNot(same(oldContainer)));
      expect(newContainer.read(authRepositoryProvider), same(second));
      expect(first.authenticationInvalidations, greaterThan(0));
      expect(second.authenticationInvalidations, 0);
      expect(created, 2);
      expect(disposed, 1);
      expect(
        GoRouter.of(newContext).routeInformationProvider,
        isNot(same(oldRoutes)),
      );
      expect(() => oldRoutes.addListener(() {}), throwsFlutterError);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(disposed, 2);
      expect(second.authenticationInvalidations, greaterThan(0));
    });

    testWidgets(
      'same-club repository replacement restores the new account without disposing its protected owner',
      (tester) async {
        var disposed = 0;
        var closed = 0;
        final owner = Provider<Object>((ref) {
          ref.onDispose(() => disposed++);
          return Object();
        });
        final first = FakeAuthRepository(
          restoreResult: const UserProfile(
            id: 'first-account',
            clubId: '1',
            publicUserId: 'synthetic-first',
          ),
        );
        final second = FakeAuthRepository(
          restoreResult: const UserProfile(
            id: 'second-account',
            clubId: '1',
            publicUserId: 'synthetic-second',
          ),
        );
        final modules = [_HomeModule(), _IndependentIdentityModule()];
        AfriClubApp app(AuthRepository repository) => AfriClubApp(
          key: const ValueKey('retained-root'),
          config: config,
          modules: modules,
          authRepository: repository,
          eagerProviders: [owner],
          initialLocation: '/native-identity-entry',
          onAccountChanged: () => closed++,
        );
        await tester.pumpWidget(app(first));
        await tester.pumpAndSettle();
        final context = tester.element(find.text('Independent identity entry'));
        final container = ProviderScope.containerOf(context);
        final routes = GoRouter.of(context).routeInformationProvider;
        final protectedOwner = container.read(owner);
        expect(container.read(authStateProvider).user?.id, 'first-account');

        await tester.pumpWidget(app(second));
        await tester.pumpAndSettle();
        final newContext = tester.element(
          find.text('Independent identity entry'),
        );
        expect(ProviderScope.containerOf(newContext), same(container));
        expect(container.read(authRepositoryProvider), same(second));
        expect(first.authenticationInvalidations, greaterThan(0));
        expect(second.authenticationInvalidations, 0);
        expect(container.read(authStateProvider).user?.id, 'second-account');
        expect(container.read(owner), same(protectedOwner));
        expect(GoRouter.of(newContext).routeInformationProvider, same(routes));
        expect(closed, greaterThanOrEqualTo(1));
        expect(disposed, 0);
        await tester.pumpWidget(const SizedBox.shrink());
        expect(disposed, 1);
        expect(second.authenticationInvalidations, greaterThan(0));
      },
    );

    testWidgets(
      'global account changes synchronously close independent private views',
      (tester) async {
        final auth = _AccountTransitionNotifier();
        var closed = 0;
        await tester.pumpWidget(
          AfriClubApp(
            config: config,
            modules: [_HomeModule(), _IndependentIdentityModule()],
            authRepository: FakeAuthRepository(),
            initialLocation: '/native-identity-entry',
            providerOverrides: [authStateProvider.overrideWith(() => auth)],
            onAccountChanged: () {
              closed++;
            },
          ),
        );
        await tester.pumpAndSettle();
        auth.change(
          const AuthAuthenticated(
            profile: UserProfile(
              id: 'legacy-first',
              clubId: '1',
              publicUserId: 'synthetic',
            ),
          ),
        );
        expect(closed, 0);
        auth.change(
          const AuthAuthenticated(
            profile: UserProfile(
              id: 'legacy-second',
              clubId: '1',
              publicUserId: 'synthetic',
            ),
          ),
        );
        expect(closed, 1);
        auth.change(
          const AuthAuthenticated(
            profile: UserProfile(
              id: 'legacy-second',
              clubId: '2',
              publicUserId: 'synthetic',
            ),
          ),
        );
        expect(closed, 2);
        auth.change(const AuthUnauthenticated());
        expect(closed, 3);
        await tester.pump();
        expect(find.text('Independent identity entry'), findsOneWidget);
        final routeInformation = GoRouter.of(
          tester.element(find.text('Independent identity entry')),
        ).routeInformationProvider;
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        expect(() => routeInformation.addListener(() {}), throwsFlutterError);
      },
    );

    for (final path in ['/settings', '/admin']) {
      testWidgets('foreign-club grant cannot authorize $path', (tester) async {
        await tester.pumpWidget(
          AfriClubApp(
            config: const _FakeClubConfig(clubId: '2'),
            modules: [
              _HomeModule(),
              _OnboardingModule(),
              _SettingsModule(),
              _AdminModule(),
            ],
            authRepository: FakeAuthRepository(clubId: '2'),
            initialLocation: path,
            providerOverrides: [
              authStateProvider.overrideWith(_AccountTransitionNotifier.new),
            ],
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(_FakePhoneAuthScreen), findsOneWidget);
        expect(find.text('reauth-from:$path'), findsOneWidget);
        expect(find.byType(_FakeSettingsScreen), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }

    for (final signedIn in [false, true]) {
      testWidgets(
        'independent identity entry stays reachable without a Supabase grant ($signedIn)',
        (tester) async {
          await tester.pumpWidget(
            AfriClubApp(
              config: config,
              modules: [
                _HomeModule(),
                _OnboardingModule(),
                _SettingsModule(),
                _IndependentIdentityModule(),
              ],
              authRepository: FakeAuthRepository(
                restoreResult: signedIn
                    ? const UserProfile(
                        id: 'user-1',
                        clubId: '1',
                        publicUserId: '483912',
                      )
                    : null,
              ),
              initialLocation: '/native-identity-entry',
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('Independent identity entry'), findsOneWidget);
          expect(find.byType(_FakeOnboardingScreen), findsNothing);
          expect(find.byType(_FakeHomeScreen), findsNothing);
          final context = tester.element(
            find.text('Independent identity entry'),
          );
          GoRouter.of(context).go('/settings');
          await tester.pumpAndSettle();
          expect(
            find.byType(signedIn ? _FakeSettingsScreen : _FakeOnboardingScreen),
            findsOneWidget,
          );
        },
      );
    }

    for (final hasMomo in [true, false]) {
      testWidgets(
        'startup restores a user from the retired splash alias (MOMO: $hasMomo)',
        (tester) async {
          await tester.pumpWidget(
            AfriClubApp(
              config: config,
              modules: [_HomeModule(), _OnboardingModule(), _SettingsModule()],
              authRepository: FakeAuthRepository(
                restoreResult: UserProfile(
                  id: 'user-1',
                  clubId: '1',
                  publicUserId: '483912',
                  momoNumber: hasMomo ? '0781234567' : null,
                  momoProvider: hasMomo ? 'MoMo' : null,
                ),
              ),
              initialLocation: '/splash',
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(_FakeHomeScreen), findsOneWidget);
          expect(find.byType(_FakeOnboardingScreen), findsNothing);
        },
      );
    }

    testWidgets('applies the OS high-contrast variant to routed content', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(highContrast: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );

      await tester.pumpWidget(
        AfriClubApp(
          config: config,
          modules: <FeatureModule>[
            _HomeModule(),
            _OnboardingModule(),
            _SettingsModule(),
          ],
          authRepository: FakeAuthRepository(
            restoreResult: const UserProfile(
              id: 'user-1',
              clubId: '1',
              publicUserId: '483912',
            ),
          ),
          initialLocation: '/home',
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(_FakeHomeScreen));
      final theme = Theme.of(context);
      expect(theme.extension<AfriDesignTokens>()!.focusRingWidth, equals(4));
      expect(
        theme.extension<AfriSemanticColors>()!.secondaryText,
        theme.extension<AfriSemanticColors>()!.primaryText,
      );
    });

    testWidgets(
      'redirects unauthenticated deep links to onboarding through splash recovery',
      (tester) async {
        await tester.pumpWidget(
          AfriClubApp(
            config: config,
            modules: <FeatureModule>[
              _HomeModule(),
              _OnboardingModule(),
              _SettingsModule(),
              _AdminModule(),
            ],
            authRepository: FakeAuthRepository(restoreResult: null),
            initialLocation: '/settings',
          ),
        );

        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byType(_FakeOnboardingScreen), findsOneWidget);
        final context = tester.element(find.byType(_FakeOnboardingScreen));
        expect(
          GoRouterState.of(context).uri.queryParameters['from'],
          '/settings',
        );
      },
    );

    testWidgets(
      'redirects an expired startup session to reauthentication with destination',
      (tester) async {
        await tester.pumpWidget(
          AfriClubApp(
            config: config,
            modules: <FeatureModule>[
              _HomeModule(),
              _OnboardingModule(),
              _SettingsModule(),
            ],
            authRepository: FakeAuthRepository(
              restoreError: StateError('expired session'),
            ),
            initialLocation: '/settings/notifications',
          ),
        );

        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byType(_FakePhoneAuthScreen), findsOneWidget);
        expect(
          find.text('reauth-from:/settings/notifications'),
          findsOneWidget,
        );
      },
    );

    for (final malformed in ['%FF', '%2Fsettings%2F%25FF']) {
      testWidgets(
        'rejects malformed deferred destination $malformed after authentication',
        (tester) async {
          await tester.pumpWidget(
            AfriClubApp(
              config: config,
              modules: [_HomeModule(), _OnboardingModule(), _SettingsModule()],
              authRepository: FakeAuthRepository(
                restoreResult: const UserProfile(
                  id: 'user-1',
                  clubId: '1',
                  publicUserId: '483912',
                ),
              ),
              initialLocation: '/onboarding?from=$malformed',
            ),
          );
          await tester.pump();
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.byType(_FakeHomeScreen), findsOneWidget);
          expect(find.byType(_FakeSettingsScreen), findsNothing);
        },
      );
    }

    testWidgets('rejects external deferred destinations after authentication', (
      tester,
    ) async {
      await tester.pumpWidget(
        AfriClubApp(
          config: config,
          modules: <FeatureModule>[
            _HomeModule(),
            _OnboardingModule(),
            _SettingsModule(),
          ],
          authRepository: FakeAuthRepository(
            restoreResult: const UserProfile(
              id: 'user-1',
              clubId: '1',
              publicUserId: '483912',
            ),
          ),
          initialLocation:
              '/onboarding?from=https%3A%2F%2Fattacker.example%2Fsettings',
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(_FakeHomeScreen), findsOneWidget);
      expect(find.byType(_FakeSettingsScreen), findsNothing);
    });

    testWidgets(
      'redirects non-admin authenticated deep links away from admin routes',
      (tester) async {
        await tester.pumpWidget(
          AfriClubApp(
            config: config,
            modules: <FeatureModule>[
              _HomeModule(),
              _OnboardingModule(),
              _SettingsModule(),
              _AdminModule(),
            ],
            authRepository: FakeAuthRepository(
              restoreResult: const UserProfile(
                id: 'user-1',
                clubId: '1',
                publicUserId: '483912',
              ),
            ),
            initialLocation: '/admin',
          ),
        );

        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byType(_FakeSettingsScreen), findsOneWidget);
        expect(find.byType(_FakeOnboardingScreen), findsNothing);
      },
    );

    testWidgets(
      'routes an involuntary session loss to reauthentication and preserves destination',
      (tester) async {
        final authChanges = StreamController<supabase.AuthState>();
        addTearDown(authChanges.close);
        await tester.pumpWidget(
          AfriClubApp(
            config: config,
            modules: <FeatureModule>[
              _HomeModule(),
              _OnboardingModule(),
              _SettingsModule(),
            ],
            authRepository: FakeAuthRepository(
              restoreResult: const UserProfile(
                id: 'user-1',
                clubId: '1',
                publicUserId: '483912',
              ),
              authChanges: authChanges.stream,
            ),
            initialLocation: '/settings',
          ),
        );

        await tester.pump();
        await tester.pumpAndSettle();
        expect(find.byType(_FakeSettingsScreen), findsOneWidget);

        authChanges.add(
          const supabase.AuthState(supabase.AuthChangeEvent.signedOut, null),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byType(_FakePhoneAuthScreen), findsOneWidget);
        expect(find.text('reauth-from:/settings'), findsOneWidget);
      },
    );

    testWidgets('redirects disabled deep links to the unavailable screen', (
      tester,
    ) async {
      await tester.pumpWidget(
        AfriClubApp(
          config: config,
          modules: <FeatureModule>[
            _HomeModule(),
            _OnboardingModule(),
            _SettingsModule(),
            _AdminModule(),
            _TicketsModule(),
          ],
          authRepository: FakeAuthRepository(
            restoreResult: const UserProfile(
              id: 'user-1',
              clubId: '1',
              publicUserId: '483912',
            ),
          ),
          platformConfigSnapshot: <String, dynamic>{
            'channel': 'mobile',
            'features': <Map<String, dynamic>>[
              <String, dynamic>{
                'feature_key': 'ticketing',
                'display_name': 'Ticketing',
                'is_enabled': true,
                'visibility_state': 'hidden',
                'channel': <String, dynamic>{
                  'is_enabled': true,
                  'is_visible': false,
                  'show_in_navigation': false,
                  'show_on_home': false,
                  'route_key': '/tickets',
                },
              },
            ],
            'content_blocks': const <Map<String, dynamic>>[],
          },
          initialLocation: '/tickets',
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      expect(
        find.text('This feature is currently unavailable.'),
        findsOneWidget,
      );
      expect(find.text('Tickets'), findsNothing);
    });

    testWidgets('preserves 200 percent platform text scaling', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(
        AfriClubApp(
          config: config,
          modules: <FeatureModule>[_HomeModule(), _OnboardingModule()],
          authRepository: FakeAuthRepository(
            restoreResult: const UserProfile(
              id: 'user-1',
              clubId: '1',
              publicUserId: '483912',
            ),
          ),
          initialLocation: '/home',
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('text-scale:2.0'), findsOneWidget);
    });

    testWidgets(
      'adapts bottom navigation to a tablet rail while preserving branch state',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          AfriClubApp(
            config: config,
            modules: <FeatureModule>[
              _HomeModule(),
              _ClubModule(),
              _PredictModule(),
              _MembershipModule(),
              _OnboardingModule(),
              _SettingsModule(),
            ],
            authRepository: FakeAuthRepository(
              restoreResult: const UserProfile(
                id: 'user-1',
                clubId: '1',
                publicUserId: '483912',
              ),
            ),
            initialLocation: '/home',
          ),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byType(AfriClubBottomNav), findsOneWidget);
        expect(find.byType(NavigationRail), findsNothing);
        await tester.enterText(
          find.byKey(const ValueKey('home-route-draft')),
          'Preserve this draft',
        );
        await tester.tap(find.text('Membership'));
        await tester.pumpAndSettle();
        expect(find.byType(_FakeSettingsScreen), findsOneWidget);

        tester.view.physicalSize = const Size(834, 1194);
        await tester.pumpAndSettle();

        expect(find.byType(AfriClubBottomNav), findsNothing);
        expect(find.byType(NavigationRail), findsOneWidget);
        final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
        rail.onDestinationSelected!(0);
        await tester.pumpAndSettle();

        expect(
          tester
              .widget<TextField>(find.byKey(const ValueKey('home-route-draft')))
              .controller
              ?.text,
          'Preserve this draft',
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'deep-linked full-height task pops back to its canonical parent',
      (tester) async {
        await tester.pumpWidget(
          AfriClubApp(
            config: config,
            modules: <FeatureModule>[
              _HomeModule(),
              _OnboardingModule(),
              _SettingsModule(),
            ],
            authRepository: FakeAuthRepository(
              restoreResult: const UserProfile(
                id: 'user-1',
                clubId: '1',
                publicUserId: '483912',
              ),
            ),
            initialLocation: '/settings/edit-profile',
          ),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byType(_FakeSettingsDetailScreen), findsOneWidget);
        final context = tester.element(find.byType(_FakeSettingsDetailScreen));
        GoRouter.of(context).pop();
        await tester.pumpAndSettle();

        expect(find.byType(_FakeSettingsDetailScreen), findsNothing);
        expect(find.byType(_FakeSettingsScreen), findsOneWidget);
      },
    );

    testWidgets('uses one hinge-safe mobile shell on a dual-screen posture', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(850, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(850, 900),
            platformBrightness: Brightness.dark,
            displayFeatures: [
              ui.DisplayFeature(
                bounds: Rect.fromLTWH(417, 0, 16, 900),
                type: ui.DisplayFeatureType.hinge,
                state: ui.DisplayFeatureState.postureHalfOpened,
              ),
            ],
          ),
          child: AfriClubApp(
            config: config,
            modules: <FeatureModule>[
              _HomeModule(),
              _ClubModule(),
              _PredictModule(),
              _MembershipModule(),
              _OnboardingModule(),
              _SettingsModule(),
            ],
            authRepository: FakeAuthRepository(
              restoreResult: const UserProfile(
                id: 'user-1',
                clubId: '1',
                publicUserId: '483912',
              ),
            ),
            initialLocation: '/home',
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(AfriClubBottomNav), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
      final shellRect = tester.getRect(find.byType(AfriClubBottomNav));
      expect(shellRect.right, lessThanOrEqualTo(417));
      expect(tester.takeException(), isNull);
    });

    testWidgets('golden adaptive shell uses a tablet rail', (tester) async {
      tester.view.physicalSize = const Size(834, 1194);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      await tester.pumpWidget(
        AfriClubApp(
          config: config,
          modules: <FeatureModule>[
            _HomeModule(),
            _ClubModule(),
            _PredictModule(),
            _MembershipModule(),
            _OnboardingModule(),
            _SettingsModule(),
          ],
          authRepository: FakeAuthRepository(
            restoreResult: const UserProfile(
              id: 'user-1',
              clubId: '1',
              publicUserId: '483912',
            ),
          ),
          initialLocation: '/home',
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(NavigationRail), findsOneWidget);
      await expectLater(
        find.byKey(const ValueKey('adaptive-app-shell')),
        matchesGoldenFile('goldens/adaptive_shell_tablet_dark_834x1194.png'),
      );
    });

    testWidgets('golden adaptive shell avoids a separating hinge', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(850, 900);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(850, 900),
            platformBrightness: Brightness.dark,
            displayFeatures: [
              ui.DisplayFeature(
                bounds: Rect.fromLTWH(417, 0, 16, 900),
                type: ui.DisplayFeatureType.hinge,
                state: ui.DisplayFeatureState.postureHalfOpened,
              ),
            ],
          ),
          child: AfriClubApp(
            config: config,
            modules: <FeatureModule>[
              _HomeModule(),
              _ClubModule(),
              _PredictModule(),
              _MembershipModule(),
              _OnboardingModule(),
              _SettingsModule(),
            ],
            authRepository: FakeAuthRepository(
              restoreResult: const UserProfile(
                id: 'user-1',
                clubId: '1',
                publicUserId: '483912',
              ),
            ),
            initialLocation: '/home',
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(AfriClubBottomNav), findsOneWidget);
      await expectLater(
        find.byKey(const ValueKey('adaptive-app-shell')),
        matchesGoldenFile('goldens/adaptive_shell_hinge_dark_850x900.png'),
      );
    });
  });
}

Future<ByteData> _loadFlutterArtifactFont(String fileName) async {
  try {
    return await rootBundle.load('packages/flutter/fonts/$fileName');
  } on Object {
    final flutterExecutable =
        (Process.runSync('which', <String>['flutter']).stdout as String).trim();
    final flutterRoot = File(flutterExecutable).resolveSymbolicLinksSync();
    final bytes = await File(
      '${File(flutterRoot).parent.parent.path}/bin/cache/artifacts/material_fonts/$fileName',
    ).readAsBytes();
    return ByteData.sublistView(bytes);
  }
}

class _IndependentIdentityModule extends FeatureModule {
  @override
  String get featureKey => 'membership';
  @override
  Set<String> get independentlyAuthenticatedPaths => const {
    '/native-identity-entry',
  };
  @override
  List<RouteBase> get routes => [
    GoRoute(
      path: '/native-identity-entry',
      builder: (context, state) =>
          const Scaffold(body: Text('Independent identity entry')),
    ),
  ];
}

class _FakeOnboardingScreen extends StatelessWidget {
  const _FakeOnboardingScreen();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Text('Onboarding'));
}

class _FakePhoneAuthScreen extends StatelessWidget {
  const _FakePhoneAuthScreen({required this.from});

  final String? from;

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Text('reauth-from:${from ?? 'none'}'));
}

class _FakeSettingsScreen extends StatelessWidget {
  const _FakeSettingsScreen();

  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('Settings'));
}

class _AccountTransitionNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthAuthenticated(
    profile: UserProfile(
      id: 'legacy-first',
      clubId: '1',
      publicUserId: 'synthetic',
    ),
  );
  void change(AuthState next) {
    state = next;
  }
}

class FakeAuthRepository extends AuthRepository {
  FakeAuthRepository({
    super.clubId = '1',
    this.restoreResult,
    this.restoreError,
    this.adminAccess = AdminWorkspaceAccess.none,
    this.authChanges,
  });

  final UserProfile? restoreResult;
  final Object? restoreError;
  final AdminWorkspaceAccess adminAccess;
  final Stream<supabase.AuthState>? authChanges;
  int authenticationInvalidations = 0;

  @override
  void invalidatePendingAuthentication() {
    authenticationInvalidations++;
    super.invalidatePendingAuthentication();
  }

  @override
  Future<UserProfile?> restoreCurrentUser() async {
    if (restoreError != null) {
      throw restoreError!;
    }
    return restoreResult;
  }

  @override
  Future<void> signOut() async {}

  @override
  Future<AdminWorkspaceAccess> resolveAdminAccess(String userId) async {
    return adminAccess;
  }

  @override
  Stream<supabase.AuthState> get authStateChanges =>
      authChanges ?? const Stream<supabase.AuthState>.empty();
}

class _FakeClubConfig implements ClubConfig {
  const _FakeClubConfig({this.clubId = '1'});

  @override
  String get appName => 'AFRICLUB Test';

  @override
  final String clubId;

  @override
  String get clubName => 'AFRICLUB Test Club';

  @override
  ClubColors get colors => const ClubColors(
    primary: ColorTokens.referenceAccountBlue,
    secondary: ColorTokens.referenceChromeBlack,
    accent: ColorTokens.referenceRewardsVioletHot,
    gradient: <Color>[
      ColorTokens.referenceChromeBlack,
      ColorTokens.referenceAccountBlue,
    ],
  );

  @override
  String get country => 'Rwanda';

  @override
  String get countryCode => 'RW';
  @override
  String get currency => 'RWF';

  @override
  String get currencySymbol => 'RWF';

  @override
  bool get hasChat => false;

  @override
  bool get hasFanClubs => false;

  @override
  bool get hasShop => false;

  @override
  bool get hasTicketing => false;

  @override
  Map<String, bool> get features => const <String, bool>{
    'home': true,
    'onboarding': true,
    'settings': true,
    'admin': true,
    'ticketing': true,
  };

  @override
  String get language => 'en';

  @override
  String get momoPrefix => '*182*';

  @override
  MomoConfig get momo => const MomoConfig(
    ussdTemplate: '*182*8*1*{amount}*{momo}#',
    countryCode: 'RW',
  );

  @override
  String get supabaseAnonKey => 'anon';

  @override
  String get supabaseUrl => 'https://example.supabase.co';

  @override
  List<String> get supportedLanguages => const <String>['en'];

  @override
  String get environment => 'test';
}

class _HomeModule extends FeatureModule {
  @override
  String get featureKey => 'home';

  @override
  List<RouteBase> get routes => const <RouteBase>[];

  @override
  TabRoute get tabRoute => TabRoute(
    path: '/home',
    label: 'Home',
    icon: AfriIcons.home,
    activeIcon: AfriIcons.home,
    builder: (context, state) => const _FakeHomeScreen(),
  );
}

class _FakeHomeScreen extends StatefulWidget {
  const _FakeHomeScreen();

  @override
  State<_FakeHomeScreen> createState() => _FakeHomeScreenState();
}

class _FakeHomeScreenState extends State<_FakeHomeScreen> {
  final TextEditingController _draftController = TextEditingController();

  @override
  void dispose() {
    _draftController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1).toStringAsFixed(1);
    return Scaffold(
      body: Column(
        children: [
          Text('text-scale:$scale'),
          TextField(
            key: const ValueKey('home-route-draft'),
            controller: _draftController,
          ),
        ],
      ),
    );
  }
}

class _OnboardingModule extends FeatureModule {
  @override
  String get featureKey => 'onboarding';

  @override
  List<RouteBase> get routes => <RouteBase>[
    GoRoute(
      path: '/splash',
      redirect: (context, state) => Uri(
        path: '/onboarding',
        queryParameters: state.uri.queryParameters.isEmpty
            ? null
            : state.uri.queryParameters,
      ).toString(),
    ),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const _FakeOnboardingScreen(),
    ),
    GoRoute(
      path: '/auth/phone',
      builder: (context, state) =>
          _FakePhoneAuthScreen(from: state.uri.queryParameters['from']),
    ),
  ];

  @override
  Set<String> get publicPaths => const <String>{
    '/splash',
    '/onboarding',
    '/auth/phone',
  };
}

class _SettingsModule extends FeatureModule {
  @override
  String get featureKey => 'settings';

  @override
  TabRoute get tabRoute => TabRoute(
    path: '/settings',
    label: 'Settings',
    icon: AfriIcons.settings,
    activeIcon: AfriIcons.settings,
    builder: (context, state) => const _FakeSettingsScreen(),
  );

  @override
  List<RouteBase> get routes => <RouteBase>[
    GoRoute(
      path: 'edit-profile',
      pageBuilder: (context, state) => afriSheetPage(
        state,
        const _FakeSettingsDetailScreen(),
        fullHeight: true,
      ),
    ),
    GoRoute(
      path: 'notifications',
      pageBuilder: (context, state) => afriSheetPage(
        state,
        const _FakeSettingsDetailScreen(),
        fullHeight: true,
      ),
    ),
  ];
}

class _ClubModule extends FeatureModule {
  @override
  String get featureKey => 'club';

  @override
  TabRoute get tabRoute => TabRoute(
    path: '/club',
    label: 'Club',
    icon: AfriIcons.clubZone,
    activeIcon: AfriIcons.clubZone,
    builder: (context, state) => const Scaffold(body: Text('Club')),
  );
}

class _PredictModule extends FeatureModule {
  @override
  String get featureKey => 'predict';

  @override
  TabRoute get tabRoute => TabRoute(
    path: '/predict',
    label: 'Predict',
    icon: AfriIcons.bolt,
    activeIcon: AfriIcons.bolt,
    builder: (context, state) => const Scaffold(body: Text('Predict')),
  );
}

class _MembershipModule extends FeatureModule {
  @override
  String get featureKey => 'membership';

  @override
  TabRoute get tabRoute => TabRoute(
    path: '/membership',
    label: 'Membership',
    icon: AfriIcons.membership,
    activeIcon: AfriIcons.membership,
    builder: (context, state) => const _FakeSettingsScreen(),
  );
}

class _FakeSettingsDetailScreen extends StatelessWidget {
  const _FakeSettingsDetailScreen();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Text('Settings detail'));
}

class _AdminModule extends FeatureModule {
  @override
  String get featureKey => 'admin';

  @override
  List<RouteBase> get routes => <RouteBase>[
    GoRoute(
      path: '/admin',
      builder: (context, state) => const Scaffold(body: Text('Admin')),
    ),
  ];
}

class _TicketsModule extends FeatureModule {
  @override
  String get featureKey => 'ticketing';

  @override
  List<RouteBase> get routes => <RouteBase>[
    GoRoute(
      path: '/tickets',
      builder: (context, state) => const Scaffold(body: Text('Tickets')),
    ),
  ];
}
