import 'package:intl/intl.dart';

/// Date formatter — localized date/time display.
class AfriDateFormatter {
  /// e.g. 'Mar 30, 2026'
  static String formatDate(DateTime date) {
    return DateFormat.yMMMd().format(date);
  }

  /// e.g. '3:06 PM'
  static String formatTime(DateTime date) {
    return DateFormat.jm().format(date);
  }

  /// e.g. 'Mar 30, 2026 at 3:06 PM'
  static String formatDateTime(DateTime date) {
    return '${formatDate(date)} at ${formatTime(date)}';
  }

  /// e.g. '2 hours ago', 'just now'
  static String timeAgo(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    return formatDate(date);
  }

  /// Match kickoff format: 'SAT 30 MAR · 15:00'
  static String matchKickoff(DateTime date) {
    final day = DateFormat('EEE').format(date).toUpperCase();
    final dayNum = DateFormat('d').format(date);
    final month = DateFormat('MMM').format(date).toUpperCase();
    final time = DateFormat('HH:mm').format(date);
    return '$day $dayNum $month · $time';
  }
}
