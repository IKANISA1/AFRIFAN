enum BiopayTaskResultTone { success, error, blocked, pending }

class BiopayTaskResultArgs {
  const BiopayTaskResultArgs({
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

  final BiopayTaskResultTone tone;
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
