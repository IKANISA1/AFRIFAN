import 'package:flutter/material.dart';

import '../club_config.dart';

/// Color tokens for the Tactile Monolith design system.
///
/// The app keeps club identity colors for domain accents, but the platform
/// shell is anchored in a shared nocturnal violet palette so every surface
/// feels carved from the same material system.
class ColorTokens {
  ColorTokens._();

  static bool _initialized = false;

  static Color _primary = const Color(0xFF0038A8);
  static Color _secondary = const Color(0xFF001742);
  static Color _accent = const Color(0xFFD4A017);
  static List<Color> _gradient = const [Color(0xFF1F1147), Color(0xFF7B5BFF)];

  static const Color _defaultPrimary = Color(0xFF0038A8);
  static const Color _defaultSecondary = Color(0xFF001742);
  static const Color _defaultAccent = Color(0xFFD4A017);

  static const Color _monolithViolet = Color(0xFF7B5BFF);
  static const Color _monolithOrchid = Color(0xFFA98DFF);
  static const Color _voidBase = Color(0xFF0D0A27);

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
      _voidBase,
      primaryAlpha: 0.08,
      secondaryAlpha: 0.16,
    );
    _darkSurfaceDim = _darkBackground;
    _darkSurfaceContainerLowest = _stackColor(
      const Color(0xFF120D30),
      secondaryAlpha: 0.16,
      primaryAlpha: 0.04,
    );
    _darkSurfaceContainerLow = _stackColor(
      const Color(0xFF18123B),
      secondaryAlpha: 0.14,
      primaryAlpha: 0.06,
    );
    _darkSurfaceContainer = _stackColor(
      const Color(0xFF22194A),
      secondaryAlpha: 0.10,
      primaryAlpha: 0.08,
    );
    _darkSurface = _stackColor(
      const Color(0xFF2A2057),
      secondaryAlpha: 0.08,
      primaryAlpha: 0.10,
    );
    _darkSurfaceContainerHigh = _stackColor(
      const Color(0xFF322968),
      primaryAlpha: 0.14,
      whiteAlpha: 0.02,
    );
    _darkSurfaceContainerHighest = _stackColor(
      const Color(0xFF3A307B),
      primaryAlpha: 0.18,
      whiteAlpha: 0.04,
    );
    _darkSurfaceBright = _stackColor(
      const Color(0xFF4A3F93),
      primaryAlpha: 0.22,
      whiteAlpha: 0.06,
    );
    _darkPrimary = Color.lerp(_monolithViolet, _primary, 0.14)!;
    _darkPrimaryContainer = Color.lerp(_monolithOrchid, _primary, 0.10)!;
    _darkSecondaryContainer = Color.alphaBlend(
      _accent.withValues(alpha: 0.18),
      _darkSurfaceContainerHigh,
    );
    _darkOutlineVariant = Color.alphaBlend(
      _darkPrimaryContainer.withValues(alpha: 0.15),
      Colors.white.withValues(alpha: 0.06),
    );

    _lightBackground = const Color(0xFFF7F4FF);
    _lightSurfaceDim = _lightBackground;
    _lightSurfaceContainerLowest = const Color(0xFFFFFFFF);
    _lightSurfaceContainerLow = const Color(0xFFF3EEFF);
    _lightSurfaceContainer = const Color(0xFFECE4FF);
    _lightSurface = const Color(0xFFE5DAFF);
    _lightSurfaceContainerHigh = const Color(0xFFDDD0FF);
    _lightSurfaceContainerHighest = const Color(0xFFD4C3FF);
    _lightSurfaceBright = const Color(0xFFF9F5FF);
    _lightPrimary = _monolithViolet;
    _lightPrimaryContainer = _monolithOrchid;
    _lightSecondaryContainer = Color.alphaBlend(
      _accent.withValues(alpha: 0.20),
      _lightSurfaceContainerHigh,
    );
    _lightOutlineVariant = Color.alphaBlend(
      _lightPrimary.withValues(alpha: 0.15),
      const Color(0xFF322968).withValues(alpha: 0.06),
    );

    _initialized = true;
  }

  static bool get isInitialized => _initialized;

  static const bool isDark = true;

  static Color get clubPrimary => _primary;
  static Color get clubSecondary => _secondary;
  static Color get clubAccent => _accent;
  static List<Color> get clubGradient => _gradient;

  @Deprecated('Use clubPrimary instead')
  static Color get clubRed => _primary;
  @Deprecated('Use clubSecondary instead')
  static Color get deepNavy => _secondary;
  @Deprecated('Use clubAccent instead')
  static Color get trophyGold => _accent;

  static Color _darkBackground = _voidBase;
  static Color _darkSurfaceDim = _voidBase;
  static Color _darkSurface = const Color(0xFF2A2057);
  static Color _darkSurfaceContainerLowest = const Color(0xFF120D30);
  static Color _darkSurfaceContainerLow = const Color(0xFF18123B);
  static Color _darkSurfaceContainer = const Color(0xFF22194A);
  static Color _darkSurfaceContainerHigh = const Color(0xFF322968);
  static Color _darkSurfaceContainerHighest = const Color(0xFF3A307B);
  static Color _darkSurfaceBright = const Color(0xFF4A3F93);
  static Color _darkPrimary = _monolithViolet;
  static Color _darkPrimaryContainer = _monolithOrchid;
  static Color _darkSecondaryContainer = const Color(0xFF4A3F93);
  static Color _darkOutlineVariant = Colors.white.withValues(alpha: 0.12);

  static Color _lightBackground = const Color(0xFFF7F4FF);
  static Color _lightSurfaceDim = const Color(0xFFF7F4FF);
  static Color _lightSurface = const Color(0xFFE5DAFF);
  static Color _lightSurfaceContainerLowest = Colors.white;
  static Color _lightSurfaceContainerLow = const Color(0xFFF3EEFF);
  static Color _lightSurfaceContainer = const Color(0xFFECE4FF);
  static Color _lightSurfaceContainerHigh = const Color(0xFFDDD0FF);
  static Color _lightSurfaceContainerHighest = const Color(0xFFD4C3FF);
  static Color _lightSurfaceBright = const Color(0xFFF9F5FF);
  static Color _lightPrimary = _monolithViolet;
  static Color _lightPrimaryContainer = _monolithOrchid;
  static Color _lightSecondaryContainer = const Color(0xFFECE4FF);
  static Color _lightOutlineVariant = const Color(0x332A2057);

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
      isDark ? const Color(0xFFF8F4FF) : const Color(0xFF1D1538);
  static Color get onSurfaceVariant =>
      isDark ? const Color(0xFFC9C0E8) : const Color(0xFF544C77);

  static Color get glassFill =>
      surfaceBright.withValues(alpha: isDark ? 0.60 : 0.72);
  static Color get ghostBorder =>
      primaryContainer.withValues(alpha: isDark ? 0.15 : 0.18);

  static const double glassBlurSigma = 20.0;

  static Color get navActive => primaryContainer;

  static Color get ambientShadow => Color.alphaBlend(
    clubSecondary.withValues(alpha: 0.22),
    const Color(0xFF080614).withValues(alpha: 0.92),
  );

  static Color get scrim => background.withValues(alpha: 0.76);

  static const Color success = Color(0xFF52D39F);
  static const Color warning = Color(0xFFF4C96B);
  static const Color error = Color(0xFFFF6B8C);
  static const Color info = Color(0xFF7FB6FF);

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
