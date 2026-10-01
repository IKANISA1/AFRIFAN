import 'dart:io';

import 'package:app_registry/app_registry.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../app_registry/tool/generate_route_inventory.dart';
import 'fixtures/five_club_configs.dart';
import 'fixtures/native_route_registration.dart';

void main() {
  test('current route discovery retains explicit unverified state cells', () {
    final workspace = resolveRouteInventoryWorkspace(Directory.current);
    const supplied = String.fromEnvironment('LOCAL_ROUTE_STATE_OUTPUT');
    final temporary = supplied.isEmpty
        ? Directory.systemTemp.createTempSync('africlub-route-discovery-')
        : null;
    if (temporary != null) {
      addTearDown(() => temporary.deleteSync(recursive: true));
    }
    final output = supplied.isEmpty ? temporary! : Directory(supplied);
    final result = generateRouteInventory(
      workspace: workspace,
      outputDirectory: output,
      registeredNativeFeaturesByClub: fiveClubFixtures(
        workspace,
      ).map((club, config) => MapEntry(club, registeredNativeFeatures(config))),
    );
    expect(result['duplicate_keys'], isEmpty);
    final routes = result['routes']! as List<Map<String, Object?>>;
    expect(routes, isNotEmpty);
    expect(
      routes.map((route) => route['surface']).toSet(),
      containsAll(<String>[
        'mobile',
        'mobile_internal_admin',
        'consumer_web',
        'admin_pwa',
        'web_api',
      ]),
    );
    final closure = result['state_closure']! as Map<String, Object?>;
    expect(closure['closure_complete'], isFalse);
    expect(closure['open_cell_count'], greaterThan(0));
    // Discovery is not execution of the listed UI states or acceptance.
    expect(closure['evidenced_cell_count'], 0);
  });

  test(
    'actual club registry excludes only explicit Costa native capabilities',
    () {
      final workspace = resolveRouteInventoryWorkspace(Directory.current);
      final fixtures = fiveClubFixtures(workspace);
      for (final club in fixtures.entries) {
        final registered = registeredNativeFeatures(club.value);
        final internal = internalAdminFixtureConfig(club.value);
        expect(internal.features, {
          ...club.value.features,
          'mobile_admin': true,
        });
        expect(
          AppModuleRegistry.build(
            club.value,
            allowInternalMobileAdmin: true,
          ).any((module) => module.featureKey == 'admin'),
          isFalse,
          reason: 'The registry argument alone cannot activate mobile admin.',
        );
        expect(
          AppModuleRegistry.build(
            internal,
            allowInternalMobileAdmin: false,
          ).any((module) => module.featureKey == 'admin'),
          isFalse,
          reason: 'The capability alone cannot activate mobile admin.',
        );
        expect(
          registered,
          containsAll(['membership', 'admin', 'home', 'club']),
        );
        for (final feature in ['fan_clubs', 'shop', 'ticketing']) {
          expect(
            registered.contains(feature),
            club.key != 'costa_do_sol',
            reason: '${club.key} $feature actual compiled registration',
          );
        }
      }
    },
  );
}
