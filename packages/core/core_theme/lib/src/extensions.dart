import 'package:flutter/material.dart';

import 'club_config_scope.dart';
import 'runtime_branding.dart';
import 'tokens/afri_design_tokens.dart';
import 'tokens/afri_semantic_colors.dart';
import 'tokens/spacing_tokens.dart';

/// BuildContext extensions for accessing AFRICLUB theme tokens.
///
/// Usage:
/// ```dart
/// final colors = context.afriSemanticColors;
/// final space = context.afriSpace;
/// ```
extension AfriThemeExtension on BuildContext {
  /// Access the semantic color tokens from the current theme.
  ///
  /// Falls back to [AfriSemanticColors.dark] if the extension
  /// is not registered (e.g. during bootstrap).
  AfriSemanticColors get afriSemanticColors =>
      Theme.of(this).extension<AfriSemanticColors>() ?? AfriSemanticColors.dark;

  /// Access the non-color design tokens from root DESIGN.md.
  AfriDesignTokens get afriDesignTokens =>
      Theme.of(this).extension<AfriDesignTokens>() ??
      AfriDesignTokens.standard();

  /// Access the spacing token helper.
  AfriSpaceHelper get afriSpace => const AfriSpaceHelper();

  /// Active club currency code, falling back to runtime branding.
  String get afriCurrencyCode =>
      ClubConfigScope.maybeOf(this)?.currency ??
      RuntimeBranding.displayCurrencyCode;

  /// Active club currency symbol, falling back to runtime branding.
  String get afriCurrencySymbol =>
      ClubConfigScope.maybeOf(this)?.currencySymbol ??
      RuntimeBranding.displayCurrencySymbol;

  /// Active club country code, falling back to runtime branding.
  String get afriCountryCode =>
      ClubConfigScope.maybeOf(this)?.countryCode ??
      RuntimeBranding.displayCountryCode;
}

/// Helper class for accessing spacing tokens as properties.
///
/// Usage:
/// ```dart
/// SizedBox(height: context.afriSpace.x4); // 16.0
/// ```
class AfriSpaceHelper {
  const AfriSpaceHelper();

  double get x0 => 0.0;
  double get x1 => SpacingTokens.spacing1;
  double get x2 => SpacingTokens.spacing2;
  double get x3 => SpacingTokens.spacing3;
  double get x4 => SpacingTokens.spacing4;
  double get x5 => SpacingTokens.spacing5;
  double get x6 => SpacingTokens.spacing6;
  double get x7 => SpacingTokens.spacing7;
  double get x8 => SpacingTokens.spacing8;
  double get x9 => SpacingTokens.spacing9;
  double get x10 => SpacingTokens.spacing10;
  double get x12 => SpacingTokens.spacing12;
  double get x16 => SpacingTokens.spacing16;
  double get x20 => SpacingTokens.spacing20;
}
