import 'dart:collection';

import 'package:core_utils/core_utils.dart';

/// Client-side rate limiter for BioPay operations.
///
/// Prevents abuse by enforcing maximum attempt counts within sliding windows.
/// This is a defense-in-depth measure — server-side Edge Functions should
/// also enforce their own rate limits.
class BiopayRateLimiter {
  BiopayRateLimiter({
    this.maxEnrollmentsPerHour = 3,
    this.maxMatchesPerMinute = 10,
    this.maxMatchesPerHour = 60,
    this.maxPaymentIntentsPerMinute = 5,
  });

  final int maxEnrollmentsPerHour;
  final int maxMatchesPerMinute;
  final int maxMatchesPerHour;
  final int maxPaymentIntentsPerMinute;

  // Sliding window buckets
  final Queue<DateTime> _enrollAttempts = Queue<DateTime>();
  final Queue<DateTime> _matchAttempts = Queue<DateTime>();
  final Queue<DateTime> _paymentIntentAttempts = Queue<DateTime>();

  /// Check if enrollment is allowed. Returns null if allowed, or a
  /// user-friendly message if rate-limited.
  String? checkEnrollmentAllowed() {
    _pruneOlderThan(_enrollAttempts, const Duration(hours: 1));
    if (_enrollAttempts.length >= maxEnrollmentsPerHour) {
      return 'Too many enrollment attempts. Please wait before trying again.';
    }
    return null;
  }

  /// Record an enrollment attempt.
  void recordEnrollmentAttempt() {
    _enrollAttempts.add(DateTime.now());
  }

  /// Check if a match attempt is allowed.
  String? checkMatchAllowed() {
    final now = DateTime.now();

    // Check per-minute limit
    _pruneOlderThan(_matchAttempts, const Duration(minutes: 1));
    final recentCount = _matchAttempts
        .where((t) => now.difference(t).inMinutes < 1)
        .length;
    if (recentCount >= maxMatchesPerMinute) {
      return 'Too many match attempts. Please wait a moment.';
    }

    // Check per-hour limit
    _pruneOlderThan(_matchAttempts, const Duration(hours: 1));
    if (_matchAttempts.length >= maxMatchesPerHour) {
      return 'Hourly match limit reached. Please try again later.';
    }

    return null;
  }

  /// Record a match attempt.
  void recordMatchAttempt() {
    _matchAttempts.add(DateTime.now());
  }

  /// Check if creating a payment intent is allowed.
  String? checkPaymentIntentAllowed() {
    _pruneOlderThan(_paymentIntentAttempts, const Duration(minutes: 1));
    if (_paymentIntentAttempts.length >= maxPaymentIntentsPerMinute) {
      return 'Too many payment requests. Please wait.';
    }
    return null;
  }

  /// Record a payment intent attempt.
  void recordPaymentIntentAttempt() {
    _paymentIntentAttempts.add(DateTime.now());
  }

  /// Reset all rate limit counters (e.g., on user sign-out).
  void reset() {
    _enrollAttempts.clear();
    _matchAttempts.clear();
    _paymentIntentAttempts.clear();
    AfriLogger.info('BiopayRateLimiter', 'Counters reset.');
  }

  /// Remove entries older than the given duration from the queue.
  void _pruneOlderThan(Queue<DateTime> queue, Duration window) {
    final cutoff = DateTime.now().subtract(window);
    while (queue.isNotEmpty && queue.first.isBefore(cutoff)) {
      queue.removeFirst();
    }
  }
}
