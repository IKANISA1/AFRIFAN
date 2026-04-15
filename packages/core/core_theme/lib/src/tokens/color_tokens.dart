import 'package:flutter/material.dart';

import '../club_config.dart';

/// Shared color tokens for the AFRICLUB minimalist mobile system.
///
/// The app stays club-branded through accent colors, but the foundation is a
/// calmer neutral shell so information hierarchy comes from spacing, surface,
/// and state rather than decorative gradients.
class ColorTokens {
  ColorTokens._();

  static bool _initialized = false;

  static Color _primary = const Color(0xFF0D63F3);
  static Color _secondary = const Color(0xFF0A1326);
  static Color _accent = const Color(0xFFE2B85F);
  static List<Color> _gradient = const [Color(0xFF0A1326), Color(0xFF0D63F3)];

  static const Color _defaultPrimary = Color(0xFF0D63F3);
  static const Color _defaultSecondary = Color(0xFF0A1326);
  static const Color _defaultAccent = Color(0xFFE2B85F);

  static const Color _inkBase = Color(0xFF08111F);

  static bool _isWhite(Color color) => color.computeLuminance() > 0.9;

  static Color _stackColor(
    Color base, {
    double primaryAlpha = 0.0,
    double secondaryAlpha = 0.0,
    double whiteAlpha = 0.0,
  }) {
    var current = base;
    if (secondaryAlpha > 0) {
      current = Color.alphaBlend(
        _secondary.withValues(alpha: secondaryAlpha.clamp(0.0, 1.0)),
        current,
      );
    }
    if (primaryAlpha > 0) {
      current = Color.alphaBlend(
        _primary.withValues(alpha: primaryAlpha.clamp(0.0, 1.0)),
        current,
      );
    }
    if (whiteAlpha > 0) {
      current = Color.alphaBlend(
        Colors.white.withValues(alpha: whiteAlpha.clamp(0.0, 1.0)),
        current,
      );
    }
    return current;
  }

  static void init(ClubColors colors) {
    _primary = _isWhite(colors.primary) ? _defaultPrimary : colors.primary;
    _secondary = _isWhite(colors.secondary)
        ? _defaultSecondary
        : colors.secondary;
    _accent = _isWhite(colors.accent) ? _defaultAccent : colors.accent;
    _gradient = colors.gradient.isNotEmpty
        ? colors.gradient
        : [_secondary, _primary];

    _darkBackground = _stackColor(
      _inkBase,
      primaryAlpha: 0.02,
      secondaryAlpha: 0.16,
    );
    _darkSurfaceDim = _darkBackground;
    _darkSurfaceContainerLowest = _stackColor(
      const Color(0xFF0E172A),
      secondaryAlpha: 0.08,
      primaryAlpha: 0.02,
    );
    _darkSurfaceContainerLow = _stackColor(
      const Color(0xFF111C31),
      secondaryAlpha: 0.08,
      primaryAlpha: 0.03,
    );
    _darkSurfaceContainer = _stackColor(
      const Color(0xFF142238),
      secondaryAlpha: 0.06,
      primaryAlpha: 0.04,
    );
    _darkSurface = _stackColor(
      const Color(0xFF172740),
      secondaryAlpha: 0.04,
      primaryAlpha: 0.05,
    );
    _darkSurfaceContainerHigh = _stackColor(
      const Color(0xFF1C2D49),
      primaryAlpha: 0.06,
      whiteAlpha: 0.01,
    );
    _darkSurfaceContainerHighest = _stackColor(
      const Color(0xFF233755),
      primaryAlpha: 0.08,
      whiteAlpha: 0.02,
    );
    _darkSurfaceBright = _stackColor(
      const Color(0xFF2C4364),
      primaryAlpha: 0.10,
      whiteAlpha: 0.04,
    );
    _darkPrimary = Color.lerp(_primary, Colors.white, 0.04)!;
    _darkPrimaryContainer = Color.lerp(_primary, Colors.white, 0.16)!;
    _darkSecondaryContainer = Color.alphaBlend(
      _accent.withValues(alpha: 0.12),
      _darkSurfaceContainerHigh,
    );
    _darkOutlineVariant = Color.alphaBlend(
      Colors.white.withValues(alpha: 0.04),
      _darkPrimary.withValues(alpha: 0.10),
    );

    _lightBackground = const Color(0xFFF7F9FC);
    _lightSurfaceDim = _lightBackground;
    _lightSurfaceContainerLowest = const Color(0xFFFFFFFF);
    _lightSurfaceContainerLow = const Color(0xFFF3F6FA);
    _lightSurfaceContainer = const Color(0xFFEDF2F8);
    _lightSurface = const Color(0xFFE7EEF6);
    _lightSurfaceContainerHigh = const Color(0xFFDEE8F3);
    _lightSurfaceContainerHighest = const Color(0xFFD5E0ED);
    _lightSurfaceBright = const Color(0xFFF9FBFE);
    _lightPrimary = _primary;
    _lightPrimaryContainer = Color.lerp(_primary, Colors.white, 0.22)!;
    _lightSecondaryContainer = Color.alphaBlend(
      _accent.withValues(alpha: 0.14),
      _lightSurfaceContainerHigh,
    );
    _lightOutlineVariant = const Color(0x14334C70);

    _initialized = true;
  }

  static bool get isInitialized => _initialized;

  static const bool isDark = true;

  static Color get clubPrimary => _primary;
  static Color get clubSecondary => _secondary;
  static Color get clubAccent => _accent;
  static List<Color> get clubGradient => _gradient;

  static Color _darkBackground = _inkBase;
  static Color _darkSurfaceDim = _inkBase;
  static Color _darkSurface = const Color(0xFF172740);
  static Color _darkSurfaceContainerLowest = const Color(0xFF0E172A);
  static Color _darkSurfaceContainerLow = const Color(0xFF111C31);
  static Color _darkSurfaceContainer = const Color(0xFF142238);
  static Color _darkSurfaceContainerHigh = const Color(0xFF1C2D49);
  static Color _darkSurfaceContainerHighest = const Color(0xFF233755);
  static Color _darkSurfaceBright = const Color(0xFF2C4364);
  static Color _darkPrimary = _defaultPrimary;
  static Color _darkPrimaryContainer = const Color(0xFF4E8CFF);
  static Color _darkSecondaryContainer = const Color(0xFF294160);
  static Color _darkOutlineVariant = const Color(0x223F5A81);

  static Color _lightBackground = const Color(0xFFF7F9FC);
  static Color _lightSurfaceDim = const Color(0xFFF7F9FC);
  static Color _lightSurface = const Color(0xFFE7EEF6);
  static Color _lightSurfaceContainerLowest = Colors.white;
  static Color _lightSurfaceContainerLow = const Color(0xFFF3F6FA);
  static Color _lightSurfaceContainer = const Color(0xFFEDF2F8);
  static Color _lightSurfaceContainerHigh = const Color(0xFFDEE8F3);
  static Color _lightSurfaceContainerHighest = const Color(0xFFD5E0ED);
  static Color _lightSurfaceBright = const Color(0xFFF9FBFE);
  static Color _lightPrimary = _defaultPrimary;
  static Color _lightPrimaryContainer = const Color(0xFF4E8CFF);
  static Color _lightSecondaryContainer = const Color(0xFFEEF3FB);
  static Color _lightOutlineVariant = const Color(0x14334C70);

  static Color get background => isDark ? _darkBackground : _lightBackground;
  static Color get surfaceDim => isDark ? _darkSurfaceDim : _lightSurfaceDim;
  static Color get surface => isDark ? _darkSurface : _lightSurface;
  static Color get surfaceBright =>
      isDark ? _darkSurfaceBright : _lightSurfaceBright;
  static Color get surfaceVariant => surfaceContainerHigh;
  static Color get primary => isDark ? _darkPrimary : _lightPrimary;
  static Color get primaryContainer =>
      isDark ? _darkPrimaryContainer : _lightPrimaryContainer;
  static Color get secondaryContainer =>
      isDark ? _darkSecondaryContainer : _lightSecondaryContainer;
  static Color get surfaceContainerLowest =>
      isDark ? _darkSurfaceContainerLowest : _lightSurfaceContainerLowest;
  static Color get surfaceContainerLow =>
      isDark ? _darkSurfaceContainerLow : _lightSurfaceContainerLow;
  static Color get surfaceContainer =>
      isDark ? _darkSurfaceContainer : _lightSurfaceContainer;
  static Color get surfaceContainerHigh =>
      isDark ? _darkSurfaceContainerHigh : _lightSurfaceContainerHigh;
  static Color get surfaceContainerHighest =>
      isDark ? _darkSurfaceContainerHighest : _lightSurfaceContainerHighest;
  static Color get outlineVariant =>
      isDark ? _darkOutlineVariant : _lightOutlineVariant;

  static Color get onSurface =>
      isDark ? const Color(0xFFF6F8FC) : const Color(0xFF121A27);
  static Color get onSurfaceVariant =>
      isDark ? const Color(0xFF9EABC2) : const Color(0xFF5E6B80);

  static Color get glassFill =>
      surfaceContainerHigh.withValues(alpha: isDark ? 0.92 : 0.94);
  static Color get ghostBorder =>
      Colors.white.withValues(alpha: isDark ? 0.08 : 0.10);

  static const double glassBlurSigma = 10.0;

  static Color get navActive => primaryContainer;

  static Color get ambientShadow => const Color(0xFF040812);

  static Color get scrim => background.withValues(alpha: 0.72);

  static const Color success = Color(0xFF4AC789);
  static const Color warning = Color(0xFFF0BF63);
  static const Color error = Color(0xFFFF6B6B);
  static const Color info = Color(0xFF69A8FF);

  static LinearGradient heroGradient({Color? from, Color? to}) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [from ?? primary, to ?? primaryContainer],
      stops: const [0.0, 1.0],
    );
  }

  static Color primaryTint(double alpha) =>
      primary.withValues(alpha: alpha.clamp(0.0, 1.0));

  static Color accentTint(double alpha) =>
      clubAccent.withValues(alpha: alpha.clamp(0.0, 1.0));
}
