enum BioPayRecoveryIssue { camera, deviceAuth, nfc, feature }

class BioPayRecoveryArgs {
  const BioPayRecoveryArgs({
    required this.issue,
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.primaryRoute,
    this.secondaryLabel,
    this.secondaryRoute,
  });

  final BioPayRecoveryIssue issue;
  final String title;
  final String message;
  final String primaryLabel;
  final String primaryRoute;
  final String? secondaryLabel;
  final String? secondaryRoute;
}
