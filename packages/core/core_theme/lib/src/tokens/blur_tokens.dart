/// Blur presets for the Revolut-Borrowed glass layers.
class AfriBlur {
  AfriBlur._();

  /// Subtle blur for inset pebbles and small overlays.
  static const double subtle = 12.0;

  /// Standard floating glass blur.
  static const double standard = 20.0;

  /// Heavy blur for modals, nav bars, and floating sheets.
  static const double overlay = 28.0;

  /// Atmospheric blur for hero lighting and deep glows.
  static const double atmospheric = 40.0;
}
