import 'package:intl/intl.dart';

extension FantasyIntFormatting on int {
  String get fantasyBudgetDisplay => '£${(this / 10).toStringAsFixed(1)}M';
  String get separated => NumberFormat.decimalPattern().format(this);
}

extension FantasyDurationFormatting on Duration {
  String get countdownLabel {
    if (inSeconds <= 0) return 'Deadline passed';
    final days = inDays;
    final hours = inHours.remainder(24);
    final minutes = inMinutes.remainder(60);
    final seconds = inSeconds.remainder(60);
    if (days > 0) return '${days}d ${hours}h';
    if (inHours > 0) return '${inHours}h ${minutes}m';
    if (inMinutes > 0) return '${inMinutes}m ${seconds}s';
    return '${inSeconds}s';
  }
}

extension FantasyStringFormatting on String {
  String get titleCased {
    if (trim().isEmpty) return this;
    return split(RegExp(r'[_\s]+'))
        .where((segment) => segment.isNotEmpty)
        .map(
          (segment) =>
              segment[0].toUpperCase() + segment.substring(1).toLowerCase(),
        )
        .join(' ');
  }
}
