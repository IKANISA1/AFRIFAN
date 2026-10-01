import 'dart:async';
import 'dart:io';

import 'package:app_registry/app_registry.dart';
import 'package:core_router/core_router.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_support/app_font_loader.dart';

import '../../../app_registry/tool/generate_route_inventory.dart';
import 'fixtures/five_club_configs.dart';
import 'fixtures/local_route_state_assertions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await loadAppFonts();
    TypographyTokens.debugUseFallbackFonts = true;
  });
  tearDownAll(() => TypographyTokens.debugUseFallbackFonts = false);
  final workspace = resolveRouteInventoryWorkspace(Directory.current);
  final temporary = Directory.systemTemp.createTempSync(
    'native-alias-catalog-',
  );
  final inventory = generateRouteInventory(
    workspace: workspace,
    outputDirectory: temporary,
  );
  tearDownAll(() => temporary.deleteSync(recursive: true));
  final routes = (inventory['routes']! as List<Map<String, Object?>>).where(
    (route) =>
        route['kind'] == 'redirect' &&
        (route['surface'] == 'mobile' ||
            route['surface'] == 'mobile_internal_admin'),
  );
  for (final club in fiveClubFixtures(workspace).entries) {
    for (final route in routes) {
      for (final state in ['error', 'permission_denied', 'security_timeout']) {
        testWidgets(
          'five club ${club.key} injected preflight ${route['path']} $state',
          (tester) async {
            localRouteFixtureConfig = club.value;
            localRouteFixtureClub = club.key;
            addTearDown(() {
              localRouteFixtureConfig = null;
              localRouteFixtureClub = null;
            });
            tester.view.physicalSize = const Size(390, 844);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final requested = (route['path']! as String)
                .split('/')
                .map(
                  (part) =>
                      part.startsWith(':') ? 'SENSITIVE_IDENTIFIER' : part,
                )
                .join('/');
            final visited = <String>[];
            final router = AppRouter(
              modules: AppModuleRegistry.build(
                club.value,
                allowInternalMobileAdmin: true,
              ),
              initialLocation: requested,
              shellBuilder: (_, shell) => Scaffold(body: shell),
              redirect: (_, value) {
                visited.add(value.uri.path);
                if (value.uri.path == requested) {
                  throw switch (state) {
                    'security_timeout' => TimeoutException('synthetic timeout'),
                    'permission_denied' => StateError(
                      'synthetic permission denied',
                    ),
                    _ => StateError('synthetic preflight failure'),
                  };
                }
                return null;
              },
            ).router;
            addTearDown(router.dispose);
            await tester.pumpWidget(
              MaterialApp.router(
                theme: ClubTheme.from(club.value, brightness: Brightness.dark),
                builder: (_, child) => ClubConfigScope(
                  config: club.value,
                  child: RepaintBoundary(
                    key: const ValueKey('alias-recovery'),
                    child: child!,
                  ),
                ),
                routerConfig: router,
              ),
            );
            await tester.pumpAndSettle();
            expect(
              visited,
              contains(requested),
              reason: 'Fault occurs at the actual requested alias preflight.',
            );
            expect(
              visited,
              isNot(contains(route['target_path'])),
              reason:
                  'Alias target must not receive authority after a failed preflight.',
            );
            final recovery = tester.widget<RouteRecoveryScreen>(
              find.byType(RouteRecoveryScreen),
            );
            expect(recovery.requestedPath, requested);
            expect(recovery.kind, RouteRecoveryKind.routerError);
            expect(recovery.visualState, switch (state) {
              'permission_denied' => RouteRecoveryVisualState.permissionDenied,
              'security_timeout' => RouteRecoveryVisualState.securityTimeout,
              _ => RouteRecoveryVisualState.error,
            });
            expect(find.textContaining('SENSITIVE'), findsNothing);
            await expectGoldenOrClubAssertions(
              tester,
              find.byKey(const ValueKey('alias-recovery')),
              'injected_preflight_state_$state.png',
              // Injected callback faults verify only the shared parser/recovery
              // contract, never an alias-owned operational state.
              route: '<router-error>',
              kind: 'error_path',
              surface: 'mobile',
            );
            await tester.pumpWidget(const SizedBox.shrink());
          },
        );
      }
    }
  }
}
