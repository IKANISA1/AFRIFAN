import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../app_registry/tool/generate_route_inventory.dart';

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
}
