String biopayAmountInputLabel({String? currencyCode}) {
  final normalized = currencyCode?.trim();
  if (normalized == null || normalized.isEmpty) {
    return 'Amount';
  }
  return 'Amount in $normalized';
}

String formatBiopayAmount({
  required int amount,
  String? currencySymbol,
  String? currencyCode,
}) {
  final symbol = currencySymbol?.trim();
  if (symbol != null && symbol.isNotEmpty) {
    return '$symbol $amount';
  }

  final code = currencyCode?.trim();
  if (code != null && code.isNotEmpty) {
    return '$code $amount';
  }

  return amount.toString();
}
