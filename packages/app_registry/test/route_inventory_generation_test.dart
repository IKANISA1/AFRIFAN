import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/generate_route_inventory.dart';

void main() {
  test('generates a complete multi-surface route inventory', () {
    const configuredOutput = String.fromEnvironment('ROUTE_INVENTORY_OUT_DIR');
    final workspace = Directory.current.absolute;
    final outputDirectory = Directory(
      configuredOutput.isEmpty
          ? '${workspace.path}/output/route_inventory_test'
          : configuredOutput,
    );

    final payload = generateRouteInventory(
      workspace: workspace,
      outputDirectory: outputDirectory,
    );
    final routes = payload['routes']! as List<Map<String, Object?>>;
    final routeKeys = routes
        .map((route) => '${route['surface']}|${route['path']}')
        .toSet();

    expect(payload['duplicate_keys'], isEmpty);
    expect(routes.length, greaterThan(100));
    expect(routeKeys, contains('mobile|/home'));
    expect(routeKeys, contains('mobile|/search'));
    expect(routeKeys, contains('native_tv|/tv/session'));
    expect(routeKeys, contains('admin_pwa|/admin'));
    expect(routeKeys, contains('venue_portal|/venue'));
    expect(routeKeys, contains('web_api|/api/search-index'));
    expect(
      File('${outputDirectory.path}/route-inventory.json').existsSync(),
      isTrue,
    );
    expect(
      File('${outputDirectory.path}/route-inventory.md').existsSync(),
      isTrue,
    );
    expect(
      File('${outputDirectory.path}/route-state-closure.json').existsSync(),
      isTrue,
    );
    expect(
      File('${outputDirectory.path}/route-state-closure.md').existsSync(),
      isTrue,
    );
    expect(
      File(
        '${outputDirectory.path}/screen-archetype-coverage.json',
      ).existsSync(),
      isTrue,
    );
    expect(
      File('${outputDirectory.path}/screen-archetype-coverage.md').existsSync(),
      isTrue,
    );
    final generatedClosure = payload['state_closure']! as Map<String, Object?>;
    expect(generatedClosure['evidenced_cell_count'], greaterThan(0));
    expect(generatedClosure['open_cell_count'], lessThan(1980));
    expect(generatedClosure['closure_complete'], isFalse);

    // A missing evidence overlay must retain the original fail-closed ledger
    // rather than promoting source discovery to behavioral or visual proof.
    final blankOutputDirectory = Directory.systemTemp.createTempSync(
      'africlub-route-state-blank-',
    );
    addTearDown(() {
      if (blankOutputDirectory.existsSync()) {
        blankOutputDirectory.deleteSync(recursive: true);
      }
    });
    final closure = generateRouteStateClosure(
      routes: routes,
      workspace: workspace,
      outputDirectory: blankOutputDirectory,
      evidenceFile: File(
        '${blankOutputDirectory.path}/missing-route-state-evidence.json',
      ),
    );
    final closureRoutes = closure['routes']! as List<Map<String, Object?>>;
    expect(closureRoutes, hasLength(routes.length));
    expect(closure['state_count'], routeClosureStates.length);
    expect(closure['cell_count'], routes.length * routeClosureStates.length);
    expect(closure['evidenced_cell_count'], 0);
    expect(closure['closure_complete'], isFalse);
    for (final route in closureRoutes) {
      final states = route['states']! as Map<String, Object?>;
      expect(states.keys.toSet(), routeClosureStates.toSet());
      for (final value in states.values) {
        final state = value! as Map<String, Object?>;
        expect(state['applicability'], anyOf('applicable', 'not_applicable'));
        expect(state['evidence_status'], isNot('required'));
        expect(state['test_evidence'], isEmpty);
        expect(state['screenshot_evidence'], isEmpty);
      }
    }
    final redirect = closureRoutes.firstWhere(
      (route) => route['kind'] == 'redirect',
    );
    final redirectStates = redirect['states']! as Map<String, Object?>;
    expect(
      (redirectStates['focused']! as Map<String, Object?>)['applicability'],
      'not_applicable',
    );
    expect(
      (redirectStates['permission_denied']!
          as Map<String, Object?>)['applicability'],
      'applicable',
    );
    final api = closureRoutes.firstWhere(
      (route) => route['kind'] == 'api_route',
    );
    final apiStates = api['states']! as Map<String, Object?>;
    expect(
      (apiStates['error']! as Map<String, Object?>)['applicability'],
      'applicable',
    );
    expect(
      (apiStates['dark']! as Map<String, Object?>)['applicability'],
      'not_applicable',
    );

    // An evidence overlay cannot turn a structurally non-applicable cell into
    // a completed requirement, even when its linked files are otherwise valid.
    final invalidEvidenceFile = File(
      '${blankOutputDirectory.path}/non-applicable-evidence.json',
    );
    final invalidRedirectCell =
        '${redirect['surface']}|${redirect['path']}|'
        '${redirect['kind']}|focused';
    invalidEvidenceFile.writeAsStringSync(
      '${jsonEncode(<String, Object?>{
        'schema_version': '1.0',
        'cells': <String, Object?>{
          invalidRedirectCell: <String, Object?>{
            'test_evidence': <String>['packages/features/feat_home/test/home_screen_states_test.dart'],
            'screenshot_evidence': <String>['packages/features/feat_home/test/goldens/'
                'home_compact_dark_320x760.png'],
            'disposition_note': 'Invalid control fixture for a non-applicable redirect state.',
            'owner': 'Route governance test',
            'reviewed_at': '2026-07-24',
          },
        },
      })}\n',
    );
    expect(
      () => generateRouteStateClosure(
        routes: routes,
        workspace: workspace,
        outputDirectory: blankOutputDirectory,
        evidenceFile: invalidEvidenceFile,
      ),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('non-applicable route-state cell'),
        ),
      ),
    );

    final archetypeCoverage = generateScreenArchetypeCoverage(
      routes: routes,
      workspace: workspace,
      outputDirectory: outputDirectory,
    );
    expect(
      archetypeCoverage['archetype_count'],
      requiredScreenArchetypes.length,
    );
    expect(archetypeCoverage['unmapped_archetype_count'], 0);
    expect(archetypeCoverage['ownerless_archetype_count'], 0);
    expect(archetypeCoverage['closure_complete'], isTrue);
    final archetypes =
        archetypeCoverage['archetypes']! as List<Map<String, Object?>>;
    expect(
      archetypes.map((entry) => entry['archetype']).toSet(),
      requiredScreenArchetypes.toSet(),
    );
    for (final entry in archetypes) {
      expect(entry['applicability'], 'applicable');
      expect(entry['status'], 'mapped');
      expect(entry['owner'], isNotEmpty);
      expect(entry['route_count'], greaterThan(0));
      expect(entry['route_keys'], isNotEmpty);
      expect(entry['test_evidence'], isEmpty);
      expect(entry['screenshot_evidence'], isEmpty);
    }
  });
}
