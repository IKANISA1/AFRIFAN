import 'package:flutter/material.dart';

import '../club_config.dart';

/// Shared color tokens for the AFRICLUB Revolut-borrowed mobile system.
///
/// Club identity remains available as accents, but the app canvas follows the
/// COOL/MOBI finance-shell pattern: vertical dark gradients, black glass chrome,
/// compact readable panels, and route families instead of screen-local colors.
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

  static const Color _inkBase = Color(0xFF09090B);
  static const Color referenceChromeBlack = Color(0xFF050510);
  static const Color referenceAccountNavy = Color(0xFF000840);
  static const Color referenceAccountBlue = Color(0xFF0818A0);
  static const Color referencePaymentsPurple = Color(0xFF181038);
  static const Color referencePaymentsPurpleMid = Color(0xFF302848);
  static const Color referencePaymentsPurpleDeep = Color(0xFF100820);
  static const Color referenceAssetNavy = Color(0xFF101830);
  static const Color referenceAssetNavyMid = Color(0xFF303870);
  static const Color referenceRewardsViolet = Color(0xFF302878);
  static const Color referenceRewardsVioletHot = Color(0xFF9838F0);
  static const Color referenceWealthTeal = Color(0xFF102028);
  static const Color referenceWealthTealMid = Color(0xFF204050);
  static const Color referenceContentDark = Color(0xFF101018);
  static const Color referenceStockTealBlack = Color(0xFF001010);

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

    _darkBackground = Color.alphaBlend(
      _primary.withValues(alpha: 0.10),
      referencePaymentsPurpleDeep,
    );
    _darkSurfaceDim = _darkBackground;
    _darkSurfaceContainerLowest = Color.alphaBlend(
      _primary.withValues(alpha: 0.06),
      referenceChromeBlack,
    );
    _darkSurfaceContainerLow = Color.alphaBlend(
      _primary.withValues(alpha: 0.08),
      referencePaymentsPurpleDeep,
    );
    _darkSurfaceContainer = Color.alphaBlend(
      _primary.withValues(alpha: 0.10),
      referencePaymentsPurple,
    );
    _darkSurface = Color.alphaBlend(
      _primary.withValues(alpha: 0.08),
      referenceAssetNavy,
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
    _darkPrimary = Color.lerp(_primary, Colors.white, 0.10)!;
    _darkPrimaryContainer = Color.lerp(_primary, Colors.white, 0.24)!;
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
  static Color _darkSurface = const Color(0xFF18181B);
  static Color _darkSurfaceContainerLowest = const Color(0xFF09090B);
  static Color _darkSurfaceContainerLow = const Color(0xFF121215);
  static Color _darkSurfaceContainer = const Color(0xFF18181B);
  static Color _darkSurfaceContainerHigh = const Color(0xFF27272A);
  static Color _darkSurfaceContainerHighest = const Color(0xFF3F3F46);
  static Color _darkSurfaceBright = const Color(0xFF52525B);
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
      Colors.white.withValues(alpha: isDark ? 0.075 : 0.10);
  static Color get ghostBorder =>
      Colors.white.withValues(alpha: isDark ? 0.18 : 0.14);

  static const double glassBlurSigma = 22.0;
  static Color get chrome => referenceChromeBlack.withValues(alpha: 0.94);
  static Color get chromeBorder => Colors.white.withValues(alpha: 0.28);
  static Color get chromeForeground => const Color(0xFFFFFDFB);

  static const Color transparent = Color(0x00000000);
  static const Color onDark = Color(0xFFFFFFFF);
  static const Color onDarkDim = Color(0x99FFFFFF);
  static const Color onDarkSubtle = Color(0x8AFFFFFF);
  static const Color onDarkFaint = Color(0x61FFFFFF);
  static const Color onDarkSoft = Color(0x3DFFFFFF);
  static const Color onDarkHairline = Color(0x1AFFFFFF);
  static const Color borrowedPaper = Color(0xFFFFFFFF);
  static const Color borrowedInk = _inkBase;
  static const Color borrowedInkMuted = Color(0x8A09090B);
  static const Color borrowedInkSubtle = Color(0x6109090B);
  static const Color borrowedInkFaint = Color(0x4209090B);
  static const Color borrowedHairline = Color(0x0D09090B);

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

  static LinearGradient borrowedGradient({
    required List<Color> colors,
    AlignmentGeometry begin = Alignment.topLeft,
    AlignmentGeometry end = Alignment.bottomRight,
    List<double>? stops,
  }) {
    return LinearGradient(begin: begin, end: end, colors: colors, stops: stops);
  }

  static LinearGradient borrowedSurfaceGradient({
    Color? tint,
    double tintAlpha = 0.12,
    Color? from,
    Color? to,
  }) {
    final tintColor = tint?.withValues(alpha: tintAlpha.clamp(0.0, 1.0));
    return borrowedGradient(
      colors: [
        from ?? tintColor ?? surfaceContainerHigh,
        to ?? surfaceContainerLow,
      ],
    );
  }

  static LinearGradient imageScrimGradient({
    Color color = Colors.black,
    List<double> alphas = const [0.0, 1.0],
    List<double>? stops,
  }) {
    return borrowedGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: alphas
          .map((alpha) => color.withValues(alpha: alpha.clamp(0.0, 1.0)))
          .toList(growable: false),
      stops: stops,
    );
  }

  static LinearGradient productFallbackGradient(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('kit')) {
      return borrowedGradient(
        colors: [primaryTint(0.55), surfaceContainerHighest],
      );
    }
    if (lower.contains('access')) {
      return borrowedGradient(
        colors: [surfaceContainerHighest, surfaceContainerLow],
      );
    }
    return borrowedGradient(
      colors: [surfaceContainerHigh, surfaceContainerLow],
    );
  }

  static Color primaryTint(double alpha) =>
      primary.withValues(alpha: alpha.clamp(0.0, 1.0));

  static Color accentTint(double alpha) =>
      clubAccent.withValues(alpha: alpha.clamp(0.0, 1.0));

  static LinearGradient screenGradientForPath([String? path]) {
    final normalized = (path ?? '').trim().toLowerCase();
    if (normalized.contains('membership') ||
        normalized.contains('wallet') ||
        normalized.contains('contribute') ||
        normalized.contains('payment')) {
      return _verticalGradient(
        referenceAssetNavyMid,
        referenceAssetNavy,
        referenceChromeBlack,
      );
    }
    if (normalized.contains('settings') ||
        normalized.contains('profile') ||
        normalized.contains('privacy')) {
      return _verticalGradient(
        referenceContentDark,
        referencePaymentsPurpleDeep,
        referenceChromeBlack,
      );
    }
    if (normalized.contains('shop') ||
        normalized.contains('tickets') ||
        normalized.contains('rewards')) {
      return _verticalGradient(
        referenceRewardsVioletHot,
        referenceRewardsViolet,
        referencePaymentsPurpleDeep,
      );
    }
    if (normalized.contains('live') ||
        normalized.contains('fanzone') ||
        normalized.contains('league')) {
      return _verticalGradient(
        referenceWealthTealMid,
        referenceWealthTeal,
        referenceStockTealBlack,
      );
    }
    if (normalized.contains('onboarding') || normalized.contains('auth')) {
      return _verticalGradient(
        Color.alphaBlend(
          _primary.withValues(alpha: 0.28),
          referenceAccountBlue,
        ),
        referenceAccountNavy,
        referenceChromeBlack,
      );
    }
    return _verticalGradient(
      Color.alphaBlend(
        _primary.withValues(alpha: 0.18),
        referencePaymentsPurpleMid,
      ),
      referencePaymentsPurple,
      referencePaymentsPurpleDeep,
    );
  }

  static LinearGradient _verticalGradient(Color top, Color mid, Color bottom) {
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [top, mid, bottom],
      stops: const [0, 0.52, 1],
    );
  }
}
