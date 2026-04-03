import 'package:flutter/material.dart';

import 'spacing_tokens.dart';

/// Responsive layout constants for adapting content across device sizes.
///
/// Provides breakpoint-aware padding and max content widths to prevent
/// screens from stretching too wide on tablets/desktop while maintaining
/// a comfortable mobile layout.
class AfriResponsive {
  AfriResponsive._();

  // ── Breakpoints ──
  static const double compactMaxWidth = 600.0;
  static const double mediumMaxWidth = 840.0;
  static const double expandedMaxWidth = 1200.0;

  // ── Max content widths per breakpoint ──
  static const double mobileContentMax = 480.0;
  static const double tabletContentMax = 680.0;
  static const double desktopContentMax = 960.0;

  /// Returns the max content width for the given screen width.
  static double maxContentWidthForWidth(double screenWidth) {
    if (screenWidth <= compactMaxWidth) return screenWidth;
    if (screenWidth <= mediumMaxWidth) return tabletContentMax;
    return desktopContentMax;
  }

  /// Returns horizontal padding appropriate for the screen width.
  static EdgeInsets horizontalPadding(double screenWidth) {
    if (screenWidth <= compactMaxWidth) {
      return const EdgeInsets.symmetric(horizontal: SpacingTokens.spacing4);
    }
    if (screenWidth <= mediumMaxWidth) {
      return const EdgeInsets.symmetric(horizontal: SpacingTokens.spacing6);
    }
    return const EdgeInsets.symmetric(horizontal: SpacingTokens.spacing8);
  }

  /// Standard scaffold padding (applies to most screens).
  static const EdgeInsets scaffoldPadding = EdgeInsets.symmetric(
    horizontal: SpacingTokens.spacing4,
    vertical: SpacingTokens.spacing4,
  );
}
