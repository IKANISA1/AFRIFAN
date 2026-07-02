import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final repoRoot = _findRepoRoot();

  group('DESIGN.md UI Guardrails', () {
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
          'Found GoogleFonts usage in UI source. Use TypographyTokens and the platform font stack.',
          violations,
        ),
      );
    });

    test('Icon choices route through AfriIcons tokens', () {
      final violations = _scanDartFiles(
        roots: [
          Directory('${repoRoot.path}/packages'),
          Directory('${repoRoot.path}/apps'),
        ],
        pattern: RegExp(r'\b(Icons|CupertinoIcons)\.'),
        allow: (path) =>
            path.endsWith(
              '/packages/core/core_theme/lib/src/tokens/icon_tokens.dart',
            ) ||
            path.contains('/test/') ||
            path.contains('/integration_test/'),
      );

      expect(
        violations,
        isEmpty,
        reason: _formatViolations(
          'Found direct platform icon constants. Add a semantic AfriIcons token instead.',
          violations,
        ),
      );
    });

    test('Typography avoids raw family strings', () {
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
          'Found raw fontFamily strings. Use TypographyTokens and the platform font stack.',
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
          'Found negative letter spacing. Universal typography uses zero tracking.',
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

    test('Club config test fixtures use shared color tokens', () {
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
          '/packages/core/core_theme/test/ui_source_guardrails_test.dart',
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
          'Found local gradient constructors. Use ColorTokens gradient helpers.',
          violations,
        ),
      );
    });

    test('Feature route app bars use shared chrome', () {
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

    test('Feature route tab bars use shared chrome', () {
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

    test('Feature packages use shared bottom sheet routes', () {
      final violations = _scanDartFiles(
        roots: [
          Directory('${repoRoot.path}/packages/features'),
          Directory('${repoRoot.path}/apps'),
        ],
        pattern: RegExp(r'\bshowModalBottomSheet\s*(?:<[^>]+>)?\s*\('),
      );

      expect(
        violations,
        isEmpty,
        reason: _formatViolations(
          'Found direct Material bottom-sheet routes. Use showAfriBottomSheet from core_theme.',
          violations,
        ),
      );
    });

    test('Migrated packages use shared toast primitives', () {
      final violations = _scanDartFiles(
        roots: [
          Directory('${repoRoot.path}/packages/features/feat_admin'),
          Directory('${repoRoot.path}/packages/features/feat_contributions'),
          Directory('${repoRoot.path}/packages/features/feat_fan_clubs'),
          Directory('${repoRoot.path}/packages/features/feat_gamification'),
          Directory('${repoRoot.path}/packages/features/feat_live'),
          Directory('${repoRoot.path}/packages/features/feat_membership'),
          Directory('${repoRoot.path}/packages/features/feat_onboarding'),
          Directory('${repoRoot.path}/packages/features/feat_settings'),
          Directory('${repoRoot.path}/packages/features/feat_shop'),
          Directory('${repoRoot.path}/packages/features/feat_ticketing'),
        ],
        pattern: RegExp(
          r'\b(ScaffoldMessenger\.of|showSnackBar|SnackBar|SnackBarAction)\b',
        ),
      );

      expect(
        violations,
        isEmpty,
        reason: _formatViolations(
          'Found direct snackbar usage in migrated packages. Use AfriToast from core_theme.',
          violations,
        ),
      );
    });

    test('Migrated shop routes shape and spacing through tokens', () {
      final violations = _scanDartFiles(
        roots: [Directory('${repoRoot.path}/packages/features/feat_shop/lib')],
        pattern: RegExp(
          r'BorderRadius\.(?:circular|only|vertical|horizontal)\(\s*(?:const\s+)?(?:[0-9]|Radius\.circular\(\s*[0-9])|'
          r'Radius\.circular\(\s*[0-9]|'
          r'EdgeInsets\.(?:all|symmetric|only|fromLTRB)\(\s*[0-9]|'
          r'SizedBox\(\s*(?:width|height):\s*[0-9]|'
          r'min(?:Width|Height):\s*[0-9]',
        ),
      );

      expect(
        violations,
        isEmpty,
        reason: _formatViolations(
          'Found raw shop shape or spacing values. Use ShapeTokens and SpacingTokens.',
          violations,
        ),
      );
    });

    test('Migrated ticketing routes shape and spacing through tokens', () {
      final violations = _scanDartFiles(
        roots: [
          Directory('${repoRoot.path}/packages/features/feat_ticketing/lib'),
        ],
        pattern: RegExp(
          r'BorderRadius\.(?:circular|only|vertical|horizontal)\(\s*(?:const\s+)?(?:[0-9]|Radius\.circular\(\s*[0-9])|'
          r'Radius\.circular\(\s*[0-9]|'
          r'EdgeInsets\.(?:all|symmetric|only|fromLTRB)\(\s*[0-9]|'
          r'SizedBox\(\s*(?:width|height):\s*[0-9]|'
          r'min(?:Width|Height):\s*[0-9]',
        ),
      );

      expect(
        violations,
        isEmpty,
        reason: _formatViolations(
          'Found raw ticketing shape or spacing values. Use ShapeTokens and SpacingTokens.',
          violations,
        ),
      );
    });

    test('Migrated membership routes shape and spacing through tokens', () {
      final violations = _scanDartFiles(
        roots: [
          Directory('${repoRoot.path}/packages/features/feat_membership/lib'),
        ],
        pattern: RegExp(
          r'BorderRadius\.(?:circular|only|vertical|horizontal)\(\s*(?:const\s+)?(?:[0-9]|Radius\.circular\(\s*[0-9])|'
          r'Radius\.circular\(\s*[0-9]|'
          r'EdgeInsets\.(?:all|symmetric|only|fromLTRB)\(\s*[0-9]|'
          r'SizedBox\(\s*(?:width|height):\s*[0-9]|'
          r'min(?:Width|Height):\s*[0-9]',
        ),
      );

      expect(
        violations,
        isEmpty,
        reason: _formatViolations(
          'Found raw membership shape or spacing values. Use ShapeTokens and SpacingTokens.',
          violations,
        ),
      );
    });

    test('Migrated gamification surfaces shape and spacing through tokens', () {
      final violations = _scanDartFiles(
        roots: [
          Directory('${repoRoot.path}/packages/features/feat_gamification/lib'),
        ],
        pattern: RegExp(
          r'BorderRadius\.(?:circular|only|vertical|horizontal)\(\s*(?:const\s+)?(?:[0-9]|Radius\.circular\(\s*[0-9])|'
          r'Radius\.circular\(\s*[0-9]|'
          r'EdgeInsets\.(?:all|symmetric|only|fromLTRB)\(\s*[0-9]|'
          r'SizedBox\(\s*(?:width|height):\s*[0-9]|'
          r'(?:Animated)?Container\(\s*(?:width|height):\s*[0-9]|'
          r'min(?:Width|Height):\s*[0-9]',
        ),
      );

      expect(
        violations,
        isEmpty,
        reason: _formatViolations(
          'Found raw shape or spacing values in migrated gamification surfaces. Use ShapeTokens and SpacingTokens.',
          violations,
        ),
      );
    });

    test('Gamification fixed dimensions route through tokens', () {
      final violations = _scanDartFiles(
        roots: [
          Directory('${repoRoot.path}/packages/features/feat_gamification/lib'),
        ],
        pattern: RegExp(
          r'(?:horizontal|vertical|width|height|size|minHeight|minWidth):\s*[0-9]|'
          r'Radius\.circular\([0-9]|'
          r'BorderRadius\.circular\([0-9]|'
          r'EdgeInsets\.all\([0-9]',
        ),
      );

      expect(
        violations,
        isEmpty,
        reason: _formatViolations(
          'Found raw gamification dimensions or typography heights. Use shared tokens instead.',
          violations,
        ),
      );
    });

    test('Migrated settings dimensions and typography route through tokens', () {
      final violations = _scanDartFiles(
        roots: [
          Directory('${repoRoot.path}/packages/features/feat_settings/lib'),
        ],
        pattern: RegExp(
          r'(?:horizontal|vertical|width|height|size|minHeight|minWidth):\s*[0-9]|'
          r'Size\(\s*double\.infinity\s*,\s*[0-9]|'
          r'Radius\.circular\([0-9]|'
          r'BorderRadius\.circular\([0-9]|'
          r'EdgeInsets\.all\([0-9]|'
          r'letterSpacing:\s*[0-9]',
        ),
      );

      expect(
        violations,
        isEmpty,
        reason: _formatViolations(
          'Found raw settings dimensions or typography tracking. Use SizeTokens, ShapeTokens, SpacingTokens, and TypographyTokens instead.',
          violations,
        ),
      );
    });

    test('Migrated fan club dimensions and typography route through tokens', () {
      final violations = _scanDartFiles(
        roots: [
          Directory('${repoRoot.path}/packages/features/feat_fan_clubs/lib'),
        ],
        pattern: RegExp(
          r'(?:horizontal|vertical|width|height|size|minHeight|minWidth):\s*[0-9]|'
          r'Size\(\s*double\.infinity\s*,\s*[0-9]|'
          r'Radius\.circular\([0-9]|'
          r'BorderRadius\.circular\([0-9]|'
          r'EdgeInsets\.all\([0-9]|'
          r'letterSpacing:\s*[0-9]',
        ),
      );

      expect(
        violations,
        isEmpty,
        reason: _formatViolations(
          'Found raw fan-club dimensions or typography tracking. Use SizeTokens, ShapeTokens, SpacingTokens, and TypographyTokens instead.',
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

    test('Feature packages use shared input field primitives', () {
      final violations = _scanDartFiles(
        roots: [
          Directory('${repoRoot.path}/packages/features'),
          Directory('${repoRoot.path}/apps'),
        ],
        pattern: RegExp(r'\b(TextField|TextFormField)\s*\('),
      );

      expect(
        violations,
        isEmpty,
        reason: _formatViolations(
          'Found direct Material text inputs. Use AfriInputField or AfriTextFormField from core_theme.',
          violations,
        ),
      );
    });

    test('Feature packages use shared compact toggle primitives', () {
      final violations = _scanDartFiles(
        roots: [
          Directory('${repoRoot.path}/packages/features'),
          Directory('${repoRoot.path}/apps'),
        ],
        pattern: RegExp(r'\b(Switch|Checkbox|Radio|Slider)\s*\('),
      );

      expect(
        violations,
        isEmpty,
        reason: _formatViolations(
          'Found direct Material compact controls. Use AfriSwitch or a shared core_theme control primitive.',
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

    for (final entity in _safeRecursiveList(root)) {
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

    for (final entity in _safeRecursiveList(root)) {
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

List<FileSystemEntity> _safeRecursiveList(Directory root) {
  final entities = <FileSystemEntity>[];
  final pending = <Directory>[root];

  while (pending.isNotEmpty) {
    final directory = pending.removeLast();
    List<FileSystemEntity> children;
    try {
      children = directory.listSync(followLinks: false);
    } on FileSystemException {
      continue;
    }

    for (final child in children) {
      final normalizedPath = child.path.replaceAll('\\', '/');
      if (_isGeneratedPath(normalizedPath)) {
        continue;
      }
      entities.add(child);
      if (child is Directory) {
        pending.add(child);
      }
    }
  }

  return entities;
}

bool _isGeneratedPath(String normalizedPath) {
  return normalizedPath.contains('/build/') ||
      normalizedPath.contains('/.dart_tool/') ||
      normalizedPath.contains('/.next/') ||
      normalizedPath.endsWith('/.next') ||
      normalizedPath.contains('/ios/Pods/');
}

String _formatViolations(String heading, List<String> violations) {
  if (violations.isEmpty) return heading;
  return '$heading\n${violations.join('\n')}';
}
