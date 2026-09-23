import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// UI token assertions for root DESIGN.md compliance.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Typography Tokens — body and label hierarchy (known values)', () {
    final bodyFontSizes = {
      'bodyLarge': TypographyTokens.semanticSizes['bodyLarge']!,
      'bodyMedium': TypographyTokens.semanticSizes['bodyMedium']!,
      'bodySmall': TypographyTokens.semanticSizes['bodySmall']!,
    };

    final labelFontSizes = {
      'labelLarge': TypographyTokens.semanticSizes['labelLarge']!,
      'labelMedium': TypographyTokens.semanticSizes['labelMedium']!,
      'labelSmall': TypographyTokens.semanticSizes['labelSmall']!,
    };

    final titleFontSizes = {
      'titleLarge': TypographyTokens.semanticSizes['titleLarge']!,
      'titleMedium': TypographyTokens.semanticSizes['titleMedium']!,
      'titleSmall': TypographyTokens.semanticSizes['titleSmall']!,
    };

    for (final entry in bodyFontSizes.entries) {
      test('${entry.key} fontSize (${entry.value}) respects body floor', () {
        final minimum = switch (entry.key) {
          'bodyLarge' => 16.0,
          'bodyMedium' => 14.0,
          _ => 13.0,
        };
        expect(entry.value, greaterThanOrEqualTo(minimum));
      });
    }

    for (final entry in labelFontSizes.entries) {
      test('${entry.key} fontSize (${entry.value}) >= 12', () {
        expect(entry.value, greaterThanOrEqualTo(12));
      });
    }

    for (final entry in titleFontSizes.entries) {
      test('${entry.key} fontSize (${entry.value}) >= 14', () {
        expect(entry.value, greaterThanOrEqualTo(14));
      });
    }

    test('body hierarchy stays ordered', () {
      expect(
        bodyFontSizes['bodyLarge']!,
        greaterThan(bodyFontSizes['bodyMedium']!),
      );
      expect(
        bodyFontSizes['bodyMedium']!,
        greaterThan(bodyFontSizes['bodySmall']!),
      );
    });

    test('label hierarchy stays ordered', () {
      expect(
        labelFontSizes['labelLarge']!,
        greaterThan(labelFontSizes['labelMedium']!),
      );
      expect(
        labelFontSizes['labelMedium']!,
        greaterThan(labelFontSizes['labelSmall']!),
      );
    });
  });

  group('Typography Tokens — compact display scale (known values)', () {
    final heroFontSizes = {
      'displayLarge': TypographyTokens.semanticSizes['displayLarge']!,
      'displayMedium': TypographyTokens.semanticSizes['displayMedium']!,
      'displaySmall': TypographyTokens.semanticSizes['displaySmall']!,
      'headlineLarge': TypographyTokens.semanticSizes['headlineLarge']!,
    };

    for (final entry in heroFontSizes.entries) {
      test('${entry.key} fontSize (${entry.value}) remains readable', () {
        final minimum = entry.key == 'headlineLarge' ? 28.0 : 32.0;
        expect(entry.value, greaterThanOrEqualTo(minimum));
      });
    }
  });

  group('Blur Tokens — glass depth', () {
    test('standard blur is 20px', () {
      expect(AfriBlur.standard, equals(20.0));
    });

    test('overlay blur is 28px', () {
      expect(AfriBlur.overlay, equals(28.0));
    });

    test('atmospheric blur is 40px', () {
      expect(AfriBlur.atmospheric, equals(40.0));
    });

    test('subtle blur is 12px', () {
      expect(AfriBlur.subtle, equals(12.0));
    });
  });

  group('Shadow Tokens — tonal surface parity', () {
    test('light glass is quieter than dark glass', () {
      final light = AfriShadows.glass(Brightness.light).single;
      final dark = AfriShadows.glass(Brightness.dark).single;

      expect(light.color.a, lessThan(dark.color.a));
      expect(light.blurRadius, lessThan(dark.blurRadius));
      expect(light.offset.dy, lessThan(dark.offset.dy));
    });
  });

  group('Color Tokens — Dark Mode Enforced', () {
    test('system primary is defined and not transparent', () {
      expect(ColorTokens.primary.a, greaterThan(0));
    });

    test('glassFill is defined', () {
      expect(ColorTokens.glassFill, isNotNull);
    });

    test('ghostBorder is defined', () {
      expect(ColorTokens.ghostBorder, isNotNull);
    });

    test('onSurface is light-colored (for dark mode)', () {
      expect(ColorTokens.onSurface.computeLuminance(), greaterThan(0.5));
    });

    test('surface is dark', () {
      expect(ColorTokens.surface.computeLuminance(), lessThan(0.5));
    });

    test('primary container is brighter than the background', () {
      expect(
        ColorTokens.primaryContainer.computeLuminance(),
        greaterThan(ColorTokens.background.computeLuminance()),
      );
    });

    test('ghost border stays subtle', () {
      expect(ColorTokens.ghostBorder.a, lessThan(0.3));
    });
  });

  group('Spacing Tokens — Consistency', () {
    test('spacing values are positive and monotonically increasing', () {
      expect(SpacingTokens.spacing1, greaterThan(0));
      expect(SpacingTokens.spacing2, greaterThan(SpacingTokens.spacing1));
      expect(SpacingTokens.spacing3, greaterThan(SpacingTokens.spacing2));
      expect(SpacingTokens.spacing4, greaterThan(SpacingTokens.spacing3));
      expect(SpacingTokens.spacing5, greaterThan(SpacingTokens.spacing4));
      expect(SpacingTokens.spacing6, greaterThan(SpacingTokens.spacing5));
    });

    test('breathing room spacings are >= 32', () {
      expect(SpacingTokens.spacing8, greaterThanOrEqualTo(32));
      expect(SpacingTokens.spacing10, greaterThanOrEqualTo(40));
    });
  });

  group('Shape Tokens — tactile rounding', () {
    test('shared groups use the native rounded surface contract', () {
      final tokens = AfriDesignTokens.standard();

      expect(tokens.cardRadius, equals(24.0));
      expect(tokens.panelRadius, equals(24.0));
      expect(tokens.cardRadius, lessThan(tokens.sheetRadius + 1));
    });

    test('larger radii remain available for sheets and platform chrome', () {
      final tokens = AfriDesignTokens.standard();

      expect(tokens.sheetRadius, equals(ShapeTokens.radiusXl));
      expect(tokens.pillRadius, equals(ShapeTokens.radiusFull));
    });
  });

  group('Border Tokens — ghost outline fallback', () {
    test('hairline outline is 0.6px', () {
      expect(BorderTokens.hairline, equals(0.6));
    });

    test('focus outline is stronger than the default', () {
      expect(BorderTokens.focus, greaterThan(BorderTokens.standard));
    });
  });

  group('Universal Design Tokens — runtime DESIGN.md contract', () {
    final tokens = AfriDesignTokens.standard();

    test('ClubTheme registers design tokens as a ThemeExtension', () {
      final theme = ClubTheme.from(ClubConfig.fallback());

      expect(theme.extension<AfriDesignTokens>(), isNotNull);
      expect(
        theme.extension<AfriDesignTokens>()!.cardRadius,
        equals(tokens.cardRadius),
      );
    });

    test('ClubTheme provides distinct light and dark semantic palettes', () {
      final config = ClubConfig.fallback();
      final light = ClubTheme.from(config, brightness: Brightness.light);
      final dark = ClubTheme.from(config, brightness: Brightness.dark);

      expect(light.brightness, Brightness.light);
      expect(dark.brightness, Brightness.dark);
      expect(light.colorScheme.surface, isNot(dark.colorScheme.surface));
      expect(
        light.extension<AfriSemanticColors>()?.appBackground,
        isNot(dark.extension<AfriSemanticColors>()?.appBackground),
      );
      expect(
        light.extension<AfriSemanticColors>()?.primaryText.computeLuminance(),
        lessThan(
          dark.extension<AfriSemanticColors>()!.primaryText.computeLuminance(),
        ),
      );
    });

    test('route gradients remain theme-aware and readable in light mode', () {
      ColorTokens.setBrightness(Brightness.dark);
      final dark = ColorTokens.screenGradientForPath('/home').colors;
      ColorTokens.setBrightness(Brightness.light);
      addTearDown(() => ColorTokens.setBrightness(Brightness.dark));
      final lightPaths = <String>[
        '/home',
        '/settings',
        '/membership',
        '/predict',
        '/shop',
      ];

      for (final path in lightPaths) {
        final colors = ColorTokens.screenGradientForPath(path).colors;
        expect(colors, isNot(equals(dark)));
        expect(
          colors.every((color) => color.computeLuminance() > 0.62),
          isTrue,
          reason: '$path must keep dark light-mode text readable',
        );
      }
    });

    test('ClubTheme provides a structural high-contrast variant', () {
      final config = ClubConfig.fallback();
      for (final brightness in Brightness.values) {
        final standard = ClubTheme.from(config, brightness: brightness);
        final highContrast = ClubTheme.from(
          config,
          brightness: brightness,
          highContrast: true,
        );
        final standardColors = standard.extension<AfriSemanticColors>()!;
        final highContrastColors = highContrast
            .extension<AfriSemanticColors>()!;

        expect(
          highContrast.extension<AfriDesignTokens>()!.focusRingWidth,
          greaterThan(standard.extension<AfriDesignTokens>()!.focusRingWidth),
        );
        expect(
          highContrast.inputDecorationTheme.focusedBorder!.borderSide.width,
          equals(AfriDesignTokens.highContrast().focusRingWidth),
        );
        expect(highContrast.cardTheme.shape, isA<RoundedRectangleBorder>());
        expect(
          (highContrast.cardTheme.shape! as RoundedRectangleBorder).side.width,
          equals(BorderTokens.strong),
        );
        expect(
          highContrastColors.secondaryText,
          highContrastColors.primaryText,
        );
        expect(highContrastColors.tertiaryText, highContrastColors.primaryText);
        expect(highContrastColors.border, isNot(standardColors.border));
      }
    });

    test('responsive bands match DESIGN.md breakpoints', () {
      expect(
        tokens.viewportBandForWidth(320),
        equals(AfriViewportBand.compactPhone),
      );
      expect(
        tokens.viewportBandForWidth(390),
        equals(AfriViewportBand.standardPhone),
      );
      expect(
        tokens.viewportBandForWidth(500),
        equals(AfriViewportBand.largePhone),
      );
      expect(
        tokens.viewportBandForWidth(640),
        equals(AfriViewportBand.smallTablet),
      );
      expect(
        tokens.viewportBandForWidth(720),
        equals(AfriViewportBand.expanded),
      );
    });

    test('touch targets satisfy accessibility floors', () {
      expect(tokens.minTouchTarget, greaterThanOrEqualTo(48));
      expect(tokens.minDenseIconTarget, greaterThanOrEqualTo(44));
      expect(tokens.comfortableTouchTarget, greaterThan(tokens.minTouchTarget));
    });

    test('motion durations stay within DESIGN.md bands', () {
      expect(tokens.fastMotion.inMilliseconds, inInclusiveRange(120, 180));
      expect(tokens.standardMotion.inMilliseconds, inInclusiveRange(200, 280));
      expect(tokens.slowMotion.inMilliseconds, inInclusiveRange(320, 420));
      expect(
        tokens.motionFor(reducedMotionEnabled: true, role: AfriMotionRole.slow),
        equals(tokens.reducedMotion),
      );
    });

    test('shared command and navigation chrome use one semantic contract', () {
      expect(AfriChromeTokens.maxTopCommandActions, 2);
      expect(AfriChromeTokens.commandControlSize, equals(44));
      expect(
        AfriChromeTokens.navigationCompactHeight,
        greaterThanOrEqualTo(SizeTokens.touchTargetMin),
      );
      expect(
        AfriChromeTokens.navigationRegularHeight,
        equals(AfriChromeTokens.navigationCompactHeight),
      );
      expect(
        AfriClubBottomNav.compactHeight,
        AfriChromeTokens.navigationCompactHeight,
      );
      expect(
        AfriClubBottomNav.regularHeight,
        AfriChromeTokens.navigationRegularHeight,
      );
      expect(AfriMotion.navigation, const Duration(milliseconds: 180));
      expect(BorderTokens.chromeFocus, greaterThan(BorderTokens.chrome));
    });

    test('focus and admin contracts are concrete', () {
      expect(tokens.focusRingWidth, greaterThanOrEqualTo(3));
      expect(tokens.focusScale, greaterThanOrEqualTo(1));
      expect(tokens.adminRailWidth, greaterThanOrEqualTo(240));
      expect(tokens.adminTableRowHeight, greaterThanOrEqualTo(48));
    });

    test('required evidence ids cover mobile, admin, and state gates', () {
      expect(AfriDesignTokens.requiredStateIds, contains('permissionDenied'));
      expect(AfriDesignTokens.requiredStateIds, contains('reducedMotion'));
      expect(
        AfriDesignTokens.requiredMobileViewportIds,
        contains('compactPhone320To374'),
      );
      expect(
        AfriDesignTokens.requiredAdminEvidenceIds,
        contains('bulkSelection'),
      );
    });
  });
}
