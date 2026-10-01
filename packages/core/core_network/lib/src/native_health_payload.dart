/// Native operational diagnostics share the backend's finite catalogs in
/// `_shared/diagnostics.ts` and `_shared/observability.ts`. All entry points,
/// including legacy queue replay, must normalize before storing or sending.
class NativeHealthPayload {
  NativeHealthPayload._();

  static const services = <String>{
    'edge_function',
    'sms_ingest',
    'momo_parsing',
    'client',
  };
  static const functions = <String>{
    'admin-send-notification',
    'admin-settle-fixture',
    'admin-upload-image',
    'delete-account',
    'dispatch-scheduled-notifications',
    'football-sync',
    'generate-admin-image',
    'generate-product-image',
    'get-platform-config',
    'google-wallet-ticket-pass',
    'livescore-openai-sync',
    'parse-momo-sms',
    'record-operational-health',
    'send-notification',
    'send-sms',
    'settle-prediction-notifications',
    'sms-ingest',
    'sync-google-wallet-ticket-state',
  };
  static const issues = <String>{
    'parse_queue_failed',
    'payment_requires_review',
    'momo_parse_failed',
    'function_invocation_failed',
    'sms_ingest_failed',
    'operational_event',
  };
  static const metadataEnums = <String, Set<String>>{
    'parser_provider': {'gemini', 'openai'},
    'parse_status': {'pending', 'parsed', 'needs_review', 'failed'},
    'match_status': {'matched', 'unmatched', 'needs_review', 'manual_review'},
    'ingestion_source': {
      'android_sms_listener',
      'android_sms_listener_foreground',
      'android_sms_listener_background',
      'android_sms_initial_sync',
      'android_sms_manual_sync',
    },
    'source_provider': {'livescore', 'api_football'},
    'mode': {'preview', 'sync'},
    'error_name': {
      'Error',
      'TypeError',
      'RangeError',
      'SyntaxError',
      'ReferenceError',
      'URIError',
      'EvalError',
      'AggregateError',
      'AbortError',
      'TimeoutError',
      'HttpError',
      'ApiFootballError',
      'RateLimitExceededError',
      'UnknownError',
    },
  };
  static const metadataNumbers = <String>{
    'count',
    'attempt',
    'duration_ms',
    'retry_after_seconds',
    'error_count',
    'source_note_count',
    'access_issue_count',
    'allowed_competitions_loaded',
    'openai_requests_used',
    'raw_rows_seen',
    'rows_skipped',
    'non_livescore_rows_rejected',
    'competitions_filtered',
    'competitions_upserted',
    'seasons_upserted',
    'teams_upserted',
    'fixtures_upserted',
    'pools_settled',
  };
  static final _timestamp = RegExp(
    r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,3})?Z$',
  );

  // Only known keys are read. Unknown objects are never traversed, converted
  // to strings, or passed to jsonEncode/toJson. Unusual maps fail closed.
  static Object? _read(Map value, String key) {
    try {
      return value[key];
    } catch (_) {
      return null;
    }
  }

  static String? _catalog(
    Object? value,
    Set<String> values,
    String? fallback,
  ) => value is String && values.contains(value) ? value : fallback;

  static Map<String, dynamic> normalize(Map payload) {
    final status = _catalog(_read(payload, 'status'), {
      'ok',
      'warn',
      'error',
    }, 'ok')!;
    final defaultSeverity = switch (status) {
      'error' => 'critical',
      'warn' => 'warning',
      _ => 'info',
    };
    final issue = _read(payload, 'issueCode');
    final rawTime = _read(payload, 'occurredAt');
    final parsedTime = rawTime is String && _timestamp.hasMatch(rawTime)
        ? DateTime.tryParse(rawTime)
        : null;
    final time = parsedTime ?? DateTime.now().toUtc();
    final occurredAt = DateTime.fromMillisecondsSinceEpoch(
      time.millisecondsSinceEpoch,
      isUtc: true,
    ).toIso8601String();
    return <String, dynamic>{
      'service': _catalog(_read(payload, 'service'), services, 'client'),
      'component': _catalog(_read(payload, 'component'), functions, 'general'),
      'status': status,
      'severity': _catalog(_read(payload, 'severity'), {
        'info',
        'warning',
        'critical',
      }, defaultSeverity),
      'issueCode': issue == null
          ? null
          : _catalog(issue, issues, 'operational_event'),
      'message': switch (status) {
        'error' => 'Operational health failure.',
        'warn' => 'Operational health requires review.',
        _ => 'Operational health event.',
      },
      'functionName': _catalog(_read(payload, 'functionName'), functions, null),
      'userId': null,
      'subjectType': null,
      'subjectId': null,
      'metadata': diagnosticMetadata(_read(payload, 'metadata')),
      'occurredAt': occurredAt,
    };
  }

  static Map<String, Object> diagnosticMetadata(Object? value) {
    final result = <String, Object>{};
    if (value is! Map) return result;
    for (final entry in metadataEnums.entries) {
      final item = _read(value, entry.key);
      if (item is String && entry.value.contains(item)) {
        result[entry.key] = item;
      }
    }
    for (final key in metadataNumbers) {
      final item = _read(value, key);
      if (item is num &&
          item.isFinite &&
          item == item.roundToDouble() &&
          item >= 0 &&
          item <= 1000000000) {
        result[key] = item.toInt();
      }
    }
    final status = _read(value, 'http_status');
    if (status is num &&
        status.isFinite &&
        status == status.roundToDouble() &&
        status >= 100 &&
        status <= 599) {
      result['http_status'] = status.toInt();
    }
    for (final key in ['retryable', 'dry_run']) {
      final item = _read(value, key);
      if (item is bool) result[key] = item;
    }
    return result;
  }
}
