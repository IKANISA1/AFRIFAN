import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:app_registry/app_registry.dart';
import 'package:core_app/core_app.dart';
import 'package:core_auth/core_auth.dart';
import 'package:core_network/core_network.dart';
import 'package:core_router/core_router.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:test_support/app_font_loader.dart';

import '../../../app_registry/tool/generate_route_inventory.dart';
import '../../../core/core_app/test/app_routing_guard_test.dart'
    show FakeAuthRepository;
import 'fixtures/five_club_configs.dart';
import 'fixtures/local_route_state_assertions.dart';

// These fixtures retain every production module redirect and root admission
// callback. Inert destination builders isolate navigation proof; they provide
// no rendered state, screenshot, or accessibility credit for the destination.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await loadAppFonts();
    TypographyTokens.debugUseFallbackFonts = true;
  });
  tearDownAll(() => TypographyTokens.debugUseFallbackFonts = false);
  final workspace = resolveRouteInventoryWorkspace(Directory.current);
  for (final club in fiveClubFixtures(workspace).entries) {
    group('five club ${club.key} genuine alias navigation', () {
      setUp(() {
        localRouteFixtureConfig = club.value;
        localRouteFixtureClub = club.key;
        ColorTokens.init();
        ColorTokens.setBrightness(Brightness.dark);
      });
      tearDown(() {
        localRouteFixtureConfig = null;
        localRouteFixtureClub = null;
      });
      const deniedAliases = <String, String>{
        '/club/projects': '/contribute?type=project',
        '/club/projects/:projectId': '/contribute/group/local-item',
        '/contribute/groups': '/contribute/groups',
        '/contribute/projects': '/contribute/projects',
        '/live': '/live',
        '/live-match': '/live-match',
        '/live/news/:articleId': '/live/news/local-item',
        '/membership/fans': '/membership/fans',
        '/my-tickets': '/my-tickets',
        '/admin/settle': '/admin/settle',
      };
      for (final alias in deniedAliases.entries) {
        testWidgets('actual admission denied ${alias.key}', (tester) async {
          final requested = _examplePath(alias.key);
          final visited = <Uri>[];
          final callbacks = <String>[];
          final admin = alias.key == '/admin/settle';
          final auth = admin
              ? AuthAuthenticated(
                  profile: UserProfile(
                    id: 'local-account',
                    clubId: club.value.clubId,
                    publicUserId: 'local-account',
                  ),
                )
              : const AuthUnauthenticated();
          await tester.pumpWidget(
            AfriClubApp(
              config: club.value,
              modules: _navigationModules(club.value, visited, callbacks),
              authRepository: FakeAuthRepository(clubId: club.value.clubId),
              initialLocation: requested,
              providerOverrides: [
                authStateProvider.overrideWith(() => _CachedAuth(auth)),
              ],
            ),
          );
          await tester.pumpAndSettle();
          final destination = visited.last;
          expect(destination.path, admin ? '/settings' : '/onboarding');
          if (!admin) {
            expect(destination.queryParameters['from'], alias.value);
          }
          if (alias.key.startsWith('/club/projects')) {
            expect(callbacks, contains(requested));
            expect(
              visited.any((uri) => uri.path.startsWith('/contribute')),
              isFalse,
              reason:
                  'The real canonical target admission denies before build.',
            );
          } else {
            expect(
              callbacks,
              isNot(contains(requested)),
              reason: 'Root admission denies before the alias callback.',
            );
          }
          expect(tester.takeException(), isNull);
          emitLocalNavigationAssertion(
            route: alias.key,
            state: 'permission_denied',
            surface: admin ? 'mobile_internal_admin' : 'mobile',
          );
          await tester.pumpWidget(const SizedBox.shrink());
        });
      }

      const forwarding = <String, String>{
        '/club/partners/local-item': '/club/partners?partner=local-item',
        '/club/results': '/club/fixtures?tab=results',
        '/club/projects': '/contribute?type=project',
        '/club/projects/local-item': '/contribute/group/local-item',
        '/contribute/groups': '/contribute?type=community',
        '/contribute/projects': '/contribute?type=project',
        '/fan-clubs/local-item': '/fan-clubs?club=local-item',
        '/live': '/predict/match/live',
        '/live-match': '/predict/match/live',
        '/live/news/local-item': '/club/news/local-item',
        '/membership/fans': '/fan-clubs',
        '/my-tickets': '/tickets?tab=mine',
        '/splash': '/onboarding',
        '/admin/settle': '/admin/predict',
        '/splash?from=%FF': '/onboarding',
        '/splash?from=%2Fclub%2Fnews%2Flocal-item':
            '/onboarding?from=%2Fclub%2Fnews%2Flocal-item',
      };
      for (final alias in forwarding.entries) {
        testWidgets('actual callback traverses ${alias.key}', (tester) async {
          final visited = <Uri>[];
          final callbacks = <String>[];
          final router = AppRouter(
            modules: _navigationModules(club.value, visited, callbacks),
            initialLocation: alias.key,
            shellBuilder: (_, shell) => Scaffold(body: shell),
          ).router;
          addTearDown(router.dispose);
          await tester.pumpWidget(
            MaterialApp.router(
              routerConfig: router,
              theme: ClubTheme.from(club.value, brightness: Brightness.dark),
              builder: (context, child) => ClubConfigScope(
                config: club.value,
                child: RepaintBoundary(
                  key: const ValueKey('alias-navigation-boundary'),
                  child: child!,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final missingFanClubs =
              club.value.features['fan_clubs'] == false &&
              (alias.key == '/fan-clubs/local-item' ||
                  alias.key == '/membership/fans');
          final missingTickets =
              club.value.features['ticketing'] == false &&
              alias.key == '/my-tickets';
          if (missingFanClubs || missingTickets) {
            expect(visited, isEmpty);
            final recovery = tester.widget<RouteRecoveryScreen>(
              find.byType(RouteRecoveryScreen),
            );
            expect(recovery.kind, RouteRecoveryKind.routerError);
            expect(recovery.visualState, RouteRecoveryVisualState.error);
            expect(
              recovery.requestedPath,
              alias.key == '/membership/fans' ? '/fan-clubs' : alias.key,
            );
            expect(recovery.fallbackLocation, '/home');
            expect(
              callbacks.contains(Uri.parse(alias.key).path),
              alias.key == '/membership/fans',
              reason: 'Only MembershipModule remains registered in this club.',
            );
            await expectGoldenOrClubAssertions(
              tester,
              find.byKey(const ValueKey('alias-navigation-boundary')),
              'unregistered_alias_state_error.png',
              route: '<router-error>',
              kind: 'error_path',
            );
            await tester.tap(find.widgetWithText(AfriButton, 'Go home'));
            await tester.pumpAndSettle();
            expect(visited.last.path, '/home');
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
            return;
          }
          expect(visited.last.toString(), alias.value);
          expect(callbacks, contains(Uri.parse(alias.key).path));
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        });
      }

      for (final outcome in [
        'loading',
        'empty',
        'error',
        'offline',
        'permission_denied',
        'conflict',
        'security_timeout',
      ]) {
        testWidgets('actual open-web resolver $outcome', (tester) async {
          final requests = <http.Request>[];
          final held = Completer<http.Response>();
          final client = (await tester.runAsync(() async {
            final client = supabase.SupabaseClient(
              'https://local-link.invalid',
              'local-unused-key',
              authOptions: const supabase.AuthClientOptions(
                autoRefreshToken: false,
              ),
              httpClient: MockClient((request) async {
                requests.add(request);
                if (outcome == 'offline') {
                  throw const SocketException('local controlled offline');
                }
                if (outcome == 'loading' || outcome == 'security_timeout') {
                  return held.future;
                }
                final status = switch (outcome) {
                  'permission_denied' => 403,
                  'conflict' => 409,
                  'error' => 500,
                  _ => 200,
                };
                return http.Response(
                  status == 200
                      ? 'null'
                      : jsonEncode({
                          'code': status == 403
                              ? '42501'
                              : status == 409
                              ? '40001'
                              : 'XX000',
                          'message': 'Local controlled link outcome',
                        }),
                  status,
                  headers: {'content-type': 'application/json'},
                  request: request,
                );
              }),
            );
            await client.auth.setInitialSession(_session(club.value.clubId));
            return client;
          }))!;
          addTearDown(() => tester.runAsync(client.dispose));
          final visited = <Uri>[];
          final callbacks = <String>[];
          final router = AppRouter(
            modules: _navigationModules(club.value, visited, callbacks),
            initialLocation: '/club/open-web?path=%2Fnews%2Flocal-item',
            shellBuilder: (_, shell) => Scaffold(body: shell),
          ).router;
          addTearDown(router.dispose);
          await tester.pumpWidget(
            ProviderScope(
              overrides: [supabaseClientProvider.overrideWithValue(client)],
              child: MaterialApp.router(routerConfig: router),
            ),
          );
          for (var i = 0; i < 20 && requests.isEmpty; i++) {
            await tester.pump(const Duration(milliseconds: 1));
          }
          expect(requests, hasLength(1));
          final request = requests.single;
          expect(request.url.path, '/rest/v1/rpc/resolve_club_public_link_v1');
          expect(jsonDecode(request.body), {
            'p_club_id': int.parse(club.value.clubId),
            'p_source_path': '/news/local-item',
          });
          expect(callbacks, contains('/club/open-web'));
          if (outcome == 'loading') {
            expect(
              visited,
              isEmpty,
              reason: 'A held real RPC must not build a premature target.',
            );
            emitLocalNavigationAssertion(
              route: '/club/open-web',
              state: outcome,
            );
            held.complete(
              http.Response(
                'null',
                200,
                headers: {'content-type': 'application/json'},
                request: request,
              ),
            );
          }
          if (outcome == 'security_timeout') {
            await tester.pump(const Duration(seconds: 12, milliseconds: 1));
          }
          await tester.pumpAndSettle();
          expect(visited.last.path, '/club/news');
          expect(
            requests,
            hasLength(1),
            reason: 'Fallback must not retry upstream.',
          );
          expect(tester.takeException(), isNull);
          if (outcome != 'loading') {
            emitLocalNavigationAssertion(
              route: '/club/open-web',
              state: outcome,
            );
          }
          if (outcome == 'security_timeout') {
            held.complete(
              http.Response(
                'null',
                200,
                headers: {'content-type': 'application/json'},
                request: request,
              ),
            );
            await tester.pump();
            expect(visited.last.path, '/club/news');
            expect(requests, hasLength(1));
          }
          await tester.pumpWidget(const SizedBox.shrink());
        });
      }
    });
  }
}

String _examplePath(String path) => path
    .split('/')
    .map((part) => part.startsWith(':') ? 'local-item' : part)
    .join('/');

String _session(String clubId) => jsonEncode({
  'access_token': 'local-unused-token',
  'refresh_token': 'local-unused-refresh',
  'token_type': 'bearer',
  'expires_in': 3600,
  'user': {
    'id': 'local-account',
    'aud': 'authenticated',
    'app_metadata': {'club_id': int.parse(clubId)},
    'user_metadata': {},
    'created_at': '2026-09-30T00:00:00Z',
  },
});

class _CachedAuth extends AuthNotifier {
  _CachedAuth(this.cached);
  final AuthState cached;
  @override
  AuthState build() => cached;
  @override
  Future<void> restore() async {}
}

List<FeatureModule> _navigationModules(
  ClubConfig config,
  List<Uri> visited,
  List<String> callbacks,
) {
  final modules = AppModuleRegistry.build(
    internalAdminFixtureConfig(config),
    allowInternalMobileAdmin: true,
  ).toList();
  // Both actual internal-build gates are explicit; omitted consumer modules
  // are never appended to the configured registry.
  return modules
      .map((module) => _NavigationModule(module, visited, callbacks))
      .toList();
}

class _NavigationModule extends FeatureModule {
  _NavigationModule(this.base, this.visited, this.callbacks);
  final FeatureModule base;
  final List<Uri> visited;
  final List<String> callbacks;
  @override
  String get featureKey => base.featureKey;
  @override
  Set<String> get publicPaths => base.publicPaths;
  @override
  Set<String> get independentlyAuthenticatedPaths =>
      base.independentlyAuthenticatedPaths;
  Widget _target(BuildContext _, GoRouterState state) {
    visited.add(state.uri);
    return Text('Navigation target: ${state.uri}');
  }

  @override
  TabRoute? get tabRoute {
    final tab = base.tabRoute;
    return tab == null
        ? null
        : TabRoute(
            path: tab.path,
            label: tab.label,
            icon: tab.icon,
            activeIcon: tab.activeIcon,
            builder: _target,
          );
  }

  @override
  List<RouteBase> get routes => base.routes.map(_route).toList();
  @override
  List<RouteBase> get standaloneRoutes =>
      base.standaloneRoutes.map(_route).toList();
  RouteBase _route(RouteBase route) {
    if (route is! GoRoute) throw StateError('Unexpected module route type');
    final original = route.redirect;
    return GoRoute(
      path: route.path,
      name: route.name,
      builder: _target,
      redirect: original == null
          ? null
          : (context, state) {
              callbacks.add(state.uri.path);
              return original(context, state);
            },
      routes: route.routes.map(_route).toList(),
    );
  }
}
