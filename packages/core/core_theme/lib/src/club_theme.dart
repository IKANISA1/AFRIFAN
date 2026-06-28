import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import 'club_config.dart';
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
/// surfaces, and typography flow through a calmer Revolut-borrowed system in
/// `core_theme`.
class ClubTheme {
  ClubTheme._();

  static ThemeData from(ClubConfig config) {
    final semanticColors = AfriSemanticColors.dark.copyWith(
      accent: ColorTokens.primaryContainer,
      accentSoft: ColorTokens.primaryContainer.withValues(alpha: 0.18),
      buttonPrimaryBackground: ColorTokens.primaryContainer,
    );

    final colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: ColorTokens.primary,
      onPrimary: Colors.white,
      primaryContainer: ColorTokens.primaryContainer,
      onPrimaryContainer: Colors.white,
      secondary: ColorTokens.clubAccent,
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
      outline: ColorTokens.outlineVariant,
      outlineVariant: ColorTokens.ghostBorder,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: ColorTokens.background,
      dividerColor: Colors.transparent,
      extensions: <ThemeExtension>[semanticColors],
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      splashFactory: NoSplash.splashFactory,
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
          side: BorderTokens.side(color: ColorTokens.ghostBorder, opacity: 0.8),
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
          backgroundColor: ColorTokens.primaryContainer,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: ColorTokens.primary.withValues(alpha: 0.18),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: ShapeTokens.buttonRadius),
          textStyle: TypographyTokens.labelLarge(),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ColorTokens.primaryContainer,
          foregroundColor: Colors.white,
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
        fillColor: ColorTokens.surfaceContainerLowest,
        border: BorderTokens.input(
          borderRadius: ShapeTokens.inputRadius,
          color: ColorTokens.ghostBorder,
          opacity: 0.95,
        ),
        enabledBorder: BorderTokens.input(
          borderRadius: ShapeTokens.inputRadius,
          color: ColorTokens.ghostBorder,
          opacity: 0.95,
        ),
        focusedBorder: BorderTokens.input(
          borderRadius: ShapeTokens.inputRadius,
          color: ColorTokens.primaryContainer,
          opacity: 0.75,
          width: BorderTokens.focus,
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
        side: BorderTokens.side(color: ColorTokens.ghostBorder, opacity: 0.9),
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
        side: BorderTokens.side(),
      ),
    );
  }

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
