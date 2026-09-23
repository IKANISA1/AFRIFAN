import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Predict supporting copy clears 4.5:1 across the discovery canvas', () {
    ColorTokens.setBrightness(Brightness.dark);
    for (final background in [
      ...ColorTokens.screenGradientForPath('/predict', Brightness.dark).colors,
      ColorTokens.overviewSurfaceForPath('/predict'),
    ]) {
      expect(
        _contrastRatio(ColorTokens.overviewSecondaryText, background),
        greaterThanOrEqualTo(4.5),
      );
    }
  });

  setUpAll(() {
    ColorTokens.init();
  });

  tearDown(() => ColorTokens.setBrightness(Brightness.dark));

  for (final brightness in Brightness.values) {
    test('${brightness.name} semantic text and status pairs meet 4.5:1', () {
      ColorTokens.setBrightness(brightness);
      final colors = brightness == Brightness.dark
          ? AfriSemanticColors.dark
          : AfriSemanticColors.light;

      final textPairs = <String, (Color, Color)>{
        'primary text / app background': (
          colors.primaryText,
          colors.appBackground,
        ),
        'secondary text / app background': (
          colors.secondaryText,
          colors.appBackground,
        ),
        'tertiary text / app background': (
          colors.tertiaryText,
          colors.appBackground,
        ),
        'primary button label / primary button': (
          colors.buttonPrimaryForeground,
          colors.buttonPrimaryBackground,
        ),
        'danger / app background': (colors.danger, colors.appBackground),
        'warning / app background': (colors.warning, colors.appBackground),
        'info / app background': (colors.info, colors.appBackground),
        'success / app background': (colors.success, colors.appBackground),
      };

      for (final MapEntry(key: name, value: pair) in textPairs.entries) {
        expect(
          _contrastRatio(pair.$1, pair.$2),
          greaterThanOrEqualTo(4.5),
          reason: '$name must meet WCAG AA-equivalent normal-text contrast.',
        );
      }
    });

    test('${brightness.name} focus and icon pairs meet 3:1', () {
      ColorTokens.setBrightness(brightness);
      final colors = brightness == Brightness.dark
          ? AfriSemanticColors.dark
          : AfriSemanticColors.light;

      expect(
        _contrastRatio(colors.accent, colors.appBackground),
        greaterThanOrEqualTo(3),
        reason: 'The visible focus/accent indicator must meet 3:1.',
      );
      expect(
        _contrastRatio(colors.secondaryText, colors.cardSurface),
        greaterThanOrEqualTo(3),
        reason: 'Secondary icons must remain distinguishable on cards.',
      );
    });

    test('${brightness.name} overlay combinations meet contrast floors', () {
      ColorTokens.setBrightness(brightness);
      final colors = brightness == Brightness.dark
          ? AfriSemanticColors.dark
          : AfriSemanticColors.light;

      expect(
        _contrastRatio(colors.primaryText, colors.overlaySurface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(
          ColorTokens.accessibleMetricColor(colors.secondaryText),
          colors.overlaySurface,
        ),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(
          ColorTokens.accessibleChartColor(colors.accent),
          colors.overlaySurface,
        ),
        greaterThanOrEqualTo(3),
      );
      expect(
        _contrastRatio(ColorTokens.onDarkDim, Colors.black),
        greaterThanOrEqualTo(4.5),
        reason: 'Muted text over the governed image scrim must remain legible.',
      );
    });

    test('${brightness.name} disabled controls remain visibly unavailable', () {
      ColorTokens.setBrightness(brightness);

      expect(
        _contrastRatio(
          ColorTokens.accessibleDisabledColor(ColorTokens.onSurfaceVariant),
          ColorTokens.surfaceContainerHigh,
        ),
        greaterThanOrEqualTo(3),
        reason:
            'Inactive controls are WCAG-exempt, but the design contract still '
            'requires a visible unavailable state.',
      );
    });

    test('${brightness.name} chart and metric accents are normalized', () {
      ColorTokens.setBrightness(brightness);
      final candidates = <Color>[
        ColorTokens.onSurfaceVariant,
        ColorTokens.primary,
        ColorTokens.primaryContainer,
        ColorTokens.primary,
        ColorTokens.success,
        ColorTokens.warning,
        ColorTokens.info,
        ColorTokens.error,
      ];
      final backgrounds = <Color>[
        ColorTokens.background,
        ColorTokens.surfaceContainerLow,
        ColorTokens.surfaceContainerHigh,
        ColorTokens.surfaceBright,
      ];

      for (final candidate in candidates) {
        final metric = ColorTokens.accessibleMetricColor(candidate);
        final chart = ColorTokens.accessibleChartColor(candidate);
        for (final background in backgrounds) {
          expect(_contrastRatio(metric, background), greaterThanOrEqualTo(4.5));
          expect(_contrastRatio(chart, background), greaterThanOrEqualTo(3));
        }
      }
    });
  }

  test('black chrome foreground meets normal-text contrast', () {
    expect(
      _contrastRatio(
        ColorTokens.chromeForeground,
        ColorTokens.referenceChromeBlack,
      ),
      greaterThanOrEqualTo(4.5),
    );
  });

  for (final brightness in Brightness.values) {
    test('${brightness.name} high-contrast theme strengthens boundaries', () {
      final theme = ClubTheme.from(
        ClubConfig.fallback(),
        brightness: brightness,
        highContrast: true,
      );
      final colors = theme.extension<AfriSemanticColors>()!;

      expect(
        _contrastRatio(colors.secondaryText, colors.appBackground),
        greaterThanOrEqualTo(7),
      );
      expect(
        _contrastRatio(colors.tertiaryText, colors.appBackground),
        greaterThanOrEqualTo(7),
      );
      expect(
        _contrastRatio(colors.borderStrong, colors.appBackground),
        greaterThanOrEqualTo(7),
      );
      expect(
        theme.extension<AfriDesignTokens>()!.focusRingWidth,
        greaterThanOrEqualTo(4),
      );
    });
  }
}

double _contrastRatio(Color foreground, Color background) {
  final opaqueBackground = background.a < 1
      ? Color.alphaBlend(background, Colors.black)
      : background;
  final opaqueForeground = foreground.a < 1
      ? Color.alphaBlend(foreground, opaqueBackground)
      : foreground;
  final foregroundLuminance = opaqueForeground.computeLuminance();
  final backgroundLuminance = opaqueBackground.computeLuminance();
  final lighter = foregroundLuminance > backgroundLuminance
      ? foregroundLuminance
      : backgroundLuminance;
  final darker = foregroundLuminance > backgroundLuminance
      ? backgroundLuminance
      : foregroundLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}
