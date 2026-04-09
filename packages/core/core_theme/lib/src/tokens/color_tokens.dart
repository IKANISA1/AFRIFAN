import 'package:flutter/material.dart';

import '../club_config.dart';

/// Color tokens for the ROUGEBLACK design system.
///
/// "The Stadium Pulse" palette: deep midnight stadium shadows
/// punctuated by high-velocity club accents.
///
/// ## Architecture
/// **Platform constants** (background, surface, glass, semantic) are identical
/// across all 50+ clubs and are compile-time `const`.
///
/// **Club-specific accents** (`clubPrimary`, `clubSecondary`, `clubAccent`,
/// `navActive`, hero gradient) are initialized ONCE at startup from
/// [ClubColors] via [ColorTokens.init].
///
/// Legacy aliases `clubRed`, `deepNavy`, `trophyGold` delegate to the
/// dynamic getters so existing widget code keeps compiling without changes.
class ColorTokens {
  ColorTokens._();

  // ────────────────────────────────────────────────────────────────────────
  //  §1 — Dynamic Club Colors (set once at startup via init)
  // ────────────────────────────────────────────────────────────────────────

  /// Has [init] been called?
  static bool _initialized = false;

  // Backing stores — Rayon Sports blue defaults (overwritten by init).
  static Color _primary = const Color(0xFF0038A8); // Rayon Blue
  static Color _secondary = const Color(0xFF001742); // Deep Navy
  static Color _accent = const Color(0xFFD4A017); // Trophy Gold
  static List<Color> _gradient = const [Color(0xFF8885F0), Color(0xFF0038A8)];
  // ── Design system defaults (used when a club color is white) ──
  static const Color _defaultPrimary = Color(0xFF0038A8);
  static const Color _defaultSecondary = Color(0xFF001742);
  static const Color _defaultAccent = Color(0xFFD4A017);

  /// Returns true if a color is white or near-white (luminance > 0.9).
  /// White colors break the dark-mode UI, so they are dropped.
  static bool _isWhite(Color c) => c.computeLuminance() > 0.9;

  /// Initialize club-specific colors from [ClubColors].
  ///
  /// **Must be called once** in `bootstrap()` before `runApp()`.
  /// Calling multiple times is safe (idempotent) — it overwrites the
  /// previous palette.
  ///
  /// **White-drop rule:** If any club color is white/near-white, it is
  /// replaced with the design system default for that slot. This ensures
  /// all accent surfaces remain visible on the dark theme.
  ///
  /// ```dart
  /// Future<void> bootstrap(ClubConfig config) async {
  ///   ...
  ///   ColorTokens.init(config.colors);
  ///   runApp(AfriClubApp(...));
  /// }
  /// ```
  static void init(ClubColors colors) {
    _primary = _isWhite(colors.primary) ? _defaultPrimary : colors.primary;
    _secondary = _isWhite(colors.secondary)
        ? _defaultSecondary
        : colors.secondary;
    _accent = _isWhite(colors.accent) ? _defaultAccent : colors.accent;

    _gradient = colors.gradient.isNotEmpty
        ? colors.gradient
        : [_primary, _secondary];

    // ── Pre-calculate both DARK and LIGHT palettes ──
    final hsl = HSLColor.fromColor(_primary);
    final coreLight = hsl.withLightness(0.97).withSaturation(0.15).toColor();

    // Dark Palette - strictly using club colors, no synthetic blacks
    _darkSurfaceContainerLowest = _secondary;
    _darkBackground = Color.lerp(_secondary, _primary, 0.05)!;
    _darkSurfaceContainerLow = Color.lerp(_secondary, _primary, 0.11)!;
    _darkSurfaceContainer = Color.lerp(_secondary, _primary, 0.19)!;
    _darkSurface = Color.lerp(_secondary, _primary, 0.27)!;
    _darkSurfaceContainerHigh = Color.lerp(_secondary, _primary, 0.37)!;
    _darkSurfaceContainerHighest = Color.lerp(_secondary, _primary, 0.48)!;
    _darkOutlineVariant = Color.lerp(_secondary, Colors.white, 0.28)!;

    // Light Palette
    _lightBackground = coreLight;
    _lightSurface = Color.lerp(coreLight, _primary, 0.05)!;
    _lightSurfaceContainerLowest = Color.lerp(coreLight, Colors.white, 0.4)!;
    _lightSurfaceContainerLow = Color.lerp(coreLight, _primary, 0.02)!;
    _lightSurfaceContainer = Color.lerp(coreLight, _primary, 0.06)!;
    _lightSurfaceContainerHigh = Color.lerp(coreLight, _primary, 0.12)!;
    _lightSurfaceContainerHighest = Color.lerp(coreLight, _primary, 0.18)!;
    _lightOutlineVariant = Color.lerp(coreLight, _primary, 0.25)!;

    _initialized = true;
  }

  /// Whether the dynamic palette has been initialized.
  static bool get isInitialized => _initialized;

  // ── Theme brightness contract ──
  // The shared app theme is dark-only, so tokens must not branch on
  // platform brightness or they drift away from ThemeData at runtime.
  static const bool isDark = true;

  // ── Public getters — the dynamic palette ──

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

  // ────────────────────────────────────────────────────────────────────────
  //  §2 — Platform Constants (Dynamic by Brightness)
  // ────────────────────────────────────────────────────────────────────────

  static Color _darkBackground = _defaultPrimary;
  static Color _darkSurface = _defaultPrimary;
  static Color _darkSurfaceContainerLowest = _defaultPrimary;
  static Color _darkSurfaceContainerLow = _defaultPrimary;
  static Color _darkSurfaceContainer = _defaultPrimary;
  static Color _darkSurfaceContainerHigh = _defaultPrimary;
  static Color _darkSurfaceContainerHighest = _defaultPrimary;
  static Color _darkOutlineVariant = _defaultPrimary;

  static Color _lightBackground = _defaultPrimary;
  static Color _lightSurface = _defaultPrimary;
  static Color _lightSurfaceContainerLowest = _defaultPrimary;
  static Color _lightSurfaceContainerLow = _defaultPrimary;
  static Color _lightSurfaceContainer = _defaultPrimary;
  static Color _lightSurfaceContainerHigh = _defaultPrimary;
  static Color _lightSurfaceContainerHighest = _defaultPrimary;
  static Color _lightOutlineVariant = _defaultPrimary;

  static Color get background => isDark ? _darkBackground : _lightBackground;
  static Color get surface => isDark ? _darkSurface : _lightSurface;
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

  // ── On Surface (Text) ──
  static Color get onSurface =>
      isDark ? const Color(0xFFFFFFFF) : const Color(0xFF1E293B);
  static Color get onSurfaceVariant =>
      isDark ? const Color(0xFFC9D4EA) : const Color(0xFF475569);

  // ── Glass Mandate Parameters ──
  static Color get glassFill => isDark
      ? Colors.white.withValues(alpha: 0.05)
      : _primary.withValues(alpha: 0.05);

  static Color get ghostBorder => isDark
      ? Colors.white.withValues(alpha: 0.10)
      : _primary.withValues(alpha: 0.10);

  static const double glassBlurSigma = 12.0;

  // ── Active state for navigation ──
  static Color get navActive {
    return _accent;
  }

  // ── Ambient shadow (for glass cards) ──
  // "Don't use standard Drop Shadows" — all shadows tinted with surface hue.
  static Color get ambientShadow {
    return _primary.withValues(alpha: 0.25);
  }

  // ── Modals & Overlays ──
  static Color get scrim {
    return _primary.withValues(alpha: 0.60);
  }

  // ── Semantic ──
  static const Color success = Color(0xFF4ADE80);
  static const Color warning = Color(0xFFFBBF24);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF60A5FA);

  // ── Signature gradient (secondary → primary, 135°) ──
  static LinearGradient heroGradient({Color? from, Color? to}) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [from ?? _accent, to ?? _primary],
    );
  }

  // ── Utility: Generate a tinted surface from the club primary ──
  /// Returns the club primary at a given alpha (for subtle tinted cards).
  static Color primaryTint(double alpha) =>
      _primary.withValues(alpha: alpha.clamp(0.0, 1.0));

  /// Returns the club accent at a given alpha.
  static Color accentTint(double alpha) =>
      _accent.withValues(alpha: alpha.clamp(0.0, 1.0));
}
