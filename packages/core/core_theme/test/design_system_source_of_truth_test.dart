import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final repoRoot = _findRepoRoot();

  group('Design System Guardrails', () {
    test('ThemeData construction stays centralized in core_theme', () {
      final violations = _scanDartFiles(
        roots: [
          Directory('${repoRoot.path}/packages'),
          Directory('${repoRoot.path}/apps'),
        ],
        pattern: RegExp(r'\bThemeData\s*\('),
        allow: (path) =>
            path.endsWith(
              '/packages/core/core_theme/lib/src/club_theme.dart',
            ) ||
            path.contains('/test/') ||
            path.contains('/integration_test/'),
      );

      expect(
        violations,
        isEmpty,
        reason: _formatViolations(
          'Found ThemeData constructors outside the single-source core theme.',
          violations,
        ),
      );
    });

    test('GoogleFonts usage stays out of UI source', () {
      final violations = _scanDartFiles(
        roots: [
          Directory('${repoRoot.path}/packages'),
          Directory('${repoRoot.path}/apps'),
        ],
        pattern: RegExp(r'\bGoogleFonts\.'),
        allow: (path) =>
            path.contains('/test/') || path.contains('/integration_test/'),
      );

      expect(
        violations,
        isEmpty,
        reason: _formatViolations(
          'Found GoogleFonts usage in UI source. Use RevolutBorrowed through TypographyTokens.',
          violations,
        ),
      );
    });

    test('Typography uses borrowed font tokens without raw family strings', () {
      final violations = _scanDartFiles(
        roots: [
          Directory('${repoRoot.path}/packages'),
          Directory('${repoRoot.path}/apps'),
        ],
        pattern: RegExp(r'''fontFamily:\s*['"]'''),
      );

      expect(
        violations,
        isEmpty,
        reason: _formatViolations(
          'Found raw fontFamily strings. Use TypographyTokens.borrowedFontFamily.',
          violations,
        ),
      );
    });

    test('Typography does not use negative letter spacing', () {
      final violations = _scanDartFiles(
        roots: [
          Directory('${repoRoot.path}/packages'),
          Directory('${repoRoot.path}/apps'),
        ],
        pattern: RegExp(r'letterSpacing:\s*-[0-9]'),
      );

      expect(
        violations,
        isEmpty,
        reason: _formatViolations(
          'Found negative letter spacing. Borrowed typography uses zero tracking.',
          violations,
        ),
      );
    });

    test('Feature packages do not declare local font fixtures', () {
      final violations = _scanTextFiles(
        roots: [Directory('${repoRoot.path}/packages/features')],
        extensions: const {'.yaml', '.yml'},
        pattern: RegExp(r'test/fonts|google_fonts'),
      );

      expect(
        violations,
        isEmpty,
        reason: _formatViolations(
          'Found feature-local font fixture declarations.',
          violations,
        ),
      );
    });

    test('Feature packages use shared border tokens instead of raw outlines', () {
      final violations = _scanDartFiles(
        roots: [Directory('${repoRoot.path}/packages/features')],
        pattern: RegExp(r'\b(Border\.all|BorderSide|OutlineInputBorder)\s*\('),
      );

      expect(
        violations,
        isEmpty,
        reason: _formatViolations(
          'Found raw border constructors in feature packages. Route them through BorderTokens.',
          violations,
        ),
      );
    });
  });
}

Directory _findRepoRoot() {
  var current = Directory.current.absolute;
  while (true) {
    final packagesDir = Directory('${current.path}/packages');
    final appsDir = Directory('${current.path}/apps');
    if (packagesDir.existsSync() && appsDir.existsSync()) {
      return current;
    }

    final parent = current.parent;
    if (parent.path == current.path) {
      throw StateError(
        'Could not locate repository root from ${Directory.current.path}',
      );
    }
    current = parent;
  }
}

List<String> _scanDartFiles({
  required List<Directory> roots,
  required RegExp pattern,
  bool Function(String normalizedPath)? allow,
}) {
  final violations = <String>[];

  for (final root in roots) {
    if (!root.existsSync()) continue;

    for (final entity in root.listSync(recursive: true, followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;

      final normalizedPath = entity.path.replaceAll('\\', '/');
      if (_isGeneratedPath(normalizedPath)) continue;
      if (normalizedPath.endsWith('.g.dart')) continue;
      if (allow != null && allow(normalizedPath)) continue;

      final content = entity.readAsStringSync();
      if (pattern.hasMatch(content)) {
        violations.add(normalizedPath);
      }
    }
  }

  violations.sort();
  return violations;
}

List<String> _scanTextFiles({
  required List<Directory> roots,
  required Set<String> extensions,
  required RegExp pattern,
}) {
  final violations = <String>[];

  for (final root in roots) {
    if (!root.existsSync()) continue;

    for (final entity in root.listSync(recursive: true, followLinks: false)) {
      if (entity is! File) continue;

      final normalizedPath = entity.path.replaceAll('\\', '/');
      if (_isGeneratedPath(normalizedPath)) continue;
      if (!extensions.any(normalizedPath.endsWith)) continue;

      final content = entity.readAsStringSync();
      if (pattern.hasMatch(content)) {
        violations.add(normalizedPath);
      }
    }
  }

  violations.sort();
  return violations;
}

bool _isGeneratedPath(String normalizedPath) {
  return normalizedPath.contains('/build/') ||
      normalizedPath.contains('/.dart_tool/') ||
      normalizedPath.contains('/ios/Pods/');
}

String _formatViolations(String heading, List<String> violations) {
  if (violations.isEmpty) return heading;
  return '$heading\n${violations.join('\n')}';
}
