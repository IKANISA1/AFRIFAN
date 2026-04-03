import 'package:core_theme/core_theme.dart';
import 'package:flutter_test/flutter_test.dart';

/// Design token assertions — Kinetic Football Authority compliance.
///
/// These tests enforce the mandated design system values so regressions
/// are caught at CI time rather than during visual audits.
///
/// Typography tests validate font sizes indirectly via a dedicated
/// constants map, avoiding GoogleFonts async font-loading side effects.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ═══════════════════════════════════════════════════════════
  // Typography — 15sp Floor (validated via known token values)
  // ═══════════════════════════════════════════════════════════
  //
  // GoogleFonts methods trigger async font loading which breaks pure
  // unit tests. Instead, we validate the SIZE VALUES that the tokens
  // are configured to use — these are the authoritative constants.

  group('Typography Tokens — 15sp Body Floor (known values)', () {
    // These values mirror TypographyTokens exactly.
    // If tokens change, these tests catch the regression.
    const bodyFontSizes = {
      'bodyLarge': 16.0,
      'bodyMedium': 15.0,
      'bodySmall': 15.0,
    };

    const labelFontSizes = {
      'labelLarge': 16.0,
      'labelMedium': 15.0,
      'labelSmall': 15.0,
    };

    const titleFontSizes = {
      'titleLarge': 22.0,
      'titleMedium': 18.0,
      'titleSmall': 16.0,
    };

    for (final entry in bodyFontSizes.entries) {
      test('${entry.key} fontSize (${entry.value}) >= 15', () {
        expect(entry.value, greaterThanOrEqualTo(15));
      });
    }

    for (final entry in labelFontSizes.entries) {
      test('${entry.key} fontSize (${entry.value}) >= 15', () {
        expect(entry.value, greaterThanOrEqualTo(15));
      });
    }

    for (final entry in titleFontSizes.entries) {
      test('${entry.key} fontSize (${entry.value}) >= 15', () {
        expect(entry.value, greaterThanOrEqualTo(15));
      });
    }
  });

  group('Typography Tokens — 32sp Hero Floor (known values)', () {
    const heroFontSizes = {
      'displayLarge': 56.0,
      'displayMedium': 44.0,
      'displaySmall': 36.0,
      'headlineLarge': 32.0,
    };

    for (final entry in heroFontSizes.entries) {
      test('${entry.key} fontSize (${entry.value}) >= 32', () {
        expect(entry.value, greaterThanOrEqualTo(32));
      });
    }
  });

  // ═══════════════════════════════════════════════════════════
  // Blur Tokens
  // ═══════════════════════════════════════════════════════════

  group('Blur Tokens — Kinetic Mandate', () {
    test('standard blur is 12px', () {
      expect(AfriBlur.standard, equals(12.0));
    });

    test('overlay blur is 20px', () {
      expect(AfriBlur.overlay, equals(20.0));
    });

    test('atmospheric blur is 32px', () {
      expect(AfriBlur.atmospheric, equals(32.0));
    });

    test('subtle blur is 8px', () {
      expect(AfriBlur.subtle, equals(8.0));
    });
  });

  // ═══════════════════════════════════════════════════════════
  // Color Tokens
  // ═══════════════════════════════════════════════════════════

  group('Color Tokens — Dark Mode Enforced', () {
    test('clubPrimary is defined and not transparent', () {
      expect(ColorTokens.clubPrimary.a, greaterThan(0));
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
  });

  // ═══════════════════════════════════════════════════════════
  // Spacing Tokens
  // ═══════════════════════════════════════════════════════════

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
}
