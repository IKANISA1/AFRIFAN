import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final repoRoot = _findRepoRoot();

  group('DESIGN.md UI Guardrails', () {
    test('Repository design documents do not introduce competing rules', () {
      final violations = _findSecondaryDesignAuthorityFiles(repoRoot);

      expect(
        violations,
        isEmpty,
        reason: _formatViolations(
          'Found competing design rules. Keep product mappings in DESIGN.md and bind them to the selected skill authority.',
          violations,
        ),
      );
    });

    test('Generated design gate validates the selected skill authority', () {
      final gate = File(
        '${repoRoot.path}/tools/scripts/design_compliance_report.sh',
      );

      expect(gate.existsSync(), isTrue);
      final content = gate.readAsStringSync();
      expect(content, contains('validate_design_authority.mjs'));
      expect(content, contains('.authority_sha256'));
      expect(content, contains('design-authority-binding.json'));
      expect(content, isNot(contains(r'${SOURCE_DESIGN:-$ROOT/DESIGN.md}')));
      expect(content, contains('output/design_compliance'));
      expect(content, contains('route_evidence_matrix.md'));
    });

    test('Primary mobile journeys retain automated touch-target audits', () {
      const auditedRouteTests = <String>[
        'packages/features/feat_home/test/home_screen_states_test.dart',
        'packages/features/feat_home/test/discovery_search_test.dart',
        'packages/features/feat_gamification/test/predict_shell_navigation_test.dart',
        'packages/features/feat_settings/test/settings_screens_test.dart',
        'packages/features/feat_onboarding/test/onboarding_flow_test.dart',
        'packages/features/feat_membership/test/membership_screen_ui_test.dart',
        'packages/features/feat_contributions/test/contributions_hub_screen_test.dart',
        'packages/features/feat_ticketing/test/match_list_ui_test.dart',
        'packages/features/feat_shop/test/shop_screen_catalog_test.dart',
      ];

      for (final relativePath in auditedRouteTests) {
        final file = File('${repoRoot.path}/$relativePath');
        expect(
          file.existsSync(),
          isTrue,
          reason: 'Missing primary-route test: $relativePath',
        );
        expect(
          file.readAsStringSync(),
          contains('expectTapTargetsMeetMinimum(tester'),
          reason:
              '$relativePath must retain its rendered 48x48 touch-target audit.',
        );
      }
    });

    test('Reduced-motion coverage stays attached to required surfaces', () {
      const requiredSourceContracts = <String, List<String>>{
        'packages/core/core_router/lib/src/route_transitions.dart': [
          'AfriMotion.reduceMotion(context)',
        ],
        'packages/features/feat_onboarding/lib/src/screens/onboarding_screen.dart':
            [
              'if (AfriMotion.reduceMotion(context))',
              '_pageController.jumpToPage(next)',
              'AfriMotion.resolve(context, AfriMotion.standard)',
            ],
        'packages/core/core_theme/lib/src/widgets/afri_skeleton.dart': [
          '_reduceMotion = AfriMotion.reduceMotion(context)',
        ],
        'packages/core/core_theme/lib/src/widgets/afri_scanner_shell.dart': [
          '_reduceMotion = AfriMotion.reduceMotion(context)',
          '.afriAnimate(context)',
        ],
        'packages/features/feat_shop/lib/src/widgets/shop_loading_skeleton.dart':
            ['final reduceMotion = AfriMotion.reduceMotion(context)'],
        'packages/core/core_theme/lib/src/widgets/afri_bottom_sheet.dart': [
          'AnimationStyle.noAnimation',
        ],
        'packages/core/core_theme/lib/src/widgets/afri_action_sheet.dart': [
          'AnimationStyle.noAnimation',
        ],
        'apps/rayon_sports/web/src/components/count-up.tsx': [
          'useReducedMotion()',
        ],
        'apps/rayon_sports/web/src/components/mobile-nav-drawer.tsx': [
          'useReducedMotion()',
          'motion-reduce:transition-none',
        ],
        'apps/rayon_sports/web/src/components/admin/admin-shell.tsx': [
          'motion-reduce:transition-none',
        ],
        'apps/rayon_sports/web/src/ui-kit/theme.css': [
          '@media (prefers-reduced-motion: reduce)',
          'animation-delay: 0ms !important',
          'transition-delay: 0ms !important',
        ],
      };

      for (final entry in requiredSourceContracts.entries) {
        final file = File('${repoRoot.path}/${entry.key}');
        expect(file.existsSync(), isTrue, reason: 'Missing ${entry.key}');
        final source = file.readAsStringSync();
        for (final contract in entry.value) {
          expect(
            source,
            contains(contract),
            reason: '${entry.key} lost reduced-motion contract: $contract',
          );
        }
      }
    });

    test('Feature effect chains route through the reduced-motion adapter', () {
      final violations = <String>[];
      final featuresRoot = Directory('${repoRoot.path}/packages/features');

      for (final entity in _safeRecursiveList(featuresRoot)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final normalizedPath = entity.path.replaceAll('\\', '/');
        if (!normalizedPath.contains('/lib/')) continue;
        final source = entity.readAsStringSync();
        if (!source.contains('package:flutter_animate/flutter_animate.dart')) {
          continue;
        }
        if (RegExp(r'\.animate\s*\(').hasMatch(source)) {
          violations.add(normalizedPath);
        }
      }

      expect(
        violations,
        isEmpty,
        reason: _formatViolations(
          'Found a feature Widget.animate() chain. Use afriAnimate(context) so reduced motion skips effects and stagger delays.',
          violations,
        ),
      );
    });

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
          'Found ThemeData constructors outside the centralized core theme.',
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

    test('Shared top and bottom chrome contain no standard-covered literals', () {
      final violations = _scanDartFiles(
        roots: [
          Directory(
            '${repoRoot.path}/packages/core/core_theme/lib/src/widgets',
          ),
        ],
        pattern: RegExp(
          r'\b(TextStyle|BoxShadow|Duration)\s*\(|'
          r'\bColors\.|'
          r'\bBorder\.all\s*\(|'
          r'ImageFilter\.blur\([^)]*(?:sigmaX|sigmaY):\s*-?[0-9]|'
          r'(?:width|height|size|minWidth|minHeight|blurRadius|spreadRadius|fontSize|letterSpacing|scaleEnd|alpha):\s*-?[0-9]',
          multiLine: true,
        ),
        allow: (path) =>
            !path.endsWith('/afri_top_command_bar.dart') &&
            !path.endsWith('/africlub_bottom_nav.dart'),
      );

      expect(
        violations,
        isEmpty,
        reason: _formatViolations(
          'Found a one-off chrome constant. Route command/nav geometry, focus, blur, shadow, typography, color strength, and motion through semantic tokens.',
          violations,
        ),
      );
    });

    test(
      'Shared components centralize typography, motion, blur, and shadows',
      () {
        final violations = _scanDartFiles(
          roots: [
            Directory(
              '${repoRoot.path}/packages/core/core_theme/lib/src/widgets',
            ),
          ],
          pattern: RegExp(
            r'(^|[^A-Za-z])TextStyle\s*\(|'
            r'\b(BoxShadow|Duration)\s*\(|'
            r'\b[0-9]+\.(?:ms|seconds)\b|'
            r'ImageFilter\.blur\([^)]*(?:sigmaX|sigmaY):\s*-?[0-9]',
            multiLine: true,
          ),
        );

        expect(
          violations,
          isEmpty,
          reason: _formatViolations(
            'Found a standard-covered shared-component literal. Use TypographyTokens, AfriMotion, AfriBlur, or AfriShadows.',
            violations,
          ),
        );
      },
    );

    test('Shared component boundaries route through BorderTokens', () {
      final violations = _scanDartFiles(
        roots: [
          Directory(
            '${repoRoot.path}/packages/core/core_theme/lib/src/widgets',
          ),
        ],
        pattern: RegExp(r'\bBorder\.all\s*\('),
      );

      expect(
        violations,
        isEmpty,
        reason: _formatViolations(
          'Found a direct shared-component border. Use BorderTokens so normal and focus boundaries stay synchronized.',
          violations,
        ),
      );
    });

    test('Shared fixed geometry routes through semantic size tokens', () {
      final violations = _scanDartFiles(
        roots: [
          Directory(
            '${repoRoot.path}/packages/core/core_theme/lib/src/widgets',
          ),
        ],
        pattern: RegExp(
          r'(?:width|height|size|minWidth|minHeight|maxWidth|maxHeight|dimension|strokeWidth|indicatorWeight|displacement|edgeOffset|fontSize|letterSpacing|scaleEnd):\s*(?:[^,\n]*\?\s*)?-?[0-9]+(?:\.[0-9]+)?|'
          r'this\.(?:width|height|size|minWidth|minHeight|maxWidth|maxHeight|displacement|edgeOffset|strokeWidth|fontSize)\s*=\s*-?[0-9]+(?:\.[0-9]+)?|'
          r'EdgeInsets\.(?:all|symmetric|only|fromLTRB)\([^)]*(?:horizontal|vertical|top|bottom|left|right):\s*-?[0-9]+(?:\.[0-9]+)?|'
          r'BoxConstraints\([^)]*(?:minWidth|minHeight|maxWidth|maxHeight):\s*-?[0-9]+(?:\.[0-9]+)?',
          multiLine: true,
        ),
      );

      expect(
        violations,
        isEmpty,
        reason: _formatViolations(
          'Found fixed shared-component geometry outside AfriComponentSizes, SizeTokens, SpacingTokens, ShapeTokens, BorderTokens, or TypographyTokens.',
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

    test('Priority transaction routes use the shared responsive scaffold', () {
      final violations = _scanDartFiles(
        roots: [
          Directory(
            '${repoRoot.path}/packages/features/feat_membership/lib/src/screens',
          ),
          Directory(
            '${repoRoot.path}/packages/features/feat_contributions/lib/src/screens',
          ),
          Directory(
            '${repoRoot.path}/packages/features/feat_shop/lib/src/screens',
          ),
          Directory(
            '${repoRoot.path}/packages/features/feat_ticketing/lib/src/screens',
          ),
          Directory(
            '${repoRoot.path}/packages/features/feat_onboarding/lib/src/screens',
          ),
        ],
        pattern: RegExp(r'return\s+(?:const\s+)?Scaffold\s*\('),
      );

      expect(
        violations,
        isEmpty,
        reason: _formatViolations(
          'Found a priority transaction route bypassing AfriScreenScaffold.',
          violations,
        ),
      );
    });

    test('Priority notification route uses the shared responsive scaffold', () {
      final violations = _scanDartFiles(
        roots: [
          Directory(
            '${repoRoot.path}/packages/features/feat_gamification/lib/src/screens',
          ),
          Directory(
            '${repoRoot.path}/packages/features/feat_settings/lib/src/screens',
          ),
        ],
        pattern: RegExp(r'return\s+(?:const\s+)?Scaffold\s*\('),
        allow: (path) {
          return !path.endsWith('/prediction_notifications_screen.dart') &&
              !path.endsWith('/notification_preferences_screen.dart');
        },
      );

      expect(
        violations,
        isEmpty,
        reason: _formatViolations(
          'Found the priority notification route bypassing AfriScreenScaffold.',
          violations,
        ),
      );
    });

    test('Fan Zone route uses the shared responsive scaffold', () {
      final violations = _scanDartFiles(
        roots: [
          Directory(
            '${repoRoot.path}/packages/features/feat_gamification/lib/src/screens',
          ),
        ],
        pattern: RegExp(r'return\s+(?:const\s+)?Scaffold\s*\('),
        allow: (path) => !path.endsWith('/club_fan_zone_screen.dart'),
      );

      expect(
        violations,
        isEmpty,
        reason: _formatViolations(
          'Found the Fan Zone route bypassing AfriScreenScaffold.',
          violations,
        ),
      );
    });

    test(
      'Router fallbacks and migrated Settings routes use the shared scaffold',
      () {
        final violations = _scanDartFiles(
          roots: [
            Directory('${repoRoot.path}/packages/core/core_router/lib/src'),
            Directory(
              '${repoRoot.path}/packages/features/feat_settings/lib/src/screens',
            ),
          ],
          pattern: RegExp(r'\bScaffold\s*\('),
          allow: (path) {
            if (path.contains('/packages/core/core_router/lib/src/')) {
              return false;
            }

            return !path.endsWith('/edit_profile_screen.dart') &&
                !path.endsWith('/privacy_settings_screen.dart');
          },
        );

        expect(
          violations,
          isEmpty,
          reason: _formatViolations(
            'Found a migrated router or Settings route bypassing AfriScreenScaffold.',
            violations,
          ),
        );
      },
    );

    test('Fan club and live routes use the shared responsive scaffold', () {
      final violations = _scanDartFiles(
        roots: [
          Directory(
            '${repoRoot.path}/packages/features/feat_fan_clubs/lib/src/screens',
          ),
          Directory(
            '${repoRoot.path}/packages/features/feat_live/lib/src/screens',
          ),
        ],
        pattern: RegExp(r'\bScaffold\s*\('),
      );

      expect(
        violations,
        isEmpty,
        reason: _formatViolations(
          'Found a Fan Club or Live route bypassing AfriScreenScaffold.',
          violations,
        ),
      );
    });

    test('All gamification routes use the shared responsive scaffold', () {
      final violations = _scanDartFiles(
        roots: [
          Directory(
            '${repoRoot.path}/packages/features/feat_gamification/lib/src/screens',
          ),
        ],
        pattern: RegExp(r'\bScaffold\s*\('),
      );

      expect(
        violations,
        isEmpty,
        reason: _formatViolations(
          'Found a gamification route bypassing AfriScreenScaffold.',
          violations,
        ),
      );
    });

    test('All Flutter admin routes use the shared responsive scaffold', () {
      final violations = _scanDartFiles(
        roots: [
          Directory(
            '${repoRoot.path}/packages/features/feat_admin/lib/src/screens',
          ),
        ],
        pattern: RegExp(r'\bScaffold\s*\('),
      );

      expect(
        violations,
        isEmpty,
        reason: _formatViolations(
          'Found a Flutter admin route bypassing AfriScreenScaffold.',
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
        allow: _isTouchTargetAuditTool,
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

    test('Visible task copy does not describe obvious interface mechanics', () {
      final violations = _scanDartFiles(
        roots: [
          Directory('${repoRoot.path}/packages/features'),
          Directory('${repoRoot.path}/apps'),
        ],
        pattern: RegExp(
          r'''['"][^'"]*(action below|confirm below|app UI|show in [^'"]+ UI|controls UI rendering state|safe (app|product) destination|pair securely|connecting securely|last safe controller layout|on this screen|in this app|secure sign-in code)[^'"]*['"]''',
          caseSensitive: false,
        ),
        allow: (path) => path.endsWith(
          '/packages/core/core_theme/test/ui_source_guardrails_test.dart',
        ),
      );

      expect(
        violations,
        isEmpty,
        reason: _formatViolations(
          'Found visible copy that explains obvious interface mechanics.',
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
        allow: _isTouchTargetAuditTool,
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
        allow: _isTouchTargetAuditTool,
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
        allow: _isTouchTargetAuditTool,
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
        allow: _isTouchTargetAuditTool,
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
        allow: _isTouchTargetAuditTool,
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

    test('Repo stores only governed runtime media', () {
      final violations = _findStoredVisualAssets(repoRoot);

      expect(
        violations,
        isEmpty,
        reason: _formatViolations(
          'Found unmanaged visual assets. Runtime product media must live under an app assets directory or the registered Club crest package directory with a same-folder SOURCES.md entry, source URL, and explicit release-approval requirement.',
          violations,
        ),
      );
    });

    test('Deleted static design asset paths do not return', () {
      final violations = _findForbiddenStaticDesignReferences(repoRoot);

      expect(
        violations,
        isEmpty,
        reason: _formatViolations(
          'Found references to deleted static design assets or asset contracts.',
          violations,
        ),
      );
    });

    test('Generated Lighthouse evidence stays outside source scans', () {
      expect(
        _isGeneratedPath(
          '${repoRoot.path}/apps/rayon_sports/web/.lighthouseci/home-run-1.html',
        ),
        isTrue,
      );
      expect(
        _isGeneratedPath(
          '${repoRoot.path}/apps/rayon_sports/web/src/app/page.tsx',
        ),
        isFalse,
      );
    });

    test('Preserved Drive evidence does not become an active design surface', () {
      final fixture = Directory.systemTemp.createTempSync(
        'africlub-visual-source-boundary-',
      );
      addTearDown(() => fixture.deleteSync(recursive: true));
      void write(String relative, String content) {
        final file = File('${fixture.path}/$relative');
        file.parent.createSync(recursive: true);
        file.writeAsStringSync(content);
      }

      write(
        'docs/drive-import/2026-09-28/mirror/DESIGN.md',
        'Historical source of truth for product design. assets/images/old.png',
      );
      write(
        'docs/drive-import/2026-09-28/mirror/capture.png',
        'Synthetic archived screenshot bytes; no runtime rights approval.',
      );
      expect(_findSecondaryDesignAuthorityFiles(fixture), isEmpty);
      expect(_findStoredVisualAssets(fixture), isEmpty);
      expect(_findForbiddenStaticDesignReferences(fixture), isEmpty);

      // Copying historical material into a live surface restores every guard;
      // the archive's location cannot confer runtime rights or design authority.
      write(
        'docs/style-guide.md',
        'Competing source of truth for product design.',
      );
      write(
        'apps/club/assets/capture.png',
        'Synthetic unregistered live asset bytes.',
      );
      write(
        'apps/club/lib/screen.dart',
        "Image.asset('assets/images/old.png')",
      );
      expect(_findSecondaryDesignAuthorityFiles(fixture), [
        '${fixture.path}/docs/style-guide.md',
      ]);
      expect(_findStoredVisualAssets(fixture), [
        '${fixture.path}/apps/club/assets/capture.png',
      ]);
      expect(_findForbiddenStaticDesignReferences(fixture), [
        '${fixture.path}/apps/club/lib/screen.dart',
      ]);
      expect(
        _isPreservedDriveEvidencePath(
          fixture,
          '${fixture.path}/apps/club/docs/drive-import/capture.png',
        ),
        isFalse,
      );
    });

    test('Registered media API templates do not waive static asset guards', () {
      final fixture = Directory.systemTemp.createTempSync(
        'africlub-media-api-reference-',
      );
      addTearDown(() => fixture.deleteSync(recursive: true));
      final worker = File(
        '${fixture.path}/cloudflare/rayon-public/src/index.mjs',
      );
      worker.parent.createSync(recursive: true);
      const apiTemplate =
          r'return `${origin}/v1/public/rayon/media/${encodeURIComponent(id)}`;';
      worker.writeAsStringSync(apiTemplate);
      expect(_findForbiddenStaticDesignReferences(fixture), isEmpty);
      worker.writeAsStringSync(
        '$apiTemplate\nconst unregistered = "/media/old-design.png";',
      );
      expect(_findForbiddenStaticDesignReferences(fixture), [worker.path]);
    });

    test('Browser QA output does not become runtime media or design authority', () {
      final fixture = Directory.systemTemp.createTempSync(
        'africlub-browser-qa-source-boundary-',
      );
      addTearDown(() => fixture.deleteSync(recursive: true));
      void write(String relative, String content) {
        final file = File('${fixture.path}/$relative');
        file.parent.createSync(recursive: true);
        file.writeAsStringSync(content);
      }

      write(
        'apps/rayon_sports/web/tmp/browser-portal-controlled-fixture/capture.png',
        'Synthetic screenshot',
      );
      write(
        'apps/rayon_sports/web/tmp/browser-portal-controlled-fixture/private-details.json',
        '"Image.asset assets/images/retired.png"',
      );
      write(
        'apps/rayon_sports/web/tmp/browser-portal-controlled-fixture/DESIGN.md',
        'Competing source of truth for product design.',
      );
      expect(_findStoredVisualAssets(fixture), isEmpty);
      expect(_findForbiddenStaticDesignReferences(fixture), isEmpty);
      expect(_findSecondaryDesignAuthorityFiles(fixture), isEmpty);

      write(
        'apps/rayon_sports/web/src/components/browser-membership-portal.tsx',
        'const ungoverned = "/media/retired.png";',
      );
      write(
        'apps/rayon_sports/web/public/unguarded.png',
        'Synthetic runtime media',
      );
      write(
        'apps/rayon_sports/web/tmp-lookalike/capture.png',
        'Synthetic ungoverned sibling',
      );
      expect(_findForbiddenStaticDesignReferences(fixture), [
        '${fixture.path}/apps/rayon_sports/web/src/components/browser-membership-portal.tsx',
      ]);
      expect(_findStoredVisualAssets(fixture), [
        '${fixture.path}/apps/rayon_sports/web/public/unguarded.png',
        '${fixture.path}/apps/rayon_sports/web/tmp-lookalike/capture.png',
      ]);
    });

    test('Source inventory paths do not waive active static asset checks', () {
      final fixture = Directory.systemTemp.createTempSync(
        'africlub-source-inventory-boundary-',
      );
      addTearDown(() => fixture.deleteSync(recursive: true));
      const relative = 'docs/release/production-goal-evidence-2026-09-30.json';
      final manifest = File('${fixture.path}/$relative');
      manifest.parent.createSync(recursive: true);
      final metadata = <String, Object>{
        'schema_version': 1,
        'source_snapshot': <String, Object>{
          'sha256': 'a' * 64,
          'files': [
            {
              'path': 'apps/club/assets/images/retired.png',
              'bytes': 12,
              'sha256': 'b' * 64,
            },
          ],
        },
        'logs': <Object>[],
        'changes': <Object>[],
        'self_description': {'path': relative},
      };
      manifest.writeAsStringSync(jsonEncode(metadata));
      expect(_findForbiddenStaticDesignReferences(fixture), isEmpty);
      final snapshot = metadata['source_snapshot'] as Map<String, Object>;
      snapshot['inventory_sha256'] = snapshot.remove('sha256')!;
      manifest.writeAsStringSync(jsonEncode(metadata));
      expect(_findForbiddenStaticDesignReferences(fixture), isEmpty);

      final runtime = File('${fixture.path}/apps/club/lib/screen.dart');
      runtime.parent.createSync(recursive: true);
      runtime.writeAsStringSync("Image.asset('assets/images/retired.png')");
      expect(_findForbiddenStaticDesignReferences(fixture), [runtime.path]);
      runtime.deleteSync();
      for (final phase in ['3', '30', '0', '03', '100']) {
        final phasePath =
            'docs/release/production-goal-evidence-2026-09-30-phase$phase.json';
        final phaseManifest = File('${fixture.path}/$phasePath');
        metadata['self_description'] = {'path': phasePath};
        phaseManifest.writeAsStringSync(jsonEncode(metadata));
        expect(
          _findForbiddenStaticDesignReferences(fixture),
          ['3', '30'].contains(phase) ? isEmpty : [phaseManifest.path],
          reason: 'Only bounded canonical phase inventory names are metadata.',
        );
        phaseManifest.deleteSync();
      }
      metadata['self_description'] = {'path': 'wrong/path.json'};
      manifest.writeAsStringSync(jsonEncode(metadata));
      expect(_findForbiddenStaticDesignReferences(fixture), [manifest.path]);
      manifest.writeAsStringSync('"Image.asset assets/images/retired.png"');
      expect(_findForbiddenStaticDesignReferences(fixture), [manifest.path]);
    });

    test('Empty synthetic favicon response does not waive harness asset guards', () {
      final fixture = Directory.systemTemp.createTempSync(
        'africlub-browser-harness-static-boundary-',
      );
      addTearDown(() => fixture.deleteSync(recursive: true));
      const responses = <String, String>{
        'apps/rayon_sports/web/scripts/browser-portal-controlled-qa.mjs':
            "if(pathname==='/favicon.ico'){res.writeHead(204,headers);res.end();return;}",
        'cloudflare/operator-api/tests/browser/server.mjs':
            "if(req.url==='/favicon.ico'){res.writeHead(204);res.end();return;}",
        'cloudflare/payment-exceptions/tests/browser/server.mjs':
            "if(url.pathname==='/favicon.ico'){res.writeHead(204);res.end();return;}",
      };
      for (final entry in responses.entries) {
        final harness = File('${fixture.path}/${entry.key}');
        harness.parent.createSync(recursive: true);
        harness.writeAsStringSync(entry.value);
        expect(_findForbiddenStaticDesignReferences(fixture), isEmpty);
        harness.writeAsStringSync(
          '${entry.value}\nconst oldAsset = "/media/retired.png";',
        );
        expect(_findForbiddenStaticDesignReferences(fixture), [harness.path]);
        harness.deleteSync();
      }
    });

    test('Registered media replay calls retain static asset protection', () {
      final fixture = Directory.systemTemp.createTempSync(
        'africlub-registered-media-replay-boundary-',
      );
      addTearDown(() => fixture.deleteSync(recursive: true));
      const calls = <String, String>{
        'cloudflare/rayon-public/tests/response-boundary.test.mjs':
            "get(f,'media/'+ASSET)",
        'cloudflare/rayon-public/tests/snapshot.test.mjs':
            r'f.fetch(`media/${assetId}?snapshot=${s.id}`)',
        'tools/scripts/replay_public_snapshot_export.mjs':
            r'invoke(`media/${item.source_id}?snapshot=${id}`)',
        'cloudflare/operator-api/scripts/replay-saved-export.mjs':
            r'invoke(`media/${o.source_id}?snapshot=${snapshot[0].snapshot_id}`)',
      };
      for (final entry in calls.entries) {
        final file = File('${fixture.path}/${entry.key}');
        file.parent.createSync(recursive: true);
        file.writeAsStringSync(entry.value);
        expect(_findForbiddenStaticDesignReferences(fixture), isEmpty);
        file.writeAsStringSync(
          '${entry.value}\nconst retired = "/media/old.png";',
        );
        expect(_findForbiddenStaticDesignReferences(fixture), [file.path]);
        file.deleteSync();
      }
    });

    test('Static media paths are distinguished from slash-separated prose', () {
      final fixture = Directory.systemTemp.createTempSync(
        'africlub-static-path-context-',
      );
      addTearDown(() => fixture.deleteSync(recursive: true));
      final source = File('${fixture.path}/apps/club/lib/screen.dart');
      source.parent.createSync(recursive: true);
      for (final reference in [
        'Approve source/media/brand rights with expiry and scope',
        'Approve source/icons/brand rights with expiry and scope',
      ]) {
        source.writeAsStringSync('"$reference"');
        expect(
          _findForbiddenStaticDesignReferences(fixture),
          isEmpty,
          reason: reference,
        );
      }

      for (final reference in [
        '/media/file.jpg',
        '"/media/file.jpg"',
        'https://example.com/media/file.jpg',
        'src="/media/file.jpg"',
        '/icons/club.svg',
        'https://example.com/icons/club.svg',
        '../media/file.jpg',
        'public/media/file.jpg',
        'src="public/media/club"',
        r'`${origin}/media/file.jpg`',
      ]) {
        source.writeAsStringSync(reference);
        expect(_findForbiddenStaticDesignReferences(fixture), [
          source.path,
        ], reason: reference);
      }
    });
  });
}

List<String> _findSecondaryDesignAuthorityFiles(Directory repoRoot) {
  final violations = <String>[];
  final designAuthorityName = RegExp(
    r'(^|/)(design|design-system|style-guide|screen[-_]inventory|visual[-_]baseline|screenshot[-_]matrix|ui[-_]ux|ux[-_]audit|design[-_]audit)([._/-]|$)',
    caseSensitive: false,
  );
  final designAuthorityContent = RegExp(
    r'\b(source of truth for .*design|product design migration|product design completion|design completion audit|screen inventory|screenshot matrix|visual baseline|style guide)\b',
    caseSensitive: false,
  );

  for (final entity in _safeRecursiveList(repoRoot)) {
    if (entity is! File) continue;

    final normalizedPath = entity.path.replaceAll('\\', '/');
    if (_isGeneratedPath(normalizedPath)) continue;
    if (normalizedPath == '${repoRoot.path}/DESIGN.md') continue;
    if (!normalizedPath.endsWith('.md') && !normalizedPath.endsWith('.mdx')) {
      continue;
    }

    final content = entity.readAsStringSync();
    if (designAuthorityName.hasMatch(normalizedPath) ||
        designAuthorityContent.hasMatch(content)) {
      violations.add(normalizedPath);
    }
  }

  violations.sort();
  return violations;
}

List<String> _findStoredVisualAssets(Directory repoRoot) {
  final violations = <String>[];
  final forbiddenExtensions = <String>{
    '.png',
    '.jpg',
    '.jpeg',
    '.webp',
    '.svg',
    '.ico',
    '.icns',
  };

  for (final entity in _safeRecursiveList(repoRoot)) {
    if (entity is! File) continue;
    final normalizedPath = entity.path.replaceAll('\\', '/');
    if (_isGeneratedPath(normalizedPath)) continue;
    if (normalizedPath.contains('/ios/Pods/')) continue;

    final lower = normalizedPath.toLowerCase();
    if (forbiddenExtensions.any(lower.endsWith)) {
      if (_isGovernedRuntimeMedia(repoRoot, entity)) continue;
      if (_isGovernedStoreReleaseMedia(repoRoot, entity)) continue;
      if (_isGovernedGoldenEvidence(repoRoot, entity)) continue;
      if (_isGovernedReviewFixtureMedia(repoRoot, entity)) continue;
      violations.add(normalizedPath);
    }
  }

  violations.sort();
  return violations;
}

bool _isGovernedReviewFixtureMedia(Directory root, File file) {
  const directory = 'packages/testing/test_support/assets/shop/';
  final relative = file.path.substring(root.path.length + 1);
  if (!relative.startsWith(directory)) return false;
  final manifest = File('${root.path}/${directory}sources.json');
  if (!manifest.existsSync()) return false;
  final metadata =
      jsonDecode(manifest.readAsStringSync()) as Map<String, dynamic>;
  if (metadata['runtime_bundled'] != false) return false;
  final assets = metadata['assets'] as List<dynamic>;
  return assets.whereType<Map<String, dynamic>>().any(
    (asset) =>
        asset['path'] == relative &&
        '${asset['url']}'.startsWith('https://') &&
        RegExp(r'^[0-9a-f]{64}$').hasMatch('${asset['sha256']}') &&
        asset['use'] ==
            'Local design review fixture only; not a runtime asset or production media approval.',
  );
}

bool _isGovernedStoreReleaseMedia(Directory repoRoot, File mediaFile) {
  final normalizedRoot = repoRoot.path.replaceAll('\\', '/');
  final normalizedPath = mediaFile.path.replaceAll('\\', '/');
  final relativePath = normalizedPath.startsWith('$normalizedRoot/')
      ? normalizedPath.substring(normalizedRoot.length + 1)
      : normalizedPath;

  String? manifestPath;
  var isControlledPath = false;
  if (RegExp(
    r'^apps/rayon_sports/android/app/src/main/res/mipmap-[^/]+/ic_launcher\.png$',
  ).hasMatch(relativePath)) {
    return _isGovernedNativeLauncherEntry(repoRoot, relativePath);
  } else if (relativePath.startsWith(
    'apps/rayon_sports/android/fastlane/metadata/android/en-US/images/',
  )) {
    manifestPath =
        '${repoRoot.path}/apps/rayon_sports/store_metadata/play_store/artwork_manifest.json';
    isControlledPath = true;
  } else if (relativePath.startsWith(
    'apps/rayon_sports/ios/Runner/Assets.xcassets/AppIcon.appiconset/',
  )) {
    return _isGovernedNativeLauncherEntry(repoRoot, relativePath);
  } else if (relativePath.startsWith(
    'apps/rayon_sports/ios/fastlane/screenshots/en-US/',
  )) {
    manifestPath =
        '${repoRoot.path}/apps/rayon_sports/store_metadata/app_store/artwork_manifest.json';
    isControlledPath = true;
  }
  if (!isControlledPath || manifestPath == null) return false;

  final manifest = File(manifestPath);
  if (!manifest.existsSync()) return false;
  try {
    final decoded = jsonDecode(manifest.readAsStringSync());
    if (decoded is! Map<String, dynamic>) return false;
    final status = '${decoded['status']}'.toLowerCase();
    final approvals = decoded['approvals_required'];
    final content = manifest.readAsStringSync();
    return (status.contains('pending') ||
            status == 'approved_current_listing_reuse_exact_binary_verified') &&
        approvals is List<dynamic> &&
        approvals.contains('rayon_brand_and_content_rights') &&
        content.contains('capture_from_exact_candidate');
  } on FormatException {
    return false;
  }
}

bool _isGovernedNativeLauncherEntry(Directory repoRoot, String relativePath) {
  final manifest = File(
    '${repoRoot.path}/apps/rayon_sports/store_metadata/native_launcher_assets.json',
  );
  if (!manifest.existsSync()) return false;

  try {
    final decoded = jsonDecode(manifest.readAsStringSync());
    if (decoded is! Map<String, dynamic>) return false;
    final rights = decoded['rights_basis'];
    final assets = decoded['assets'];
    if (decoded['generator'] != 'tools/generate_store_artwork.swift' ||
        rights is! Map<String, dynamic> ||
        rights['original_project_owned'] != true ||
        rights['contains_club_crest'] != false ||
        rights['contains_third_party_artwork'] != false ||
        assets is! List<dynamic>) {
      return false;
    }
    return assets.whereType<Map<String, dynamic>>().any(
      (asset) =>
          asset['path'] == relativePath &&
          RegExp(r'^[0-9a-f]{64}$').hasMatch('${asset['sha256']}'),
    );
  } on FormatException {
    return false;
  }
}

bool _isGovernedRuntimeMedia(Directory repoRoot, File mediaFile) {
  final normalizedRoot = repoRoot.path.replaceAll('\\', '/');
  final normalizedPath = mediaFile.path.replaceAll('\\', '/');
  final isAppMedia =
      normalizedPath.startsWith('$normalizedRoot/apps/') &&
      normalizedPath.contains('/assets/');
  final isClubCrest =
      normalizedPath.startsWith(
        '$normalizedRoot/packages/core/core_theme/assets/crests/',
      ) ||
      normalizedPath.startsWith(
        '$normalizedRoot/apps/rayon_sports/web/public/crests/',
      );
  if (!isAppMedia && !isClubCrest) {
    return false;
  }

  final manifest = File('${mediaFile.parent.path}/SOURCES.md');
  if (!manifest.existsSync()) return false;

  final content = manifest.readAsStringSync();
  final filename = mediaFile.uri.pathSegments.last;
  final hasFileEntry = content.contains('`$filename`');
  final hasSourceUrl = RegExp(
    r'\bsource:\s*`https://',
    caseSensitive: false,
  ).hasMatch(content);
  final hasApprovalGate = RegExp(
    r'\b(approval|right[- ]to[- ]use|rights)\b.*\b(recorded|required|approved)\b',
    caseSensitive: false,
    dotAll: true,
  ).hasMatch(content);

  return hasFileEntry && hasSourceUrl && hasApprovalGate;
}

bool _isGovernedGoldenEvidence(Directory repoRoot, File mediaFile) {
  final normalizedRoot = repoRoot.path.replaceAll('\\', '/');
  final normalizedPath = mediaFile.path.replaceAll('\\', '/');
  final isTestSurface =
      normalizedPath.startsWith('$normalizedRoot/packages/') ||
      normalizedPath.startsWith('$normalizedRoot/apps/');
  if (!isTestSurface || !normalizedPath.contains('/test/goldens/')) {
    return false;
  }

  final manifest = File(
    '${repoRoot.path}/docs/governance/golden-baselines.json',
  );
  if (!manifest.existsSync()) return false;

  final relativePath = normalizedPath.substring(normalizedRoot.length + 1);
  try {
    final decoded = jsonDecode(manifest.readAsStringSync());
    if (decoded is! Map<String, dynamic>) return false;
    final baselines = decoded['baselines'];
    if (baselines is! List<dynamic>) return false;
    return baselines.whereType<Map<String, dynamic>>().any(
      (baseline) =>
          baseline['path'] == relativePath &&
          RegExp(r'^[0-9a-f]{64}$').hasMatch('${baseline['sha256']}'),
    );
  } on FormatException {
    return false;
  }
}

List<String> _findForbiddenStaticDesignReferences(Directory repoRoot) {
  // Directory names embedded in a slash-separated task title are prose. Root
  // paths, URL paths, relative asset files and string/attribute references are
  // actual static asset contracts and remain prohibited.
  const rootOrUrlAssetPath =
      r'''(?:^|[\s"'`(=:\[\]{},])(?:(?:https?://|//)[^\s"'`<>]*?|(?:\.{1,2})?(?:/[^/\s"'`<>]+)*?)/(?:icons|media)/''';
  const quotedRelativeAssetPath =
      r'''(?:^|["'`(=:\[\]{},])(?:[A-Za-z0-9_.-]+/)*(?:icons|media)/''';
  const relativeAssetFile =
      r'''(?:^|[\s"'`(=:\[\]{},])(?:[A-Za-z0-9_.-]+/)*(?:icons|media)/[^\s"'`<>]+\.[A-Za-z0-9]+''';
  const deletedAssetContracts =
      r'(CREST_ASSET|crestAsset|assets/crest|assets/images|LaunchImage|\bAppIcon\b|ic_launcher|splash_logo|favicon|Image\.asset)';
  final forbidden = RegExp(
    '$deletedAssetContracts|$rootOrUrlAssetPath|'
    '$quotedRelativeAssetPath|$relativeAssetFile',
    multiLine: true,
  );

  return _scanTextFiles(
    roots: [repoRoot],
    extensions: const {
      '.dart',
      '.yaml',
      '.yml',
      '.json',
      '.ts',
      '.tsx',
      '.js',
      '.jsx',
      '.mjs',
      '.css',
      '.xml',
      '.plist',
      '.pbxproj',
      '.md',
      '.sh',
      '.html',
    },
    pattern: forbidden,
    sourceForInspection: (path, source) =>
        _isGoalSourceEvidenceManifest(repoRoot, path, source)
        ? ''
        : _staticAssetScanSource(path, source),
    allow: (path) =>
        ((path.endsWith('/docs/architecture/club-identity.md') ||
                path.endsWith(
                  '/packages/core/core_theme/lib/src/widgets/afri_team_card.dart',
                ) ||
                path.endsWith(
                  '/packages/core/core_theme/lib/src/team_assets.g.dart',
                ) ||
                path.endsWith('/packages/core/core_theme/pubspec.yaml') ||
                path.endsWith(
                  '/packages/testing/test_support/lib/predict_fixture_images.dart',
                ) ||
                path.endsWith(
                  '/packages/core/core_theme/test/team_identity_test.dart',
                )) &&
            _isGovernedRuntimeMedia(
              repoRoot,
              File(
                '${repoRoot.path}/packages/core/core_theme/assets/crests/rayon-sports.png',
              ),
            )) ||
        path.endsWith(
          '/packages/core/core_theme/test/ui_source_guardrails_test.dart',
        ) ||
        path.endsWith(
          '/apps/rayon_sports/android/app/src/main/AndroidManifest.xml',
        ) ||
        path.endsWith(
          '/apps/rayon_sports/ios/Runner.xcodeproj/project.pbxproj',
        ) ||
        path.endsWith(
          '/apps/rayon_sports/store_metadata/app_store/artwork_manifest.json',
        ) ||
        path.endsWith(
          '/apps/rayon_sports/store_metadata/native_launcher_assets.json',
        ) ||
        path.endsWith('/apps/rayon_sports/store_metadata/source_evidence.md') ||
        path.endsWith(
          '/apps/rayon_sports/web/src/app/brand-mark.svg/route.ts',
        ) ||
        path.endsWith(
          '/apps/rayon_sports/web/src/app/brand-surface.svg/route.ts',
        ) ||
        path.endsWith('/tools/scripts/design_compliance_report.sh') ||
        // This negative-test fixture verifies the same registered-media gate;
        // its synthetic crest path is never loaded by product runtime code.
        path.endsWith('/tools/scripts/design_registered_media.test.mjs'),
  );
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
  bool Function(String normalizedPath)? allow,
  String Function(String normalizedPath, String source)? sourceForInspection,
}) {
  final violations = <String>[];

  for (final root in roots) {
    if (!root.existsSync()) continue;

    for (final entity in _safeRecursiveList(root)) {
      if (entity is! File) continue;

      final normalizedPath = entity.path.replaceAll('\\', '/');
      if (_isGeneratedPath(normalizedPath)) continue;
      if (allow != null && allow(normalizedPath)) continue;
      if (!extensions.any(normalizedPath.endsWith)) continue;

      final rawContent = entity.readAsStringSync();
      final content =
          sourceForInspection?.call(normalizedPath, rawContent) ?? rawContent;
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
      if (_isGeneratedPath(normalizedPath) ||
          _isPreservedDriveEvidencePath(root, normalizedPath)) {
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

bool _isPreservedDriveEvidencePath(Directory root, String normalizedPath) {
  final archiveRoot = '${root.path.replaceAll('\\', '/')}/docs/drive-import';
  return normalizedPath == archiveRoot ||
      normalizedPath.startsWith('$archiveRoot/');
}

bool _isGoalSourceEvidenceManifest(
  Directory repoRoot,
  String normalizedPath,
  String source,
) {
  final normalizedRoot = repoRoot.path.replaceAll('\\', '/');
  final relative = normalizedPath.startsWith('$normalizedRoot/')
      ? normalizedPath.substring(normalizedRoot.length + 1)
      : '';
  if (!RegExp(
    r'^docs/release/production-goal-evidence-\d{4}-\d{2}-\d{2}(?:-phase[1-9]\d?)?\.json$',
  ).hasMatch(relative)) {
    return false;
  }
  // The inventory describes paths and hashes; it cannot make the referenced
  // runtime file or asset exempt from its own independent source scan.
  try {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic> || decoded['schema_version'] != 1) {
      return false;
    }
    final snapshot = decoded['source_snapshot'];
    final self = decoded['self_description'];
    if (snapshot is! Map<String, dynamic> ||
        self is! Map<String, dynamic> ||
        self['path'] != relative ||
        decoded['logs'] is! List<dynamic> ||
        decoded['changes'] is! List<dynamic> ||
        (snapshot['sha256'] ?? snapshot['inventory_sha256']) is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(
          (snapshot['sha256'] ?? snapshot['inventory_sha256']) as String,
        )) {
      return false;
    }
    final files = snapshot['files'];
    return files is List<dynamic> &&
        files.every(
          (record) =>
              record is Map<String, dynamic> &&
              record['path'] is String &&
              (record['path'] as String).isNotEmpty &&
              record['bytes'] is int &&
              (record['bytes'] as int) >= 0 &&
              record['sha256'] is String &&
              RegExp(r'^[a-f0-9]{64}$').hasMatch(record['sha256'] as String),
        );
  } on FormatException {
    return false;
  }
}

String _staticAssetScanSource(String normalizedPath, String source) {
  var inspected = source;
  // These exact loopback QA routes return an empty 204; they do not load or
  // preserve a retired favicon. Other references in each harness still fail.
  const emptyIconResponses = <String, String>{
    '/apps/rayon_sports/web/scripts/browser-portal-controlled-qa.mjs':
        "if(pathname==='/favicon.ico'){res.writeHead(204,headers);res.end();return;}",
    '/cloudflare/operator-api/tests/browser/server.mjs':
        "if(req.url==='/favicon.ico'){res.writeHead(204);res.end();return;}",
    '/cloudflare/payment-exceptions/tests/browser/server.mjs':
        "if(url.pathname==='/favicon.ico'){res.writeHead(204);res.end();return;}",
  };
  for (final entry in emptyIconResponses.entries) {
    if (normalizedPath.endsWith(entry.key)) {
      inspected = inspected.replaceAll(entry.value, '');
    }
  }
  // These exact test/replay calls resolve relative fragments against the
  // protected /v1/public/rayon/ API. They never load a retired static directory.
  // Keep every other asset reference in the same files under the normal guard.
  const registeredMediaCalls = <String, List<String>>{
    '/cloudflare/rayon-public/tests/response-boundary.test.mjs': [
      "get(f,'media/'+ASSET)",
    ],
    '/cloudflare/rayon-public/tests/snapshot.test.mjs': [
      r'f.fetch(`media/${assetId}`)',
      r'f.fetch(`media/${assetId}?snapshot=${s.id}`)',
      r"f.fetch(`media/${assetId}?snapshot=${'0'.repeat(64)}`)",
    ],
    '/tools/scripts/replay_public_snapshot_export.mjs': [
      r'invoke(`media/${item.source_id}?snapshot=${id}`)',
    ],
    '/cloudflare/operator-api/scripts/replay-saved-export.mjs': [
      r'invoke(`media/${o.source_id}?snapshot=${snapshot[0].snapshot_id}`)',
    ],
  };
  for (final entry in registeredMediaCalls.entries) {
    if (normalizedPath.endsWith(entry.key)) {
      for (final call in entry.value) {
        inspected = inspected.replaceAll(call, '');
      }
    }
  }
  // This exact dynamic URL points at the governed media API, not the retired
  // static /media asset directory. Retain all other checks on this Worker.
  if (!normalizedPath.endsWith('/cloudflare/rayon-public/src/index.mjs')) {
    return inspected;
  }
  return inspected.replaceAll(
    r'${origin}/v1/public/rayon/media/${encodeURIComponent(id)}',
    '',
  );
}

bool _isGeneratedPath(String normalizedPath) {
  return normalizedPath.contains('/build/') ||
      normalizedPath.contains('/.dart_tool/') ||
      normalizedPath.contains('/.lighthouseci/') ||
      normalizedPath.endsWith('/.lighthouseci') ||
      normalizedPath.contains('/.next/') ||
      normalizedPath.endsWith('/.next') ||
      normalizedPath.contains('/.open-next/') ||
      normalizedPath.endsWith('/.open-next') ||
      normalizedPath.contains('/apps/rayon_sports/web/tmp/') ||
      normalizedPath.endsWith('/apps/rayon_sports/web/tmp') ||
      normalizedPath.contains('/apps/rayon_sports/web/test-results/') ||
      normalizedPath.endsWith('/apps/rayon_sports/web/test-results') ||
      normalizedPath.contains('/apps/rayon_sports/web/playwright-report/') ||
      normalizedPath.endsWith('/apps/rayon_sports/web/playwright-report') ||
      normalizedPath.contains('/test/failures/') ||
      normalizedPath.endsWith('/test/failures') ||
      normalizedPath.contains('/coverage/') ||
      normalizedPath.endsWith('/coverage') ||
      normalizedPath.contains('/output/') ||
      normalizedPath.contains('/node_modules/') ||
      normalizedPath.contains('/ios/Pods/');
}

bool _isTouchTargetAuditTool(String normalizedPath) {
  return normalizedPath.endsWith(
        '/packages/testing/test_support/lib/touch_target_audit.dart',
      ) ||
      normalizedPath.endsWith(
        '/packages/testing/test_support/test/touch_target_audit_test.dart',
      );
}

String _formatViolations(String heading, List<String> violations) {
  if (violations.isEmpty) return heading;
  return '$heading\n${violations.join('\n')}';
}
