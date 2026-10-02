import 'dart:async';

import 'package:core_auth/core_auth.dart';
import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'admin_notification_command.dart';
import 'admin_providers.dart';
import 'repositories/admin_repository.dart';

export 'admin_notification_command.dart';

enum AdminNotificationsPhase { ready, degraded }

enum AdminNotificationsFailureKind {
  offline,
  permissionDenied,
  conflict,
  securityTimeout,
  unknown,
}

class AdminNotificationsFailure implements Exception {
  const AdminNotificationsFailure(this.kind);

  final AdminNotificationsFailureKind kind;

  static AdminNotificationsFailure fromError(Object error) {
    if (error is AdminNotificationsFailure) return error;
    if (error is TimeoutException) {
      return const AdminNotificationsFailure(
        AdminNotificationsFailureKind.securityTimeout,
      );
    }
    final value = error.toString().toLowerCase();
    if (value.contains('socketexception') ||
        value.contains('failed host lookup') ||
        value.contains('network is unreachable') ||
        value.contains('connection refused') ||
        value.contains('offline')) {
      return const AdminNotificationsFailure(
        AdminNotificationsFailureKind.offline,
      );
    }
    if (value.contains('permission') ||
        value.contains('forbidden') ||
        value.contains('unauthorized') ||
        value.contains('admin access required') ||
        value.contains('row-level security') ||
        value.contains('rls') ||
        value.contains('42501')) {
      return const AdminNotificationsFailure(
        AdminNotificationsFailureKind.permissionDenied,
      );
    }
    if (value.contains('conflict') ||
        value.contains('changed') ||
        value.contains('stale') ||
        value.contains('duplicate') ||
        value.contains('23505') ||
        value.contains('409')) {
      return const AdminNotificationsFailure(
        AdminNotificationsFailureKind.conflict,
      );
    }
    return const AdminNotificationsFailure(
      AdminNotificationsFailureKind.unknown,
    );
  }

  @override
  String toString() => 'AdminNotificationsFailure(${kind.name})';
}

class AdminNotificationGroup {
  const AdminNotificationGroup({required this.id, required this.name});

  factory AdminNotificationGroup.fromJson(Map<String, dynamic> json) {
    return AdminNotificationGroup(
      id: _requiredString(json['id'], field: 'group.id', max: 128),
      name: _requiredString(json['name'], field: 'group.name', max: 160),
    );
  }

  final String id;
  final String name;
}

class AdminNotificationRecord {
  const AdminNotificationRecord({
    required this.id,
    required this.title,
    required this.body,
    required this.audienceType,
    required this.deliveryMode,
    required this.status,
    required this.requestedCount,
    required this.sentCount,
    required this.failedCount,
    required this.createdAt,
    this.audienceTier,
    this.audienceGroupName,
    this.scheduledAt,
    this.sentAt,
  });

  factory AdminNotificationRecord.fromJson(Map<String, dynamic> json) {
    final audienceType = _requiredEnum(
      json['audience_type'],
      field: 'notification.audience_type',
      allowed: const <String>{'all_fans', 'by_tier', 'by_group'},
    );
    final audienceTier = _optionalString(
      json['audience_tier'],
      field: 'notification.audience_tier',
      max: 80,
    );
    final audienceGroupName = _optionalString(
      json['audience_group_name'],
      field: 'notification.audience_group_name',
      max: 160,
    );
    if (audienceType == 'by_tier' && audienceTier == null) {
      throw const FormatException('Invalid notification audience.');
    }
    if (audienceType == 'by_group' && audienceGroupName == null) {
      throw const FormatException('Invalid notification audience.');
    }
    return AdminNotificationRecord(
      id: _requiredString(json['id'], field: 'notification.id', max: 128),
      title: _requiredString(
        json['title'],
        field: 'notification.title',
        max: 120,
      ),
      body: _requiredString(json['body'], field: 'notification.body', max: 500),
      audienceType: audienceType,
      audienceTier: audienceTier,
      audienceGroupName: audienceGroupName,
      deliveryMode: _requiredEnum(
        json['delivery_mode'],
        field: 'notification.delivery_mode',
        allowed: const <String>{'send_now', 'schedule'},
      ),
      status: _requiredEnum(
        json['status'],
        field: 'notification.status',
        allowed: const <String>{
          'draft',
          'pending',
          'scheduled',
          'sent',
          'delivered',
          'failed',
          'cancelled',
          'processing',
          'partial',
          'unknown',
        },
      ),
      scheduledAt: _optionalDate(
        json['scheduled_at'],
        field: 'notification.scheduled_at',
      ),
      sentAt: _optionalDate(json['sent_at'], field: 'notification.sent_at'),
      requestedCount: _boundedInt(
        json['requested_recipient_count'],
        field: 'notification.requested_recipient_count',
        maximum: 10000000,
      ),
      sentCount: _boundedInt(
        json['sent_count'],
        field: 'notification.sent_count',
        maximum: 10000000,
      ),
      failedCount: _boundedInt(
        json['failed_count'],
        field: 'notification.failed_count',
        maximum: 10000000,
      ),
      createdAt: _requiredDateTime(
        json['created_at'],
        field: 'notification.created_at',
      ),
    );
  }

  final String id;
  final String title;
  final String body;
  final String audienceType;
  final String? audienceTier;
  final String? audienceGroupName;
  final String deliveryMode;
  final String status;
  final DateTime? scheduledAt;
  final DateTime? sentAt;
  final int requestedCount;
  final int sentCount;
  final int failedCount;
  final DateTime createdAt;
}

class AdminNotificationDraft {
  const AdminNotificationDraft(this.payload);

  factory AdminNotificationDraft.fromRaw(Map<String, dynamic> raw) =>
      AdminNotificationDraft(normalizeNotificationArguments(raw));

  final Map<String, dynamic> payload;
}

class AdminNotificationDelivery {
  const AdminNotificationDelivery({
    required this.status,
    required this.requestedCount,
    required this.sentCount,
    required this.failedCount,
    this.scheduledAt,
    this.unknownCount = 0,
    this.pendingCount = 0,
  });

  factory AdminNotificationDelivery.fromRaw(Object? raw) {
    if (raw is! Map) {
      throw const FormatException('Invalid notification delivery.');
    }
    final map = Map<String, dynamic>.from(raw);
    return AdminNotificationDelivery(
      status: _requiredEnum(
        map['status'],
        field: 'delivery.status',
        allowed: const <String>{
          'queued',
          'processing',
          'unknown',
          'scheduled',
          'sent',
          'partial',
          'failed',
        },
      ),
      unknownCount: _boundedInt(
        map['unknown_count'] ?? 0,
        field: 'delivery.unknown_count',
        maximum: 500,
      ),
      pendingCount: _boundedInt(
        map['pending_count'] ?? 0,
        field: 'delivery.pending_count',
        maximum: 500,
      ),
      requestedCount: _boundedInt(
        map['requested_recipient_count'],
        field: 'delivery.requested_recipient_count',
        maximum: 10000000,
      ),
      sentCount: _boundedInt(
        map['sent_count'],
        field: 'delivery.sent_count',
        maximum: 10000000,
      ),
      failedCount: _boundedInt(
        map['failed_count'],
        field: 'delivery.failed_count',
        maximum: 10000000,
      ),
      scheduledAt: _optionalDate(
        map['scheduled_at'],
        field: 'delivery.scheduled_at',
      ),
    );
  }

  final String status;
  final int requestedCount;
  final int sentCount;
  final int failedCount;
  final DateTime? scheduledAt;
  final int unknownCount, pendingCount;
}

class AdminNotificationsSnapshot {
  const AdminNotificationsSnapshot({
    required this.groups,
    required this.history,
    this.phase = AdminNotificationsPhase.ready,
    this.failure,
    this.isMutating = false,
    this.mutationOutcomeUnconfirmed = false,
    this.pendingAttempt,
    this.commandReceipt,
  });

  const AdminNotificationsSnapshot.empty()
    : groups = const <AdminNotificationGroup>[],
      history = const <AdminNotificationRecord>[],
      phase = AdminNotificationsPhase.ready,
      failure = null,
      isMutating = false,
      mutationOutcomeUnconfirmed = false,
      pendingAttempt = null,
      commandReceipt = null;

  factory AdminNotificationsSnapshot.fromRaw(Object? raw) {
    if (raw is! Map) {
      throw const FormatException('Invalid notification context.');
    }
    final map = Map<String, dynamic>.from(raw);
    final groups = _strictRows(
      map['groups'],
      maximum: 50,
      label: 'notification groups',
    ).map(AdminNotificationGroup.fromJson).toList(growable: false);
    final history = _strictRows(
      map['history'],
      maximum: 100,
      label: 'notification history',
    ).map(AdminNotificationRecord.fromJson).toList(growable: false);
    if (groups.map((group) => group.id).toSet().length != groups.length ||
        history.map((item) => item.id).toSet().length != history.length) {
      throw const FormatException('Duplicate notification context.');
    }
    return AdminNotificationsSnapshot(
      groups: List<AdminNotificationGroup>.unmodifiable(groups),
      history: List<AdminNotificationRecord>.unmodifiable(history),
    );
  }

  final List<AdminNotificationGroup> groups;
  final List<AdminNotificationRecord> history;
  final AdminNotificationsPhase phase;
  final AdminNotificationsFailure? failure;
  final bool isMutating;
  final bool mutationOutcomeUnconfirmed;
  final AdminNotificationAttempt? pendingAttempt;
  final AdminNotificationCommandReceipt? commandReceipt;

  bool get actionsEnabled =>
      phase == AdminNotificationsPhase.ready &&
      failure == null &&
      !isMutating &&
      !mutationOutcomeUnconfirmed &&
      pendingAttempt == null;

  AdminNotificationsSnapshot copyWith({
    List<AdminNotificationGroup>? groups,
    List<AdminNotificationRecord>? history,
    AdminNotificationsPhase? phase,
    AdminNotificationsFailure? failure,
    bool clearFailure = false,
    bool? isMutating,
    bool? mutationOutcomeUnconfirmed,
    AdminNotificationAttempt? pendingAttempt,
    AdminNotificationCommandReceipt? commandReceipt,
    bool clearPending = false,
  }) {
    return AdminNotificationsSnapshot(
      groups: groups ?? this.groups,
      history: history ?? this.history,
      phase: phase ?? this.phase,
      failure: clearFailure ? null : failure ?? this.failure,
      isMutating: isMutating ?? this.isMutating,
      mutationOutcomeUnconfirmed:
          mutationOutcomeUnconfirmed ?? this.mutationOutcomeUnconfirmed,
      pendingAttempt: clearPending
          ? null
          : pendingAttempt ?? this.pendingAttempt,
      commandReceipt: commandReceipt ?? this.commandReceipt,
    );
  }
}

abstract interface class AdminNotificationsGateway {
  AdminNotificationOwner captureOwner();
  Future<AdminNotificationsSnapshot> load();
  Future<Map<String, dynamic>> command(
    AdminNotificationAttempt attempt,
    bool submit,
  );
}

class SupabaseAdminNotificationsGateway implements AdminNotificationsGateway {
  const SupabaseAdminNotificationsGateway(this._repository);
  final AdminRepository _repository;
  @override
  AdminNotificationOwner captureOwner() =>
      _repository.captureNotificationOwner();
  Future<void> _requireAdmin() async {
    if (!await _repository.isCurrentUserNotificationAdmin()) {
      throw const AdminNotificationsFailure(
        AdminNotificationsFailureKind.permissionDenied,
      );
    }
  }

  @override
  Future<AdminNotificationsSnapshot> load() async {
    final owner = captureOwner();
    try {
      await _requireAdmin();
      owner.requireCurrent();
      final raw = await _repository.getAdminNotificationContext();
      owner.requireCurrent();
      return AdminNotificationsSnapshot.fromRaw(raw);
    } finally {
      await owner.dispose();
    }
  }

  @override
  Future<Map<String, dynamic>> command(
    AdminNotificationAttempt attempt,
    bool submit,
  ) async {
    await _requireAdmin();
    return _repository.submitAdminNotification(attempt, submit: submit);
  }
}

final adminNotificationJournalProvider = Provider<AdminNotificationJournal>(
  (ref) => HiveAdminNotificationJournal(),
);
final adminNotificationsGatewayProvider = Provider<AdminNotificationsGateway>((
  ref,
) {
  // Recreate the owner on account/login/MFA changes; old operations remain fenced.
  ref.watch(authStateProvider);
  return SupabaseAdminNotificationsGateway(ref.watch(adminRepositoryProvider));
});
final adminNotificationsLoadTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 12),
);
final adminNotificationsMutationTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 12),
);
final adminNotificationsEnabledProvider = Provider<bool>((ref) => true);

class AdminNotificationsNotifier
    extends AsyncNotifier<AdminNotificationsSnapshot> {
  var _busy = false;
  var _epoch = 0;
  var _alive = true;
  AdminNotificationCommandFlow? _flow;
  AdminNotificationOwner? get currentOwner => _flow?.owner;

  @override
  Future<AdminNotificationsSnapshot> build() async {
    final epoch = ++_epoch;
    _alive = true;
    _busy = false;
    final gateway = ref.watch(adminNotificationsGatewayProvider);
    final owner = gateway.captureOwner();
    final flow = AdminNotificationCommandFlow(
      owner: owner,
      journal: ref.read(adminNotificationJournalProvider),
      transport: gateway.command,
      timeout: ref.read(adminNotificationsMutationTimeoutProvider),
    );
    _flow = flow;
    ref.onDispose(() {
      _alive = false;
      unawaited(owner.dispose());
    });
    await flow.restore();
    _current(flow, epoch);
    return _load(flow, epoch);
  }

  bool _owned(AdminNotificationCommandFlow flow, int epoch) =>
      _alive &&
      epoch == _epoch &&
      identical(_flow, flow) &&
      flow.owner.isCurrent();
  void _current(AdminNotificationCommandFlow flow, int epoch) {
    if (!_owned(flow, epoch)) throw const SupabaseSessionChangedException();
  }

  Future<void> refresh() async {
    if (_busy || _flow == null) return;
    final flow = _flow!, epoch = _epoch;
    _busy = true;
    final previous = state.valueOrNull;
    state = const AsyncLoading<AdminNotificationsSnapshot>().copyWithPrevious(
      state,
    );
    try {
      if (flow.attempt != null) await flow.recover();
      _current(flow, epoch);
      state = AsyncData(await _load(flow, epoch));
    } catch (error, stack) {
      if (_owned(flow, epoch)) {
        _applyFailure(
          AdminNotificationsFailure.fromError(error),
          stack,
          previous,
          flow,
        );
      }
    } finally {
      if (_owned(flow, epoch)) _busy = false;
    }
  }

  Future<AdminNotificationDelivery?> send(Map<String, dynamic> raw) async {
    if (_busy || _flow == null) return null;
    final previous = state.valueOrNull;
    if (previous == null || !previous.actionsEnabled) return null;
    final draft = AdminNotificationDraft.fromRaw(raw);
    final groupId = draft.payload['group_id'];
    if (groupId != null &&
        !previous.groups.any((group) => group.id == groupId)) {
      throw const FormatException('Invalid notification group.');
    }
    return _mutate(() => _flow!.submit(draft.payload));
  }

  Future<AdminNotificationDelivery?> resumeOriginal() async {
    if (_busy || _flow?.attempt == null) return null;
    return _mutate(() => _flow!.resumeOriginal());
  }

  Future<AdminNotificationDelivery?> _mutate(
    Future<AdminNotificationCommandReceipt?> Function() work,
  ) async {
    final flow = _flow!, epoch = _epoch;
    final previous = state.valueOrNull;
    _busy = true;
    if (previous != null) {
      state = AsyncData(
        previous.copyWith(isMutating: true, clearFailure: true),
      );
    }
    try {
      _requireOnline();
      _current(flow, epoch);
      final receipt = await work();
      _current(flow, epoch);
      state = AsyncData(await _load(flow, epoch));
      return receipt?.delivery == null
          ? null
          : AdminNotificationDelivery.fromRaw(receipt!.delivery);
    } catch (error, stack) {
      if (_owned(flow, epoch)) {
        _applyFailure(
          AdminNotificationsFailure.fromError(error),
          stack,
          previous,
          flow,
        );
      }
      return null;
    } finally {
      if (_owned(flow, epoch)) _busy = false;
    }
  }

  Future<AdminNotificationsSnapshot> _load(
    AdminNotificationCommandFlow flow,
    int epoch,
  ) async {
    _requireOnline();
    AdminNotificationsSnapshot result;
    try {
      result = await ref
          .read(adminNotificationsGatewayProvider)
          .load()
          .timeout(ref.read(adminNotificationsLoadTimeoutProvider));
    } catch (error) {
      throw AdminNotificationsFailure.fromError(error);
    }
    _current(flow, epoch);
    return result.copyWith(
      pendingAttempt: flow.attempt,
      commandReceipt: flow.receipt,
      clearPending: flow.attempt == null,
      mutationOutcomeUnconfirmed: flow.attempt != null,
    );
  }

  void _applyFailure(
    AdminNotificationsFailure failure,
    StackTrace stack,
    AdminNotificationsSnapshot? previous,
    AdminNotificationCommandFlow flow,
  ) {
    if (failure.kind == AdminNotificationsFailureKind.permissionDenied) {
      // The encrypted original remains for the same subject after reauthentication.
      state = AsyncData(
        AdminNotificationsSnapshot(
          groups: const [],
          history: const [],
          phase: AdminNotificationsPhase.degraded,
          failure: failure,
        ),
      );
      return;
    }
    state = previous == null
        ? AsyncError(failure, stack)
        : AsyncData(
            previous.copyWith(
              phase: AdminNotificationsPhase.degraded,
              failure: failure,
              isMutating: false,
              pendingAttempt: flow.attempt,
              commandReceipt: flow.receipt,
              mutationOutcomeUnconfirmed: flow.attempt != null,
            ),
          );
  }
}

final adminNotificationsProvider =
    AsyncNotifierProvider<
      AdminNotificationsNotifier,
      AdminNotificationsSnapshot
    >(AdminNotificationsNotifier.new);

void _requireOnline() {
  if (!ConnectivityService.isOnline) {
    throw const AdminNotificationsFailure(
      AdminNotificationsFailureKind.offline,
    );
  }
}

List<Map<String, dynamic>> _strictRows(
  Object? value, {
  required int maximum,
  required String label,
}) {
  if (value is! List || value.length > maximum) {
    throw FormatException('Invalid $label.');
  }
  return List<Map<String, dynamic>>.unmodifiable(
    value.map((row) {
      if (row is Map<String, dynamic>) return row;
      if (row is Map) return Map<String, dynamic>.from(row);
      throw FormatException('Invalid $label.');
    }),
  );
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

String? _optionalString(
  Object? value, {
  required String field,
  required int max,
}) {
  if (value == null || value == '') return null;
  return _requiredString(value, field: field, max: max);
}

String _requiredEnum(
  Object? value, {
  required String field,
  required Set<String> allowed,
}) {
  final normalized = _requiredString(
    value,
    field: field,
    max: 32,
  ).toLowerCase();
  if (!allowed.contains(normalized)) throw FormatException('Invalid $field.');
  return normalized;
}

int _boundedInt(Object? value, {required String field, required int maximum}) {
  if (value is! num || value.toInt() != value) {
    throw FormatException('Invalid $field.');
  }
  final parsed = value.toInt();
  if (parsed < 0 || parsed > maximum) throw FormatException('Invalid $field.');
  return parsed;
}

DateTime _requiredDateTime(Object? value, {required String field}) {
  if (value is! String || value.length > 64) {
    throw FormatException('Invalid $field.');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) throw FormatException('Invalid $field.');
  return parsed;
}

DateTime? _optionalDate(Object? value, {required String field}) {
  if (value == null || value == '') return null;
  return _requiredDateTime(value, field: field);
}
