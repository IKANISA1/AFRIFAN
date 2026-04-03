import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'club_config.dart';
import 'tokens/afri_semantic_colors.dart';
import 'tokens/color_tokens.dart';
import 'tokens/motion_tokens.dart';
import 'tokens/shape_tokens.dart';
import 'tokens/spacing_tokens.dart';
import 'tokens/typography_tokens.dart';

/// Generates a complete [ThemeData] from any [ClubConfig].
///
/// The ROUGEBLACK design system uses a Soft Slate (Middle Ground) Dark Mode.
/// Platform constants (glass, shadows, typography) adapt dynamically.
/// Only the primary/secondary/accent colors change per club via
/// [AfriSemanticColors.copyWith].
///
/// Key features ported from Cool repo:
/// - [AfriSemanticColors] as ThemeExtension (lerp + copyWith)
/// - Ripple-less interaction model (scale + opacity + haptic)
/// - Branded page transitions (fade + scale)
class ClubTheme {
  ClubTheme._();

  /// Generate a complete ThemeData from a ClubConfig.
  static ThemeData from(ClubConfig config) {
    final colors = config.colors;

    // ── Build semantic colors for this club ──
    final semanticColors = AfriSemanticColors.dark.copyWith(
      buttonPrimaryBackground: colors.primary,
      accent: colors.accent,
    );

    final colorScheme = ColorScheme(
      brightness: Brightness.dark,
      // Primary
      primary: colors.primary,
      onPrimary: Colors.white,
      primaryContainer: colors.primary,
      onPrimaryContainer: Colors.white,
      // Secondary
      secondary: colors.accent,
      onSecondary: ColorTokens.background,
      secondaryContainer: colors.accent.withValues(alpha: 0.2),
      onSecondaryContainer: colors.accent,
      // Surface hierarchy
      surface: ColorTokens.surface,
      onSurface: ColorTokens.onSurface,
      surfaceContainerLowest: ColorTokens.surfaceContainerLowest,
      surfaceContainerLow: ColorTokens.surfaceContainerLow,
      surfaceContainer: ColorTokens.surfaceContainer,
      surfaceContainerHigh: ColorTokens.surfaceContainerHigh,
      surfaceContainerHighest: ColorTokens.surfaceContainerHighest,
      // Error
      error: ColorTokens.error,
      onError: ColorTokens.background,
      // Outline
      outline: ColorTokens.outlineVariant,
      outlineVariant: ColorTokens.outlineVariant.withValues(alpha: 0.15),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: ColorTokens.background,

      // ── Attach semantic colors as ThemeExtension ──
      extensions: <ThemeExtension>[semanticColors],

      // ── Ripple-less interaction model ──
      // Replace Material ripple with scale + opacity + haptic feedback
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      splashFactory: NoSplash.splashFactory,

      // ── Branded page transitions (fade + scale) ──
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _AfriPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: _AfriPageTransitionsBuilder(),
          TargetPlatform.windows: _AfriPageTransitionsBuilder(),
        },
      ),

      // ── App Bar ──
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TypographyTokens.titleLarge(colors.primary),
        iconTheme: IconThemeData(color: ColorTokens.onSurface),
      ),

      // ── Card (Glassmorphism) ──
      cardTheme: CardThemeData(
        color: ColorTokens.glassFill,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: ShapeTokens.cardRadius,
          side: BorderSide(color: ColorTokens.ghostBorder, width: 1),
        ),
      ),

      // ── Bottom Navigation ──
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: ColorTokens.surfaceContainerLowest.withValues(
          alpha: 0.9,
        ),
        selectedItemColor: colors.primary,
        unselectedItemColor: ColorTokens.onSurface.withValues(alpha: 0.5),
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        elevation: 0,
      ),

      // ── Text Theme ──
      textTheme: _buildTextTheme(colors.primary),

      // ── Elevated Button (Claymorphic) ──
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: ShapeTokens.buttonRadius),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),

      // ── Filled Button ──
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: SpacingTokens.spacing6,
            vertical: SpacingTokens.spacing4,
          ),
          shape: RoundedRectangleBorder(borderRadius: ShapeTokens.buttonRadius),
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      // ── Text Button ──
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.primary,
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── Input ──
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ColorTokens.surfaceContainerHigh,
        border: OutlineInputBorder(
          borderRadius: ShapeTokens.inputRadius,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: ShapeTokens.inputRadius,
          borderSide: BorderSide(color: ColorTokens.ghostBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: ShapeTokens.inputRadius,
          borderSide: BorderSide(color: colors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        hintStyle: GoogleFonts.inter(
          color: ColorTokens.onSurface.withValues(alpha: 0.4),
          fontSize: 15,
        ),
      ),

      // ── Divider (should not be used — but fallback) ──
      dividerTheme: DividerThemeData(
        color: ColorTokens.ghostBorder,
        thickness: 0.5,
        space: 0,
      ),

      // ── Chip ──
      chipTheme: ChipThemeData(
        backgroundColor: ColorTokens.surfaceContainerHigh,
        selectedColor: colors.primary.withValues(alpha: 0.2),
        labelStyle: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: ColorTokens.onSurface,
        ),
        side: BorderSide(color: ColorTokens.ghostBorder),
        shape: RoundedRectangleBorder(borderRadius: ShapeTokens.chipRadius),
      ),

      // ── Snackbar ──
      snackBarTheme: SnackBarThemeData(
        backgroundColor: ColorTokens.surfaceContainerHighest,
        contentTextStyle: GoogleFonts.inter(
          color: ColorTokens.onSurface,
          fontSize: 15,
        ),
        shape: RoundedRectangleBorder(borderRadius: ShapeTokens.cardRadius),
        behavior: SnackBarBehavior.floating,
      ),

      // ── Bottom Sheet ──
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(ShapeTokens.radiusXl),
          ),
        ),
      ),

      // ── Toggles & Checkboxes ──
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) {
            return ColorTokens.onSurface;
          }
          return ColorTokens.outlineVariant;
        }),
        trackColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) {
            return colors.accent;
          }
          return ColorTokens.surfaceContainerHighest;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) {
            return colors.accent;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(ColorTokens.onSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        side: BorderSide(color: ColorTokens.outlineVariant),
      ),
    );
  }

  /// Build the complete text theme with Barlow Condensed + Inter.
  static TextTheme _buildTextTheme(Color primaryColor) {
    return TextTheme(
      // ── Display: Barlow Condensed ExtraBold 800 ──
      displayLarge: TypographyTokens.displayLarge(primaryColor),
      displayMedium: TypographyTokens.displayMedium(primaryColor),
      displaySmall: TypographyTokens.displaySmall(primaryColor),
      // ── Headlines: Barlow Condensed Bold 700 ──
      headlineLarge: TypographyTokens.headlineLarge(),
      headlineMedium: TypographyTokens.headlineMedium(),
      headlineSmall: TypographyTokens.headlineSmall(),
      // ── Titles: Barlow Condensed Bold 700 ──
      titleLarge: TypographyTokens.titleLarge(primaryColor),
      titleMedium: TypographyTokens.titleMedium(),
      titleSmall: TypographyTokens.titleSmall(),
      // ── Body: Inter Regular 400 ──
      bodyLarge: TypographyTokens.bodyLarge(),
      bodyMedium: TypographyTokens.bodyMedium(),
      bodySmall: TypographyTokens.bodySmall(),
      // ── Labels: Inter SemiBold 600 ──
      labelLarge: TypographyTokens.labelLarge(),
      labelMedium: TypographyTokens.labelMedium(),
      labelSmall: TypographyTokens.labelSmall(),
    );
  }
}

/// Custom page transition: Fade + subtle scale (0.98 → 1.0).
///
/// Creates the premium, smooth transition feel used throughout
/// the Cool app. This replaces the default Material zoom transition.
class _AfriPageTransitionsBuilder extends PageTransitionsBuilder {
  const _AfriPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: AfriMotion.enterCurve),
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.98, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: AfriMotion.enterCurve),
        ),
        child: child,
      ),
    );
  }
}
