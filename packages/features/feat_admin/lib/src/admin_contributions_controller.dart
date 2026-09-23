import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'admin_providers.dart';
import 'repositories/admin_repository.dart';

enum AdminContributionsPhase { ready, degraded }

enum AdminContributionsFailureKind {
  offline,
  permissionDenied,
  conflict,
  securityTimeout,
  unknown,
}

class AdminContributionsFailure implements Exception {
  const AdminContributionsFailure(this.kind);

  final AdminContributionsFailureKind kind;

  static AdminContributionsFailure fromError(Object error) {
    if (error is AdminContributionsFailure) return error;
    if (error is TimeoutException) {
      return const AdminContributionsFailure(
        AdminContributionsFailureKind.securityTimeout,
      );
    }
    final normalized = error.toString().toLowerCase();
    if (normalized.contains('socketexception') ||
        normalized.contains('failed host lookup') ||
        normalized.contains('network is unreachable') ||
        normalized.contains('connection refused') ||
        normalized.contains('offline')) {
      return const AdminContributionsFailure(
        AdminContributionsFailureKind.offline,
      );
    }
    if (normalized.contains('permission') ||
        normalized.contains('forbidden') ||
        normalized.contains('unauthorized') ||
        normalized.contains('admin access required') ||
        normalized.contains('row-level security') ||
        normalized.contains('rls') ||
        normalized.contains('42501')) {
      return const AdminContributionsFailure(
        AdminContributionsFailureKind.permissionDenied,
      );
    }
    if (normalized.contains('conflict') ||
        normalized.contains('changed') ||
        normalized.contains('stale') ||
        normalized.contains('409')) {
      return const AdminContributionsFailure(
        AdminContributionsFailureKind.conflict,
      );
    }
    return const AdminContributionsFailure(
      AdminContributionsFailureKind.unknown,
    );
  }

  @override
  String toString() => 'AdminContributionsFailure(${kind.name})';
}

enum AdminContributionGroupFilter {
  all('ALL', null),
  projects('TEAM PROJECTS', 'project'),
  community('COMMUNITY', 'community');

  const AdminContributionGroupFilter(this.label, this.value);

  final String label;
  final String? value;
}

enum AdminContributionSort {
  recent('RECENT'),
  total('TOTAL');

  const AdminContributionSort(this.label);

  final String label;
}

class AdminContributionGroup {
  const AdminContributionGroup({
    required this.id,
    required this.name,
    required this.type,
    required this.currentTotal,
    required this.targetAmount,
    required this.memberCount,
    required this.isClosed,
    required this.createdAt,
  });

  factory AdminContributionGroup.fromJson(Map<String, dynamic> json) {
    return AdminContributionGroup(
      id: _requiredString(json['id'], field: 'group.id', max: 80),
      name: _requiredString(json['name'], field: 'group.name', max: 120),
      type: _requiredEnum(
        json['group_type'],
        field: 'group.type',
        allowed: const <String>{'project', 'community'},
      ),
      currentTotal: _boundedMoney(
        json['current_total'],
        field: 'group.current_total',
      ),
      targetAmount: _boundedMoney(
        json['target_amount'],
        field: 'group.target_amount',
        nullable: true,
      ),
      memberCount: _boundedCount(
        json['member_count'],
        field: 'group.member_count',
      ),
      isClosed: _requiredBool(json['is_closed'], field: 'group.is_closed'),
      createdAt: _requiredDate(json['created_at'], field: 'group.created_at'),
    );
  }

  final String id;
  final String name;
  final String type;
  final int currentTotal;
  final int targetAmount;
  final int memberCount;
  final bool isClosed;
  final DateTime createdAt;
}

class AdminContributionRecord {
  const AdminContributionRecord({
    required this.id,
    required this.groupId,
    required this.amount,
    required this.status,
    required this.createdAt,
  });

  factory AdminContributionRecord.fromJson(Map<String, dynamic> json) {
    return AdminContributionRecord(
      id: _requiredString(json['id'], field: 'contribution.id', max: 80),
      groupId: _requiredString(
        json['group_id'],
        field: 'contribution.group_id',
        max: 80,
      ),
      amount: _boundedMoney(json['amount'], field: 'contribution.amount'),
      status: _requiredEnum(
        json['status'],
        field: 'contribution.status',
        allowed: const <String>{'pending', 'confirmed', 'failed'},
      ),
      createdAt: _requiredDate(
        json['created_at'],
        field: 'contribution.created_at',
      ),
    );
  }

  final String id;
  final String groupId;
  final int amount;
  final String status;
  final DateTime createdAt;
}

class AdminContributionsSnapshot {
  const AdminContributionsSnapshot({
    required this.groups,
    required this.contributions,
    this.filter = AdminContributionGroupFilter.all,
    this.sort = AdminContributionSort.recent,
    this.phase = AdminContributionsPhase.ready,
    this.failure,
  });

  const AdminContributionsSnapshot.empty()
    : groups = const <AdminContributionGroup>[],
      contributions = const <AdminContributionRecord>[],
      filter = AdminContributionGroupFilter.all,
      sort = AdminContributionSort.recent,
      phase = AdminContributionsPhase.ready,
      failure = null;

  factory AdminContributionsSnapshot.fromRawCollections(
    Object? rawGroups,
    Object? rawContributions,
  ) {
    final groups = List<AdminContributionGroup>.unmodifiable(
      _strictRows(
        rawGroups,
        maximum: 200,
        label: 'contribution groups',
      ).map(AdminContributionGroup.fromJson),
    );
    final groupIds = groups.map((group) => group.id).toSet();
    final contributions = List<AdminContributionRecord>.unmodifiable(
      _strictRows(
        rawContributions,
        maximum: 500,
        label: 'contributions',
      ).map(AdminContributionRecord.fromJson),
    );
    if (contributions.any(
      (contribution) => !groupIds.contains(contribution.groupId),
    )) {
      throw const FormatException('Contribution group is unavailable.');
    }
    return AdminContributionsSnapshot(
      groups: groups,
      contributions: contributions,
    );
  }

  final List<AdminContributionGroup> groups;
  final List<AdminContributionRecord> contributions;
  final AdminContributionGroupFilter filter;
  final AdminContributionSort sort;
  final AdminContributionsPhase phase;
  final AdminContributionsFailure? failure;

  List<AdminContributionGroup> get visibleGroups {
    final result = groups
        .where((group) => filter.value == null || group.type == filter.value)
        .toList(growable: false);
    result.sort((left, right) {
      if (sort == AdminContributionSort.total) {
        final amount = right.currentTotal.compareTo(left.currentTotal);
        if (amount != 0) return amount;
      } else {
        final date = right.createdAt.compareTo(left.createdAt);
        if (date != 0) return date;
      }
      return left.name.compareTo(right.name);
    });
    return List<AdminContributionGroup>.unmodifiable(result);
  }

  int monthlyTotalAt(DateTime now) {
    return contributions.fold<int>(0, (sum, contribution) {
      if (contribution.status == 'failed' ||
          contribution.createdAt.year != now.year ||
          contribution.createdAt.month != now.month) {
        return sum;
      }
      return sum + contribution.amount;
    });
  }

  int recordCountFor(String groupId) =>
      contributions.where((item) => item.groupId == groupId).length;

  DateTime? lastActivityFor(String groupId) {
    DateTime? latest;
    for (final contribution in contributions) {
      if (contribution.groupId != groupId) continue;
      if (latest == null || contribution.createdAt.isAfter(latest)) {
        latest = contribution.createdAt;
      }
    }
    return latest;
  }

  bool get controlsEnabled =>
      phase == AdminContributionsPhase.ready && failure == null;

  AdminContributionsSnapshot copyWith({
    List<AdminContributionGroup>? groups,
    List<AdminContributionRecord>? contributions,
    AdminContributionGroupFilter? filter,
    AdminContributionSort? sort,
    AdminContributionsPhase? phase,
    AdminContributionsFailure? failure,
    bool clearFailure = false,
  }) {
    return AdminContributionsSnapshot(
      groups: groups ?? this.groups,
      contributions: contributions ?? this.contributions,
      filter: filter ?? this.filter,
      sort: sort ?? this.sort,
      phase: phase ?? this.phase,
      failure: clearFailure ? null : failure ?? this.failure,
    );
  }
}

abstract interface class AdminContributionsGateway {
  Future<AdminContributionsSnapshot> load();
}

class SupabaseAdminContributionsGateway implements AdminContributionsGateway {
  const SupabaseAdminContributionsGateway(this._repository);

  final AdminRepository _repository;

  Future<void> _requireAdmin() async {
    if (!await _repository.isCurrentUserAppMetadataAdmin()) {
      throw const AdminContributionsFailure(
        AdminContributionsFailureKind.permissionDenied,
      );
    }
  }

  @override
  Future<AdminContributionsSnapshot> load() async {
    await _requireAdmin();
    final groups = await _repository.getContributionGroups(limit: 200);
    final groupIds = groups
        .map((group) => group['id'])
        .whereType<Object>()
        .map((value) => value.toString())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    if (groupIds.isEmpty) return const AdminContributionsSnapshot.empty();
    await _requireAdmin();
    final contributions = await _repository.getContributionMonitorRecords(
      groupIds,
      limit: 500,
    );
    return AdminContributionsSnapshot.fromRawCollections(groups, contributions);
  }
}

final adminContributionsGatewayProvider = Provider<AdminContributionsGateway>((
  ref,
) {
  return SupabaseAdminContributionsGateway(ref.watch(adminRepositoryProvider));
});

final adminContributionsLoadTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 12),
);

final adminContributionsEnabledProvider = Provider<bool>((ref) => true);

class AdminContributionsNotifier
    extends AsyncNotifier<AdminContributionsSnapshot> {
  var _busy = false;

  @override
  Future<AdminContributionsSnapshot> build() => _load();

  Future<void> refresh() async {
    if (_busy) return;
    _busy = true;
    final previous = state.valueOrNull;
    state = const AsyncLoading<AdminContributionsSnapshot>().copyWithPrevious(
      state,
    );
    try {
      final loaded = await _load();
      state = AsyncData(
        loaded.copyWith(filter: previous?.filter, sort: previous?.sort),
      );
    } catch (error, stackTrace) {
      _applyFailure(
        AdminContributionsFailure.fromError(error),
        stackTrace,
        previous,
      );
    } finally {
      _busy = false;
    }
  }

  void selectFilter(AdminContributionGroupFilter filter) {
    final previous = state.valueOrNull;
    if (_busy || previous == null || !previous.controlsEnabled) return;
    state = AsyncData(previous.copyWith(filter: filter));
  }

  void selectSort(AdminContributionSort sort) {
    final previous = state.valueOrNull;
    if (_busy || previous == null || !previous.controlsEnabled) return;
    state = AsyncData(previous.copyWith(sort: sort));
  }

  Future<AdminContributionsSnapshot> _load() async {
    if (!ConnectivityService.isOnline) {
      throw const AdminContributionsFailure(
        AdminContributionsFailureKind.offline,
      );
    }
    try {
      return await ref
          .read(adminContributionsGatewayProvider)
          .load()
          .timeout(ref.read(adminContributionsLoadTimeoutProvider));
    } catch (error, stackTrace) {
      final failure = AdminContributionsFailure.fromError(error);
      AfriLogger.warn(
        'AdminContributionsNotifier',
        'Contribution monitor load failed.',
        failure,
        stackTrace,
      );
      throw failure;
    }
  }

  void _applyFailure(
    AdminContributionsFailure failure,
    StackTrace stackTrace,
    AdminContributionsSnapshot? previous,
  ) {
    if (failure.kind == AdminContributionsFailureKind.permissionDenied) {
      state = AsyncData(
        AdminContributionsSnapshot(
          groups: const <AdminContributionGroup>[],
          contributions: const <AdminContributionRecord>[],
          filter: previous?.filter ?? AdminContributionGroupFilter.all,
          sort: previous?.sort ?? AdminContributionSort.recent,
          phase: AdminContributionsPhase.degraded,
          failure: failure,
        ),
      );
      return;
    }
    state = previous != null
        ? AsyncData(
            previous.copyWith(
              phase: AdminContributionsPhase.degraded,
              failure: failure,
            ),
          )
        : AsyncError(failure, stackTrace);
  }
}

final adminContributionsProvider =
    AsyncNotifierProvider<
      AdminContributionsNotifier,
      AdminContributionsSnapshot
    >(AdminContributionsNotifier.new);

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

int _boundedMoney(
  Object? value, {
  required String field,
  bool nullable = false,
}) {
  if (nullable && value == null) return 0;
  if (value is! num || value.toInt() != value) {
    throw FormatException('Invalid $field.');
  }
  final amount = value.toInt();
  if (amount < 0 || amount > 1000000000000) {
    throw FormatException('Invalid $field.');
  }
  return amount;
}

int _boundedCount(Object? value, {required String field}) {
  if (value is! num || value.toInt() != value) {
    throw FormatException('Invalid $field.');
  }
  final count = value.toInt();
  if (count < 0 || count > 10000000) throw FormatException('Invalid $field.');
  return count;
}

bool _requiredBool(Object? value, {required String field}) {
  if (value is! bool) throw FormatException('Invalid $field.');
  return value;
}

DateTime _requiredDate(Object? value, {required String field}) {
  if (value is! String || value.length > 48) {
    throw FormatException('Invalid $field.');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) throw FormatException('Invalid $field.');
  return parsed.toUtc();
}
