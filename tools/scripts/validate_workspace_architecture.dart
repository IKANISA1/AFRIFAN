import 'dart:io';

import 'package:yaml/yaml.dart';

/// Validates the physical workspace, production imports, and package graph.
/// Development dependencies may compose features for integration tests.
List<String> validateWorkspace(Directory root) {
  final errors = <String>[];
  final manifest = _yaml(File('${root.path}/pubspec.yaml'));
  final paths = (manifest['workspace'] as List).cast<String>();
  final packages = <String, _Package>{};
  if (paths.toSet().length != paths.length) {
    errors.add('Duplicate workspace paths.');
  }
  for (final path in paths) {
    final file = File('${root.path}/$path/pubspec.yaml');
    if (!file.existsSync()) {
      errors.add('Missing workspace manifest: $path');
      continue;
    }
    final package = _Package(path, _yaml(file));
    if (packages.containsKey(package.name)) {
      errors.add('Duplicate package name: ${package.name}');
    }
    packages[package.name] = package;
    if (package.layer == 'unknown') {
      errors.add('Package outside the documented layers: $path');
    }
    if (package.manifest['resolution'] != 'workspace') {
      errors.add('$path must use resolution: workspace.');
    }
  }
  for (final parent in ['apps', 'packages']) {
    for (final path in _manifestPaths(Directory('${root.path}/$parent'), 2)) {
      final relative = path.substring(root.path.length + 1);
      if (!paths.contains(relative)) {
        errors.add('Package missing from workspace: $relative');
      }
    }
  }

  for (final package in packages.values) {
    final runtimeImports = <String>{};
    for (final name in package.dependencies.keys) {
      final target = packages[name];
      if (target != null && !_allows(package, target)) {
        errors.add('Forbidden runtime dependency: ${package.name} -> $name');
      }
      if (package.layer != 'testing' &&
          const {
            'flutter_test',
            'integration_test',
            'test',
            'test_support',
          }.contains(name)) {
        errors.add('Test dependency in production: ${package.name} -> $name');
      }
    }
    for (final group in ['dependencies', 'dev_dependencies']) {
      final declarations = _map(package.manifest[group]);
      for (final entry in declarations.entries) {
        final target = packages[entry.key];
        final spec = entry.value;
        if (target == null && spec is Map && spec['path'] != null) {
          errors.add(
            '${package.name}: path dependency ${entry.key} is outside '
            'the workspace.',
          );
        } else if (target != null) {
          final path = spec is Map ? spec['path'] : null;
          final expected = Directory(
            '${root.path}/${target.path}',
          ).absolute.uri;
          final actual = path is String
              ? Directory('${root.path}/${package.path}/$path').absolute.uri
              : null;
          if (actual?.normalizePath() != expected.normalizePath()) {
            errors.add(
              '${package.name}: ${entry.key} must point to '
              '${target.path}.',
            );
          }
        }
      }
    }
    final lib = Directory('${root.path}/${package.path}/lib');
    if (lib.existsSync()) {
      for (final file
          in lib
              .listSync(recursive: true, followLinks: false)
              .whereType<File>()
              .where((f) => f.path.endsWith('.dart'))) {
        for (final uri in _imports(file.readAsStringSync())) {
          if (!uri.startsWith('package:')) continue;
          final parts = uri.substring('package:'.length).split('/');
          final name = parts.first;
          if (name == package.name) continue;
          runtimeImports.add(name);
          if (!package.dependencies.containsKey(name)) {
            errors.add('${file.path}: undeclared runtime dependency $name.');
          }
          if (packages.containsKey(name) &&
              parts.length > 1 &&
              parts[1] == 'src' &&
              package.layer != 'testing') {
            errors.add('${file.path}: private cross-package import $uri.');
          }
        }
      }
    }
    if (package.layer == 'app') {
      for (final name in package.dependencies.keys) {
        // Native app manifests retain the Flutter SDK even for tiny entrypoints.
        if (name != 'flutter' && !runtimeImports.contains(name)) {
          errors.add('${package.name}: unused app dependency $name.');
        }
      }
    }
  }
  final visited = <String>{};
  final visiting = <String>[];
  void visit(String name) {
    if (visiting.contains(name)) {
      errors.add(
        'Runtime dependency cycle: ${[...visiting, name].join(' -> ')}',
      );
      return;
    }
    if (!visited.add(name)) return;
    visiting.add(name);
    for (final dependency in packages[name]!.dependencies.keys) {
      if (packages.containsKey(dependency)) visit(dependency);
    }
    visiting.removeLast();
  }

  packages.keys.forEach(visit);
  return errors;
}

bool _allows(_Package source, _Package target) {
  if (source.layer == 'testing') return target.layer != 'app';
  if (target.layer == 'testing' || target.layer == 'app') return false;
  return switch (source.layer) {
    'core' => target.layer == 'core',
    'data' => {'core', 'data'}.contains(target.layer),
    'club' => target.layer == 'core',
    'feature' => {'core', 'data'}.contains(target.layer),
    'composition' => {'core', 'data', 'feature'}.contains(target.layer),
    'app' =>
      target.name == 'core_app' ||
          target.name == 'app_registry' ||
          target.name == 'club_${source.name}',
    _ => false,
  };
}

Iterable<String> _manifestPaths(Directory directory, int depth) sync* {
  if (!directory.existsSync()) return;
  if (File('${directory.path}/pubspec.yaml').existsSync()) {
    yield directory.path;
    return;
  }
  if (depth == 0) return;
  for (final child
      in directory.listSync(followLinks: false).whereType<Directory>()) {
    if (!child.uri.pathSegments
        .where((s) => s.isNotEmpty)
        .last
        .startsWith('.')) {
      yield* _manifestPaths(child, depth - 1);
    }
  }
}

Iterable<String> _imports(String source) sync* {
  // Match directives, including conditional imports. The analyzer separately
  // validates Dart syntax and imports; this check enforces package ownership.
  final uncommented = source
      .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
      .replaceAll(RegExp(r'^\s*//.*$', multiLine: true), '');
  for (final directive in RegExp(
    r'^\s*(?:import|export)\s+([^;]+);',
    multiLine: true,
  ).allMatches(uncommented)) {
    for (final uri in RegExp(
      r'''['"]([^'"]+)['"]''',
    ).allMatches(directive.group(1)!)) {
      yield uri.group(1)!;
    }
  }
}

Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : {};

Map<String, dynamic> _yaml(File file) =>
    _map(loadYaml(file.readAsStringSync()));

class _Package {
  _Package(this.path, this.manifest);
  final String path;
  final Map<String, dynamic> manifest;
  String get name => manifest['name'] as String;
  Map<String, dynamic> get dependencies => _map(manifest['dependencies']);
  String get layer {
    if (RegExp(r'^apps/[a-z0-9_]+$').hasMatch(path)) return 'app';
    if (path == 'packages/app_registry') return 'composition';
    for (final entry in const {
      'core': 'core',
      'data': 'data',
      'features': 'feature',
      'clubs': 'club',
      'testing': 'testing',
    }.entries) {
      if (RegExp('^packages/${entry.key}/[a-z0-9_]+\$').hasMatch(path)) {
        return entry.value;
      }
    }
    return 'unknown';
  }
}

void main(List<String> args) {
  final root = args.isEmpty
      ? Directory.current
      : Directory(args.single).absolute;
  final errors = validateWorkspace(root);
  if (errors.isNotEmpty) {
    stderr.writeln(errors.join('\n'));
    exitCode = 1;
  } else {
    stdout.writeln(
      'Workspace architecture passed: manifests, layer boundaries, '
      'production imports, thin apps, and acyclic dependencies.',
    );
  }
}
