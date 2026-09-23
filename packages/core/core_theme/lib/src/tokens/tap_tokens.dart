/// Minimum tap target sizes for accessibility compliance.
///
/// Following Material Design accessibility guidelines:
/// minimum 48dp for all interactive elements.
class AfriTapTargets {
  AfriTapTargets._();

  /// Minimum interactive target (48dp). WCAG minimum.
  static const double minimum = 48.0;

  /// Comfortable target (56dp). For primary actions.
  static const double comfortable = 56.0;

  /// Large target (64dp). For bottom nav, FABs.
  static const double large = 64.0;
}
