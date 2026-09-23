import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'club_config.dart';
import 'tokens/afri_design_tokens.dart';
import 'tokens/afri_semantic_colors.dart';
import 'tokens/border_tokens.dart';
import 'tokens/color_tokens.dart';
import 'tokens/motion_tokens.dart';
import 'tokens/shape_tokens.dart';
import 'tokens/spacing_tokens.dart';
import 'tokens/typography_tokens.dart';

/// Generates a complete [ThemeData] from any [ClubConfig].
///
/// Club identity colors still come from tenant config, but the shared shell,
/// surfaces, and typography flow through the universal mobile system in
/// `core_theme`.
class ClubTheme {
  ClubTheme._();

  static ThemeData from(
    ClubConfig config, {
    Brightness brightness = Brightness.dark,
    bool highContrast = false,
  }) {
    final previousBrightness = ColorTokens.brightness;
    ColorTokens.setBrightness(brightness);
    try {
      return _build(config, brightness, highContrast);
    } finally {
      ColorTokens.setBrightness(previousBrightness);
    }
  }

  static ThemeData _build(
    ClubConfig config,
    Brightness brightness,
    bool highContrast,
  ) {
    final isDark = brightness == Brightness.dark;
    final baseSemanticColors =
        (isDark ? AfriSemanticColors.dark : AfriSemanticColors.light).copyWith(
          accent: ColorTokens.primaryContainer,
          accentSoft: ColorTokens.primaryContainer.withValues(alpha: 0.18),
        );
    final highContrastBoundary = isDark ? Colors.white : ColorTokens.onSurface;
    final semanticColors = highContrast
        ? baseSemanticColors.copyWith(
            secondaryText: ColorTokens.onSurface,
            tertiaryText: ColorTokens.onSurface,
            border: highContrastBoundary,
            borderStrong: highContrastBoundary,
            accentSoft: ColorTokens.primaryContainer.withValues(alpha: 0.36),
          )
        : baseSemanticColors;
    final boundaryColor = highContrast
        ? highContrastBoundary
        : ColorTokens.ghostBorder;
    final boundaryWidth = highContrast
        ? BorderTokens.strong
        : BorderTokens.hairline;
    final focusWidth = highContrast
        ? AfriDesignTokens.highContrast().focusRingWidth
        : BorderTokens.focus;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: ColorTokens.primary,
      onPrimary: ColorTokens.contrastForeground(ColorTokens.primary),
      primaryContainer: ColorTokens.primaryContainer,
      onPrimaryContainer: ColorTokens.contrastForeground(
        ColorTokens.primaryContainer,
      ),
      secondary: ColorTokens.primaryContainer,
      onSecondary: ColorTokens.background,
      secondaryContainer: ColorTokens.secondaryContainer,
      onSecondaryContainer: ColorTokens.onSurface,
      surface: ColorTokens.surface,
      onSurface: ColorTokens.onSurface,
      surfaceContainerLowest: ColorTokens.surfaceContainerLowest,
      surfaceContainerLow: ColorTokens.surfaceContainerLow,
      surfaceContainer: ColorTokens.surfaceContainer,
      surfaceContainerHigh: ColorTokens.surfaceContainerHigh,
      surfaceContainerHighest: ColorTokens.surfaceContainerHighest,
      error: ColorTokens.error,
      onError: ColorTokens.background,
      outline: highContrast ? highContrastBoundary : ColorTokens.outlineVariant,
      outlineVariant: boundaryColor,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: ColorTokens.background,
      dividerColor: Colors.transparent,
      extensions: <ThemeExtension>[
        semanticColors,
        highContrast
            ? AfriDesignTokens.highContrast()
            : AfriDesignTokens.standard(),
      ],
      splashColor: ColorTokens.primaryContainer.withValues(alpha: 0.20),
      highlightColor: ColorTokens.primaryContainer.withValues(alpha: 0.14),
      hoverColor: ColorTokens.primaryContainer.withValues(alpha: 0.10),
      focusColor: ColorTokens.primaryContainer.withValues(alpha: 0.18),
      splashFactory: InkRipple.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _AfriPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: _AfriPageTransitionsBuilder(),
          TargetPlatform.windows: _AfriPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TypographyTokens.titleLarge().copyWith(
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: ColorTokens.onSurface),
      ),
      cardTheme: CardThemeData(
        color: ColorTokens.surfaceContainerLow,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: ShapeTokens.cardRadius,
          side: BorderTokens.side(
            color: boundaryColor,
            opacity: highContrast ? 1 : 0.8,
            width: boundaryWidth,
          ),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        selectedItemColor: ColorTokens.primaryContainer,
        unselectedItemColor: ColorTokens.onSurface.withValues(alpha: 0.5),
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        elevation: 0,
      ),
      textTheme: _buildTextTheme(),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: semanticColors.buttonPrimaryBackground,
          foregroundColor: semanticColors.buttonPrimaryForeground,
          minimumSize: const Size(0, 52),
          elevation: 0,
          shadowColor: ColorTokens.primary.withValues(alpha: 0.18),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: ShapeTokens.buttonRadius),
          textStyle: TypographyTokens.labelLarge(),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: semanticColors.buttonPrimaryBackground,
          foregroundColor: semanticColors.buttonPrimaryForeground,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(
            horizontal: SpacingTokens.spacing6,
            vertical: SpacingTokens.spacing4,
          ),
          shape: RoundedRectangleBorder(borderRadius: ShapeTokens.buttonRadius),
          textStyle: TypographyTokens.labelLarge(),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ColorTokens.primaryContainer,
          textStyle: TypographyTokens.labelMedium().copyWith(
            color: ColorTokens.primaryContainer,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: semanticColors.inputSurface,
        border: BorderTokens.input(
          borderRadius: ShapeTokens.inputRadius,
          color: boundaryColor,
          opacity: highContrast ? 1 : 0.95,
          width: boundaryWidth,
        ),
        enabledBorder: BorderTokens.input(
          borderRadius: ShapeTokens.inputRadius,
          color: boundaryColor,
          opacity: highContrast ? 1 : 0.95,
          width: boundaryWidth,
        ),
        focusedBorder: BorderTokens.input(
          borderRadius: ShapeTokens.inputRadius,
          color: ColorTokens.primaryContainer,
          opacity: highContrast ? 1 : 0.75,
          width: focusWidth,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: TypographyTokens.bodyMedium().copyWith(
          color: ColorTokens.onSurfaceVariant.withValues(alpha: 0.72),
        ),
        labelStyle: TypographyTokens.bodyMedium().copyWith(
          color: ColorTokens.onSurfaceVariant,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Colors.transparent,
        thickness: 0,
        space: 0,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: ColorTokens.secondaryContainer,
        selectedColor: Color.alphaBlend(
          ColorTokens.primary.withValues(alpha: 0.16),
          ColorTokens.surfaceContainerHigh,
        ),
        labelStyle: TypographyTokens.labelMedium().copyWith(
          color: ColorTokens.onSurface,
        ),
        side: BorderTokens.side(
          color: boundaryColor,
          opacity: highContrast ? 1 : 0.9,
          width: boundaryWidth,
        ),
        shape: RoundedRectangleBorder(borderRadius: ShapeTokens.chipRadius),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: ColorTokens.surfaceContainerHigh.withValues(
          alpha: 0.94,
        ),
        contentTextStyle: TypographyTokens.bodyMedium(),
        shape: RoundedRectangleBorder(borderRadius: ShapeTokens.cardRadius),
        behavior: SnackBarBehavior.floating,
      ),
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
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return ColorTokens.surfaceContainerHighest;
        }),
        trackColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) {
            return ColorTokens.primaryContainer;
          }
          return ColorTokens.surfaceContainerLow;
        }),
        overlayColor: _controlInteractionOverlay,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) {
            return ColorTokens.primaryContainer;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(ColorTokens.onSurface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ShapeTokens.radiusSm),
        ),
        side: BorderTokens.side(color: boundaryColor, width: boundaryWidth),
        overlayColor: _controlInteractionOverlay,
      ),
      radioTheme: RadioThemeData(overlayColor: _controlInteractionOverlay),
    );
  }

  static final WidgetStateProperty<Color?> _controlInteractionOverlay =
      WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.focused)) {
          return ColorTokens.primaryContainer.withValues(alpha: 0.22);
        }
        if (states.contains(WidgetState.pressed)) {
          return ColorTokens.primaryContainer.withValues(alpha: 0.18);
        }
        if (states.contains(WidgetState.hovered)) {
          return ColorTokens.primaryContainer.withValues(alpha: 0.12);
        }
        return null;
      });

  static TextTheme _buildTextTheme() {
    return TextTheme(
      displayLarge: TypographyTokens.displayLarge(),
      displayMedium: TypographyTokens.displayMedium(),
      displaySmall: TypographyTokens.displaySmall(),
      headlineLarge: TypographyTokens.headlineLarge(),
      headlineMedium: TypographyTokens.headlineMedium(),
      headlineSmall: TypographyTokens.headlineSmall(),
      titleLarge: TypographyTokens.titleLarge(),
      titleMedium: TypographyTokens.titleMedium(),
      titleSmall: TypographyTokens.titleSmall(),
      bodyLarge: TypographyTokens.bodyLarge(),
      bodyMedium: TypographyTokens.bodyMedium(),
      bodySmall: TypographyTokens.bodySmall(),
      labelLarge: TypographyTokens.labelLarge(),
      labelMedium: TypographyTokens.labelMedium(),
      labelSmall: TypographyTokens.labelSmall(),
    );
  }
}

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
    if (AfriMotion.reduceMotion(context)) return child;
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
