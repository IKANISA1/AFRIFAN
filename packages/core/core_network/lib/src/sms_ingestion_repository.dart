import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Captured SMS ready for ingestion.
class SmsCapturePayload {
  const SmsCapturePayload({
    required this.sender,
    required this.body,
    required this.receivedAt,
    required this.deviceMessageKey,
    required this.ingestionSource,
    this.countryCode,
  });

  final String sender;
  final String body;
  final DateTime receivedAt;
  final String deviceMessageKey;
  final String ingestionSource;

  /// ISO country code linking to the `countries` table (e.g. 'RW').
  final String? countryCode;
}

/// Result of an SMS ingestion call.
class SmsIngestionResult {
  const SmsIngestionResult({
    required this.rawSmsId,
    required this.inserted,
    required this.parseQueued,
  });

  final String rawSmsId;
  final bool inserted;
  final bool parseQueued;
}

/// Thrown when the sms-ingest edge function returns HTTP 429.
class SmsRateLimitException implements Exception {
  const SmsRateLimitException([this.message = 'SMS rate limit exceeded']);

  final String message;

  @override
  String toString() => message;
}

/// White-label SMS ingestion repository.
///
/// Ingests mobile money transaction SMS into Supabase for parsing.
/// Supports dynamic sender IDs per country/provider.
class SmsIngestionRepository {
  SmsIngestionRepository({
    required SupabaseClient client,
    List<String>? approvedSenderIds,
  }) : _client = client,
       _approvedSenderIds = approvedSenderIds ?? defaultApprovedSenderIds;

  final SupabaseClient _client;
  final List<String> _approvedSenderIds;

  /// Default sender IDs covering MTN MoMo Rwanda.
  /// Override via constructor for other countries/providers.
  static const defaultApprovedSenderIds = <String>[
    'M-Money',
    'M-Money Alerts',
    'M Money',
    'MobileMoney',
    'Mobile Money',
    'MoMo',
    'MoMo Alerts',
    'MOMO',
    'MTN MoMo',
    'MTN MOMO',
    'M-Pesa',
    'MPESA',
    'Airtel Money',
    'Orange Money',
    'Tigo Pesa',
  ];

  String? get currentUserId => _client.auth.currentUser?.id;

  /// Normalized sender tokens for matching.
  Set<String> get _normalizedTokens => _approvedSenderIds
      .map(_normalizeSender)
      .where((s) => s.isNotEmpty)
      .toSet();

  /// Check if a sender matches the approved list.
  bool isApprovedSender(String? sender) {
    final normalized = _normalizeSender(sender);
    if (normalized.isEmpty) return false;
    return _normalizedTokens.contains(normalized);
  }

  /// Build a device message key for deduplication.
  static String buildDeviceMessageKey({
    required String sender,
    required String body,
    required DateTime receivedAt,
  }) {
    final normalizedSender = _normalizeSender(sender);
    final normalizedBody = _normalizeWhitespace(body);
    final payload =
        '$normalizedSender|${receivedAt.toUtc().toIso8601String()}|$normalizedBody';
    return sha256.convert(utf8.encode(payload)).toString();
  }

  /// Capture a device SMS and build the payload if it's from an approved sender.
  SmsCapturePayload? captureFromDevice({
    required String? sender,
    required String? body,
    int? timestampMillis,
    String ingestionSource = 'android_sms_listener',
    String? countryCode,
  }) {
    final trimmedSender = sender?.trim() ?? '';
    final trimmedBody = _normalizeWhitespace(body ?? '');
    if (trimmedBody.isEmpty || !isApprovedSender(trimmedSender)) {
      return null;
    }

    final receivedAt = _timestampToUtc(timestampMillis);
    return SmsCapturePayload(
      sender: trimmedSender,
      body: trimmedBody,
      receivedAt: receivedAt,
      deviceMessageKey: buildDeviceMessageKey(
        sender: trimmedSender,
        body: trimmedBody,
        receivedAt: receivedAt,
      ),
      ingestionSource: ingestionSource,
      countryCode: countryCode,
    );
  }

  /// Ingest a captured SMS into Supabase.
  Future<SmsIngestionResult?> ingestCapture({
    required SmsCapturePayload capture,
    String? userId,
  }) async {
    final resolvedUserId = userId ?? currentUserId;
    if (resolvedUserId == null || resolvedUserId.isEmpty) return null;

    final dynamic response;
    try {
      response = await _client.functions.invoke(
        'sms-ingest',
        body: <String, dynamic>{
          'sender': capture.sender,
          'smsBody': capture.body,
          'smsReceivedAt': capture.receivedAt.toIso8601String(),
          'deviceMessageKey': capture.deviceMessageKey,
          'ingestionSource': capture.ingestionSource,
          if (capture.countryCode != null) 'countryCode': capture.countryCode,
        },
      );
    } on FunctionException catch (error) {
      if (_isRateLimitError(error)) {
        throw SmsRateLimitException(
          error.details?.toString() ?? 'SMS rate limit exceeded',
        );
      }
      rethrow;
    }

    final data = response.data;
    if (data is Map && data['success'] == false) {
      final message = data['message']?.toString() ?? 'Failed to ingest SMS.';
      if (message.contains('Rate limit')) {
        throw SmsRateLimitException(message);
      }
      throw StateError(message);
    }
    if (data is! Map) {
      throw const FormatException('Unexpected sms-ingest response payload.');
    }

    final rawSmsId = data['rawSmsId']?.toString();
    if (rawSmsId == null || rawSmsId.isEmpty) return null;

    return SmsIngestionResult(
      rawSmsId: rawSmsId,
      inserted: data['inserted'] == true,
      parseQueued: data['parseQueued'] == true,
    );
  }

  // ─── Helpers ────────────────────────────────────────────────

  static DateTime _timestampToUtc(int? timestampMillis) {
    if (timestampMillis == null || timestampMillis <= 0) {
      return DateTime.now().toUtc();
    }
    return DateTime.fromMillisecondsSinceEpoch(timestampMillis, isUtc: true);
  }

  static String _normalizeSender(String? value) {
    final sender = value?.toLowerCase().trim() ?? '';
    return sender.replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  static String _normalizeWhitespace(String value) {
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static bool _isRateLimitError(FunctionException error) {
    final status = error.status;
    if (status == 429) return true;
    final details = error.details?.toString().toLowerCase() ?? '';
    return details.contains('rate limit');
  }
}
