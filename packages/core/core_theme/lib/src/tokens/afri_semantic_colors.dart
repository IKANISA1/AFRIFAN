import 'package:flutter/material.dart';

import 'color_tokens.dart';

/// Semantic color token system for the AFRICLUB platform.
///
/// Provides a theme-aware, composable color API via [ThemeExtension].
/// Clubs override only their accent/primary/secondary while inheriting
/// the full semantic vocabulary. Supports `lerp()` for animated theme
/// transitions and `copyWith()` for per-club overrides.
///
/// Access via `context.afriSemanticColors` extension.
/// External brand colors referenced across features.
///
/// These are NOT club-specific; they represent third-party or contextual
/// constants (e.g. WhatsApp brand green, stadium pitch, celebration effects).
/// Feature packages should use these instead of hardcoding hex values.
abstract final class ExternalBrandColors {
  /// WhatsApp official brand green.
  static const Color whatsAppGreen = Color(0xFF25D366);

  /// Stadium pitch deep green (used in seat maps, match visuals).
  static const Color stadiumPitch = Color(0xFF1B5E20);

  /// Confetti / celebration palette — non-club-specific accent colors.
  static const List<Color> confettiPalette = <Color>[
    Color(0xFFFFD32A), // gold
    Color(0xFF5352ED), // indigo
    Color(0xFFFF6B6B), // coral
    Color(0xFF1DD1A1), // mint
    Color(0xFF54A0FF), // sky blue
  ];
}

class AfriSemanticColors extends ThemeExtension<AfriSemanticColors> {
  const AfriSemanticColors({
    // ── App-level surfaces ──
    required this.appBackground,
    required this.elevatedBackground,
    required this.shellGradientTop,
    required this.shellGradientBottom,
    // ── Card surfaces ──
    required this.cardSurface,
    required this.cardSurfaceStrong,
    required this.overlaySurface,
    // ── Input surfaces ──
    required this.inputSurface,
    // ── Text hierarchy ──
    required this.primaryText,
    required this.secondaryText,
    required this.tertiaryText,
    // ── Borders ──
    required this.border,
    required this.borderStrong,
    // ── Interactive ──
    required this.accent,
    required this.accentSoft,
    required this.buttonPrimaryBackground,
    required this.buttonPrimaryForeground,
    // ── Semantic status ──
    required this.danger,
    required this.warning,
    required this.info,
    required this.success,
    // ── Domain surfaces ──
    required this.operationalSurface,
    required this.analyticsSurface,
    required this.commerceSurface,
    required this.teamSurface,
    // ── Glass ──
    required this.highlightColor,
    required this.shadowColor,
    // ── Gradients ──
    required this.surfaceGradient,
  });

  // ── App-level surfaces ──
  final Color appBackground;
  final Color elevatedBackground;
  final Color shellGradientTop;
  final Color shellGradientBottom;

  // ── Card surfaces ──
  final Color cardSurface;
  final Color cardSurfaceStrong;
  final Color overlaySurface;

  // ── Input surfaces ──
  final Color inputSurface;

  // ── Text hierarchy ──
  final Color primaryText;
  final Color secondaryText;
  final Color tertiaryText;

  // ── Borders ──
  final Color border;
  final Color borderStrong;

  // ── Interactive ──
  final Color accent;
  final Color accentSoft;
  final Color buttonPrimaryBackground;
  final Color buttonPrimaryForeground;

  // ── Semantic status ──
  final Color danger;
  final Color warning;
  final Color info;
  final Color success;

  // ── Domain surfaces ──
  final Color operationalSurface;
  final Color analyticsSurface;
  final Color commerceSurface;
  final Color teamSurface;

  // ── Glass ──
  final Color highlightColor;
  final Color shadowColor;

  // ── Gradients ──
  final LinearGradient surfaceGradient;

  // ─────────────────────────────────────────────────────────────────
  // Dark theme — default Tactile Monolith palette
  // ─────────────────────────────────────────────────────────────────
  static AfriSemanticColors get dark => AfriSemanticColors(
    // ── App-level surfaces ──
    appBackground: ColorTokens.background,
    elevatedBackground: ColorTokens.surfaceContainerLow,
    shellGradientTop: ColorTokens.surfaceDim,
    shellGradientBottom: ColorTokens.surfaceContainerHigh,
    // ── Card surfaces ──
    cardSurface: ColorTokens.surfaceContainerHigh,
    cardSurfaceStrong: ColorTokens.surfaceContainerHighest,
    overlaySurface: ColorTokens.surfaceBright,
    // ── Input surfaces ──
    inputSurface: ColorTokens.surfaceContainerLowest,
    // ── Text hierarchy ──
    primaryText: ColorTokens.onSurface,
    secondaryText: ColorTokens.onSurfaceVariant,
    tertiaryText: ColorTokens.onSurfaceVariant.withValues(alpha: 0.65),
    // ── Borders ──
    border: ColorTokens.ghostBorder,
    borderStrong: ColorTokens.primaryContainer.withValues(alpha: 0.28),
    // ── Interactive ──
    accent: ColorTokens.primaryContainer,
    accentSoft: ColorTokens.primaryContainer.withValues(alpha: 0.18),
    buttonPrimaryBackground: ColorTokens.primaryContainer,
    buttonPrimaryForeground: const Color(0xFFFFFFFF),
    // ── Semantic status ──
    danger: ColorTokens.error,
    warning: ColorTokens.warning,
    info: ColorTokens.info,
    success: ColorTokens.success,
    // ── Domain surfaces ──
    operationalSurface: ColorTokens.surfaceContainer,
    analyticsSurface: ColorTokens.surfaceContainerHigh,
    commerceSurface: ColorTokens.secondaryContainer,
    teamSurface: ColorTokens.surfaceContainerLowest,
    // ── Glass ──
    highlightColor: Colors.white.withValues(alpha: 0.16),
    shadowColor: ColorTokens.ambientShadow,
    // ── Gradients ──
    surfaceGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        ColorTokens.surfaceContainerHigh,
        ColorTokens.surfaceContainerHighest,
      ],
    ),
  );

  // ─────────────────────────────────────────────────────────────────
  // Light theme — derived from the shared light ColorTokens palette
  // ─────────────────────────────────────────────────────────────────
  static AfriSemanticColors get light => AfriSemanticColors(
    appBackground: ColorTokens.background,
    elevatedBackground: ColorTokens.surfaceContainerLow,
    shellGradientTop: ColorTokens.surfaceBright,
    shellGradientBottom: ColorTokens.surfaceContainerHigh,
    cardSurface: Colors.white,
    cardSurfaceStrong: ColorTokens.surfaceContainerLow,
    overlaySurface: ColorTokens.surfaceBright,
    inputSurface: Colors.white,
    primaryText: ColorTokens.onSurface,
    secondaryText: ColorTokens.onSurfaceVariant,
    tertiaryText: ColorTokens.onSurfaceVariant.withValues(alpha: 0.7),
    border: ColorTokens.ghostBorder,
    borderStrong: ColorTokens.outlineVariant.withValues(alpha: 0.6),
    accent: ColorTokens.primary,
    accentSoft: ColorTokens.primary.withValues(alpha: 0.12),
    buttonPrimaryBackground: ColorTokens.primary,
    buttonPrimaryForeground: const Color(0xFFFFFFFF),
    danger: ColorTokens.error,
    warning: ColorTokens.warning,
    info: ColorTokens.info,
    success: ColorTokens.success,
    operationalSurface: ColorTokens.surfaceContainer,
    analyticsSurface: ColorTokens.surfaceContainerHigh,
    commerceSurface: ColorTokens.secondaryContainer,
    teamSurface: ColorTokens.surfaceContainerLowest,
    highlightColor: Colors.white.withValues(alpha: 0.65),
    shadowColor: ColorTokens.ambientShadow.withValues(alpha: 0.14),
    surfaceGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        ColorTokens.surfaceContainerLowest,
        ColorTokens.surfaceContainerHigh,
      ],
    ),
  );

  // ─────────────────────────────────────────────────────────────────
  // copyWith — enables per-club color overrides
  // ─────────────────────────────────────────────────────────────────
  @override
  AfriSemanticColors copyWith({
    Color? appBackground,
    Color? elevatedBackground,
    Color? shellGradientTop,
    Color? shellGradientBottom,
    Color? cardSurface,
    Color? cardSurfaceStrong,
    Color? overlaySurface,
    Color? inputSurface,
    Color? primaryText,
    Color? secondaryText,
    Color? tertiaryText,
    Color? border,
    Color? borderStrong,
    Color? accent,
    Color? accentSoft,
    Color? buttonPrimaryBackground,
    Color? buttonPrimaryForeground,
    Color? danger,
    Color? warning,
    Color? info,
    Color? success,
    Color? operationalSurface,
    Color? analyticsSurface,
    Color? commerceSurface,
    Color? teamSurface,
    Color? highlightColor,
    Color? shadowColor,
    LinearGradient? surfaceGradient,
  }) {
    return AfriSemanticColors(
      appBackground: appBackground ?? this.appBackground,
      elevatedBackground: elevatedBackground ?? this.elevatedBackground,
      shellGradientTop: shellGradientTop ?? this.shellGradientTop,
      shellGradientBottom: shellGradientBottom ?? this.shellGradientBottom,
      cardSurface: cardSurface ?? this.cardSurface,
      cardSurfaceStrong: cardSurfaceStrong ?? this.cardSurfaceStrong,
      overlaySurface: overlaySurface ?? this.overlaySurface,
      inputSurface: inputSurface ?? this.inputSurface,
      primaryText: primaryText ?? this.primaryText,
      secondaryText: secondaryText ?? this.secondaryText,
      tertiaryText: tertiaryText ?? this.tertiaryText,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      buttonPrimaryBackground:
          buttonPrimaryBackground ?? this.buttonPrimaryBackground,
      buttonPrimaryForeground:
          buttonPrimaryForeground ?? this.buttonPrimaryForeground,
      danger: danger ?? this.danger,
      warning: warning ?? this.warning,
      info: info ?? this.info,
      success: success ?? this.success,
      operationalSurface: operationalSurface ?? this.operationalSurface,
      analyticsSurface: analyticsSurface ?? this.analyticsSurface,
      commerceSurface: commerceSurface ?? this.commerceSurface,
      teamSurface: teamSurface ?? this.teamSurface,
      highlightColor: highlightColor ?? this.highlightColor,
      shadowColor: shadowColor ?? this.shadowColor,
      surfaceGradient: surfaceGradient ?? this.surfaceGradient,
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // lerp — enables animated theme transitions
  // ─────────────────────────────────────────────────────────────────
  @override
  AfriSemanticColors lerp(AfriSemanticColors? other, double t) {
    if (other is! AfriSemanticColors) return this;
    return AfriSemanticColors(
      appBackground: Color.lerp(appBackground, other.appBackground, t)!,
      elevatedBackground: Color.lerp(
        elevatedBackground,
        other.elevatedBackground,
        t,
      )!,
      shellGradientTop: Color.lerp(
        shellGradientTop,
        other.shellGradientTop,
        t,
      )!,
      shellGradientBottom: Color.lerp(
        shellGradientBottom,
        other.shellGradientBottom,
        t,
      )!,
      cardSurface: Color.lerp(cardSurface, other.cardSurface, t)!,
      cardSurfaceStrong: Color.lerp(
        cardSurfaceStrong,
        other.cardSurfaceStrong,
        t,
      )!,
      overlaySurface: Color.lerp(overlaySurface, other.overlaySurface, t)!,
      inputSurface: Color.lerp(inputSurface, other.inputSurface, t)!,
      primaryText: Color.lerp(primaryText, other.primaryText, t)!,
      secondaryText: Color.lerp(secondaryText, other.secondaryText, t)!,
      tertiaryText: Color.lerp(tertiaryText, other.tertiaryText, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      buttonPrimaryBackground: Color.lerp(
        buttonPrimaryBackground,
        other.buttonPrimaryBackground,
        t,
      )!,
      buttonPrimaryForeground: Color.lerp(
        buttonPrimaryForeground,
        other.buttonPrimaryForeground,
        t,
      )!,
      danger: Color.lerp(danger, other.danger, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      info: Color.lerp(info, other.info, t)!,
      success: Color.lerp(success, other.success, t)!,
      operationalSurface: Color.lerp(
        operationalSurface,
        other.operationalSurface,
        t,
      )!,
      analyticsSurface: Color.lerp(
        analyticsSurface,
        other.analyticsSurface,
        t,
      )!,
      commerceSurface: Color.lerp(commerceSurface, other.commerceSurface, t)!,
      teamSurface: Color.lerp(teamSurface, other.teamSurface, t)!,
      highlightColor: Color.lerp(highlightColor, other.highlightColor, t)!,
      shadowColor: Color.lerp(shadowColor, other.shadowColor, t)!,
      surfaceGradient: LinearGradient.lerp(
        surfaceGradient,
        other.surfaceGradient,
        t,
      )!,
    );
  }
}
