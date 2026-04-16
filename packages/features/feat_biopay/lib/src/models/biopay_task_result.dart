enum BioPayTaskResultTone { success, error, blocked, pending }

class BioPayTaskResultArgs {
  const BioPayTaskResultArgs({
    required this.tone,
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.primaryRoute,
    this.secondaryLabel,
    this.secondaryRoute,
    this.alias,
    this.maskedRecipientValue,
    this.amount,
    this.currencyCode,
    this.currencySymbol,
  });

  final BioPayTaskResultTone tone;
  final String title;
  final String message;
  final String primaryLabel;
  final String primaryRoute;
  final String? secondaryLabel;
  final String? secondaryRoute;
  final String? alias;
  final String? maskedRecipientValue;
  final int? amount;
  final String? currencyCode;
  final String? currencySymbol;
}
