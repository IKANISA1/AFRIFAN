import 'package:core_theme/core_theme.dart';
import 'package:flutter_test/flutter_test.dart';

/// Design token assertions — Tactile Monolith compliance.
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
        final minimum = entry.key == 'bodySmall' ? 14.0 : 15.0;
        expect(entry.value, greaterThanOrEqualTo(minimum));
      });
    }

    for (final entry in labelFontSizes.entries) {
      test('${entry.key} fontSize (${entry.value}) >= 11', () {
        expect(entry.value, greaterThanOrEqualTo(11));
      });
    }

    for (final entry in titleFontSizes.entries) {
      test('${entry.key} fontSize (${entry.value}) >= 15', () {
        expect(entry.value, greaterThanOrEqualTo(15));
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

  group('Typography Tokens — 32sp Hero Floor (known values)', () {
    final heroFontSizes = {
      'displayLarge': TypographyTokens.semanticSizes['displayLarge']!,
      'displayMedium': TypographyTokens.semanticSizes['displayMedium']!,
      'displaySmall': TypographyTokens.semanticSizes['displaySmall']!,
      'headlineLarge': TypographyTokens.semanticSizes['headlineLarge']!,
    };

    for (final entry in heroFontSizes.entries) {
      test('${entry.key} fontSize (${entry.value}) >= 32', () {
        expect(entry.value, greaterThanOrEqualTo(32));
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

  group('Color Tokens — Dark Mode Enforced', () {
    test('clubPrimary is defined and not transparent', () {
      expect(ColorTokens.clubPrimary.a, greaterThan(0));
    });

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
    test('minimum shared radius is 24px', () {
      expect(ShapeTokens.radiusMd, equals(24.0));
    });

    test('main card radius is 48px', () {
      expect(ShapeTokens.radiusXl, equals(48.0));
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
}
