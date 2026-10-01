/// Minimum tap target sizes for accessibility compliance.
///
/// The selected revolut-design adapter keeps a minimum 48 logical pixels
/// for interactive elements as an accessible product adaptation.
class AfriTapTargets {
  AfriTapTargets._();

  /// Minimum interactive target (48 logical pixels).
  static const double minimum = 48.0;

  /// Comfortable target (56dp). For primary actions.
  static const double comfortable = 56.0;

  /// Large target (64dp). For bottom nav, FABs.
  static const double large = 64.0;
}
