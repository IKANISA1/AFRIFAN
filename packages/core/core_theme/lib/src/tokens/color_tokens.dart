import 'package:flutter/material.dart';

import '../club_config.dart';

/// Shared color tokens for the AFRICLUB universal mobile system.
///
/// Club palette metadata remains available for identity, but UI styling follows the
/// September 2026 native Dark · Glow reference: neutral task surfaces, tonal
/// groups, and colour fields reserved for the four supporter overviews.
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
  static const Color referenceTrophyGold = Color(0xFFE2B85F);
  static const Color referencePaymentsPurple = Color(0xFF181038);
  static const Color referencePaymentsPurpleMid = Color(0xFF302848);
  static const Color referencePaymentsPurpleDeep = Color(0xFF100820);
  // Colour-managed LIVE-048 card samples, 5 September 2026. These are
  // rendered observations used for our generated member card, not source tokens.
  static const Color membershipCardViolet = Color(0xFF6219E5);
  static const Color membershipCardVioletLight = Color(0xFF8017EE);
  static const Color referenceAssetNavy = Color(0xFF101830);
  static const Color referenceAssetNavyMid = Color(0xFF303870);
  static const Color referenceRewardsViolet = Color(0xFF302878);
  static const Color referenceRewardsVioletHot = Color(0xFF9838F0);
  static const Color referenceWealthTeal = Color(0xFF102028);
  static const Color referenceWealthTealMid = Color(0xFF204050);
  static const Color referenceContentDark = Color(0xFF101018);
  static const Color referenceStockTealBlack = Color(0xFF001010);

  static bool _isWhite(Color color) => color.computeLuminance() > 0.9;

  static double _contrastRatio(Color first, Color second) {
    final firstLuminance = first.computeLuminance();
    final secondLuminance = second.computeLuminance();
    final lighter = firstLuminance > secondLuminance
        ? firstLuminance
        : secondLuminance;
    final darker = firstLuminance > secondLuminance
        ? secondLuminance
        : firstLuminance;
    return (lighter + 0.05) / (darker + 0.05);
  }

  /// Resolves a metric/text accent that remains readable across the common
  /// app, card, overlay, and analytics surfaces for the active brightness.
  ///
  /// Product/club accents are identity inputs, not pre-approved foreground
  /// colors. Light mode in particular can make a gold or vivid accent
  /// unreadable unless it is normalized toward ink.
  static Color accessibleMetricColor(Color candidate) {
    return _ensureContrastAcross(candidate, <Color>[
      background,
      surfaceContainerLow,
      surfaceContainerHigh,
      surfaceBright,
    ], minimum: 4.5);
  }

  /// Resolves a non-text data-visualization stroke/marker to the 3:1
  /// meaningful-control floor across the common active surfaces.
  static Color accessibleChartColor(Color candidate) {
    return _ensureContrastAcross(candidate, <Color>[
      background,
      surfaceContainerLow,
      surfaceContainerHigh,
      surfaceBright,
    ], minimum: 3);
  }

  static Color _ensureContrastAcross(
    Color candidate,
    List<Color> backgrounds, {
    required double minimum,
  }) {
    final toward = isDark ? Colors.white : _inkBase;
    for (var step = 0; step <= 20; step += 1) {
      final adjusted = Color.lerp(candidate, toward, step / 20)!;
      final passes = backgrounds.every(
        (background) => _contrastRatio(adjusted, background) >= minimum,
      );
      if (passes) return adjusted;
    }
    return toward;
  }

  /// Chooses the higher-contrast foreground for an opaque semantic surface.
  static Color contrastForeground(Color background) {
    final whiteRatio = _contrastRatio(Colors.white, background);
    final inkRatio = _contrastRatio(_inkBase, background);
    return whiteRatio >= inkRatio ? Colors.white : _inkBase;
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

    // Provisional visual adapters measured from LIVE-007 and LIVE-020.
    // Club identity never tints a neutral task canvas or an ordinary list group.
    _darkBackground = Colors.black;
    _darkSurfaceDim = Colors.black;
    _darkSurfaceContainerLowest = const Color(0xFF101012);
    _darkSurfaceContainerLow = const Color(0xFF161618);
    _darkSurfaceContainer = const Color(0xFF161618);
    _darkSurface = const Color(0xFF161618);
    _darkSurfaceContainerHigh = const Color(0xFF161618);
    _darkSurfaceContainerHighest = const Color(0xFF242426);
    _darkSurfaceBright = const Color(0xFF2C2C2E);
    // Provisional native blue control role (LIVE-033/055), independent of
    // the club's artwork palette. Focus/status adaptations are contrast-tested.
    _darkPrimary = const Color(0xFF4D8DFF);
    _darkPrimaryContainer = const Color(0xFF4D8DFF);
    _darkSecondaryContainer = _darkSurfaceContainerHigh;
    _darkOutlineVariant = const Color(0x1FFFFFFF);

    _lightBackground = const Color(0xFFF5F5F7);
    _lightSurfaceDim = _lightBackground;
    _lightSurfaceContainerLowest = const Color(0xFFFFFFFF);
    _lightSurfaceContainerLow = const Color(0xFFF3F3F5);
    _lightSurfaceContainer = const Color(0xFFEFEFF1);
    _lightSurface = const Color(0xFFEAEAEC);
    _lightSurfaceContainerHigh = const Color(0xFFE6E6E8);
    _lightSurfaceContainerHighest = const Color(0xFFDEDEE0);
    _lightSurfaceBright = const Color(0xFFFAFAFC);
    // Accessible light adaptation; a current light native comparator is open.
    _lightPrimary = const Color(0xFF0063D9);
    _lightPrimaryContainer = const Color(0xFF0063D9);
    _lightSecondaryContainer = _lightSurfaceContainerHigh;
    _lightOutlineVariant = const Color(0x1F191C1F);

    _initialized = true;
  }

  static bool get isInitialized => _initialized;

  static Brightness _brightness = Brightness.dark;

  static Brightness get brightness => _brightness;

  static bool get isDark => _brightness == Brightness.dark;

  /// Selects the active palette for context-free legacy token reads.
  ///
  /// New widgets should prefer `Theme.of(context)` and
  /// `context.afriSemanticColors`. This bridge keeps existing shared tokens
  /// theme-aware while routes are migrated incrementally.
  static void setBrightness(Brightness brightness) {
    _brightness = brightness;
  }

  static Color get clubPrimary => _primary;
  static Color get clubSecondary => _secondary;
  static Color get clubAccent => _accent;
  static List<Color> get clubGradient => _gradient;

  static Color _darkBackground = Colors.black;
  static Color _darkSurfaceDim = Colors.black;
  static Color _darkSurface = const Color(0xFF161618);
  static Color _darkSurfaceContainerLowest = const Color(0xFF101012);
  static Color _darkSurfaceContainerLow = const Color(0xFF161618);
  static Color _darkSurfaceContainer = const Color(0xFF161618);
  static Color _darkSurfaceContainerHigh = const Color(0xFF161618);
  static Color _darkSurfaceContainerHighest = const Color(0xFF242426);
  static Color _darkSurfaceBright = const Color(0xFF2C2C2E);
  static Color _darkPrimary = const Color(0xFF4D8DFF);
  static Color _darkPrimaryContainer = const Color(0xFF4D8DFF);
  static Color _darkSecondaryContainer = const Color(0xFF161618);
  static Color _darkOutlineVariant = const Color(0x223F5A81);

  static Color _lightBackground = const Color(0xFFF5F5F7);
  static Color _lightSurfaceDim = const Color(0xFFF5F5F7);
  static Color _lightSurface = const Color(0xFFEAEAEC);
  static Color _lightSurfaceContainerLowest = Colors.white;
  static Color _lightSurfaceContainerLow = const Color(0xFFF3F3F5);
  static Color _lightSurfaceContainer = const Color(0xFFEFEFF1);
  static Color _lightSurfaceContainerHigh = const Color(0xFFE6E6E8);
  static Color _lightSurfaceContainerHighest = const Color(0xFFDEDEE0);
  static Color _lightSurfaceBright = const Color(0xFFFAFAFC);
  static Color _lightPrimary = const Color(0xFF0063D9);
  static Color _lightPrimaryContainer = const Color(0xFF0063D9);
  static Color _lightSecondaryContainer = const Color(0xFFE6E6E8);
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
      isDark ? const Color(0xFFF4F4F4) : const Color(0xFF191C1F);
  static Color get onSurfaceVariant =>
      isDark ? const Color(0xFFA1A1A3) : const Color(0xFF626266);

  static Color get glassFill =>
      Colors.white.withValues(alpha: isDark ? 0.075 : 0.10);
  static Color get ghostBorder =>
      (isDark ? Colors.white : _inkBase).withValues(alpha: 0.12);

  static const double glassBlurSigma = 22.0;
  static Color get chrome => inkBase.withValues(alpha: 0.94);
  static Color get chromeBorder => Colors.white.withValues(alpha: 0.12);
  static Color get chromeForeground => const Color(0xFFFFFDFB);

  static const Color transparent = Color(0x00000000);
  static const Color onDark = Color(0xFFFFFFFF);
  static const Color onDarkDim = Color(0x99FFFFFF);
  static const Color onDarkSubtle = Color(0x8AFFFFFF);
  static const Color onDarkFaint = Color(0x61FFFFFF);
  static const Color onDarkSoft = Color(0x3DFFFFFF);
  static const Color onDarkHairline = Color(0x1AFFFFFF);
  static const Color paperSurface = Color(0xFFFFFFFF);
  static const Color inkBase = _inkBase;

  /// High-contrast binary colors reserved for machine-readable QR modules.
  static const Color machineCodeLight = Color(0xFFFFFFFF);
  static const Color machineCodeDark = Color(0xFF000000);
  static const Color inkMuted = Color(0x8A09090B);
  static const Color inkSubtle = Color(0x6109090B);
  static const Color inkFaint = Color(0x4209090B);
  static const Color inkHairline = Color(0x0D09090B);

  static Color get navActive => primaryContainer;

  static Color get ambientShadow => const Color(0xFF040812);

  static Color get scrim => background.withValues(alpha: 0.72);

  static const Color _darkSuccess = Color(0xFF4AC789);
  static const Color _darkWarning = Color(0xFFF0BF63);
  static const Color _darkError = Color(0xFFFF6B6B);
  static const Color _darkInfo = Color(0xFF69A8FF);
  static const Color _lightSuccess = Color(0xFF176B45);
  static const Color _lightWarning = Color(0xFF7A4F00);
  static const Color _lightError = Color(0xFFB42318);
  static const Color _lightInfo = Color(0xFF0057B8);

  static Color get success => isDark ? _darkSuccess : _lightSuccess;
  static Color get warning => isDark ? _darkWarning : _lightWarning;
  static Color get error => isDark ? _darkError : _lightError;
  static Color get info => isDark ? _darkInfo : _lightInfo;

  static LinearGradient heroGradient({Color? from, Color? to}) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [from ?? primary, to ?? primaryContainer],
      stops: const [0.0, 1.0],
    );
  }

  static LinearGradient membershipCardGradient() => const LinearGradient(
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
    colors: [membershipCardViolet, membershipCardVioletLight],
  );

  /// Resolves an inactive-control foreground that stays visibly unavailable
  /// without falling below the design contract's 3:1 disabled-state floor.
  static Color accessibleDisabledColor(Color candidate) {
    return _ensureContrastAcross(candidate, <Color>[
      background,
      surfaceContainerLow,
      surfaceContainerHigh,
      surfaceBright,
    ], minimum: 3);
  }

  static LinearGradient universalGradient({
    required List<Color> colors,
    AlignmentGeometry begin = Alignment.topLeft,
    AlignmentGeometry end = Alignment.bottomRight,
    List<double>? stops,
  }) {
    return LinearGradient(begin: begin, end: end, colors: colors, stops: stops);
  }

  static LinearGradient universalSurfaceGradient({
    Color? tint,
    double tintAlpha = 0.12,
    Color? from,
    Color? to,
  }) {
    final tintColor = tint?.withValues(alpha: tintAlpha.clamp(0.0, 1.0));
    return universalGradient(
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
    return universalGradient(
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
      return universalGradient(
        colors: [primaryTint(0.55), surfaceContainerHighest],
      );
    }
    if (lower.contains('access')) {
      return universalGradient(
        colors: [surfaceContainerHighest, surfaceContainerLow],
      );
    }
    return universalGradient(
      colors: [surfaceContainerHigh, surfaceContainerLow],
    );
  }

  static Color primaryTint(double alpha) =>
      primary.withValues(alpha: alpha.clamp(0.0, 1.0));

  static Color accentTint(double alpha) =>
      primaryContainer.withValues(alpha: alpha.clamp(0.0, 1.0));

  /// Only overview routes receive a glow. Detail, search, forms and settings
  /// use a neutral canvas; substring matching would leak a glow into tasks.
  static LinearGradient screenGradientForPath([
    String? path,
    Brightness? brightness,
  ]) {
    final dark = (brightness ?? _brightness) == Brightness.dark;
    final canvas = dark ? _darkBackground : _lightBackground;
    final route = Uri.tryParse((path ?? '').trim())?.path;
    // Measured sRGB canvas samples from the original September captures,
    // excluding the Mirroring frame. Stops model each family's own extent;
    // they are rendered adapters, not exported native design tokens.
    final (values, stops) = switch (route) {
      '/home' => (
        const [
          0xFF557FFC,
          0xFF304DF8,
          0xFF1121CA,
          0xFF05129A,
          0xFF060862,
          0xFF000445,
        ],
        const [0.0, 0.13, 0.24, 0.35, 0.45, 0.56],
      ),
      '/club' => (
        const [
          0xFF2F9CAE,
          0xFF186479,
          0xFF0D4052,
          0xFF093240,
          0xFF051B24,
          0xFF03181F,
        ],
        const [0.0, 0.13, 0.24, 0.35, 0.56, 0.82],
      ),
      '/fanzone' => (
        const [
          0xFFA827F6,
          0xFF9939F6,
          0xFF814BF3,
          0xFF7051F3,
          0xFF5D4DE3,
          0xFF3B328D,
          0xFF352B7D,
        ],
        const [0.0, 0.13, 0.24, 0.35, 0.45, 0.56, 0.82],
      ),
      '/membership' => (
        const [0xFF43098B, 0xFF3A0A89, 0xFF180D24, 0xFF131416, 0xFF000000],
        const [0.0, 0.35, 0.45, 0.70, 1.0],
      ),
      // Onboarding 4: measured canvas pixels, excluding keyboard and footer.
      '/auth/phone' => (
        const [0xFF1B2B8C, 0xFF1C2D7D, 0xFF0B112F, 0xFF000000],
        const [0.0, 0.16, 0.38, 0.52],
      ),
      // Onboarding 10: centre-canvas samples, excluding keyboard and footer.
      '/auth/otp' => (
        const [0xFF1C2D97, 0xFF1C3088, 0xFF0B1234, 0xFF000105],
        const [0.0, 0.16, 0.39, 0.52],
      ),
      _ => (const <int>[], const <double>[]),
    };
    if (values.isEmpty) {
      return LinearGradient(colors: [canvas, canvas]);
    }
    final colors = values
        .map((value) {
          final color = Color(value);
          return dark
              ? color
              : Color.alphaBlend(color.withValues(alpha: 0.06), canvas);
        })
        .toList(growable: false);
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: colors,
      stops: stops,
    );
  }

  /// Tonal list groups inherit their overview canvas; task surfaces stay neutral.
  static Color overviewSurfaceForPath(String path) =>
      switch (Uri.tryParse(path)?.path) {
        '/home' => const Color(0xFF181A53),
        '/club' => const Color(0xFF192E35),
        '/fanzone' => const Color(0xFF463D8A),
        _ => surfaceContainerHigh,
      };
}
