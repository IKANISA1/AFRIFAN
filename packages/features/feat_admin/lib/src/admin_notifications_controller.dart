import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'admin_providers.dart';
import 'repositories/admin_repository.dart';

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

  factory AdminNotificationDraft.fromRaw(Map<String, dynamic> raw) {
    final audience = _requiredEnum(
      raw['audience'],
      field: 'notification.audience',
      allowed: const <String>{'all_fans', 'by_tier', 'by_group'},
    );
    final deliveryMode = _requiredEnum(
      raw['delivery_mode'],
      field: 'notification.delivery_mode',
      allowed: const <String>{'send_now', 'schedule'},
    );
    final tier = _optionalString(
      raw['tier'],
      field: 'notification.tier',
      max: 80,
    );
    final groupId = _optionalString(
      raw['group_id'],
      field: 'notification.group_id',
      max: 128,
    );
    final groupName = _optionalString(
      raw['group_name'],
      field: 'notification.group_name',
      max: 160,
    );
    final scheduledAt = _optionalDate(
      raw['scheduled_at'],
      field: 'notification.scheduled_at',
    );
    if (audience == 'by_tier' && tier == null) {
      throw const FormatException('Invalid notification tier.');
    }
    if (audience == 'by_group' && (groupId == null || groupName == null)) {
      throw const FormatException('Invalid notification group.');
    }
    if (deliveryMode == 'schedule' && scheduledAt == null) {
      throw const FormatException('Invalid notification schedule.');
    }
    final imageUrl = _optionalWebUrl(
      raw['image_url'],
      field: 'notification.image_url',
    );
    return AdminNotificationDraft(
      Map<String, dynamic>.unmodifiable(<String, dynamic>{
        'audience': audience,
        if (tier != null) 'tier': tier,
        if (groupId != null) 'group_id': groupId,
        if (groupName != null) 'group_name': groupName,
        'title': _requiredString(
          raw['title'],
          field: 'notification.title',
          max: 120,
        ),
        'body': _requiredString(
          raw['body'],
          field: 'notification.body',
          max: 500,
        ),
        if (imageUrl != null) 'image_url': imageUrl,
        'delivery_mode': deliveryMode,
        if (scheduledAt != null)
          'scheduled_at': scheduledAt.toUtc().toIso8601String(),
      }),
    );
  }

  final Map<String, dynamic> payload;
}

class AdminNotificationDelivery {
  const AdminNotificationDelivery({
    required this.status,
    required this.requestedCount,
    required this.sentCount,
    required this.failedCount,
    this.scheduledAt,
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
          'scheduled',
          'sent',
          'partial',
          'failed',
        },
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
}

class AdminNotificationsSnapshot {
  const AdminNotificationsSnapshot({
    required this.groups,
    required this.history,
    this.phase = AdminNotificationsPhase.ready,
    this.failure,
    this.isMutating = false,
    this.mutationOutcomeUnconfirmed = false,
  });

  const AdminNotificationsSnapshot.empty()
    : groups = const <AdminNotificationGroup>[],
      history = const <AdminNotificationRecord>[],
      phase = AdminNotificationsPhase.ready,
      failure = null,
      isMutating = false,
      mutationOutcomeUnconfirmed = false;

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

  bool get actionsEnabled =>
      phase == AdminNotificationsPhase.ready &&
      failure == null &&
      !isMutating &&
      !mutationOutcomeUnconfirmed;

  AdminNotificationsSnapshot copyWith({
    List<AdminNotificationGroup>? groups,
    List<AdminNotificationRecord>? history,
    AdminNotificationsPhase? phase,
    AdminNotificationsFailure? failure,
    bool clearFailure = false,
    bool? isMutating,
    bool? mutationOutcomeUnconfirmed,
  }) {
    return AdminNotificationsSnapshot(
      groups: groups ?? this.groups,
      history: history ?? this.history,
      phase: phase ?? this.phase,
      failure: clearFailure ? null : failure ?? this.failure,
      isMutating: isMutating ?? this.isMutating,
      mutationOutcomeUnconfirmed:
          mutationOutcomeUnconfirmed ?? this.mutationOutcomeUnconfirmed,
    );
  }
}

abstract interface class AdminNotificationsGateway {
  Future<AdminNotificationsSnapshot> load();

  Future<AdminNotificationDelivery> send(AdminNotificationDraft draft);
}

class SupabaseAdminNotificationsGateway implements AdminNotificationsGateway {
  const SupabaseAdminNotificationsGateway(this._repository);

  final AdminRepository _repository;

  Future<void> _requireAdmin() async {
    if (!await _repository.isCurrentUserAppMetadataAdmin()) {
      throw const AdminNotificationsFailure(
        AdminNotificationsFailureKind.permissionDenied,
      );
    }
  }

  @override
  Future<AdminNotificationsSnapshot> load() async {
    await _requireAdmin();
    return AdminNotificationsSnapshot.fromRaw(
      await _repository.getAdminNotificationContext(),
    );
  }

  @override
  Future<AdminNotificationDelivery> send(AdminNotificationDraft draft) async {
    await _requireAdmin();
    final result = await _repository.submitAdminNotification(draft.payload);
    return AdminNotificationDelivery.fromRaw(result['delivery']);
  }
}

final adminNotificationsGatewayProvider = Provider<AdminNotificationsGateway>((
  ref,
) {
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

  @override
  Future<AdminNotificationsSnapshot> build() => _load();

  Future<void> refresh() async {
    if (_busy) return;
    _busy = true;
    final previous = state.valueOrNull;
    state = const AsyncLoading<AdminNotificationsSnapshot>().copyWithPrevious(
      state,
    );
    try {
      state = AsyncData(await _load());
    } catch (error, stackTrace) {
      _applyFailure(
        AdminNotificationsFailure.fromError(error),
        stackTrace,
        previous,
      );
    } finally {
      _busy = false;
    }
  }

  Future<AdminNotificationDelivery?> send(Map<String, dynamic> raw) async {
    if (_busy) return null;
    final previous = state.valueOrNull;
    if (previous == null || !previous.actionsEnabled) return null;
    final draft = AdminNotificationDraft.fromRaw(raw);
    final groupId = draft.payload['group_id'];
    if (groupId != null &&
        !previous.groups.any((group) => group.id == groupId)) {
      throw const FormatException('Invalid notification group.');
    }
    _busy = true;
    state = AsyncData(previous.copyWith(isMutating: true, clearFailure: true));
    try {
      _requireOnline();
      final delivery = await ref
          .read(adminNotificationsGatewayProvider)
          .send(draft)
          .timeout(ref.read(adminNotificationsMutationTimeoutProvider));
      state = AsyncData(await _load());
      return delivery;
    } catch (error, stackTrace) {
      final failure = AdminNotificationsFailure.fromError(error);
      _applyFailure(
        failure,
        stackTrace,
        previous,
        mutationOutcomeUnconfirmed:
            failure.kind == AdminNotificationsFailureKind.securityTimeout ||
            failure.kind == AdminNotificationsFailureKind.conflict,
      );
      return null;
    } finally {
      _busy = false;
    }
  }

  Future<AdminNotificationsSnapshot> _load() async {
    _requireOnline();
    try {
      return await ref
          .read(adminNotificationsGatewayProvider)
          .load()
          .timeout(ref.read(adminNotificationsLoadTimeoutProvider));
    } catch (error, stackTrace) {
      final failure = AdminNotificationsFailure.fromError(error);
      AfriLogger.warn(
        'AdminNotificationsNotifier',
        'Notification workspace load failed.',
        failure,
        stackTrace,
      );
      throw failure;
    }
  }

  void _applyFailure(
    AdminNotificationsFailure failure,
    StackTrace stackTrace,
    AdminNotificationsSnapshot? previous, {
    bool mutationOutcomeUnconfirmed = false,
  }) {
    if (failure.kind == AdminNotificationsFailureKind.permissionDenied) {
      state = AsyncData(
        AdminNotificationsSnapshot(
          groups: const <AdminNotificationGroup>[],
          history: const <AdminNotificationRecord>[],
          phase: AdminNotificationsPhase.degraded,
          failure: failure,
        ),
      );
      return;
    }
    state = previous != null
        ? AsyncData(
            previous.copyWith(
              phase: AdminNotificationsPhase.degraded,
              failure: failure,
              isMutating: false,
              mutationOutcomeUnconfirmed: mutationOutcomeUnconfirmed,
            ),
          )
        : AsyncError(failure, stackTrace);
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

String? _optionalWebUrl(Object? value, {required String field}) {
  final text = _optionalString(value, field: field, max: 2048);
  if (text == null) return null;
  final uri = Uri.tryParse(text);
  if (uri == null ||
      !uri.hasAuthority ||
      (uri.scheme != 'https' && uri.scheme != 'http')) {
    throw FormatException('Invalid $field.');
  }
  return uri.toString();
}
