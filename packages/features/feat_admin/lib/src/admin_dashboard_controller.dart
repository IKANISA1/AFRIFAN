import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'admin_providers.dart';
import 'repositories/admin_repository.dart';

enum AdminDashboardPhase { ready, degraded }

enum AdminDashboardFailureKind {
  offline,
  permissionDenied,
  conflict,
  securityTimeout,
  unknown,
}

class AdminDashboardFailure implements Exception {
  const AdminDashboardFailure(this.kind);

  final AdminDashboardFailureKind kind;

  static AdminDashboardFailure fromError(Object error) {
    if (error is AdminDashboardFailure) return error;
    if (error is TimeoutException) {
      return const AdminDashboardFailure(
        AdminDashboardFailureKind.securityTimeout,
      );
    }
    final normalized = error.toString().toLowerCase();
    if (normalized.contains('socketexception') ||
        normalized.contains('failed host lookup') ||
        normalized.contains('network is unreachable') ||
        normalized.contains('connection refused') ||
        normalized.contains('offline')) {
      return const AdminDashboardFailure(AdminDashboardFailureKind.offline);
    }
    if (normalized.contains('permission') ||
        normalized.contains('forbidden') ||
        normalized.contains('unauthorized') ||
        normalized.contains('row-level security') ||
        normalized.contains('rls') ||
        normalized.contains('42501')) {
      return const AdminDashboardFailure(
        AdminDashboardFailureKind.permissionDenied,
      );
    }
    if (normalized.contains('conflict') ||
        normalized.contains('changed') ||
        normalized.contains('stale') ||
        normalized.contains('revision') ||
        normalized.contains('409')) {
      return const AdminDashboardFailure(AdminDashboardFailureKind.conflict);
    }
    return const AdminDashboardFailure(AdminDashboardFailureKind.unknown);
  }

  @override
  String toString() => 'AdminDashboardFailure(${kind.name})';
}

class AdminDashboardActivity {
  const AdminDashboardActivity({required this.title, required this.category});

  final String title;
  final String category;
}

class AdminDashboardSnapshot {
  const AdminDashboardSnapshot({
    required this.metrics,
    required this.activity,
    this.phase = AdminDashboardPhase.ready,
    this.failure,
    this.activityUnavailable = false,
  });

  final AdminDashboardMetrics metrics;
  final List<AdminDashboardActivity> activity;
  final AdminDashboardPhase phase;
  final AdminDashboardFailure? failure;
  final bool activityUnavailable;

  bool get isEmpty =>
      metrics.totalUsers == 0 &&
      metrics.activeGroups == 0 &&
      metrics.transactionsToday == 0 &&
      metrics.ticketsSold == 0 &&
      activity.isEmpty;

  bool get actionsEnabled =>
      phase == AdminDashboardPhase.ready && failure == null;

  AdminDashboardSnapshot copyWith({
    AdminDashboardPhase? phase,
    AdminDashboardFailure? failure,
    bool clearFailure = false,
  }) {
    return AdminDashboardSnapshot(
      metrics: metrics,
      activity: activity,
      phase: phase ?? this.phase,
      failure: clearFailure ? null : failure ?? this.failure,
      activityUnavailable: activityUnavailable,
    );
  }
}

abstract interface class AdminDashboardGateway {
  Future<AdminDashboardSnapshot> load();
}

class SupabaseAdminDashboardGateway implements AdminDashboardGateway {
  const SupabaseAdminDashboardGateway(this._repository);

  final AdminRepository _repository;

  @override
  Future<AdminDashboardSnapshot> load() async {
    if (!await _repository.isCurrentUserAdmin()) {
      throw const AdminDashboardFailure(
        AdminDashboardFailureKind.permissionDenied,
      );
    }

    final metrics = await _repository.getDashboardMetrics();
    var activityUnavailable = false;
    var activity = const <AdminDashboardActivity>[];
    try {
      final results = await Future.wait<Object>([
        _repository.getRecentNewsTitles(limit: 3),
        _repository.getContributionGroups(limit: 3),
      ]);
      final newsTitles = results[0] as List<String>;
      final groups = results[1] as List<Map<String, dynamic>>;
      activity = <AdminDashboardActivity>[
        ...newsTitles.map(
          (title) => AdminDashboardActivity(
            title: _boundedText(title, fallback: 'Club update'),
            category: 'CMS',
          ),
        ),
        ...groups
            .take(2)
            .map(
              (group) => AdminDashboardActivity(
                title: _boundedText(
                  group['name']?.toString(),
                  fallback: 'Contribution group',
                ),
                category: 'CONTRIBUTIONS',
              ),
            ),
      ];
    } catch (error, stackTrace) {
      activityUnavailable = true;
      AfriLogger.warn(
        'AdminDashboardGateway',
        'Recent activity is unavailable.',
        error,
        stackTrace,
      );
    }

    return AdminDashboardSnapshot(
      metrics: metrics,
      activity: List<AdminDashboardActivity>.unmodifiable(activity),
      activityUnavailable: activityUnavailable,
    );
  }
}

String _boundedText(String? value, {required String fallback}) {
  final normalized = value?.trim() ?? '';
  if (normalized.isEmpty) return fallback;
  if (normalized.length <= 120) return normalized;
  return normalized.substring(0, 120);
}

final adminDashboardGatewayProvider = Provider<AdminDashboardGateway>((ref) {
  return SupabaseAdminDashboardGateway(ref.watch(adminRepositoryProvider));
});

final adminDashboardLoadTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 12),
);

final adminDashboardEnabledProvider = Provider<bool>((ref) => true);

final adminDashboardSelectedActionProvider = StateProvider<String?>(
  (ref) => null,
);

class AdminDashboardNotifier extends AsyncNotifier<AdminDashboardSnapshot> {
  bool _refreshing = false;

  @override
  Future<AdminDashboardSnapshot> build() => _load();

  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    final previous = state.valueOrNull;
    state = const AsyncLoading<AdminDashboardSnapshot>().copyWithPrevious(
      state,
    );
    try {
      state = AsyncData(await _load());
    } catch (error, stackTrace) {
      final failure = AdminDashboardFailure.fromError(error);
      state =
          previous != null &&
              failure.kind != AdminDashboardFailureKind.permissionDenied
          ? AsyncData(
              previous.copyWith(
                phase: AdminDashboardPhase.degraded,
                failure: failure,
              ),
            )
          : failure.kind == AdminDashboardFailureKind.permissionDenied
          ? const AsyncData(
              AdminDashboardSnapshot(
                metrics: AdminDashboardMetrics(),
                activity: <AdminDashboardActivity>[],
                phase: AdminDashboardPhase.degraded,
                failure: AdminDashboardFailure(
                  AdminDashboardFailureKind.permissionDenied,
                ),
              ),
            )
          : AsyncError(failure, stackTrace);
    } finally {
      _refreshing = false;
    }
  }

  Future<AdminDashboardSnapshot> _load() async {
    if (!ConnectivityService.isOnline) {
      throw const AdminDashboardFailure(AdminDashboardFailureKind.offline);
    }
    try {
      return await ref
          .read(adminDashboardGatewayProvider)
          .load()
          .timeout(ref.read(adminDashboardLoadTimeoutProvider));
    } catch (error, stackTrace) {
      final failure = AdminDashboardFailure.fromError(error);
      AfriLogger.warn(
        'AdminDashboardNotifier',
        'Dashboard load failed.',
        failure,
        stackTrace,
      );
      throw failure;
    }
  }
}

final adminDashboardProvider =
    AsyncNotifierProvider<AdminDashboardNotifier, AdminDashboardSnapshot>(
      AdminDashboardNotifier.new,
    );
