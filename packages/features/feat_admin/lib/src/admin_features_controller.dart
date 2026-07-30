import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'admin_providers.dart';
import 'repositories/admin_repository.dart';
import 'repositories/feature_management_repository.dart';

enum AdminFeaturesPhase { ready, degraded }

enum AdminFeaturesFailureKind {
  offline,
  permissionDenied,
  conflict,
  securityTimeout,
  unknown,
}

class AdminFeaturesFailure implements Exception {
  const AdminFeaturesFailure(this.kind);

  final AdminFeaturesFailureKind kind;

  static AdminFeaturesFailure fromError(Object error) {
    if (error is AdminFeaturesFailure) return error;
    if (error is TimeoutException) {
      return const AdminFeaturesFailure(
        AdminFeaturesFailureKind.securityTimeout,
      );
    }
    final normalized = error.toString().toLowerCase();
    if (normalized.contains('socketexception') ||
        normalized.contains('failed host lookup') ||
        normalized.contains('network is unreachable') ||
        normalized.contains('connection refused') ||
        normalized.contains('offline')) {
      return const AdminFeaturesFailure(AdminFeaturesFailureKind.offline);
    }
    if (normalized.contains('permission') ||
        normalized.contains('forbidden') ||
        normalized.contains('unauthorized') ||
        normalized.contains('admin access required') ||
        normalized.contains('row-level security') ||
        normalized.contains('rls') ||
        normalized.contains('42501')) {
      return const AdminFeaturesFailure(
        AdminFeaturesFailureKind.permissionDenied,
      );
    }
    if (normalized.contains('conflict') ||
        normalized.contains('changed') ||
        normalized.contains('stale') ||
        normalized.contains('duplicate') ||
        normalized.contains('23505') ||
        normalized.contains('409')) {
      return const AdminFeaturesFailure(AdminFeaturesFailureKind.conflict);
    }
    return const AdminFeaturesFailure(AdminFeaturesFailureKind.unknown);
  }

  @override
  String toString() => 'AdminFeaturesFailure(${kind.name})';
}

enum AdminFeatureStatusFilter {
  all('ALL'),
  enabled('ENABLED'),
  disabled('DISABLED');

  const AdminFeatureStatusFilter(this.label);

  final String label;
}

class AdminManagedFeatureChannel {
  const AdminManagedFeatureChannel({
    required this.channel,
    required this.isEnabled,
    required this.isVisible,
    required this.showInNavigation,
    required this.showOnHome,
    this.sortOrder,
  });

  factory AdminManagedFeatureChannel.fromJson(Map<String, dynamic> json) {
    return AdminManagedFeatureChannel(
      channel: _requiredEnum(
        json['channel'],
        field: 'channel.channel',
        allowed: const <String>{'mobile', 'web'},
      ),
      isEnabled: _requiredBool(json['is_enabled'], field: 'channel.is_enabled'),
      isVisible: _requiredBool(json['is_visible'], field: 'channel.is_visible'),
      showInNavigation: _requiredBool(
        json['show_in_navigation'],
        field: 'channel.show_in_navigation',
      ),
      showOnHome: _requiredBool(
        json['show_on_home'],
        field: 'channel.show_on_home',
      ),
      sortOrder: _optionalBoundedInt(
        json['sort_order'],
        field: 'channel.sort_order',
        minimum: 0,
        maximum: 999,
      ),
    );
  }

  final String channel;
  final bool isEnabled;
  final bool isVisible;
  final bool showInNavigation;
  final bool showOnHome;
  final int? sortOrder;
}

class AdminManagedFeatureRules {
  const AdminManagedFeatureRules({
    required this.authRequired,
    this.scheduleStartAt,
    this.scheduleEndAt,
  });

  factory AdminManagedFeatureRules.fromJson(Map<String, dynamic> json) {
    final start = _optionalDate(
      json['schedule_start_at'],
      field: 'rules.schedule_start_at',
    );
    final end = _optionalDate(
      json['schedule_end_at'],
      field: 'rules.schedule_end_at',
    );
    if (start != null && end != null && end.isBefore(start)) {
      throw const FormatException('Invalid feature schedule.');
    }
    return AdminManagedFeatureRules(
      authRequired: _requiredBool(
        json['auth_required'],
        field: 'rules.auth_required',
      ),
      scheduleStartAt: start,
      scheduleEndAt: end,
    );
  }

  final bool authRequired;
  final DateTime? scheduleStartAt;
  final DateTime? scheduleEndAt;
}

class AdminManagedFeature {
  const AdminManagedFeature({
    required this.id,
    required this.featureKey,
    required this.displayName,
    required this.category,
    required this.isEnabled,
    required this.visibility,
    required this.channels,
    required this.rules,
    this.description,
  });

  factory AdminManagedFeature.fromJson(Map<String, dynamic> json) {
    final channels = _strictRows(
      json['channels'],
      maximum: 4,
      label: 'feature channels',
    ).map(AdminManagedFeatureChannel.fromJson).toList(growable: false);
    final channelNames = channels.map((channel) => channel.channel).toSet();
    if (channelNames.length != channels.length) {
      throw const FormatException('Duplicate feature channel.');
    }

    final rawRules = json['rules'];
    final ruleRows = _strictRows(
      rawRules ?? const <Object>[],
      maximum: 1,
      label: 'feature rules',
    );
    return AdminManagedFeature(
      id: _requiredString(json['id'], field: 'feature.id', max: 80),
      featureKey: _requiredKey(
        json['feature_key'],
        field: 'feature.feature_key',
      ),
      displayName: _requiredString(
        json['display_name'],
        field: 'feature.display_name',
        max: 100,
      ),
      description: _optionalString(
        json['description'],
        field: 'feature.description',
        max: 240,
      ),
      category: _requiredString(
        json['category'],
        field: 'feature.category',
        max: 48,
      ),
      isEnabled: _requiredBool(json['is_enabled'], field: 'feature.is_enabled'),
      visibility: _requiredEnum(
        json['visibility_state'],
        field: 'feature.visibility_state',
        allowed: const <String>{'visible', 'hidden', 'maintenance'},
      ),
      channels: List<AdminManagedFeatureChannel>.unmodifiable(channels),
      rules: ruleRows.isEmpty
          ? null
          : AdminManagedFeatureRules.fromJson(ruleRows.single),
    );
  }

  final String id;
  final String featureKey;
  final String displayName;
  final String? description;
  final String category;
  final bool isEnabled;
  final String visibility;
  final List<AdminManagedFeatureChannel> channels;
  final AdminManagedFeatureRules? rules;
}

class AdminFeaturesSnapshot {
  const AdminFeaturesSnapshot({
    required this.features,
    this.filter = AdminFeatureStatusFilter.all,
    this.phase = AdminFeaturesPhase.ready,
    this.failure,
    this.isMutating = false,
    this.mutationOutcomeUnconfirmed = false,
  });

  const AdminFeaturesSnapshot.empty()
    : features = const <AdminManagedFeature>[],
      filter = AdminFeatureStatusFilter.all,
      phase = AdminFeaturesPhase.ready,
      failure = null,
      isMutating = false,
      mutationOutcomeUnconfirmed = false;

  factory AdminFeaturesSnapshot.fromRaw(Object? raw) {
    final items = _strictRows(
      raw,
      maximum: 100,
      label: 'platform features',
    ).map(AdminManagedFeature.fromJson).toList(growable: false);
    final keys = items.map((item) => item.featureKey).toSet();
    if (keys.length != items.length) {
      throw const FormatException('Duplicate feature key.');
    }
    items.sort((left, right) {
      final category = left.category.compareTo(right.category);
      return category != 0
          ? category
          : left.displayName.compareTo(right.displayName);
    });
    return AdminFeaturesSnapshot(
      features: List<AdminManagedFeature>.unmodifiable(items),
    );
  }

  final List<AdminManagedFeature> features;
  final AdminFeatureStatusFilter filter;
  final AdminFeaturesPhase phase;
  final AdminFeaturesFailure? failure;
  final bool isMutating;
  final bool mutationOutcomeUnconfirmed;

  List<AdminManagedFeature> get visibleFeatures =>
      List<AdminManagedFeature>.unmodifiable(
        features.where(
          (feature) => switch (filter) {
            AdminFeatureStatusFilter.all => true,
            AdminFeatureStatusFilter.enabled => feature.isEnabled,
            AdminFeatureStatusFilter.disabled => !feature.isEnabled,
          },
        ),
      );

  int get enabledCount => features.where((feature) => feature.isEnabled).length;

  bool get actionsEnabled =>
      phase == AdminFeaturesPhase.ready &&
      failure == null &&
      !isMutating &&
      !mutationOutcomeUnconfirmed;

  AdminFeaturesSnapshot copyWith({
    List<AdminManagedFeature>? features,
    AdminFeatureStatusFilter? filter,
    AdminFeaturesPhase? phase,
    AdminFeaturesFailure? failure,
    bool clearFailure = false,
    bool? isMutating,
    bool? mutationOutcomeUnconfirmed,
  }) {
    return AdminFeaturesSnapshot(
      features: features ?? this.features,
      filter: filter ?? this.filter,
      phase: phase ?? this.phase,
      failure: clearFailure ? null : failure ?? this.failure,
      isMutating: isMutating ?? this.isMutating,
      mutationOutcomeUnconfirmed:
          mutationOutcomeUnconfirmed ?? this.mutationOutcomeUnconfirmed,
    );
  }
}

class AdminFeatureDetailSnapshot {
  const AdminFeatureDetailSnapshot({
    required this.feature,
    this.phase = AdminFeaturesPhase.ready,
    this.failure,
    this.isMutating = false,
    this.mutationOutcomeUnconfirmed = false,
  });

  final AdminManagedFeature? feature;
  final AdminFeaturesPhase phase;
  final AdminFeaturesFailure? failure;
  final bool isMutating;
  final bool mutationOutcomeUnconfirmed;

  bool get actionsEnabled =>
      feature != null &&
      phase == AdminFeaturesPhase.ready &&
      failure == null &&
      !isMutating &&
      !mutationOutcomeUnconfirmed;

  AdminFeatureDetailSnapshot copyWith({
    AdminManagedFeature? feature,
    bool clearFeature = false,
    AdminFeaturesPhase? phase,
    AdminFeaturesFailure? failure,
    bool clearFailure = false,
    bool? isMutating,
    bool? mutationOutcomeUnconfirmed,
  }) {
    return AdminFeatureDetailSnapshot(
      feature: clearFeature ? null : feature ?? this.feature,
      phase: phase ?? this.phase,
      failure: clearFailure ? null : failure ?? this.failure,
      isMutating: isMutating ?? this.isMutating,
      mutationOutcomeUnconfirmed:
          mutationOutcomeUnconfirmed ?? this.mutationOutcomeUnconfirmed,
    );
  }
}

abstract interface class AdminFeaturesGateway {
  Future<AdminFeaturesSnapshot> loadAll();

  Future<AdminFeatureDetailSnapshot> loadOne(String featureKey);

  Future<void> setGlobalEnabled(String featureId, bool enabled);

  Future<void> setVisibility(String featureId, String visibility);

  Future<void> updateChannel(
    String featureId,
    String channel,
    Map<String, dynamic> updates,
  );

  Future<void> updateRules(String featureId, Map<String, dynamic> updates);
}

class SupabaseAdminFeaturesGateway implements AdminFeaturesGateway {
  const SupabaseAdminFeaturesGateway(this._admin, this._features);

  final AdminRepository _admin;
  final FeatureManagementRepository _features;

  Future<void> _requireAdmin() async {
    if (!await _admin.isCurrentUserAppMetadataAdmin()) {
      throw const AdminFeaturesFailure(
        AdminFeaturesFailureKind.permissionDenied,
      );
    }
  }

  @override
  Future<AdminFeaturesSnapshot> loadAll() async {
    await _requireAdmin();
    return AdminFeaturesSnapshot.fromRaw(
      await _admin.getPlatformFeatures(limit: 100),
    );
  }

  @override
  Future<AdminFeatureDetailSnapshot> loadOne(String featureKey) async {
    final normalized = _requiredKey(featureKey, field: 'feature.feature_key');
    await _requireAdmin();
    final all = AdminFeaturesSnapshot.fromRaw(
      await _admin.getPlatformFeatures(limit: 100),
    );
    AdminManagedFeature? match;
    for (final feature in all.features) {
      if (feature.featureKey == normalized) {
        match = feature;
        break;
      }
    }
    return AdminFeatureDetailSnapshot(feature: match);
  }

  @override
  Future<void> setGlobalEnabled(String featureId, bool enabled) async {
    await _requireAdmin();
    if (!await _features.updateFeatureGlobalStatus(featureId, enabled)) {
      throw const AdminFeaturesFailure(AdminFeaturesFailureKind.unknown);
    }
  }

  @override
  Future<void> setVisibility(String featureId, String visibility) async {
    final normalized = _requiredEnum(
      visibility,
      field: 'feature.visibility_state',
      allowed: const <String>{'visible', 'hidden', 'maintenance'},
    );
    await _requireAdmin();
    if (!await _features.updateFeatureVisibility(featureId, normalized)) {
      throw const AdminFeaturesFailure(AdminFeaturesFailureKind.unknown);
    }
  }

  @override
  Future<void> updateChannel(
    String featureId,
    String channel,
    Map<String, dynamic> updates,
  ) async {
    final normalizedChannel = _requiredEnum(
      channel,
      field: 'channel.channel',
      allowed: const <String>{'mobile', 'web'},
    );
    final allowed = <String, dynamic>{};
    for (final entry in updates.entries) {
      if (const <String>{
        'is_enabled',
        'is_visible',
        'show_in_navigation',
        'show_on_home',
      }.contains(entry.key)) {
        allowed[entry.key] = _requiredBool(
          entry.value,
          field: 'channel.${entry.key}',
        );
      } else if (entry.key == 'sort_order') {
        allowed[entry.key] = _optionalBoundedInt(
          entry.value,
          field: 'channel.sort_order',
          minimum: 0,
          maximum: 999,
        );
      } else {
        throw const FormatException('Unsupported channel update.');
      }
    }
    if (allowed.isEmpty) throw const FormatException('Empty channel update.');
    await _requireAdmin();
    if (!await _features.updateChannelConfig(
      featureId,
      normalizedChannel,
      allowed,
    )) {
      throw const AdminFeaturesFailure(AdminFeaturesFailureKind.unknown);
    }
  }

  @override
  Future<void> updateRules(
    String featureId,
    Map<String, dynamic> updates,
  ) async {
    final allowed = <String, dynamic>{};
    for (final entry in updates.entries) {
      if (entry.key == 'auth_required') {
        allowed[entry.key] = _requiredBool(
          entry.value,
          field: 'rules.auth_required',
        );
      } else if (entry.key == 'schedule_start_at' ||
          entry.key == 'schedule_end_at') {
        if (entry.value == null) {
          allowed[entry.key] = null;
        } else {
          allowed[entry.key] = _requiredDate(
            entry.value,
            field: 'rules.${entry.key}',
          ).toIso8601String();
        }
      } else {
        throw const FormatException('Unsupported rule update.');
      }
    }
    if (allowed.isEmpty) throw const FormatException('Empty rules update.');
    await _requireAdmin();
    if (!await _features.updateFeatureRules(featureId, allowed)) {
      throw const AdminFeaturesFailure(AdminFeaturesFailureKind.unknown);
    }
  }
}

final adminFeaturesGatewayProvider = Provider<AdminFeaturesGateway>((ref) {
  return SupabaseAdminFeaturesGateway(
    ref.watch(adminRepositoryProvider),
    ref.watch(featureManagementRepositoryProvider),
  );
});

final adminFeaturesLoadTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 12),
);
final adminFeaturesMutationTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 12),
);
final adminFeaturesEnabledProvider = Provider<bool>((ref) => true);

class AdminFeaturesNotifier extends AsyncNotifier<AdminFeaturesSnapshot> {
  var _busy = false;

  @override
  Future<AdminFeaturesSnapshot> build() => _load();

  Future<void> refresh() async {
    if (_busy) return;
    _busy = true;
    final previous = state.valueOrNull;
    state = const AsyncLoading<AdminFeaturesSnapshot>().copyWithPrevious(state);
    try {
      final loaded = await _load();
      state = AsyncData(loaded.copyWith(filter: previous?.filter));
    } catch (error, stackTrace) {
      _applyFailure(
        AdminFeaturesFailure.fromError(error),
        stackTrace,
        previous,
      );
    } finally {
      _busy = false;
    }
  }

  void selectFilter(AdminFeatureStatusFilter filter) {
    final previous = state.valueOrNull;
    if (_busy || previous == null || !previous.actionsEnabled) return;
    state = AsyncData(previous.copyWith(filter: filter));
  }

  Future<bool> setGlobalEnabled(String featureId, bool enabled) {
    return _runMutation(
      (gateway) => gateway.setGlobalEnabled(featureId, enabled),
    );
  }

  Future<bool> setVisibility(String featureId, String visibility) {
    return _runMutation(
      (gateway) => gateway.setVisibility(featureId, visibility),
    );
  }

  Future<bool> _runMutation(
    Future<void> Function(AdminFeaturesGateway gateway) operation,
  ) async {
    if (_busy) return false;
    final previous = state.valueOrNull;
    if (previous == null || !previous.actionsEnabled) return false;
    _busy = true;
    state = AsyncData(previous.copyWith(isMutating: true, clearFailure: true));
    try {
      _requireOnline();
      await operation(
        ref.read(adminFeaturesGatewayProvider),
      ).timeout(ref.read(adminFeaturesMutationTimeoutProvider));
      final loaded = await _load();
      state = AsyncData(loaded.copyWith(filter: previous.filter));
      return true;
    } catch (error, stackTrace) {
      final failure = AdminFeaturesFailure.fromError(error);
      _applyFailure(
        failure,
        stackTrace,
        previous,
        mutationOutcomeUnconfirmed:
            failure.kind == AdminFeaturesFailureKind.securityTimeout ||
            failure.kind == AdminFeaturesFailureKind.conflict,
      );
      return false;
    } finally {
      _busy = false;
    }
  }

  Future<AdminFeaturesSnapshot> _load() async {
    _requireOnline();
    try {
      return await ref
          .read(adminFeaturesGatewayProvider)
          .loadAll()
          .timeout(ref.read(adminFeaturesLoadTimeoutProvider));
    } catch (error, stackTrace) {
      final failure = AdminFeaturesFailure.fromError(error);
      AfriLogger.warn(
        'AdminFeaturesNotifier',
        'Feature registry load failed.',
        failure,
        stackTrace,
      );
      throw failure;
    }
  }

  void _applyFailure(
    AdminFeaturesFailure failure,
    StackTrace stackTrace,
    AdminFeaturesSnapshot? previous, {
    bool mutationOutcomeUnconfirmed = false,
  }) {
    if (failure.kind == AdminFeaturesFailureKind.permissionDenied) {
      state = AsyncData(
        AdminFeaturesSnapshot(
          features: const <AdminManagedFeature>[],
          filter: previous?.filter ?? AdminFeatureStatusFilter.all,
          phase: AdminFeaturesPhase.degraded,
          failure: failure,
        ),
      );
      return;
    }
    state = previous != null
        ? AsyncData(
            previous.copyWith(
              phase: AdminFeaturesPhase.degraded,
              failure: failure,
              isMutating: false,
              mutationOutcomeUnconfirmed: mutationOutcomeUnconfirmed,
            ),
          )
        : AsyncError(failure, stackTrace);
  }
}

final adminFeaturesProvider =
    AsyncNotifierProvider<AdminFeaturesNotifier, AdminFeaturesSnapshot>(
      AdminFeaturesNotifier.new,
    );

class AdminFeatureDetailNotifier
    extends FamilyAsyncNotifier<AdminFeatureDetailSnapshot, String> {
  var _busy = false;

  @override
  Future<AdminFeatureDetailSnapshot> build(String featureKey) => _load();

  Future<void> refresh() async {
    if (_busy) return;
    _busy = true;
    final previous = state.valueOrNull;
    state = const AsyncLoading<AdminFeatureDetailSnapshot>().copyWithPrevious(
      state,
    );
    try {
      state = AsyncData(await _load());
    } catch (error, stackTrace) {
      _applyFailure(
        AdminFeaturesFailure.fromError(error),
        stackTrace,
        previous,
      );
    } finally {
      _busy = false;
    }
  }

  Future<bool> setGlobalEnabled(bool enabled) {
    final feature = state.valueOrNull?.feature;
    if (feature == null) return Future<bool>.value(false);
    return _runMutation(
      (gateway) => gateway.setGlobalEnabled(feature.id, enabled),
    );
  }

  Future<bool> setVisibility(String visibility) {
    final feature = state.valueOrNull?.feature;
    if (feature == null) return Future<bool>.value(false);
    return _runMutation(
      (gateway) => gateway.setVisibility(feature.id, visibility),
    );
  }

  Future<bool> updateChannel(String channel, Map<String, dynamic> updates) {
    final feature = state.valueOrNull?.feature;
    if (feature == null) return Future<bool>.value(false);
    return _runMutation(
      (gateway) => gateway.updateChannel(feature.id, channel, updates),
    );
  }

  Future<bool> updateRules(Map<String, dynamic> updates) {
    final feature = state.valueOrNull?.feature;
    if (feature == null) return Future<bool>.value(false);
    return _runMutation((gateway) => gateway.updateRules(feature.id, updates));
  }

  Future<bool> _runMutation(
    Future<void> Function(AdminFeaturesGateway gateway) operation,
  ) async {
    if (_busy) return false;
    final previous = state.valueOrNull;
    if (previous == null || !previous.actionsEnabled) return false;
    _busy = true;
    state = AsyncData(previous.copyWith(isMutating: true, clearFailure: true));
    try {
      _requireOnline();
      await operation(
        ref.read(adminFeaturesGatewayProvider),
      ).timeout(ref.read(adminFeaturesMutationTimeoutProvider));
      state = AsyncData(await _load());
      return true;
    } catch (error, stackTrace) {
      final failure = AdminFeaturesFailure.fromError(error);
      _applyFailure(
        failure,
        stackTrace,
        previous,
        mutationOutcomeUnconfirmed:
            failure.kind == AdminFeaturesFailureKind.securityTimeout ||
            failure.kind == AdminFeaturesFailureKind.conflict,
      );
      return false;
    } finally {
      _busy = false;
    }
  }

  Future<AdminFeatureDetailSnapshot> _load() async {
    _requireOnline();
    try {
      return await ref
          .read(adminFeaturesGatewayProvider)
          .loadOne(arg)
          .timeout(ref.read(adminFeaturesLoadTimeoutProvider));
    } catch (error, stackTrace) {
      final failure = AdminFeaturesFailure.fromError(error);
      AfriLogger.warn(
        'AdminFeatureDetailNotifier',
        'Feature detail load failed.',
        failure,
        stackTrace,
      );
      throw failure;
    }
  }

  void _applyFailure(
    AdminFeaturesFailure failure,
    StackTrace stackTrace,
    AdminFeatureDetailSnapshot? previous, {
    bool mutationOutcomeUnconfirmed = false,
  }) {
    if (failure.kind == AdminFeaturesFailureKind.permissionDenied) {
      state = AsyncData(
        AdminFeatureDetailSnapshot(
          feature: null,
          phase: AdminFeaturesPhase.degraded,
          failure: failure,
        ),
      );
      return;
    }
    state = previous != null
        ? AsyncData(
            previous.copyWith(
              phase: AdminFeaturesPhase.degraded,
              failure: failure,
              isMutating: false,
              mutationOutcomeUnconfirmed: mutationOutcomeUnconfirmed,
            ),
          )
        : AsyncError(failure, stackTrace);
  }
}

final adminFeatureDetailProvider =
    AsyncNotifierProvider.family<
      AdminFeatureDetailNotifier,
      AdminFeatureDetailSnapshot,
      String
    >(AdminFeatureDetailNotifier.new);

void _requireOnline() {
  if (!ConnectivityService.isOnline) {
    throw const AdminFeaturesFailure(AdminFeaturesFailureKind.offline);
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
  if (value == null) return null;
  if (value is! String) throw FormatException('Invalid $field.');
  final normalized = value.trim();
  if (normalized.length > max) throw FormatException('Invalid $field.');
  return normalized.isEmpty ? null : normalized;
}

String _requiredKey(Object? value, {required String field}) {
  final key = _requiredString(value, field: field, max: 80).toLowerCase();
  if (!RegExp(r'^[a-z][a-z0-9_.-]*$').hasMatch(key)) {
    throw FormatException('Invalid $field.');
  }
  return key;
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

bool _requiredBool(Object? value, {required String field}) {
  if (value is! bool) throw FormatException('Invalid $field.');
  return value;
}

int? _optionalBoundedInt(
  Object? value, {
  required String field,
  required int minimum,
  required int maximum,
}) {
  if (value == null) return null;
  if (value is! num || value.toInt() != value) {
    throw FormatException('Invalid $field.');
  }
  final parsed = value.toInt();
  if (parsed < minimum || parsed > maximum) {
    throw FormatException('Invalid $field.');
  }
  return parsed;
}

DateTime? _optionalDate(Object? value, {required String field}) {
  if (value == null) return null;
  return _requiredDate(value, field: field);
}

DateTime _requiredDate(Object? value, {required String field}) {
  if (value is! String || value.length > 48) {
    throw FormatException('Invalid $field.');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) throw FormatException('Invalid $field.');
  return parsed.toUtc();
}
