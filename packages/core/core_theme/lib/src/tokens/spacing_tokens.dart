/// Spacing tokens — generous breathing room between high-contrast elements.
///
/// Use the **semantic ** below for common layout patterns so every
/// screen speaks the same spatial language. The raw `spacingN` values
/// remain available for edge-cases.
class SpacingTokens {
  SpacingTokens._();

  // ── Raw scale ──
  static const double spacing1 = 4.0;
  static const double spacing2 =
      8.0; // 0.7rem — list item gap (replaces dividers)
  static const double spacing3 = 12.0;
  static const double spacing4 = 16.0;
  static const double spacing5 = 20.0;
  static const double spacing6 =
      24.0; // 2rem — internal card content separation
  static const double spacing7 = 28.0;
  static const double spacing8 = 32.0; // Breathing room
  static const double spacing9 = 36.0;
  static const double spacing10 =
      40.0; // Breathing room between high-contrast elements
  static const double spacing12 = 48.0;
  static const double spacing16 = 64.0;
  static const double spacing20 = 80.0;

  // ── Semantic  ──

  /// Horizontal inset for screen-level content (left/right padding).
  static const double screenPadding = spacing6; // 24

  /// Vertical gap between major sections on a screen.
  static const double sectionGap = spacing8; // 32

  /// Internal padding inside cards and containers.
  static const double cardPadding = spacing5; // 20

  /// Gap between sibling list items or card rows.
  static const double listItemGap = spacing3; // 12

  /// Tight inline gap (icon-to-label, chip-to-chip).
  static const double inlineGap = spacing2; // 8

  /// Minimum tap target padding for interactive elements.
  static const double tapPadding = spacing4; // 16
}
