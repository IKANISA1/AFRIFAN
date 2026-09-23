import 'dart:io';

import 'validate_workspace_architecture.dart';

void main() {
  var count = 0;
  void check(String name, void Function(Directory root) scenario) {
    final root = Directory.systemTemp.createTempSync('africlub-architecture-');
    try {
      scenario(root);
      count++;
      stdout.writeln('PASS $name');
    } finally {
      root.deleteSync(recursive: true);
    }
  }

  check('valid data layer and dev-only test helpers', (root) {
    _workspace(root, [
      'packages/core/core_network',
      'packages/data/club_data',
      'packages/testing/test_support',
    ]);
    _package(root, 'packages/core/core_network');
    _package(
      root,
      'packages/testing/test_support',
      extra: 'dependencies:\n  flutter_test:\n    sdk: flutter\n',
    );
    _package(
      root,
      'packages/data/club_data',
      extra:
          'dependencies:\n  core_network:\n    path: ../../core/core_network\n'
          'dev_dependencies:\n  test_support:\n    path: ../../testing/test_support\n',
      source: "import 'package:core_network/core_network.dart';",
    );
    _expect(validateWorkspace(root), null);
  });
  check('runtime cycle', (root) {
    _workspace(root, ['packages/core/core_a', 'packages/core/core_b']);
    _package(
      root,
      'packages/core/core_a',
      extra: 'dependencies:\n  core_b:\n    path: ../core_b\n',
    );
    _package(
      root,
      'packages/core/core_b',
      extra: 'dependencies:\n  core_a:\n    path: ../core_a\n',
    );
    _expect(validateWorkspace(root), 'Runtime dependency cycle');
  });
  check('core cannot depend on a feature', (root) {
    _workspace(root, ['packages/core/core_a', 'packages/features/feat_club']);
    _package(root, 'packages/features/feat_club');
    _package(
      root,
      'packages/core/core_a',
      extra:
          'dependencies:\n  feat_club:\n    path: ../../features/feat_club\n',
    );
    _expect(validateWorkspace(root), 'Forbidden runtime dependency');
  });
  check('test helpers cannot leak into production', (root) {
    _workspace(root, [
      'packages/features/feat_club',
      'packages/testing/test_support',
    ]);
    _package(root, 'packages/testing/test_support');
    _package(
      root,
      'packages/features/feat_club',
      extra:
          'dependencies:\n  test_support:\n    path: ../../testing/test_support\n',
    );
    _expect(validateWorkspace(root), 'Test dependency in production');
  });
  check('conditional imports need direct runtime dependencies', (root) {
    _workspace(root, ['packages/core/core_a']);
    _package(
      root,
      'packages/core/core_a',
      source:
          "// import 'package:ignored/comment.dart';\n"
          "import 'local.dart' if (dart.library.io) 'package:missing/io.dart';",
    );
    _expect(validateWorkspace(root), 'undeclared runtime dependency missing');
    if (validateWorkspace(root).any((e) => e.contains('ignored'))) {
      throw StateError('Comment was treated as an import.');
    }
  });
  check('private package imports rejected', (root) {
    _workspace(root, ['packages/core/core_a', 'packages/core/core_b']);
    _package(root, 'packages/core/core_b');
    _package(
      root,
      'packages/core/core_a',
      extra: 'dependencies:\n  core_b:\n    path: ../core_b\n',
      source: "export 'package:core_b/src/private.dart';",
    );
    _expect(validateWorkspace(root), 'private cross-package import');
  });
  check('orphan manifests and stale dependency paths rejected', (root) {
    _workspace(root, ['packages/core/core_a', 'packages/core/core_b']);
    _package(root, 'packages/core/core_b');
    _package(root, 'packages/features/feat_orphan');
    _package(
      root,
      'packages/core/core_a',
      extra: 'dependencies:\n  core_b:\n    path: ../old_location\n',
    );
    final errors = validateWorkspace(root);
    _expect(errors, 'Package missing from workspace');
    _expect(errors, 'must point to');
  });
  check('unused app dependencies rejected', (root) {
    _workspace(root, ['apps/club_a']);
    _package(
      root,
      'apps/club_a',
      extra: 'dependencies:\n  flutter:\n    sdk: flutter\n  unused: ^1.0.0\n',
    );
    _expect(validateWorkspace(root), 'unused app dependency unused');
  });
  stdout.writeln('$count architecture regression tests passed.');
}

void _workspace(Directory root, List<String> paths) {
  File('${root.path}/pubspec.yaml').writeAsStringSync(
    'name: fixture\nworkspace:\n${paths.map((p) => '  - $p\n').join()}',
  );
}

void _package(
  Directory root,
  String path, {
  String extra = '',
  String source = '',
}) {
  final dir = Directory('${root.path}/$path/lib')..createSync(recursive: true);
  File('${dir.parent.path}/pubspec.yaml').writeAsStringSync(
    'name: ${path.split('/').last}\nresolution: workspace\n$extra',
  );
  File('${dir.path}/entry.dart').writeAsStringSync(source);
}

void _expect(List<String> errors, String? expected) {
  if (expected == null
      ? errors.isNotEmpty
      : !errors.any((e) => e.contains(expected))) {
    throw StateError('Expected ${expected ?? 'no errors'}; got $errors');
  }
}
