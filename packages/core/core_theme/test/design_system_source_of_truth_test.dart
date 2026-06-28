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

    test('Feature and app typography routes through shared tokens', () {
      final violations = _scanDartFiles(
        roots: [
          Directory('${repoRoot.path}/packages/features'),
          Directory('${repoRoot.path}/apps'),
        ],
        pattern: RegExp(r'style:\s*(const\s+)?TextStyle\s*\('),
        allow: (path) =>
            path.contains('/test/') || path.contains('/integration_test/'),
      );

      expect(
        violations,
        isEmpty,
        reason: _formatViolations(
          'Found direct TextStyle constructors. Use TypographyTokens from core_theme.',
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

    test('Club config test fixtures use borrowed color tokens', () {
      final violations = _scanDartFiles(
        roots: [
          Directory('${repoRoot.path}/packages'),
          Directory('${repoRoot.path}/apps'),
        ],
        pattern: RegExp(
          r'(primary|secondary|accent):\s*Color\s*\(|gradient:\s*(?:<Color>)?\s*\[\s*Color\s*\(',
        ),
        allow: (path) =>
            !path.contains('/test/') && !path.contains('/integration_test/'),
      );

      expect(
        violations,
        isEmpty,
        reason: _formatViolations(
          'Found raw ClubColors fixture colors. Use ColorTokens reference colors in tests.',
          violations,
        ),
      );
    });

    test('Legacy surface component names stay out of authored UI source', () {
      final violations = _scanDartFiles(
        roots: [
          Directory('${repoRoot.path}/packages'),
          Directory('${repoRoot.path}/apps'),
        ],
        pattern: RegExp(
          r'\b(ClayCard|ClaymorphicButton|EliteCard|EliteButton|EliteButtonVariant)\b',
        ),
        allow: (path) => path.endsWith(
          '/packages/core/core_theme/test/design_system_source_of_truth_test.dart',
        ),
      );

      expect(
        violations,
        isEmpty,
        reason: _formatViolations(
          'Found legacy surface component names. Use AfriSurfaceCard, AfriPanelCard, and AfriButton.',
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

    test('Feature packages route gradients through core_theme tokens', () {
      final violations = _scanDartFiles(
        roots: [
          Directory('${repoRoot.path}/packages/features'),
          Directory('${repoRoot.path}/apps'),
        ],
        pattern: RegExp(
          r'\b(LinearGradient|RadialGradient|SweepGradient)\s*\(',
        ),
      );

      expect(
        violations,
        isEmpty,
        reason: _formatViolations(
          'Found local gradient constructors. Use ColorTokens borrowed gradient helpers.',
          violations,
        ),
      );
    });

    test('Feature route app bars use borrowed chrome', () {
      final violations = _scanDartFiles(
        roots: [
          Directory('${repoRoot.path}/packages/features'),
          Directory('${repoRoot.path}/apps'),
        ],
        pattern: RegExp(r'(appBar:\s*AppBar|\bSliverAppBar)\s*\('),
      );

      expect(
        violations,
        isEmpty,
        reason: _formatViolations(
          'Found direct route chrome. Use AfriAppBar or AfriSliverAppBar from core_theme.',
          violations,
        ),
      );
    });

    test('Feature route tab bars use borrowed chrome', () {
      final violations = _scanDartFiles(
        roots: [
          Directory('${repoRoot.path}/packages/features'),
          Directory('${repoRoot.path}/apps'),
        ],
        pattern: RegExp(r'\bTabBar\s*\('),
      );

      expect(
        violations,
        isEmpty,
        reason: _formatViolations(
          'Found direct route tabs. Use AfriTabBar from core_theme.',
          violations,
        ),
      );
    });

    test('Feature packages use shared separator primitives', () {
      final violations = _scanDartFiles(
        roots: [
          Directory('${repoRoot.path}/packages/features'),
          Directory('${repoRoot.path}/apps'),
        ],
        pattern: RegExp(r'\b(Divider|VerticalDivider)\s*\('),
      );

      expect(
        violations,
        isEmpty,
        reason: _formatViolations(
          'Found direct Material separators. Use AfriDivider from core_theme.',
          violations,
        ),
      );
    });

    test('Feature packages use shared press feedback primitives', () {
      final violations = _scanDartFiles(
        roots: [
          Directory('${repoRoot.path}/packages/features'),
          Directory('${repoRoot.path}/apps'),
        ],
        pattern: RegExp(r'\b(InkWell|InkResponse)\s*\('),
      );

      expect(
        violations,
        isEmpty,
        reason: _formatViolations(
          'Found direct Material press surfaces. Use AfriPressFeedback from core_theme.',
          violations,
        ),
      );
    });

    test('Feature packages use shared popup menu primitives', () {
      final violations = _scanDartFiles(
        roots: [
          Directory('${repoRoot.path}/packages/features'),
          Directory('${repoRoot.path}/apps'),
        ],
        pattern: RegExp(r'\bPopupMenuButton\s*\('),
      );

      expect(
        violations,
        isEmpty,
        reason: _formatViolations(
          'Found direct Material popup menus. Use AfriPopupMenuButton from core_theme.',
          violations,
        ),
      );
    });

    test('Feature packages use shared refresh primitives', () {
      final violations = _scanDartFiles(
        roots: [
          Directory('${repoRoot.path}/packages/features'),
          Directory('${repoRoot.path}/apps'),
        ],
        pattern: RegExp(r'\bRefreshIndicator\s*\('),
      );

      expect(
        violations,
        isEmpty,
        reason: _formatViolations(
          'Found direct Material pull-to-refresh chrome. Use AfriRefreshIndicator from core_theme.',
          violations,
        ),
      );
    });

    test('Feature packages use shared progress primitives', () {
      final violations = _scanDartFiles(
        roots: [
          Directory('${repoRoot.path}/packages/features'),
          Directory('${repoRoot.path}/apps'),
        ],
        pattern: RegExp(
          r'\b(CircularProgressIndicator|LinearProgressIndicator)\s*\(',
        ),
      );

      expect(
        violations,
        isEmpty,
        reason: _formatViolations(
          'Found direct Material progress indicators. Use AfriLoadingIndicator or AfriLinearProgressIndicator from core_theme.',
          violations,
        ),
      );
    });

    test('Feature packages use shared dialog primitives', () {
      final violations = _scanDartFiles(
        roots: [
          Directory('${repoRoot.path}/packages/features'),
          Directory('${repoRoot.path}/apps'),
        ],
        pattern: RegExp(
          r'\b(Dialog|AlertDialog|SimpleDialog|AboutDialog)\s*\(',
        ),
      );

      expect(
        violations,
        isEmpty,
        reason: _formatViolations(
          'Found direct Material dialog surfaces. Use AfriDialog or AfriAlertDialog from core_theme.',
          violations,
        ),
      );
    });

    test('Feature packages use shared button primitives', () {
      final violations = _scanDartFiles(
        roots: [
          Directory('${repoRoot.path}/packages/features'),
          Directory('${repoRoot.path}/apps'),
        ],
        pattern: RegExp(r'\b(TextButton|OutlinedButton|ElevatedButton)\s*\('),
      );

      expect(
        violations,
        isEmpty,
        reason: _formatViolations(
          'Found direct platform button widgets. Use AfriButton, AfriTextButton, AfriOutlinedButton, or AfriElevatedButton.',
          violations,
        ),
      );
    });

    test('Feature packages use shared chip primitives', () {
      final violations = _scanDartFiles(
        roots: [
          Directory('${repoRoot.path}/packages/features'),
          Directory('${repoRoot.path}/apps'),
        ],
        pattern: RegExp(
          r'\b(Chip|ActionChip|FilterChip|ChoiceChip|InputChip|RawChip)\s*\(',
        ),
      );

      expect(
        violations,
        isEmpty,
        reason: _formatViolations(
          'Found direct Material chip widgets. Use AfriChip, AfriChoiceChip, AfriInfoChip, or AfriStatusChip.',
          violations,
        ),
      );
    });

    test('Feature packages use shared list row primitives', () {
      final violations = _scanDartFiles(
        roots: [
          Directory('${repoRoot.path}/packages/features'),
          Directory('${repoRoot.path}/apps'),
        ],
        pattern: RegExp(
          r'\b(ListTile|SwitchListTile|CheckboxListTile|RadioListTile)\s*\(',
        ),
      );

      expect(
        violations,
        isEmpty,
        reason: _formatViolations(
          'Found direct Material list/toggle rows. Use AfriListRow, AfriListTile, or AfriSwitchListTile.',
          violations,
        ),
      );
    });

    test('Feature and app UI use core_theme color tokens', () {
      final violations = _scanDartFiles(
        roots: [
          Directory('${repoRoot.path}/packages/features'),
          Directory('${repoRoot.path}/apps'),
        ],
        pattern: RegExp(r'\bColors\.'),
      );

      expect(
        violations,
        isEmpty,
        reason: _formatViolations(
          'Found raw Material colors in feature/app UI. Use ColorTokens, AfriSemanticColors, or ExternalBrandColors from core_theme.',
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
