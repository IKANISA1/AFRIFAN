import 'dart:convert';
import 'dart:io';

import 'package:app_registry/app_registry.dart';
import 'package:core_router/core_router.dart';
import 'package:go_router/go_router.dart';

const routeClosureStates = <String>[
  'loading',
  'empty',
  'error',
  'offline',
  'permission_denied',
  'disabled',
  'focused',
  'pressed',
  'selected',
  'large_text',
  'reduced_motion',
  'dark',
  'light',
  'syncing',
  'conflict',
  'security_timeout',
];

const requiredScreenArchetypes = <String>[
  'home',
  'detail',
  'list_feed',
  'create_edit',
  'search',
  'transaction_checkout',
  'profile_settings',
  'onboarding_permissions',
  'notifications',
  'support',
  'offline',
  'admin',
];

void main(List<String> arguments) {
  final workspace = resolveRouteInventoryWorkspace(Directory.current);
  final outputDirectory = Directory(
    arguments.isEmpty
        ? '${workspace.path}/output/route_inventory'
        : arguments.first,
  );
  final payload = generateRouteInventory(
    workspace: workspace,
    outputDirectory: outputDirectory,
  );
  stdout.writeln('${outputDirectory.path}/route-inventory.json');
  final duplicateKeys = payload['duplicate_keys'] as List<Object?>;
  if (duplicateKeys.isNotEmpty) {
    stderr.writeln(
      'Duplicate route inventory keys: ${duplicateKeys.join(', ')}',
    );
    exitCode = 1;
  }
}

Directory resolveRouteInventoryWorkspace(Directory start) {
  var candidate = start.absolute;

  while (true) {
    final hasAppRegistry = Directory(
      '${candidate.path}/packages/app_registry',
    ).existsSync();
    final hasRayonWeb = Directory(
      '${candidate.path}/apps/rayon_sports/web',
    ).existsSync();
    if (hasAppRegistry && hasRayonWeb) {
      return candidate;
    }

    final parent = candidate.parent;
    if (parent.path == candidate.path) {
      return start.absolute;
    }
    candidate = parent;
  }
}

Map<String, Object?> generateRouteInventory({
  required Directory workspace,
  required Directory outputDirectory,
  File? routeStateEvidenceFile,
}) {
  outputDirectory.createSync(recursive: true);
  final generatedAt = DateTime.now().toUtc().toIso8601String();
  final routes = <Map<String, Object?>>[];
  final modules = AppModuleRegistry.allModules;

  for (final module in modules) {
    final moduleName = module.runtimeType.toString();
    final presentations = <String, RoutePresentationDecision>{
      for (final decision in module.routePresentationDecisions)
        decision.path: decision,
    };
    final tab = module.tabRoute;
    if (tab != null) {
      routes.add(
        _flutterRouteRecord(
          path: tab.path,
          name: tab.path.replaceFirst('/', ''),
          module: moduleName,
          kind: 'tab',
          public: module.publicPaths.contains(tab.path),
          presentation: presentations[tab.path],
        ),
      );
      for (final route in module.routes) {
        _collectFlutterRoute(
          route,
          parentPath: tab.path,
          module: moduleName,
          publicPaths: module.publicPaths,
          presentations: presentations,
          output: routes,
        );
      }
    } else {
      for (final route in module.routes) {
        _collectFlutterRoute(
          route,
          parentPath: '',
          module: moduleName,
          publicPaths: module.publicPaths,
          presentations: presentations,
          output: routes,
        );
      }
    }

    for (final route in module.standaloneRoutes) {
      _collectFlutterRoute(
        route,
        parentPath: '',
        module: moduleName,
        publicPaths: module.publicPaths,
        presentations: presentations,
        output: routes,
      );
    }
  }

  routes.addAll(<Map<String, Object?>>[
    _systemRecord(
      path: '/feature-unavailable',
      surface: 'mobile',
      role: 'consumer',
      kind: 'system_state',
    ),
    _systemRecord(
      path: '<router-error>',
      surface: 'mobile',
      role: 'consumer',
      kind: 'error_path',
    ),
  ]);

  routes.addAll(_collectNextRoutes(workspace));
  routes.sort((left, right) {
    final surface = (left['surface'] as String).compareTo(
      right['surface'] as String,
    );
    if (surface != 0) {
      return surface;
    }
    return (left['path'] as String).compareTo(right['path'] as String);
  });

  final uniqueKeys = <String>{};
  final duplicateKeys = <String>[];
  for (final route in routes) {
    final key = '${route['surface']}|${route['path']}|${route['kind']}';
    if (!uniqueKeys.add(key)) {
      duplicateKeys.add(key);
    }
  }

  final payload = <String, Object?>{
    'schema_version': '1.0',
    'generated_at': generatedAt,
    'workspace': workspace.path,
    'generator': 'packages/app_registry/tool/generate_route_inventory.dart',
    'sources': <String>[
      'AppModuleRegistry.allModules',
      'FeatureModule tab, nested, standalone, public-path, and presentation metadata',
      'apps/rayon_sports/web/src/app/**/page.tsx',
      'apps/rayon_sports/web/src/app/**/route.ts',
      'AppRouter system unavailable/error paths',
    ],
    'route_count': routes.length,
    'duplicate_keys': duplicateKeys,
    'routes': routes,
  };

  final jsonFile = File('${outputDirectory.path}/route-inventory.json');
  jsonFile.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(payload)}\n',
  );

  final markdown = StringBuffer()
    ..writeln('# AFRICLUB Generated Route Inventory')
    ..writeln()
    ..writeln('- Generated: `$generatedAt`')
    ..writeln('- Routes: `${routes.length}`')
    ..writeln('- Duplicate inventory keys: `${duplicateKeys.length}`')
    ..writeln('- Machine-readable source: `${jsonFile.path}`')
    ..writeln()
    ..writeln(
      '| Surface | Route | Kind | Role boundary | Guard | Presentation | Source |',
    )
    ..writeln('| --- | --- | --- | --- | --- | --- | --- |');
  for (final route in routes) {
    markdown.writeln(
      '| ${route['surface']} | `${route['path']}` | ${route['kind']} | '
      '${route['role_boundary']} | ${route['guard']} | '
      '${route['presentation']} | `${route['source']}` |',
    );
  }
  File(
    '${outputDirectory.path}/route-inventory.md',
  ).writeAsStringSync(markdown.toString());

  final closure = generateRouteStateClosure(
    routes: routes,
    workspace: workspace,
    outputDirectory: outputDirectory,
    generatedAt: generatedAt,
    evidenceFile: routeStateEvidenceFile,
  );
  payload['state_closure'] = <String, Object?>{
    'json': closure['json_path'],
    'markdown': closure['markdown_path'],
    'state_count': routeClosureStates.length,
    'cell_count': closure['cell_count'],
    'evidenced_cell_count': closure['evidenced_cell_count'],
    'open_cell_count': closure['open_cell_count'],
    'closure_complete': closure['closure_complete'],
  };
  final archetypes = generateScreenArchetypeCoverage(
    routes: routes,
    workspace: workspace,
    outputDirectory: outputDirectory,
    generatedAt: generatedAt,
  );
  payload['screen_archetype_coverage'] = <String, Object?>{
    'json': archetypes['json_path'],
    'markdown': archetypes['markdown_path'],
    'archetype_count': archetypes['archetype_count'],
    'unmapped_archetype_count': archetypes['unmapped_archetype_count'],
    'ownerless_archetype_count': archetypes['ownerless_archetype_count'],
    'closure_complete': archetypes['closure_complete'],
  };
  jsonFile.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(payload)}\n',
  );
  return payload;
}

Map<String, Object?> generateScreenArchetypeCoverage({
  required List<Map<String, Object?>> routes,
  required Directory workspace,
  required Directory outputDirectory,
  String? generatedAt,
}) {
  outputDirectory.createSync(recursive: true);
  final generated = generatedAt ?? DateTime.now().toUtc().toIso8601String();
  final archetypes = <Map<String, Object?>>[];

  for (final archetype in requiredScreenArchetypes) {
    final matches = routes
        .where((route) => _matchesScreenArchetype(route, archetype))
        .toList(growable: false);
    final owner = _screenArchetypeOwner(archetype);
    archetypes.add(<String, Object?>{
      'archetype': archetype,
      'applicability': 'applicable',
      'status': matches.isEmpty ? 'unmapped' : 'mapped',
      'owner': owner,
      'route_count': matches.length,
      'route_keys': matches
          .map(
            (route) => '${route['surface']}|${route['path']}|${route['kind']}',
          )
          .toList(growable: false),
      'not_applicable_reason': null,
      'approval_exception_id': null,
      'test_evidence': <String>[],
      'screenshot_evidence': <String>[],
    });
  }

  final unmapped = archetypes
      .where((entry) => entry['status'] == 'unmapped')
      .length;
  final ownerless = archetypes
      .where((entry) => (entry['owner'] as String).trim().isEmpty)
      .length;
  final closureComplete = unmapped == 0 && ownerless == 0;
  final jsonPath = '${outputDirectory.path}/screen-archetype-coverage.json';
  final markdownPath = '${outputDirectory.path}/screen-archetype-coverage.md';
  final payload = <String, Object?>{
    'schema_version': '1.0',
    'generated_at': generated,
    'workspace': workspace.path,
    'source_inventory': '${outputDirectory.path}/route-inventory.json',
    'required_archetypes': requiredScreenArchetypes,
    'archetype_count': archetypes.length,
    'mapped_archetype_count': archetypes.length - unmapped,
    'unmapped_archetype_count': unmapped,
    'ownerless_archetype_count': ownerless,
    'closure_complete': closureComplete,
    'archetypes': archetypes,
  };
  File(jsonPath).writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(payload)}\n',
  );

  final markdown = StringBuffer()
    ..writeln('# AFRICLUB Required Screen-Archetype Coverage')
    ..writeln()
    ..writeln('- Generated: `$generated`')
    ..writeln('- Required archetypes: `${archetypes.length}`')
    ..writeln('- Unmapped archetypes: `$unmapped`')
    ..writeln('- Ownerless archetypes: `$ownerless`')
    ..writeln('- Mapping closure complete: `$closureComplete`')
    ..writeln('- Machine-readable matrix: `$jsonPath`')
    ..writeln()
    ..writeln('| Archetype | Status | Owner | Mapped routes |')
    ..writeln('| --- | --- | --- | ---: |');
  for (final entry in archetypes) {
    markdown.writeln(
      '| ${entry['archetype']} | ${entry['status']} | '
      '${entry['owner']} | ${entry['route_count']} |',
    );
  }
  File(markdownPath).writeAsStringSync(markdown.toString());

  return <String, Object?>{
    ...payload,
    'json_path': jsonPath,
    'markdown_path': markdownPath,
  };
}

bool _matchesScreenArchetype(Map<String, Object?> route, String archetype) {
  final surface = route['surface'] as String;
  final path = route['path'] as String;
  final kind = route['kind'] as String;
  final rendered = kind != 'api_route' && kind != 'http_route';
  bool containsAny(Iterable<String> fragments) => fragments.any(path.contains);

  return switch (archetype) {
    'home' => rendered && (path == '/home' || path == '/'),
    'detail' =>
      rendered &&
          (path.contains('/:') ||
              containsAny(<String>['/detail/', '/product/', '/tier/'])),
    'list_feed' =>
      rendered &&
          containsAny(<String>[
            '/news',
            '/fixtures',
            '/results',
            '/standings',
            '/squad',
            '/supporters',
            '/tickets',
            '/shop',
          ]),
    'create_edit' =>
      rendered &&
          containsAny(<String>[
            '/create',
            '/edit-',
            '/cms/content',
            '/cms/banners',
            '/cms/config',
          ]),
    'search' => rendered && path == '/search',
    'transaction_checkout' =>
      rendered &&
          containsAny(<String>[
            '/cart',
            '/order',
            '/tickets',
            '/e-ticket',
            '/contribute',
          ]),
    'profile_settings' =>
      rendered && containsAny(<String>['/settings', '/membership', '/privacy']),
    'onboarding_permissions' =>
      rendered &&
          containsAny(<String>['/onboarding', '/auth/', '/admin/access']),
    'notifications' => rendered && path.contains('/notifications'),
    'support' =>
      rendered &&
          containsAny(<String>['/contact', '/privacy', '/terms', '/support']),
    'offline' =>
      rendered && (path.contains('/offline') || path == '/feature-unavailable'),
    'admin' => surface == 'admin_pwa' || surface == 'mobile_internal_admin',
    _ => false,
  };
}

String _screenArchetypeOwner(String archetype) {
  return switch (archetype) {
    'home' || 'search' || 'list_feed' => 'Consumer experience owner',
    'detail' => 'Feature detail owner',
    'create_edit' => 'Feature workflow owner',
    'transaction_checkout' => 'Commerce and transaction owner',
    'profile_settings' => 'Identity and settings owner',
    'onboarding_permissions' => 'Identity and onboarding owner',
    'notifications' => 'Notifications owner',
    'support' => 'Support and policy owner',
    'offline' => 'Reliability owner',
    'admin' => 'Admin product and security owner',
    _ => '',
  };
}

Map<String, Object?> generateRouteStateClosure({
  required List<Map<String, Object?>> routes,
  required Directory workspace,
  required Directory outputDirectory,
  String? generatedAt,
  File? evidenceFile,
}) {
  outputDirectory.createSync(recursive: true);
  final generated = generatedAt ?? DateTime.now().toUtc().toIso8601String();
  final resolvedEvidenceFile =
      evidenceFile ??
      File('${workspace.path}/docs/governance/route-state-evidence.json');
  final evidenceByCell = _loadRouteStateEvidence(
    routes: routes,
    workspace: workspace,
    evidenceFile: resolvedEvidenceFile,
  );
  final routeRows = <Map<String, Object?>>[];
  var applicableCells = 0;
  var notApplicableCells = 0;
  var testEvidencedCells = 0;
  var visualEvidencedCells = 0;
  var responseEvidencedCells = 0;
  var evidencedCells = 0;

  for (final route in routes) {
    final states = <String, Object?>{};
    final routeKey = '${route['surface']}|${route['path']}|${route['kind']}';
    var routeOpenCells = 0;
    for (final state in routeClosureStates) {
      final classification = _classifyClosureState(route, state);
      final applicable = classification.$1;
      final cellKey = '$routeKey|$state';
      final evidence = evidenceByCell[cellKey];
      if (!applicable && evidence != null) {
        throw FormatException(
          'Evidence is linked to non-applicable route-state cell "$cellKey".',
        );
      }
      final testEvidence = evidence?.testEvidence ?? const <String>[];
      final screenshotEvidence =
          evidence?.screenshotEvidence ?? const <String>[];
      final responseEvidence = evidence?.responseEvidence ?? const <String>[];
      final hasTestEvidence = testEvidence.isNotEmpty;
      final hasScreenshotEvidence = screenshotEvidence.isNotEmpty;
      final hasResponseEvidence = responseEvidence.isNotEmpty;
      final isEndpoint =
          route['kind'] == 'api_route' || route['kind'] == 'http_route';
      final hasRequiredArtifact = isEndpoint
          ? hasResponseEvidence
          : hasScreenshotEvidence;
      final isEvidenced = applicable && hasTestEvidence && hasRequiredArtifact;
      if (applicable) {
        applicableCells += 1;
        if (hasTestEvidence) testEvidencedCells += 1;
        if (hasScreenshotEvidence) visualEvidencedCells += 1;
        if (hasResponseEvidence) responseEvidencedCells += 1;
        if (isEvidenced) {
          evidencedCells += 1;
        } else {
          routeOpenCells += 1;
        }
      } else {
        notApplicableCells += 1;
      }
      states[state] = <String, Object?>{
        'applicability': applicable ? 'applicable' : 'not_applicable',
        'evidence_status': !applicable
            ? 'not_applicable'
            : isEvidenced
            ? 'evidenced'
            : 'open',
        'rationale': isEvidenced
            ? evidence!.dispositionNote
            : applicable
            ? _openRouteStateRationale(
                baseRationale: classification.$2,
                hasTestEvidence: hasTestEvidence,
                hasScreenshotEvidence: hasScreenshotEvidence,
                hasResponseEvidence: hasResponseEvidence,
                requiresResponseEvidence: isEndpoint,
              )
            : classification.$2,
        'test_evidence': testEvidence,
        'screenshot_evidence': screenshotEvidence,
        'response_evidence': responseEvidence,
        'accessibility_evidence':
            evidence?.accessibilityEvidence ?? const <String>[],
        'performance_evidence':
            evidence?.performanceEvidence ?? const <String>[],
        'privacy_evidence': evidence?.privacyEvidence ?? const <String>[],
        'platform_build_evidence':
            evidence?.platformBuildEvidence ?? const <String>[],
        'exception_id': null,
        'owner': evidence?.owner,
        'reviewed_at': evidence?.reviewedAt,
      };
    }
    routeRows.add(<String, Object?>{
      'route_key': routeKey,
      'surface': route['surface'],
      'path': route['path'],
      'kind': route['kind'],
      'endpoint_state_contract': route['endpoint_state_contract'],
      'rendered_state_contract': route['rendered_state_contract'],
      'role_boundary': route['role_boundary'],
      'guard': route['guard'],
      'source': route['source'],
      'closure_status': routeOpenCells == 0
          ? 'evidence_complete'
          : 'evidence_open',
      'states': states,
    });
  }

  final jsonPath = '${outputDirectory.path}/route-state-closure.json';
  final markdownPath = '${outputDirectory.path}/route-state-closure.md';
  final payload = <String, Object?>{
    'schema_version': '1.2',
    'generated_at': generated,
    'workspace': workspace.path,
    'source_inventory': '${outputDirectory.path}/route-inventory.json',
    'state_catalog': routeClosureStates,
    'route_count': routes.length,
    'state_count': routeClosureStates.length,
    'cell_count': routes.length * routeClosureStates.length,
    'applicable_cell_count': applicableCells,
    'not_applicable_cell_count': notApplicableCells,
    'test_evidenced_cell_count': testEvidencedCells,
    'visual_evidenced_cell_count': visualEvidencedCells,
    'response_evidenced_cell_count': responseEvidencedCells,
    'evidenced_cell_count': evidencedCells,
    'open_cell_count': applicableCells - evidencedCells,
    'closure_complete':
        applicableCells > 0 && evidencedCells == applicableCells,
    'evidence_source': resolvedEvidenceFile.path,
    'routes': routeRows,
  };
  File(jsonPath).writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(payload)}\n',
  );

  final markdown = StringBuffer()
    ..writeln('# AFRICLUB Route-by-State Closure Matrix')
    ..writeln()
    ..writeln('- Generated: `$generated`')
    ..writeln('- Routes: `${routes.length}`')
    ..writeln('- States per route: `${routeClosureStates.length}`')
    ..writeln(
      '- Applicable evidence cells still open: '
      '`${applicableCells - evidencedCells}`',
    )
    ..writeln('- Explicitly not-applicable cells: `$notApplicableCells`')
    ..writeln('- Test-evidenced cells: `$testEvidencedCells`')
    ..writeln('- Visual-evidenced cells: `$visualEvidencedCells`')
    ..writeln('- Response-evidenced cells: `$responseEvidencedCells`')
    ..writeln('- Fully evidenced cells: `$evidencedCells`')
    ..writeln(
      '- Closure complete: '
      '`${applicableCells > 0 && evidencedCells == applicableCells}`',
    )
    ..writeln('- Evidence source: `${resolvedEvidenceFile.path}`')
    ..writeln('- Machine-readable matrix: `$jsonPath`')
    ..writeln()
    ..writeln(
      'An `open` cell is a controlled requirement, not evidence that the state '
      'already works. A cell becomes `evidenced` only after both a current '
      'executable test and the surface-appropriate controlled artifact are '
      'linked: a screenshot for rendered routes, or a response contract for '
      'HTTP endpoints. A '
      '`not_applicable` cell is limited to redirects or HTTP endpoints with no '
      'rendered interaction.',
    )
    ..writeln()
    ..writeln(
      '| Route | Surface | Kind | Evidenced | Open states | Not applicable | '
      'Test links | Screenshot links | Response links |',
    )
    ..writeln('| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |');
  for (final row in routeRows) {
    final states = row['states']! as Map<String, Object?>;
    final open = states.values
        .where(
          (value) =>
              (value! as Map<String, Object?>)['evidence_status'] == 'open',
        )
        .length;
    final evidenced = states.values
        .where(
          (value) =>
              (value! as Map<String, Object?>)['evidence_status'] ==
              'evidenced',
        )
        .length;
    final notApplicable = states.values
        .where(
          (value) =>
              (value! as Map<String, Object?>)['evidence_status'] ==
              'not_applicable',
        )
        .length;
    final testLinks = states.values
        .expand(
          (value) =>
              (value! as Map<String, Object?>)['test_evidence']!
                  as List<Object?>,
        )
        .toSet()
        .length;
    final screenshotLinks = states.values
        .expand(
          (value) =>
              (value! as Map<String, Object?>)['screenshot_evidence']!
                  as List<Object?>,
        )
        .toSet()
        .length;
    final responseLinks = states.values
        .expand(
          (value) =>
              (value! as Map<String, Object?>)['response_evidence']!
                  as List<Object?>,
        )
        .toSet()
        .length;
    markdown.writeln(
      '| `${row['path']}` | ${row['surface']} | ${row['kind']} | '
      '$evidenced | $open | $notApplicable | $testLinks | $screenshotLinks | '
      '$responseLinks |',
    );
  }
  File(markdownPath).writeAsStringSync(markdown.toString());

  return <String, Object?>{
    ...payload,
    'json_path': jsonPath,
    'markdown_path': markdownPath,
  };
}

String _openRouteStateRationale({
  required String baseRationale,
  required bool hasTestEvidence,
  required bool hasScreenshotEvidence,
  required bool hasResponseEvidence,
  required bool requiresResponseEvidence,
}) {
  final hasRequiredArtifact = requiresResponseEvidence
      ? hasResponseEvidence
      : hasScreenshotEvidence;
  final artifactLabel = requiresResponseEvidence
      ? 'controlled response-contract proof'
      : 'controlled visual proof';
  if (hasTestEvidence && !hasRequiredArtifact) {
    return '$baseRationale Current executable test evidence is linked; '
        '$artifactLabel remains open.';
  }
  if (!hasTestEvidence && hasRequiredArtifact) {
    return '$baseRationale ${artifactLabel[0].toUpperCase()}'
        '${artifactLabel.substring(1)} is linked; current '
        'executable test evidence remains open.';
  }
  return baseRationale;
}

class _RouteStateEvidence {
  const _RouteStateEvidence({
    required this.testEvidence,
    required this.screenshotEvidence,
    required this.responseEvidence,
    required this.accessibilityEvidence,
    required this.performanceEvidence,
    required this.privacyEvidence,
    required this.platformBuildEvidence,
    required this.dispositionNote,
    required this.owner,
    required this.reviewedAt,
  });

  final List<String> testEvidence;
  final List<String> screenshotEvidence;
  final List<String> responseEvidence;
  final List<String> accessibilityEvidence;
  final List<String> performanceEvidence;
  final List<String> privacyEvidence;
  final List<String> platformBuildEvidence;
  final String dispositionNote;
  final String owner;
  final String reviewedAt;
}

Map<String, _RouteStateEvidence> _loadRouteStateEvidence({
  required List<Map<String, Object?>> routes,
  required Directory workspace,
  required File evidenceFile,
}) {
  if (!evidenceFile.existsSync()) return const {};

  final decoded = jsonDecode(evidenceFile.readAsStringSync());
  if (decoded is! Map<String, Object?>) {
    throw FormatException(
      'Route-state evidence root must be a JSON object: ${evidenceFile.path}',
    );
  }
  if (decoded['schema_version'] != '1.0') {
    throw FormatException(
      'Unsupported route-state evidence schema in ${evidenceFile.path}.',
    );
  }
  final rawCells = decoded['cells'];
  if (rawCells is! Map<String, Object?>) {
    throw const FormatException(
      'Route-state evidence must contain an object named "cells".',
    );
  }

  final knownCells = <String>{
    for (final route in routes)
      for (final state in routeClosureStates)
        '${route['surface']}|${route['path']}|${route['kind']}|$state',
  };
  final result = <String, _RouteStateEvidence>{};

  void addEvidenceCell(String cellKey, Object? rawCell, {String? groupId}) {
    if (!knownCells.contains(cellKey)) {
      throw FormatException('Unknown route-state evidence cell "$cellKey".');
    }
    if (result.containsKey(cellKey)) {
      throw FormatException(
        'Duplicate route-state evidence cell "$cellKey"'
        '${groupId == null ? '' : ' in group "$groupId"'}.',
      );
    }
    if (rawCell is! Map<String, Object?>) {
      throw FormatException('Evidence cell "$cellKey" must be a JSON object.');
    }
    final dispositionNote = rawCell['disposition_note'];
    final owner = rawCell['owner'];
    final reviewedAt = rawCell['reviewed_at'];
    if (dispositionNote is! String || dispositionNote.trim().isEmpty) {
      throw FormatException(
        'Evidence cell "$cellKey" requires a non-empty disposition_note.',
      );
    }
    if (owner is! String || owner.trim().isEmpty) {
      throw FormatException(
        'Evidence cell "$cellKey" requires a non-empty owner.',
      );
    }
    if (reviewedAt is! String || reviewedAt.trim().isEmpty) {
      throw FormatException(
        'Evidence cell "$cellKey" requires a non-empty reviewed_at.',
      );
    }
    result[cellKey] = _RouteStateEvidence(
      testEvidence: _readRouteEvidencePaths(
        workspace: workspace,
        cellKey: cellKey,
        field: 'test_evidence',
        value: rawCell['test_evidence'],
      ),
      screenshotEvidence: _readRouteEvidencePaths(
        workspace: workspace,
        cellKey: cellKey,
        field: 'screenshot_evidence',
        value: rawCell['screenshot_evidence'],
      ),
      responseEvidence: _readRouteEvidencePaths(
        workspace: workspace,
        cellKey: cellKey,
        field: 'response_evidence',
        value: rawCell['response_evidence'],
      ),
      accessibilityEvidence: _readRouteEvidencePaths(
        workspace: workspace,
        cellKey: cellKey,
        field: 'accessibility_evidence',
        value: rawCell['accessibility_evidence'],
      ),
      performanceEvidence: _readRouteEvidencePaths(
        workspace: workspace,
        cellKey: cellKey,
        field: 'performance_evidence',
        value: rawCell['performance_evidence'],
      ),
      privacyEvidence: _readRouteEvidencePaths(
        workspace: workspace,
        cellKey: cellKey,
        field: 'privacy_evidence',
        value: rawCell['privacy_evidence'],
      ),
      platformBuildEvidence: _readRouteEvidencePaths(
        workspace: workspace,
        cellKey: cellKey,
        field: 'platform_build_evidence',
        value: rawCell['platform_build_evidence'],
      ),
      dispositionNote: dispositionNote.trim(),
      owner: owner.trim(),
      reviewedAt: reviewedAt.trim(),
    );
  }

  for (final entry in rawCells.entries) {
    addEvidenceCell(entry.key, entry.value);
  }

  final rawGroups = decoded['groups'];
  if (rawGroups != null) {
    if (rawGroups is! List<Object?>) {
      throw const FormatException(
        'Route-state evidence "groups" must be a list.',
      );
    }
    for (final rawGroup in rawGroups) {
      if (rawGroup is! Map<String, Object?>) {
        throw const FormatException(
          'Each route-state evidence group must be a JSON object.',
        );
      }
      final groupId = rawGroup['id'];
      final groupCells = rawGroup['cells'];
      if (groupId is! String || groupId.trim().isEmpty) {
        throw const FormatException(
          'Each route-state evidence group requires a non-empty id.',
        );
      }
      final admissionStatus = rawGroup['admission_status'] ?? 'admitted';
      if (admissionStatus != 'admitted' && admissionStatus != 'pending') {
        throw FormatException(
          'Evidence group "$groupId" has unsupported admission_status '
          '"$admissionStatus".',
        );
      }
      // Pending groups preserve rejected or superseded artifacts for audit
      // without allowing those artifacts to close a governed route-state cell.
      // The registrar changes the status only after its complete preflight has
      // validated every route in the batch.
      if (admissionStatus == 'pending') continue;
      if (groupCells is! List<Object?> || groupCells.isEmpty) {
        throw FormatException(
          'Evidence group "$groupId" requires a non-empty cells list.',
        );
      }
      for (final rawCellKey in groupCells) {
        if (rawCellKey is! String || rawCellKey.trim().isEmpty) {
          throw FormatException(
            'Evidence group "$groupId" contains an invalid cell key.',
          );
        }
        addEvidenceCell(rawCellKey.trim(), rawGroup, groupId: groupId.trim());
      }
    }
  }
  return result;
}

List<String> _readRouteEvidencePaths({
  required Directory workspace,
  required String cellKey,
  required String field,
  required Object? value,
}) {
  if (value == null) return const [];
  if (value is! List<Object?>) {
    throw FormatException(
      'Evidence cell "$cellKey" field "$field" must be a list.',
    );
  }
  final paths = <String>[];
  for (final rawPath in value) {
    if (rawPath is! String || rawPath.trim().isEmpty) {
      throw FormatException(
        'Evidence cell "$cellKey" field "$field" contains an invalid path.',
      );
    }
    final path = rawPath.trim();
    if (path.startsWith('/') || path.contains('..')) {
      throw FormatException(
        'Evidence path must be workspace-relative and traversal-free: $path',
      );
    }
    if (!File('${workspace.path}/$path').existsSync()) {
      throw FormatException(
        'Evidence path does not exist for "$cellKey": $path',
      );
    }
    paths.add(path);
  }
  return List.unmodifiable(paths.toSet());
}

(bool, String) _classifyClosureState(Map<String, Object?> route, String state) {
  final kind = route['kind'] as String;
  if (route['rendered_state_contract'] == 'static_contact_surface') {
    const contactStates = <String>{
      'focused',
      'pressed',
      'large_text',
      'reduced_motion',
      'dark',
      'light',
    };
    final applicable = contactStates.contains(state);
    return (
      applicable,
      applicable
          ? 'Static contact surface must prove this interaction or '
                'presentation state with current rendered evidence.'
          : 'Static contact surface always renders governed fallback content '
                'and owns no collection, authorization, selection, mutation, '
                'synchronization, conflict, or timeout operation.',
    );
  }
  if (route['rendered_state_contract'] == 'controlled_search_surface') {
    return (
      true,
      'Controlled search surface must prove every content, recovery, '
          'interaction, presentation, synchronization, conflict, and bounded '
          'operation state with current rendered evidence.',
    );
  }
  if (route['rendered_state_contract'] == 'controlled_history_surface') {
    return (
      true,
      'Controlled history surface must prove every content, recovery, '
          'interaction, presentation, synchronization, conflict, and bounded '
          'operation state with current rendered evidence.',
    );
  }
  if (route['rendered_state_contract'] == 'controlled_club_hub_surface') {
    const clubHubStates = <String>{
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
    final applicable = clubHubStates.contains(state);
    return (
      applicable,
      applicable
          ? 'Controlled Club hub must prove this live identity, recovery, '
                'interaction, presentation, synchronization, or bounded-operation state.'
          : 'Controlled Club hub always retains governed fallback identity '
                'and owns no disabled or selected control state.',
    );
  }
  if (route['rendered_state_contract'] ==
      'controlled_club_information_surface') {
    const clubInformationStates = <String>{
      'loading',
      'empty',
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
    final applicable = clubInformationStates.contains(state);
    return (
      applicable,
      applicable
          ? 'Controlled Club information route must prove this content, '
                'recovery, interaction, presentation, synchronization, or bounded-operation state.'
          : 'Read-only Club information routes own no disabled or selected '
                'control state.',
    );
  }
  if (route['rendered_state_contract'] == 'static_legal_document') {
    const legalDocumentStates = <String>{
      'large_text',
      'reduced_motion',
      'dark',
      'light',
    };
    final applicable = legalDocumentStates.contains(state);
    return (
      applicable,
      applicable
          ? 'Static legal document must prove this responsive or presentation '
                'state with current rendered evidence.'
          : 'Static legal document always renders governed fallback copy and '
                'owns no controls, authorization, mutation, synchronization, '
                'conflict, or timeout workflow.',
    );
  }
  if (route['rendered_state_contract'] == 'bounded_share_target') {
    const shareTargetStates = <String>{
      'empty',
      'offline',
      'focused',
      'pressed',
      'large_text',
      'reduced_motion',
      'dark',
      'light',
    };
    final applicable = shareTargetStates.contains(state);
    return (
      applicable,
      applicable
          ? 'Bounded share intake must prove this content, recovery, '
                'interaction, or presentation state.'
          : 'Bounded share intake performs no authorization, mutation, '
                'selection, synchronization, conflict, or timed operation.',
    );
  }
  if (route['rendered_state_contract'] == 'standalone_offline_recovery') {
    const recoveryStates = <String>{
      'offline',
      'focused',
      'pressed',
      'large_text',
      'reduced_motion',
      'dark',
      'light',
    };
    final applicable = recoveryStates.contains(state);
    return (
      applicable,
      applicable
          ? 'Standalone recovery page must prove this rendered recovery or '
                'interaction state.'
          : 'Standalone recovery page has no collection, authorization, '
                'mutation, synchronization, conflict, or timeout operation.',
    );
  }
  if (kind == 'redirect') {
    final applicable =
        state == 'error' ||
        state == 'permission_denied' ||
        state == 'security_timeout';
    return (
      applicable,
      applicable
          ? 'Redirect navigation must handle this outcome deterministically.'
          : 'Redirect has no rendered control or visual state.',
    );
  }
  if (kind == 'http_route' &&
      route['endpoint_state_contract'] == 'deterministic_asset') {
    return (
      false,
      'Deterministic local asset has no input, authorization, mutation, '
          'upstream operation, or rendered interaction state.',
    );
  }
  if (kind == 'http_route' &&
      route['endpoint_state_contract'] == 'deterministic_verifier_document') {
    return (
      false,
      'Deterministic verifier document has no request input, authorization, '
          'mutation, upstream operation, or rendered interaction state.',
    );
  }
  if (kind == 'api_route' || kind == 'http_route') {
    const endpointStates = <String>{
      'empty',
      'error',
      'permission_denied',
      'syncing',
      'conflict',
      'security_timeout',
    };
    final applicable = endpointStates.contains(state);
    return (
      applicable,
      applicable
          ? 'Endpoint contract requires a controlled response for this state.'
          : 'HTTP endpoint has no rendered visual or interaction state.',
    );
  }
  return (
    true,
    'Rendered production route requires linked current test and screenshot '
        'evidence or an approved exception.',
  );
}

void _collectFlutterRoute(
  RouteBase route, {
  required String parentPath,
  required String module,
  required Set<String> publicPaths,
  required Map<String, RoutePresentationDecision> presentations,
  required List<Map<String, Object?>> output,
}) {
  if (route is! GoRoute) {
    output.add(
      _systemRecord(
        path: '$parentPath/<${route.runtimeType}>',
        surface: 'mobile',
        role: 'consumer',
        kind: 'nested_router',
        source: module,
      ),
    );
    return;
  }

  final path = _joinRoute(parentPath, route.path);
  output.add(
    _flutterRouteRecord(
      path: path,
      name: route.name,
      module: module,
      kind: route.redirect == null ? 'route' : 'redirect',
      public: publicPaths.contains(path),
      presentation: presentations[path],
    ),
  );
  for (final child in route.routes) {
    _collectFlutterRoute(
      child,
      parentPath: path,
      module: module,
      publicPaths: publicPaths,
      presentations: presentations,
      output: output,
    );
  }
}

Map<String, Object?> _flutterRouteRecord({
  required String path,
  required String? name,
  required String module,
  required String kind,
  required bool public,
  RoutePresentationDecision? presentation,
}) {
  final isAdmin = path == '/admin' || path.startsWith('/admin/');
  return <String, Object?>{
    'surface': isAdmin ? 'mobile_internal_admin' : 'mobile',
    'path': path,
    'name': name,
    'kind': kind,
    'role_boundary': isAdmin ? 'admin role' : 'consumer',
    'guard': public
        ? 'public'
        : isAdmin
        ? 'authenticated plus admin role'
        : 'authenticated',
    'presentation': presentation?.presentation.name ?? 'registered route',
    'recommendation': presentation?.recommendation,
    'target_path': presentation?.targetPath,
    'rendered_state_contract': presentation?.renderedStateContract,
    'source': module,
    'required_state_evidence': <String>[
      'loading',
      'empty',
      'error',
      'offline',
      'permission_denied_or_not_applicable',
      'large_text',
      'reduced_motion',
      'light',
      'dark',
    ],
  };
}

Map<String, Object?> _systemRecord({
  required String path,
  required String surface,
  required String role,
  required String kind,
  String source = 'packages/core/core_router/lib/src/app_router.dart',
}) {
  return <String, Object?>{
    'surface': surface,
    'path': path,
    'name': null,
    'kind': kind,
    'role_boundary': role,
    'guard': role == 'consumer' ? 'router policy' : 'surface-specific policy',
    'presentation': kind,
    'recommendation': null,
    'target_path': null,
    'source': source,
    'required_state_evidence': <String>[
      'default',
      'error',
      'offline_or_not_applicable',
      'focus',
      'large_text_or_distance_readability',
    ],
  };
}

List<Map<String, Object?>> _collectNextRoutes(Directory workspace) {
  final appDirectory = Directory(
    '${workspace.path}/apps/rayon_sports/web/src/app',
  );
  if (!appDirectory.existsSync()) {
    return const <Map<String, Object?>>[];
  }

  final output = <Map<String, Object?>>[];
  final files =
      appDirectory
          .listSync(recursive: true)
          .whereType<File>()
          .where(
            (file) =>
                file.path.endsWith('/page.tsx') ||
                file.path.endsWith('/route.ts'),
          )
          .toList()
        ..sort((left, right) => left.path.compareTo(right.path));

  for (final file in files) {
    final relative = file.path
        .substring(appDirectory.path.length + 1)
        .replaceAll(RegExp(r'/(page|route)\.tsx?$'), '')
        .replaceAll(RegExp(r'(^|/)\([^/]+\)'), '')
        .replaceAllMapped(
          RegExp(r'\[([^\]]+)\]'),
          (match) => ':${match.group(1)}',
        );
    final normalized = relative
        .replaceAll(RegExp(r'/+'), '/')
        .replaceAll(RegExp(r'^/+|/+$'), '');
    final path = normalized.isEmpty ? '/' : '/$normalized';
    final isApi = path == '/api' || path.startsWith('/api/');
    final isRouteHandler = file.path.endsWith('/route.ts');
    final isDeterministicAsset =
        isRouteHandler &&
        const <String>{'/brand-mark.svg', '/brand-surface.svg'}.contains(path);
    final isDeterministicVerifierDocument =
        isRouteHandler &&
        const <String>{
          '/.well-known/apple-app-site-association',
          '/.well-known/assetlinks.json',
        }.contains(path);
    final isStandaloneOfflineRecovery =
        !isRouteHandler &&
        const <String>{'/offline', '/admin-offline'}.contains(path);
    final isBoundedShareTarget = !isRouteHandler && path == '/share-target';
    final isStaticLegalDocument =
        !isRouteHandler && const <String>{'/privacy', '/terms'}.contains(path);
    final isStaticContactSurface =
        !isRouteHandler &&
        const <String>{
          '/account-deletion',
          '/contact',
          '/support',
        }.contains(path);
    final isControlledSearchSurface = !isRouteHandler && path == '/search';
    final isControlledHistorySurface = !isRouteHandler && path == '/history';
    final isAdmin = path == '/admin' || path.startsWith('/admin/');
    final isVenue = path == '/venue' || path.startsWith('/venue/');
    final surface = isApi
        ? 'web_api'
        : isAdmin
        ? 'admin_pwa'
        : isVenue
        ? 'venue_portal'
        : 'consumer_web';
    final role = isApi
        ? 'endpoint-specific'
        : isAdmin
        ? 'admin role'
        : isVenue
        ? 'venue operator'
        : 'public or authenticated consumer';
    output.add(<String, Object?>{
      'surface': surface,
      'path': path,
      'name': null,
      'kind': isApi
          ? 'api_route'
          : isRouteHandler
          ? 'http_route'
          : 'next_page',
      'role_boundary': role,
      'guard': isAdmin || isVenue || isApi
          ? 'proxy plus server-side authorization'
          : 'route-specific',
      'presentation': isApi || isRouteHandler
          ? 'endpoint'
          : 'responsive web page',
      'endpoint_state_contract': isDeterministicAsset
          ? 'deterministic_asset'
          : isDeterministicVerifierDocument
          ? 'deterministic_verifier_document'
          : isApi || isRouteHandler
          ? 'controlled_response'
          : null,
      'rendered_state_contract': isStandaloneOfflineRecovery
          ? 'standalone_offline_recovery'
          : isBoundedShareTarget
          ? 'bounded_share_target'
          : isStaticLegalDocument
          ? 'static_legal_document'
          : isStaticContactSurface
          ? 'static_contact_surface'
          : isControlledSearchSurface
          ? 'controlled_search_surface'
          : isControlledHistorySurface
          ? 'controlled_history_surface'
          : null,
      'recommendation': null,
      'target_path': null,
      'source': file.path.substring(workspace.path.length + 1),
      'required_state_evidence':
          isDeterministicAsset || isDeterministicVerifierDocument
          ? <String>['deterministic_success']
          : isApi || isRouteHandler
          ? <String>[
              'success',
              'invalid_input',
              'unauthenticated',
              'forbidden',
              'service_failure',
            ]
          : <String>[
              'loading',
              'empty',
              'error',
              'permission_denied_or_not_applicable',
              'keyboard',
              'zoom_reflow',
            ],
    });
  }
  return output;
}

String _joinRoute(String parent, String child) {
  if (child.startsWith('/')) {
    return child;
  }
  final normalizedParent = parent.endsWith('/')
      ? parent.substring(0, parent.length - 1)
      : parent;
  return '$normalizedParent/$child'.replaceAll(RegExp(r'/+'), '/');
}
