import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/generate_component_inventory.dart';

void main() {
  test('maps every Universal Component Library requirement fail-closed', () {
    const configuredOutput = String.fromEnvironment(
      'COMPONENT_INVENTORY_OUT_DIR',
    );
    final workspace = _findRepoRoot();
    final outputDirectory = Directory(
      configuredOutput.isEmpty
          ? '${workspace.path}/output/component_inventory_test'
          : configuredOutput,
    );
    final payload = generateComponentInventory(
      workspace: workspace,
      outputDirectory: outputDirectory,
    );
    final components = payload['components']! as List<Map<String, Object?>>;
    final keys = components
        .map((component) => component['component_key'])
        .toSet();
    const requiredCategories = <String>{
      'app_shell',
      'buttons',
      'inputs',
      'selection',
      'feedback',
      'data_display',
      'navigation',
      'overlays',
      'media',
      'security_privacy',
      'semantic_icons',
    };

    expect(components, hasLength(componentSeeds.length));
    expect(payload['schema_version'], '1.2');
    expect(keys, hasLength(components.length));
    expect(
      components.map((component) => component['category']).toSet(),
      requiredCategories,
    );
    expect(payload['state_count'], componentStateCatalog.length);
    expect(
      payload['state_cell_count'],
      components.length * componentStateCatalog.length,
    );
    expect(payload['evidenced_state_cell_count'], greaterThan(0));
    expect(payload['closure_complete'], isTrue);
    expect(payload['open_state_cell_count'], 0);
    expect(payload['not_implemented_state_cell_count'], 0);
    final globallyApplicableStates = <String>{};

    for (final component in components) {
      final status = component['implementation_status'];
      expect(status, anyOf('implemented', 'partial', 'missing'));
      final states = component['states']! as Map<String, Object?>;
      expect(states.keys.toSet(), componentStateCatalog.toSet());
      for (final value in states.values) {
        final state = value! as Map<String, Object?>;
        expect(
          state['evidence_status'],
          anyOf('open', 'evidenced', 'not_implemented', 'not_applicable'),
        );
        expect(state['evidence_status'], isNot('required'));
        if (state['evidence_status'] == 'evidenced') {
          expect(state['test_evidence'], isNotEmpty);
          expect(state['screenshot_evidence'], isNotEmpty);
        } else {
          expect(state['test_evidence'], isEmpty);
          expect(state['screenshot_evidence'], isEmpty);
        }
        expect(state['disposition_note'], isNotEmpty);
      }
      for (final entry in states.entries) {
        final state = entry.value! as Map<String, Object?>;
        if (state['evidence_status'] != 'not_applicable') {
          globallyApplicableStates.add(entry.key);
        }
      }
      for (final path in component['source_paths']! as List<Object?>) {
        expect(
          File('${workspace.path}/$path').existsSync(),
          isTrue,
          reason: '${component['component_key']} source must exist: $path',
        );
      }
      for (final path in component['candidate_test_paths']! as List<Object?>) {
        expect(
          File('${workspace.path}/$path').existsSync(),
          isTrue,
          reason:
              '${component['component_key']} candidate test must exist: $path',
        );
      }
    }
    expect(globallyApplicableStates, componentStateCatalog.toSet());
    expect(
      (payload['open_state_cell_count']! as int) +
          (payload['evidenced_state_cell_count']! as int) +
          (payload['not_implemented_state_cell_count']! as int) +
          (payload['not_applicable_state_cell_count']! as int),
      payload['state_cell_count'],
    );

    expect(
      File(
        '${outputDirectory.path}/universal-component-inventory.json',
      ).existsSync(),
      isTrue,
    );
    expect(
      File(
        '${outputDirectory.path}/universal-component-inventory.md',
      ).existsSync(),
      isTrue,
    );
  });

  test('promotes a cell only when current test and visual paths both exist', () {
    final workspace = _findRepoRoot();
    final temporary = Directory.systemTemp.createTempSync(
      'africlub-component-evidence-',
    );
    addTearDown(() => temporary.deleteSync(recursive: true));
    final evidence = File('${temporary.path}/component-state-evidence.json')
      ..writeAsStringSync(
        '${jsonEncode({
          'schema_version': '1.0',
          'cells': {
            'app_shell|top_bar|default': {
              'test_evidence': ['packages/core/core_theme/test/ui_source_guardrails_test.dart'],
              'screenshot_evidence': ['packages/core/core_theme/test/goldens/'
                  'universal_media_security_catalog_900x1600.png'],
              'disposition_note': 'Current executable and exact-pixel proof reviewed.',
            },
          },
        })}\n',
      );

    final payload = generateComponentInventory(
      workspace: workspace,
      outputDirectory: Directory('${temporary.path}/output'),
      evidenceFile: evidence,
    );
    final components = payload['components']! as List<Map<String, Object?>>;
    final topBar = components.singleWhere(
      (component) => component['component_key'] == 'app_shell|top_bar',
    );
    final states = topBar['states']! as Map<String, Object?>;
    final defaultState = states['default']! as Map<String, Object?>;

    expect(defaultState['evidence_status'], 'evidenced');
    expect(defaultState['test_evidence'], hasLength(1));
    expect(defaultState['screenshot_evidence'], hasLength(1));
    expect(payload['evidenced_state_cell_count'], 1);
    expect(
      payload['open_state_cell_count'],
      componentSeeds
              .map((seed) => applicableStatesFor(seed).length)
              .fold<int>(0, (total, count) => total + count) -
          1,
    );
    expect(payload['closure_complete'], isFalse);
  });

  test('rejects stale, unknown, or traversal evidence paths', () {
    final workspace = _findRepoRoot();
    final temporary = Directory.systemTemp.createTempSync(
      'africlub-component-invalid-evidence-',
    );
    addTearDown(() => temporary.deleteSync(recursive: true));
    final evidence = File('${temporary.path}/component-state-evidence.json')
      ..writeAsStringSync(
        '${jsonEncode({
          'schema_version': '1.0',
          'cells': {
            'buttons|primary|default': {
              'test_evidence': ['../outside.dart'],
              'screenshot_evidence': <String>[],
              'disposition_note': 'Invalid on purpose.',
            },
          },
        })}\n',
      );

    expect(
      () => generateComponentInventory(
        workspace: workspace,
        outputDirectory: Directory('${temporary.path}/output'),
        evidenceFile: evidence,
      ),
      throwsA(isA<FormatException>()),
    );
  });
}

Directory _findRepoRoot() {
  var current = Directory.current.absolute;
  while (true) {
    if (Directory('${current.path}/packages').existsSync() &&
        Directory('${current.path}/apps').existsSync()) {
      return current;
    }
    final parent = current.parent;
    if (parent.path == current.path) {
      throw StateError(
        'Could not locate the AFRICLUB repository from '
        '${Directory.current.path}.',
      );
    }
    current = parent;
  }
}
