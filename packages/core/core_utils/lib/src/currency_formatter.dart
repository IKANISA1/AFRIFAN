import 'package:intl/intl.dart';

/// Currency formatter — per-club currency display.
class CurrencyFormatter {
  final String currencyCode;
  final String currencySymbol;

  CurrencyFormatter({required this.currencyCode, required this.currencySymbol});

  /// Format amount with currency symbol: 5000 → 'RWF 5,000'
  String format(num amount) {
    final formatter = NumberFormat('#,##0', 'en');
    return '$currencySymbol ${formatter.format(amount)}';
  }

  /// Format amount without symbol: 5000 → '5,000'
  String formatPlain(num amount) {
    final formatter = NumberFormat('#,##0', 'en');
    return formatter.format(amount);
  }

  /// Compact format: 1500000 → '1.5M'
  String formatCompact(num amount) {
    final formatter = NumberFormat.compact();
    return '$currencySymbol ${formatter.format(amount)}';
  }
}
