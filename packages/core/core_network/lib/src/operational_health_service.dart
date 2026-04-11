import 'package:core_utils/core_utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Operational event status classification.
enum OperationalHealthStatus { ok, warn, error }

/// Severity level for operational events.
enum OperationalHealthSeverity { info, warning, critical }

/// Records operational health events to Supabase for monitoring.
///
/// Used by BioPay, payment services, and critical infrastructure to track
/// errors, warnings, and service disruptions in production.
class OperationalHealthService {
  OperationalHealthService({required SupabaseClient client}) : _client = client;

  final SupabaseClient _client;

  Future<void> recordEvent({
    required String service,
    required String component,
    required String message,
    OperationalHealthStatus status = OperationalHealthStatus.ok,
    OperationalHealthSeverity? severity,
    String? issueCode,
    String? functionName,
    String? userId,
    String? subjectType,
    String? subjectId,
    Map<String, dynamic> metadata = const <String, dynamic>{},
    DateTime? occurredAt,
  }) async {
    final resolvedUserId = _normalize(userId) ?? _client.auth.currentUser?.id;

    try {
      final response = await _client.functions.invoke(
        'record-operational-health',
        body: <String, dynamic>{
          'service': service,
          'component': component,
          'status': status.name,
          'severity': (severity ?? _defaultSeverity(status)).name,
          'issueCode': _normalize(issueCode),
          'message': message,
          'functionName': _normalize(functionName),
          'userId': resolvedUserId,
          'subjectType': _normalize(subjectType),
          'subjectId': _normalize(subjectId),
          'metadata': metadata,
          'occurredAt': (occurredAt ?? DateTime.now().toUtc())
              .toIso8601String(),
        },
      );
      final data = response.data;
      if (data is Map && data['success'] == false) {
        throw StateError(
          data['message']?.toString() ??
              'Failed to record operational health event.',
        );
      }
    } catch (error, stackTrace) {
      AfriLogger.error(
        'OperationalHealth',
        'Failed to record event.',
        error,
        stackTrace,
      );
    }
  }

  OperationalHealthSeverity _defaultSeverity(OperationalHealthStatus status) {
    return switch (status) {
      OperationalHealthStatus.warn => OperationalHealthSeverity.warning,
      OperationalHealthStatus.error => OperationalHealthSeverity.critical,
      OperationalHealthStatus.ok => OperationalHealthSeverity.info,
    };
  }

  String? _normalize(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}
