import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/generate_route_inventory.dart';

void main() {
  test('generates a complete multi-surface route inventory', () {
    const configuredOutput = String.fromEnvironment('ROUTE_INVENTORY_OUT_DIR');
    final workspace = resolveRouteInventoryWorkspace(Directory.current);
    final temporaryRoot = Directory.systemTemp.createTempSync(
      'africlub-route-inventory-',
    );
    addTearDown(() {
      if (temporaryRoot.existsSync()) {
        temporaryRoot.deleteSync(recursive: true);
      }
    });
    final outputDirectory = configuredOutput.isEmpty
        ? Directory('${temporaryRoot.path}/output')
        : Directory(configuredOutput);
    final routeStateEvidenceFile =
        File(
          '${temporaryRoot.path}/route-state-evidence.json',
        )..writeAsStringSync(
          '${jsonEncode(<String, Object?>{
            'schema_version': '1.0',
            'cells': <String, Object?>{
              'mobile|/home|tab|dark': <String, Object?>{
                'test_evidence': <String>['packages/features/feat_home/test/home_screen_states_test.dart'],
                'screenshot_evidence': <String>['packages/features/feat_home/test/goldens/'
                    'home_compact_dark_320x760.png'],
                'disposition_note': 'Hermetic route-inventory test evidence for one governed cell.',
                'owner': 'Route inventory test',
                'reviewed_at': '2026-08-20',
              },
            },
          })}\n',
        );

    final payload = generateRouteInventory(
      workspace: workspace,
      outputDirectory: outputDirectory,
      routeStateEvidenceFile: routeStateEvidenceFile,
    );
    final routes = payload['routes']! as List<Map<String, Object?>>;
    final routeKeys = routes
        .map((route) => '${route['surface']}|${route['path']}')
        .toSet();

    expect(payload['duplicate_keys'], isEmpty);
    expect(routes.length, greaterThan(100));
    expect(routeKeys, contains('mobile|/home'));
    expect(routeKeys, contains('mobile|/search'));
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
    expect(generatedClosure['evidenced_cell_count'], 1);
    expect(generatedClosure['open_cell_count'], greaterThan(0));
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
        expect(state['response_evidence'], isEmpty);
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
    final deterministicAssets = closureRoutes.where(
      (route) =>
          route['kind'] == 'http_route' &&
          route['endpoint_state_contract'] == 'deterministic_asset',
    );
    expect(deterministicAssets.map((route) => route['path']).toSet(), <String>{
      '/brand-mark.svg',
      '/brand-surface.svg',
    });
    for (final asset in deterministicAssets) {
      final assetStates = asset['states']! as Map<String, Object?>;
      expect(assetStates, hasLength(routeClosureStates.length));
      for (final value in assetStates.values) {
        final state = value! as Map<String, Object?>;
        expect(state['applicability'], 'not_applicable');
        expect(state['evidence_status'], 'not_applicable');
        expect(state['rationale'], contains('Deterministic local asset'));
      }
    }
    final deterministicVerifierDocuments = closureRoutes.where(
      (route) =>
          route['kind'] == 'http_route' &&
          route['endpoint_state_contract'] == 'deterministic_verifier_document',
    );
    expect(
      deterministicVerifierDocuments.map((route) => route['path']).toSet(),
      <String>{
        '/.well-known/apple-app-site-association',
        '/.well-known/assetlinks.json',
      },
    );
    for (final document in deterministicVerifierDocuments) {
      final documentStates = document['states']! as Map<String, Object?>;
      expect(documentStates, hasLength(routeClosureStates.length));
      for (final value in documentStates.values) {
        final state = value! as Map<String, Object?>;
        expect(state['applicability'], 'not_applicable');
        expect(state['evidence_status'], 'not_applicable');
        expect(state['rationale'], contains('Deterministic verifier document'));
      }
    }
    final standaloneRecoveryRoutes = closureRoutes.where(
      (route) =>
          route['rendered_state_contract'] == 'standalone_offline_recovery',
    );
    expect(
      standaloneRecoveryRoutes.map((route) => route['path']).toSet(),
      <String>{'/offline', '/admin-offline'},
    );
    const expectedRecoveryStates = <String>{
      'offline',
      'focused',
      'pressed',
      'large_text',
      'reduced_motion',
      'dark',
      'light',
    };
    for (final recoveryRoute in standaloneRecoveryRoutes) {
      final recoveryStates = recoveryRoute['states']! as Map<String, Object?>;
      for (final entry in recoveryStates.entries) {
        final state = entry.value! as Map<String, Object?>;
        expect(
          state['applicability'],
          expectedRecoveryStates.contains(entry.key)
              ? 'applicable'
              : 'not_applicable',
        );
      }
    }
    final shareTargetRoute = closureRoutes.singleWhere(
      (route) => route['rendered_state_contract'] == 'bounded_share_target',
    );
    expect(shareTargetRoute['path'], '/share-target');
    const expectedShareTargetStates = <String>{
      'empty',
      'offline',
      'focused',
      'pressed',
      'large_text',
      'reduced_motion',
      'dark',
      'light',
    };
    final shareTargetStates =
        shareTargetRoute['states']! as Map<String, Object?>;
    for (final entry in shareTargetStates.entries) {
      final state = entry.value! as Map<String, Object?>;
      expect(
        state['applicability'],
        expectedShareTargetStates.contains(entry.key)
            ? 'applicable'
            : 'not_applicable',
      );
    }
    final staticLegalDocumentRoutes = closureRoutes.where(
      (route) => route['rendered_state_contract'] == 'static_legal_document',
    );
    expect(
      staticLegalDocumentRoutes.map((route) => route['path']).toSet(),
      <String>{'/privacy', '/terms'},
    );
    const expectedStaticLegalDocumentStates = <String>{
      'large_text',
      'reduced_motion',
      'dark',
      'light',
    };
    for (final legalRoute in staticLegalDocumentRoutes) {
      final legalStates = legalRoute['states']! as Map<String, Object?>;
      for (final entry in legalStates.entries) {
        final state = entry.value! as Map<String, Object?>;
        expect(
          state['applicability'],
          expectedStaticLegalDocumentStates.contains(entry.key)
              ? 'applicable'
              : 'not_applicable',
        );
        if (!expectedStaticLegalDocumentStates.contains(entry.key)) {
          expect(
            state['rationale'],
            contains('always renders governed fallback copy'),
          );
        }
      }
    }
    final staticContactRoutes = closureRoutes.where(
      (route) => route['rendered_state_contract'] == 'static_contact_surface',
    );
    expect(staticContactRoutes.map((route) => route['path']).toSet(), <String>{
      '/account-deletion',
      '/contact',
      '/support',
    });
    const expectedStaticContactStates = <String>{
      'focused',
      'pressed',
      'large_text',
      'reduced_motion',
      'dark',
      'light',
    };
    for (final staticContactRoute in staticContactRoutes) {
      final staticContactStates =
          staticContactRoute['states']! as Map<String, Object?>;
      for (final entry in staticContactStates.entries) {
        final state = entry.value! as Map<String, Object?>;
        expect(
          state['applicability'],
          expectedStaticContactStates.contains(entry.key)
              ? 'applicable'
              : 'not_applicable',
        );
        if (!expectedStaticContactStates.contains(entry.key)) {
          expect(
            state['rationale'],
            contains('always renders governed fallback content'),
          );
        }
      }
    }
    final controlledSearchRoutes = closureRoutes.where(
      (route) =>
          route['rendered_state_contract'] == 'controlled_search_surface',
    );
    expect(controlledSearchRoutes, hasLength(1));
    expect(controlledSearchRoutes.single['path'], '/search');
    final controlledSearchStates =
        controlledSearchRoutes.single['states']! as Map<String, Object?>;
    for (final entry in controlledSearchStates.entries) {
      final state = entry.value! as Map<String, Object?>;
      expect(state['applicability'], 'applicable');
      expect(
        state['rationale'],
        contains('Controlled search surface must prove every'),
      );
    }
    final controlledHistoryRoutes = closureRoutes.where(
      (route) =>
          route['rendered_state_contract'] == 'controlled_history_surface',
    );
    expect(controlledHistoryRoutes, hasLength(1));
    expect(controlledHistoryRoutes.single['path'], '/history');
    final controlledHistoryStates =
        controlledHistoryRoutes.single['states']! as Map<String, Object?>;
    for (final entry in controlledHistoryStates.entries) {
      final state = entry.value! as Map<String, Object?>;
      expect(state['applicability'], 'applicable');
      expect(
        state['rationale'],
        contains('Controlled history surface must prove every'),
      );
    }
    final controlledClubHubRoutes = closureRoutes.where(
      (route) =>
          route['rendered_state_contract'] == 'controlled_club_hub_surface',
    );
    expect(controlledClubHubRoutes.map((route) => route['path']).toSet(), {
      '/club',
    });
    final controlledClubInformationRoutes = closureRoutes.where(
      (route) =>
          route['rendered_state_contract'] ==
          'controlled_club_information_surface',
    );
    expect(
      controlledClubInformationRoutes.map((route) => route['path']).toSet(),
      <String>{
        '/club/team',
        '/club/news',
        '/club/news/:articleId',
        '/club/fixtures',
        '/club/fixtures/:matchId',
        '/club/results',
        '/club/standings',
        '/club/history',
        '/club/projects',
        '/club/projects/:projectId',
      },
    );
    const expectedControlledClubHubStates = <String>{
      'loading',
      'error',
      'offline',
      'permission_denied',
      'focused',
      'pressed',
      'large_text',
      'reduced_motion',
      'dark',
      'light',
      'syncing',
      'conflict',
      'security_timeout',
    };
    const expectedControlledClubInformationStates = <String>{
      ...expectedControlledClubHubStates,
      'empty',
    };
    for (final route in controlledClubHubRoutes) {
      final states = route['states']! as Map<String, Object?>;
      for (final entry in states.entries) {
        expect(
          (entry.value! as Map<String, Object?>)['applicability'],
          expectedControlledClubHubStates.contains(entry.key)
              ? 'applicable'
              : 'not_applicable',
        );
      }
    }
    for (final route in controlledClubInformationRoutes) {
      final states = route['states']! as Map<String, Object?>;
      for (final entry in states.entries) {
        expect(
          (entry.value! as Map<String, Object?>)['applicability'],
          expectedControlledClubInformationStates.contains(entry.key)
              ? 'applicable'
              : 'not_applicable',
        );
      }
    }
    // HTTP endpoints use executable response contracts, not fabricated visual
    // evidence, while rendered routes continue to require screenshots.
    final apiEvidenceFile = File(
      '${blankOutputDirectory.path}/api-response-evidence.json',
    );
    final apiErrorCell =
        '${api['surface']}|${api['path']}|${api['kind']}|error';
    apiEvidenceFile.writeAsStringSync(
      '${jsonEncode(<String, Object?>{
        'schema_version': '1.0',
        'cells': <String, Object?>{
          apiErrorCell: <String, Object?>{
            'test_evidence': <String>['packages/app_registry/test/route_inventory_generation_test.dart'],
            'response_evidence': <String>['packages/app_registry/test/fixtures/api-error-response.json'],
            'disposition_note': 'The endpoint error state has executable and response-contract proof.',
            'owner': 'API reliability QA',
            'reviewed_at': '2026-07-29',
          },
        },
      })}\n',
    );
    final apiClosure = generateRouteStateClosure(
      routes: routes,
      workspace: workspace,
      outputDirectory: blankOutputDirectory,
      evidenceFile: apiEvidenceFile,
    );
    final apiClosureRoutes =
        apiClosure['routes']! as List<Map<String, Object?>>;
    final evidencedApi = apiClosureRoutes.firstWhere(
      (route) => route['route_key'] == api['route_key'],
    );
    final evidencedApiStates = evidencedApi['states']! as Map<String, Object?>;
    expect(
      (evidencedApiStates['error']! as Map<String, Object?>)['evidence_status'],
      'evidenced',
    );
    expect(apiClosure['response_evidenced_cell_count'], 1);

    // Rejected or superseded evidence may remain registered for audit, but a
    // pending admission can never close a route-state cell.
    final pendingEvidenceFile = File(
      '${blankOutputDirectory.path}/pending-route-state-evidence.json',
    );
    pendingEvidenceFile.writeAsStringSync(
      '${jsonEncode(<String, Object?>{
        'schema_version': '1.0',
        'cells': <String, Object?>{},
        'groups': <Object?>[
          <String, Object?>{
            'id': 'pending-api-error',
            'admission_status': 'pending',
            'cells': <String>[apiErrorCell],
            'test_evidence': <String>['packages/app_registry/test/route_inventory_generation_test.dart'],
            'response_evidence': <String>['packages/app_registry/test/fixtures/api-error-response.json'],
            'disposition_note': 'Rejected fixture retained without admission.',
            'owner': 'Route governance test',
            'reviewed_at': '2026-08-02',
          },
        ],
      })}\n',
    );
    final pendingClosure = generateRouteStateClosure(
      routes: routes,
      workspace: workspace,
      outputDirectory: blankOutputDirectory,
      evidenceFile: pendingEvidenceFile,
    );
    final pendingApi = (pendingClosure['routes']! as List<Map<String, Object?>>)
        .firstWhere((route) => route['route_key'] == api['route_key']);
    final pendingApiStates = pendingApi['states']! as Map<String, Object?>;
    expect(
      (pendingApiStates['error']! as Map<String, Object?>)['evidence_status'],
      'open',
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
