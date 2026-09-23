import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'admin_providers.dart';
import 'repositories/admin_repository.dart';

enum AdminSmsMonitorPhase { ready, degraded }

enum AdminSmsMonitorFailureKind {
  offline,
  permissionDenied,
  conflict,
  securityTimeout,
  unknown,
}

class AdminSmsMonitorFailure implements Exception {
  const AdminSmsMonitorFailure(this.kind);

  final AdminSmsMonitorFailureKind kind;

  static AdminSmsMonitorFailure fromError(Object error) {
    if (error is AdminSmsMonitorFailure) return error;
    if (error is TimeoutException) {
      return const AdminSmsMonitorFailure(
        AdminSmsMonitorFailureKind.securityTimeout,
      );
    }
    final value = error.toString().toLowerCase();
    if (value.contains('socketexception') ||
        value.contains('failed host lookup') ||
        value.contains('network is unreachable') ||
        value.contains('connection refused') ||
        value.contains('offline')) {
      return const AdminSmsMonitorFailure(AdminSmsMonitorFailureKind.offline);
    }
    if (value.contains('permission') ||
        value.contains('forbidden') ||
        value.contains('unauthorized') ||
        value.contains('admin privileges required') ||
        value.contains('row-level security') ||
        value.contains('rls') ||
        value.contains('42501')) {
      return const AdminSmsMonitorFailure(
        AdminSmsMonitorFailureKind.permissionDenied,
      );
    }
    if (value.contains('conflict') ||
        value.contains('changed') ||
        value.contains('409')) {
      return const AdminSmsMonitorFailure(AdminSmsMonitorFailureKind.conflict);
    }
    return const AdminSmsMonitorFailure(AdminSmsMonitorFailureKind.unknown);
  }

  @override
  String toString() => 'AdminSmsMonitorFailure(${kind.name})';
}

class AdminSmsHealthMetric {
  const AdminSmsHealthMetric({
    required this.key,
    required this.label,
    required this.status,
    required this.summary,
    required this.primaryLabel,
    required this.primaryValue,
    required this.secondaryLabel,
    required this.secondaryValue,
    required this.tertiaryLabel,
    required this.tertiaryValue,
    this.lastSignalAt,
  });

  factory AdminSmsHealthMetric.fromRaw(Map<String, dynamic> raw) {
    return AdminSmsHealthMetric(
      key: _requiredEnum(
        raw['metric_key'],
        field: 'metric.key',
        allowed: const <String>{
          'device_sync',
          'parsing',
          'reconciliation',
          'sender_inventory',
          'migration_safety',
          'retention',
          'sender_drift',
          'retry_queue',
        },
      ),
      label: _requiredString(raw['label'], field: 'metric.label', max: 80),
      status: _requiredEnum(
        raw['health_status'],
        field: 'metric.status',
        allowed: const <String>{'healthy', 'degraded', 'failing', 'unknown'},
      ),
      summary: _requiredString(
        raw['summary'],
        field: 'metric.summary',
        max: 500,
      ),
      primaryLabel: _requiredString(
        raw['primary_label'],
        field: 'metric.primary_label',
        max: 80,
      ),
      primaryValue: _boundedInt(
        raw['primary_value'],
        field: 'metric.primary_value',
      ),
      secondaryLabel: _requiredString(
        raw['secondary_label'],
        field: 'metric.secondary_label',
        max: 80,
      ),
      secondaryValue: _boundedInt(
        raw['secondary_value'],
        field: 'metric.secondary_value',
      ),
      tertiaryLabel: _requiredString(
        raw['tertiary_label'],
        field: 'metric.tertiary_label',
        max: 80,
      ),
      tertiaryValue: _boundedInt(
        raw['tertiary_value'],
        field: 'metric.tertiary_value',
      ),
      lastSignalAt: _optionalDate(
        raw['last_signal_at'],
        field: 'metric.last_signal_at',
      ),
    );
  }

  final String key;
  final String label;
  final String status;
  final String summary;
  final String primaryLabel;
  final int primaryValue;
  final String secondaryLabel;
  final int secondaryValue;
  final String tertiaryLabel;
  final int tertiaryValue;
  final DateTime? lastSignalAt;

  bool get needsAttention => status == 'degraded' || status == 'failing';
}

class AdminSmsSyncRun {
  const AdminSmsSyncRun({
    required this.id,
    required this.status,
    required this.trigger,
    required this.scannedMessages,
    required this.uploadedMessages,
    required this.duplicateMessages,
    required this.startedAt,
    this.completedAt,
  });

  factory AdminSmsSyncRun.fromRaw(Map<String, dynamic> raw) {
    final startedAt = _requiredDate(
      raw['scan_started_at'],
      field: 'run.scan_started_at',
    );
    final completedAt = _optionalDate(
      raw['scan_completed_at'],
      field: 'run.scan_completed_at',
    );
    if (completedAt != null && completedAt.isBefore(startedAt)) {
      throw const FormatException('Invalid synchronization time range.');
    }
    return AdminSmsSyncRun(
      id: _requiredUuid(raw['id'], field: 'run.id'),
      status: _requiredEnum(
        raw['status'],
        field: 'run.status',
        allowed: const <String>{
          'running',
          'succeeded',
          'failed',
          'rate_limited',
        },
      ),
      trigger: _requiredEnum(
        raw['trigger'],
        field: 'run.trigger',
        allowed: const <String>{'initial_permission_grant', 'manual'},
      ),
      scannedMessages: _boundedInt(
        raw['scanned_messages'],
        field: 'run.scanned_messages',
      ),
      uploadedMessages: _boundedInt(
        raw['uploaded_messages'],
        field: 'run.uploaded_messages',
      ),
      duplicateMessages: _boundedInt(
        raw['duplicate_messages'],
        field: 'run.duplicate_messages',
      ),
      startedAt: startedAt,
      completedAt: completedAt,
    );
  }

  final String id;
  final String status;
  final String trigger;
  final int scannedMessages;
  final int uploadedMessages;
  final int duplicateMessages;
  final DateTime startedAt;
  final DateTime? completedAt;
}

class AdminSmsMonitorSnapshot {
  const AdminSmsMonitorSnapshot({
    required this.metrics,
    required this.runs,
    this.phase = AdminSmsMonitorPhase.ready,
    this.failure,
  });

  const AdminSmsMonitorSnapshot.empty()
    : metrics = const <AdminSmsHealthMetric>[],
      runs = const <AdminSmsSyncRun>[],
      phase = AdminSmsMonitorPhase.ready,
      failure = null;

  factory AdminSmsMonitorSnapshot.fromRaw(Object? raw) {
    final map = _strictMap(raw, 'SMS monitor workspace');
    final metricRows = _strictList(map['metrics'], 'SMS health metrics');
    final runRows = _strictList(map['runs'], 'SMS synchronization runs');
    if (metricRows.length > 8 || runRows.length > 50) {
      throw const FormatException('SMS monitor workspace exceeds safe limits.');
    }
    final metrics = metricRows
        .map(
          (row) => AdminSmsHealthMetric.fromRaw(
            _strictMap(row, 'SMS health metric'),
          ),
        )
        .toList(growable: false);
    final runs = runRows
        .map(
          (row) => AdminSmsSyncRun.fromRaw(
            _strictMap(row, 'SMS synchronization run'),
          ),
        )
        .toList(growable: false);
    _requireUnique(metrics.map((metric) => metric.key), 'SMS health metric');
    _requireUnique(runs.map((run) => run.id), 'SMS synchronization run');
    return AdminSmsMonitorSnapshot(
      metrics: List<AdminSmsHealthMetric>.unmodifiable(metrics),
      runs: List<AdminSmsSyncRun>.unmodifiable(runs),
    );
  }

  final List<AdminSmsHealthMetric> metrics;
  final List<AdminSmsSyncRun> runs;
  final AdminSmsMonitorPhase phase;
  final AdminSmsMonitorFailure? failure;

  bool get controlsEnabled =>
      phase == AdminSmsMonitorPhase.ready && failure == null;

  AdminSmsMonitorSnapshot copyWith({
    List<AdminSmsHealthMetric>? metrics,
    List<AdminSmsSyncRun>? runs,
    AdminSmsMonitorPhase? phase,
    AdminSmsMonitorFailure? failure,
    bool clearFailure = false,
  }) {
    return AdminSmsMonitorSnapshot(
      metrics: metrics ?? this.metrics,
      runs: runs ?? this.runs,
      phase: phase ?? this.phase,
      failure: clearFailure ? null : failure ?? this.failure,
    );
  }
}

abstract interface class AdminSmsMonitorGateway {
  Future<AdminSmsMonitorSnapshot> load();
}

class SupabaseAdminSmsMonitorGateway implements AdminSmsMonitorGateway {
  const SupabaseAdminSmsMonitorGateway(this._repository);

  final AdminRepository _repository;

  @override
  Future<AdminSmsMonitorSnapshot> load() async {
    if (!await _repository.isCurrentUserAppMetadataPlatformAdmin()) {
      throw const AdminSmsMonitorFailure(
        AdminSmsMonitorFailureKind.permissionDenied,
      );
    }
    return AdminSmsMonitorSnapshot.fromRaw(
      await _repository.getAdminSmsMonitorWorkspace(),
    );
  }
}

final adminSmsMonitorGatewayProvider = Provider<AdminSmsMonitorGateway>((ref) {
  return SupabaseAdminSmsMonitorGateway(ref.watch(adminRepositoryProvider));
});
final adminSmsMonitorLoadTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 12),
);
final adminSmsMonitorEnabledProvider = Provider<bool>((ref) => true);

class AdminSmsMonitorNotifier extends AsyncNotifier<AdminSmsMonitorSnapshot> {
  var _busy = false;

  @override
  Future<AdminSmsMonitorSnapshot> build() => _load();

  Future<void> refresh() async {
    if (_busy) return;
    _busy = true;
    final previous = state.valueOrNull;
    state = const AsyncLoading<AdminSmsMonitorSnapshot>().copyWithPrevious(
      state,
    );
    try {
      state = AsyncData(await _load());
    } catch (error, stackTrace) {
      _applyFailure(
        AdminSmsMonitorFailure.fromError(error),
        stackTrace,
        previous,
      );
    } finally {
      _busy = false;
    }
  }

  Future<AdminSmsMonitorSnapshot> _load() async {
    _requireOnline();
    try {
      return await ref
          .read(adminSmsMonitorGatewayProvider)
          .load()
          .timeout(ref.read(adminSmsMonitorLoadTimeoutProvider));
    } catch (error, stackTrace) {
      final failure = AdminSmsMonitorFailure.fromError(error);
      AfriLogger.warn(
        'AdminSmsMonitorNotifier',
        'SMS operations workspace load failed.',
        failure,
        stackTrace,
      );
      throw failure;
    }
  }

  void _applyFailure(
    AdminSmsMonitorFailure failure,
    StackTrace stackTrace,
    AdminSmsMonitorSnapshot? previous,
  ) {
    if (failure.kind == AdminSmsMonitorFailureKind.permissionDenied) {
      state = AsyncData(
        AdminSmsMonitorSnapshot(
          metrics: const <AdminSmsHealthMetric>[],
          runs: const <AdminSmsSyncRun>[],
          phase: AdminSmsMonitorPhase.degraded,
          failure: failure,
        ),
      );
      return;
    }
    state = previous != null
        ? AsyncData(
            previous.copyWith(
              phase: AdminSmsMonitorPhase.degraded,
              failure: failure,
            ),
          )
        : AsyncError(failure, stackTrace);
  }
}

final adminSmsMonitorProvider =
    AsyncNotifierProvider<AdminSmsMonitorNotifier, AdminSmsMonitorSnapshot>(
      AdminSmsMonitorNotifier.new,
    );

void _requireOnline() {
  if (!ConnectivityService.isOnline) {
    throw const AdminSmsMonitorFailure(AdminSmsMonitorFailureKind.offline);
  }
}

Map<String, dynamic> _strictMap(Object? value, String label) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  throw FormatException('Invalid $label.');
}

List<Object?> _strictList(Object? value, String label) {
  if (value is! List) throw FormatException('Invalid $label.');
  return List<Object?>.from(value);
}

String _requiredString(
  Object? value, {
  required String field,
  required int max,
}) {
  if (value is! String) throw FormatException('Invalid $field.');
  final normalized = value.trim();
  if (normalized.isEmpty || normalized.length > max) {
    throw FormatException('Invalid $field.');
  }
  return normalized;
}

String _requiredEnum(
  Object? value, {
  required String field,
  required Set<String> allowed,
}) {
  final result = _requiredString(value, field: field, max: 40).toLowerCase();
  if (!allowed.contains(result)) throw FormatException('Invalid $field.');
  return result;
}

String _requiredUuid(Object? value, {required String field}) {
  final id = _requiredString(value, field: field, max: 36);
  if (!RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  ).hasMatch(id)) {
    throw FormatException('Invalid $field.');
  }
  return id;
}

int _boundedInt(Object? value, {required String field}) {
  if (value is! int || value < 0 || value > 1000000000) {
    throw FormatException('Invalid $field.');
  }
  return value;
}

DateTime _requiredDate(Object? value, {required String field}) {
  if (value is! String) throw FormatException('Invalid $field.');
  final parsed = DateTime.tryParse(value);
  if (parsed == null) throw FormatException('Invalid $field.');
  return parsed.toUtc();
}

DateTime? _optionalDate(Object? value, {required String field}) {
  if (value == null || value == '') return null;
  return _requiredDate(value, field: field);
}

void _requireUnique(Iterable<String> values, String label) {
  final list = values.toList(growable: false);
  if (list.toSet().length != list.length) {
    throw FormatException('Duplicate $label.');
  }
}
