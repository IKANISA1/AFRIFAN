/// Blur presets for the Glass Mandate.
///
/// "BackdropFilter Blur: 12px" — the core glass effect.
/// Additional levels for overlays and atmospheric effects.
class AfriBlur {
  AfriBlur._();

  /// Subtle background blur (8px). For light glass effects.
  static const double subtle = 8.0;

  /// Standard glass blur (12px). The Glass Mandate default.
  static const double standard = 12.0;

  /// Overlay blur (20px). For bottom sheets, modals.
  static const double overlay = 20.0;

  /// Heavy atmospheric blur (32px). For hero backgrounds.
  static const double atmospheric = 32.0;
}
