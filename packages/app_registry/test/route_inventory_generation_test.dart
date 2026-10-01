import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/generate_route_inventory.dart';

void main() {
  test(
    'legal action controls require focus and press without invented async states',
    () {
      final workspace = resolveRouteInventoryWorkspace(Directory.current);
      final temporary = Directory.systemTemp.createTempSync(
        'africlub-legal-actions-',
      );
      addTearDown(() => temporary.deleteSync(recursive: true));
      final payload = generateRouteInventory(
        workspace: workspace,
        outputDirectory: temporary,
      );
      final closure = payload['state_closure']! as Map<String, Object?>;
      final rows =
          (jsonDecode(File(closure['json']! as String).readAsStringSync())
                  as Map<String, dynamic>)['routes']!
              as List<dynamic>;
      final legal = rows
          .where(
            (route) =>
                route['rendered_state_contract'] == 'static_legal_document',
          )
          .toList();
      expect(legal.map((route) => route['path']).toSet(), {
        '/privacy',
        '/terms',
      });
      for (final route in legal) {
        final states = route['states'] as Map<String, dynamic>;
        expect(
          states.entries
              .where((entry) => entry.value['applicability'] == 'applicable')
              .map((entry) => entry.key)
              .toSet(),
          {
            'focused',
            'pressed',
            'large_text',
            'reduced_motion',
            'dark',
            'light',
          },
        );
        expect(
          states['focused']['rationale'],
          contains('actual legal-document-actions'),
        );
        for (final state in [
          'loading',
          'error',
          'syncing',
          'conflict',
          'security_timeout',
        ]) {
          expect(states[state]['applicability'], 'not_applicable');
        }
      }
    },
  );

  test(
    'native registration preserves every enabled destination and finite disabled scope',
    () {
      final workspace = resolveRouteInventoryWorkspace(Directory.current);
      final temporary = Directory.systemTemp.createTempSync(
        'africlub-registration-',
      );
      addTearDown(() => temporary.deleteSync(recursive: true));
      const features = {
        'home',
        'club',
        'live',
        'predict',
        'settings',
        'onboarding',
        'membership',
        'contributions',
        'ticketing',
        'fan_clubs',
        'admin',
        'shop',
      };
      final scopes = <String, Set<String>>{
        for (final club in [
          'as_vita',
          'costa_do_sol',
          'nkana',
          'rayon_sports',
          'vitalo',
        ])
          club: club == 'costa_do_sol'
              ? features.difference({'fan_clubs', 'shop', 'ticketing'})
              : features,
      };
      final payload = generateRouteInventory(
        workspace: workspace,
        outputDirectory: temporary,
        registeredNativeFeaturesByClub: scopes,
      );
      final routes = payload['routes']! as List<Map<String, Object?>>;
      final disabled = routes
          .where(
            (route) =>
                ((route['native_registration']
                        as Map<String, Object?>?)?['costa_do_sol']
                    as Map<String, Object?>?)?['registered'] ==
                false,
          )
          .toList();
      expect(disabled.map((route) => route['source']).toSet(), {
        'FanClubsModule',
        'ShopModule',
        'TicketingModule',
      });
      for (final route in routes.where(
        (route) => route['native_registration'] != null,
      )) {
        final registration =
            route['native_registration']! as Map<String, Object?>;
        for (final club in scopes.keys.where(
          (club) => club != 'costa_do_sol',
        )) {
          expect(
            (registration[club]! as Map<String, Object?>)['registered'],
            isTrue,
          );
        }
      }
      final membership = routes.singleWhere(
        (route) => route['path'] == '/membership/fans',
      );
      expect(
        ((membership['native_registration']
                as Map<String, Object?>)['costa_do_sol']
            as Map<String, Object?>)['registered'],
        isTrue,
      );
      expect(
        () => generateRouteInventory(
          workspace: workspace,
          outputDirectory: temporary,
          registeredNativeFeaturesByClub: {'costa_do_sol': {}},
        ),
        throwsArgumentError,
      );
    },
  );

  test(
    'only actual append-only observation endpoints have no conflict response contract',
    () {
      final workspace = resolveRouteInventoryWorkspace(Directory.current);
      final temporary = Directory.systemTemp.createTempSync(
        'africlub-observation-contract-',
      );
      addTearDown(() => temporary.deleteSync(recursive: true));
      final payload = generateRouteInventory(
        workspace: workspace,
        outputDirectory: temporary,
      );
      final closure = payload['state_closure']! as Map<String, Object?>;
      final rows =
          (jsonDecode(File(closure['json']! as String).readAsStringSync())
                  as Map<String, dynamic>)['routes']!
              as List<dynamic>;
      final api = rows.where((route) => route['surface'] == 'web_api').toList();
      final withoutConflict = <String>[];
      for (final route in api) {
        final states = route['states']! as Map<String, Object?>;
        final conflict = states['conflict']! as Map<String, Object?>;
        if (conflict['applicability'] == 'not_applicable') {
          withoutConflict.add(route['path']! as String);
        }
        for (final state in [
          'empty',
          'error',
          'permission_denied',
          'syncing',
          'security_timeout',
        ]) {
          expect(
            (states[state]! as Map<String, Object?>)['applicability'],
            'applicable',
            reason: '${route['path']} $state',
          );
        }
      }
      expect(withoutConflict..sort(), [
        '/api/pwa/events',
        '/api/telemetry/vitals',
      ]);
      expect(api.any((route) => route['path'] == '/api/pwa/vitals'), isFalse);
    },
  );

  test(
    'finite alias contracts preserve destination and unknown-route obligations',
    () {
      final workspace = resolveRouteInventoryWorkspace(Directory.current);
      final temporary = Directory.systemTemp.createTempSync(
        'africlub-alias-contract-',
      );
      addTearDown(() => temporary.deleteSync(recursive: true));
      final missingEvidence = File('${temporary.path}/no-evidence.json');
      final payload = generateRouteInventory(
        workspace: workspace,
        outputDirectory: temporary,
        routeStateEvidenceFile: missingEvidence,
      );
      final routes = payload['routes']! as List<Map<String, Object?>>;
      final closure = payload['state_closure']! as Map<String, Object?>;
      final rows =
          (jsonDecode(File(closure['json']! as String).readAsStringSync())
                  as Map<String, dynamic>)['routes']!
              as List<dynamic>;
      Set<String> applicable(Map<String, dynamic> route) =>
          (route['states'] as Map<String, dynamic>).entries
              .where((entry) => entry.value['applicability'] == 'applicable')
              .map((entry) => entry.key)
              .toSet();
      const synchronous = <String, bool>{
        '/club/partners/:partnerId': false,
        '/club/results': false,
        '/club/projects': true,
        '/club/projects/:projectId': true,
        '/contribute/groups': true,
        '/contribute/projects': true,
        '/fan-clubs/:clubId': false,
        '/live': true,
        '/live-match': true,
        '/live/news/:articleId': true,
        '/membership/fans': true,
        '/my-tickets': true,
        '/splash': false,
        '/admin/settle': true,
      };
      final aliases = rows
          .where(
            (route) =>
                route['kind'] == 'redirect' &&
                ['mobile', 'mobile_internal_admin'].contains(route['surface']),
          )
          .toList();
      expect(aliases, hasLength(15));
      for (final alias in synchronous.entries) {
        final row =
            aliases.singleWhere((route) => route['path'] == alias.key)
                as Map<String, dynamic>;
        expect(
          applicable(row),
          alias.value ? {'permission_denied'} : <String>{},
          reason: alias.key,
        );
        for (final state in (row['states'] as Map<String, dynamic>).values) {
          expect(state['rationale'], contains('synchronously'));
          expect(state['rationale'], contains('core_app/app.dart'));
        }
      }
      final openWeb =
          aliases.singleWhere((route) => route['path'] == '/club/open-web')
              as Map<String, dynamic>;
      expect(applicable(openWeb), {
        'loading',
        'empty',
        'error',
        'offline',
        'permission_denied',
        'conflict',
        'security_timeout',
      });
      final adminAlias =
          rows.singleWhere(
                (route) =>
                    route['surface'] == 'admin_pwa' &&
                    route['path'] == '/admin/contributions',
              )
              as Map<String, dynamic>;
      expect(applicable(adminAlias), {'permission_denied'});
      // Finite mappings cannot remove the canonical screen's independent UI work.
      for (final target in [
        '/club/partners',
        '/club/fixtures',
        '/contribute',
        '/contribute/group/:groupId',
        '/fan-clubs',
        '/club/news/:articleId',
        '/tickets',
        '/onboarding',
      ]) {
        final row =
            rows.singleWhere(
                  (route) =>
                      route['surface'] == 'mobile' && route['path'] == target,
                )
                as Map<String, dynamic>;
        expect(row['kind'], isNot('redirect'));
        expect(
          applicable(row),
          containsAll(['dark', 'light', 'large_text', 'reduced_motion']),
          reason: 'Destination retains rendered obligations: $target',
        );
      }
      final unreviewed = <String, Object?>{
        ...routes.firstWhere((route) => route['kind'] == 'redirect'),
        'route_key': 'mobile|/new-unreviewed-alias|redirect',
        'source': 'NewUnreviewedModule',
        'path': '/new-unreviewed-alias',
      };
      final unknownClosure = generateRouteStateClosure(
        routes: [unreviewed],
        workspace: workspace,
        outputDirectory: temporary,
        evidenceFile: missingEvidence,
      );
      final unknown =
          (unknownClosure['routes'] as List<Map<String, Object?>>).single;
      final states = unknown['states'] as Map<String, Object?>;
      expect(
        states.entries
            .where(
              (entry) =>
                  (entry.value as Map<String, Object?>)['applicability'] ==
                  'applicable',
            )
            .map((entry) => entry.key)
            .toSet(),
        {'error', 'permission_denied', 'security_timeout'},
      );
      expect(unknownClosure['evidenced_cell_count'], 0);
    },
  );

  test('generates a complete multi-surface route inventory', () {
    final workspace = resolveRouteInventoryWorkspace(Directory.current);
    final temporaryRoot = Directory.systemTemp.createTempSync(
      'africlub-route-inventory-',
    );
    addTearDown(() {
      if (temporaryRoot.existsSync()) {
        temporaryRoot.deleteSync(recursive: true);
      }
    });
    // Hermetic fixture evidence must never be exported as workspace evidence.
    final outputDirectory = Directory('${temporaryRoot.path}/output');
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
    expect(routeKeys, isNot(contains('venue_portal|/venue')));
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
      'focused',
      'pressed',
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
        '/club/team/:playerId',
        '/club/partners',
        '/club/news',
        '/club/news/:articleId',
        '/club/fixtures',
        '/club/fixtures/:matchId',
        '/club/standings',
        '/club/history',
      },
    );
    for (final path in <String>[
      '/club/open-web',
      '/club/partners/:partnerId',
      '/fan-clubs/:clubId',
    ]) {
      final route = closureRoutes.singleWhere((route) => route['path'] == path);
      expect(route['kind'], 'redirect');
      expect(
        route['rendered_state_contract'],
        isNot('controlled_club_information_surface'),
      );
    }
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

  test('exports inventory using the governed workspace evidence', () {
    const configuredOutput = String.fromEnvironment('ROUTE_INVENTORY_OUT_DIR');
    final workspace = resolveRouteInventoryWorkspace(Directory.current);
    final temporaryRoot = Directory.systemTemp.createTempSync(
      'africlub-workspace-route-inventory-',
    );
    addTearDown(() => temporaryRoot.deleteSync(recursive: true));
    final outputDirectory = configuredOutput.isEmpty
        ? Directory('${temporaryRoot.path}/output')
        : Directory(configuredOutput);

    final payload = generateRouteInventory(
      workspace: workspace,
      outputDirectory: outputDirectory,
    );
    final closure =
        jsonDecode(
              File(
                '${outputDirectory.path}/route-state-closure.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;

    expect(payload['duplicate_keys'], isEmpty);
    expect(
      closure['evidence_source'],
      '${workspace.path}/docs/governance/route-state-evidence.json',
    );
    expect(File(closure['evidence_source'] as String).existsSync(), isTrue);
    expect(closure['route_count'], payload['route_count']);
    expect(
      (payload['state_closure']!
          as Map<String, Object?>)['evidenced_cell_count'],
      closure['evidenced_cell_count'],
    );
  });
}
