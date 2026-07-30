import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'admin_providers.dart';
import 'repositories/admin_repository.dart';

enum AdminCompetitionsPhase { ready, degraded }

enum AdminCompetitionsFailureKind {
  offline,
  permissionDenied,
  conflict,
  securityTimeout,
  unknown,
}

class AdminCompetitionsFailure implements Exception {
  const AdminCompetitionsFailure(this.kind);

  final AdminCompetitionsFailureKind kind;

  static AdminCompetitionsFailure fromError(Object error) {
    if (error is AdminCompetitionsFailure) return error;
    if (error is TimeoutException) {
      return const AdminCompetitionsFailure(
        AdminCompetitionsFailureKind.securityTimeout,
      );
    }
    final normalized = error.toString().toLowerCase();
    if (normalized.contains('socketexception') ||
        normalized.contains('failed host lookup') ||
        normalized.contains('network is unreachable') ||
        normalized.contains('connection refused') ||
        normalized.contains('offline')) {
      return const AdminCompetitionsFailure(
        AdminCompetitionsFailureKind.offline,
      );
    }
    if (normalized.contains('permission') ||
        normalized.contains('forbidden') ||
        normalized.contains('unauthorized') ||
        normalized.contains('admin access required') ||
        normalized.contains('row-level security') ||
        normalized.contains('rls') ||
        normalized.contains('42501')) {
      return const AdminCompetitionsFailure(
        AdminCompetitionsFailureKind.permissionDenied,
      );
    }
    if (normalized.contains('conflict') ||
        normalized.contains('changed') ||
        normalized.contains('stale') ||
        normalized.contains('duplicate') ||
        normalized.contains('23505') ||
        normalized.contains('409')) {
      return const AdminCompetitionsFailure(
        AdminCompetitionsFailureKind.conflict,
      );
    }
    return const AdminCompetitionsFailure(AdminCompetitionsFailureKind.unknown);
  }

  @override
  String toString() => 'AdminCompetitionsFailure(${kind.name})';
}

enum AdminCompetitionRegionFilter {
  all('ALL', null),
  africa('AFRICA', 'africa'),
  europe('EUROPE', 'europe'),
  international('INTL', 'international'),
  global('GLOBAL', 'global');

  const AdminCompetitionRegionFilter(this.label, this.value);

  final String label;
  final String? value;
}

enum AdminCompetitionKindFilter {
  all('ALL', null),
  league('LEAGUE', 'league'),
  cup('CUP', 'cup'),
  tournament('TOURNAMENT', 'tournament');

  const AdminCompetitionKindFilter(this.label, this.value);

  final String label;
  final String? value;
}

class AdminCompetitionItem {
  const AdminCompetitionItem({
    required this.id,
    required this.slug,
    required this.name,
    required this.shortName,
    required this.kind,
    required this.region,
    required this.isActive,
    this.countryCode,
    this.countryName,
    this.organizer,
    this.gender,
    this.formatNotes,
  });

  factory AdminCompetitionItem.fromJson(Map<String, dynamic> json) {
    return AdminCompetitionItem(
      id: _boundedRequiredString(json['id'], field: 'competition.id', max: 80),
      slug: _boundedSlug(json['slug'], field: 'competition.slug'),
      name: _boundedRequiredString(
        json['name'],
        field: 'competition.name',
        max: 120,
      ),
      shortName: _boundedRequiredString(
        json['short_name'],
        field: 'competition.short_name',
        max: 32,
      ),
      kind: _boundedEnum(
        json['competition_kind'],
        field: 'competition.kind',
        allowed: const <String>{'league', 'cup', 'tournament'},
      ),
      region: _boundedEnum(
        json['region'],
        field: 'competition.region',
        allowed: const <String>{'africa', 'europe', 'international', 'global'},
      ),
      countryCode: _boundedOptionalString(
        json['country_code'],
        field: 'competition.country_code',
        max: 3,
      ),
      countryName: _boundedOptionalString(
        json['country_name'],
        field: 'competition.country_name',
        max: 80,
      ),
      organizer: _boundedOptionalString(
        json['organizer'],
        field: 'competition.organizer',
        max: 100,
      ),
      gender: _boundedOptionalString(
        json['gender'],
        field: 'competition.gender',
        max: 24,
      ),
      formatNotes: _boundedOptionalString(
        json['format_notes'],
        field: 'competition.format_notes',
        max: 240,
      ),
      isActive: _requiredBool(
        json['is_active'],
        field: 'competition.is_active',
      ),
    );
  }

  final String id;
  final String slug;
  final String name;
  final String shortName;
  final String kind;
  final String region;
  final String? countryCode;
  final String? countryName;
  final String? organizer;
  final String? gender;
  final String? formatNotes;
  final bool isActive;
}

class AdminCompetitionSeason {
  const AdminCompetitionSeason({
    required this.id,
    required this.competitionId,
    required this.slug,
    required this.label,
    required this.status,
    required this.isActive,
    this.yearStart,
    this.yearEnd,
  });

  factory AdminCompetitionSeason.fromJson(Map<String, dynamic> json) {
    final yearStart = _boundedOptionalYear(
      json['year_start'],
      field: 'season.year_start',
    );
    final yearEnd = _boundedOptionalYear(
      json['year_end'],
      field: 'season.year_end',
    );
    if (yearStart != null && yearEnd != null && yearEnd < yearStart) {
      throw const FormatException('Invalid season years.');
    }
    return AdminCompetitionSeason(
      id: _boundedRequiredString(json['id'], field: 'season.id', max: 80),
      competitionId: _boundedRequiredString(
        json['competition_id'],
        field: 'season.competition_id',
        max: 80,
      ),
      slug: _boundedSlug(json['slug'], field: 'season.slug'),
      label: _boundedRequiredString(
        json['label'],
        field: 'season.label',
        max: 64,
      ),
      yearStart: yearStart,
      yearEnd: yearEnd,
      status: _boundedEnum(
        json['status'],
        field: 'season.status',
        allowed: const <String>{'planned', 'active', 'finished', 'archived'},
      ),
      isActive: _requiredBool(json['is_active'], field: 'season.is_active'),
    );
  }

  final String id;
  final String competitionId;
  final String slug;
  final String label;
  final int? yearStart;
  final int? yearEnd;
  final String status;
  final bool isActive;
}

class AdminCompetitionsSnapshot {
  const AdminCompetitionsSnapshot({
    required this.competitions,
    required this.seasons,
    this.regionFilter = AdminCompetitionRegionFilter.all,
    this.kindFilter = AdminCompetitionKindFilter.all,
    this.phase = AdminCompetitionsPhase.ready,
    this.failure,
    this.isMutating = false,
    this.mutationOutcomeUnconfirmed = false,
  });

  const AdminCompetitionsSnapshot.empty()
    : competitions = const <AdminCompetitionItem>[],
      seasons = const <AdminCompetitionSeason>[],
      regionFilter = AdminCompetitionRegionFilter.all,
      kindFilter = AdminCompetitionKindFilter.all,
      phase = AdminCompetitionsPhase.ready,
      failure = null,
      isMutating = false,
      mutationOutcomeUnconfirmed = false;

  factory AdminCompetitionsSnapshot.fromRawCollections(
    Object? rawCompetitions,
    Object? rawSeasons,
  ) {
    final competitionRows = _strictRows(
      rawCompetitions,
      maximum: 200,
      label: 'competitions',
    );
    final seasonRows = _strictRows(rawSeasons, maximum: 300, label: 'seasons');
    final competitions = List<AdminCompetitionItem>.unmodifiable(
      competitionRows.map(AdminCompetitionItem.fromJson),
    );
    final competitionIds = competitions.map((item) => item.id).toSet();
    final seasons = List<AdminCompetitionSeason>.unmodifiable(
      seasonRows.map(AdminCompetitionSeason.fromJson),
    );
    if (seasons.any(
      (season) => !competitionIds.contains(season.competitionId),
    )) {
      throw const FormatException('Season competition is unavailable.');
    }
    return AdminCompetitionsSnapshot(
      competitions: competitions,
      seasons: seasons,
    );
  }

  final List<AdminCompetitionItem> competitions;
  final List<AdminCompetitionSeason> seasons;
  final AdminCompetitionRegionFilter regionFilter;
  final AdminCompetitionKindFilter kindFilter;
  final AdminCompetitionsPhase phase;
  final AdminCompetitionsFailure? failure;
  final bool isMutating;
  final bool mutationOutcomeUnconfirmed;

  List<AdminCompetitionItem> get visibleCompetitions =>
      List<AdminCompetitionItem>.unmodifiable(
        competitions.where(
          (item) =>
              (regionFilter.value == null ||
                  item.region == regionFilter.value) &&
              (kindFilter.value == null || item.kind == kindFilter.value),
        ),
      );

  int get activeCount =>
      competitions.where((competition) => competition.isActive).length;

  bool get actionsEnabled =>
      phase == AdminCompetitionsPhase.ready &&
      failure == null &&
      !isMutating &&
      !mutationOutcomeUnconfirmed;

  AdminCompetitionsSnapshot copyWith({
    List<AdminCompetitionItem>? competitions,
    List<AdminCompetitionSeason>? seasons,
    AdminCompetitionRegionFilter? regionFilter,
    AdminCompetitionKindFilter? kindFilter,
    AdminCompetitionsPhase? phase,
    AdminCompetitionsFailure? failure,
    bool clearFailure = false,
    bool? isMutating,
    bool? mutationOutcomeUnconfirmed,
  }) {
    return AdminCompetitionsSnapshot(
      competitions: competitions ?? this.competitions,
      seasons: seasons ?? this.seasons,
      regionFilter: regionFilter ?? this.regionFilter,
      kindFilter: kindFilter ?? this.kindFilter,
      phase: phase ?? this.phase,
      failure: clearFailure ? null : failure ?? this.failure,
      isMutating: isMutating ?? this.isMutating,
      mutationOutcomeUnconfirmed:
          mutationOutcomeUnconfirmed ?? this.mutationOutcomeUnconfirmed,
    );
  }
}

abstract interface class AdminCompetitionsGateway {
  Future<AdminCompetitionsSnapshot> load();

  Future<void> saveCompetition(
    Map<String, dynamic> payload, {
    String? competitionId,
  });

  Future<void> setCompetitionActive(String competitionId, bool isActive);

  Future<void> createSeason(Map<String, dynamic> payload);

  Future<void> setSeasonActive(String seasonId, bool isActive);
}

class SupabaseAdminCompetitionsGateway implements AdminCompetitionsGateway {
  const SupabaseAdminCompetitionsGateway(this._repository);

  final AdminRepository _repository;

  Future<void> _requireAdmin() async {
    if (!await _repository.isCurrentUserAppMetadataAdmin()) {
      throw const AdminCompetitionsFailure(
        AdminCompetitionsFailureKind.permissionDenied,
      );
    }
  }

  @override
  Future<AdminCompetitionsSnapshot> load() async {
    await _requireAdmin();
    final results = await Future.wait<Object?>(<Future<Object?>>[
      _repository.getManagedFootballCompetitions(limit: 200),
      _repository.getManagedFootballSeasons(limit: 300),
    ]);
    return AdminCompetitionsSnapshot.fromRawCollections(results[0], results[1]);
  }

  @override
  Future<void> saveCompetition(
    Map<String, dynamic> payload, {
    String? competitionId,
  }) async {
    await _requireAdmin();
    final controlledPayload = _competitionWritePayload(payload);
    if (competitionId == null) {
      await _repository.createManagedFootballCompetition(controlledPayload);
    } else {
      await _repository.updateManagedFootballCompetition(
        _boundedRequiredString(competitionId, field: 'competition.id', max: 80),
        controlledPayload,
      );
    }
  }

  @override
  Future<void> setCompetitionActive(String competitionId, bool isActive) async {
    await _requireAdmin();
    await _repository.updateManagedFootballCompetition(
      _boundedRequiredString(competitionId, field: 'competition.id', max: 80),
      {'is_active': isActive},
    );
  }

  @override
  Future<void> createSeason(Map<String, dynamic> payload) async {
    await _requireAdmin();
    await _repository.createManagedFootballSeason(_seasonWritePayload(payload));
  }

  @override
  Future<void> setSeasonActive(String seasonId, bool isActive) async {
    await _requireAdmin();
    await _repository.updateManagedFootballSeason(
      _boundedRequiredString(seasonId, field: 'season.id', max: 80),
      {'is_active': isActive},
    );
  }
}

final adminCompetitionsGatewayProvider = Provider<AdminCompetitionsGateway>((
  ref,
) {
  return SupabaseAdminCompetitionsGateway(ref.watch(adminRepositoryProvider));
});

final adminCompetitionsLoadTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 12),
);

final adminCompetitionsMutationTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 12),
);

final adminCompetitionsEnabledProvider = Provider<bool>((ref) => true);

class AdminCompetitionsNotifier
    extends AsyncNotifier<AdminCompetitionsSnapshot> {
  var _busy = false;

  @override
  Future<AdminCompetitionsSnapshot> build() => _load();

  Future<void> refresh() async {
    if (_busy) return;
    _busy = true;
    final previous = state.valueOrNull;
    state = const AsyncLoading<AdminCompetitionsSnapshot>().copyWithPrevious(
      state,
    );
    try {
      final loaded = await _load();
      state = AsyncData(
        loaded.copyWith(
          regionFilter: previous?.regionFilter,
          kindFilter: previous?.kindFilter,
        ),
      );
    } catch (error, stackTrace) {
      _applyFailure(
        AdminCompetitionsFailure.fromError(error),
        stackTrace,
        previous,
      );
    } finally {
      _busy = false;
    }
  }

  void selectRegion(AdminCompetitionRegionFilter filter) {
    final previous = state.valueOrNull;
    if (_busy || previous == null || !previous.actionsEnabled) return;
    state = AsyncData(previous.copyWith(regionFilter: filter));
  }

  void selectKind(AdminCompetitionKindFilter filter) {
    final previous = state.valueOrNull;
    if (_busy || previous == null || !previous.actionsEnabled) return;
    state = AsyncData(previous.copyWith(kindFilter: filter));
  }

  Future<bool> saveCompetition(
    Map<String, dynamic> payload, {
    String? competitionId,
  }) {
    return _runMutation(
      (gateway) =>
          gateway.saveCompetition(payload, competitionId: competitionId),
    );
  }

  Future<bool> setCompetitionActive(String competitionId, bool isActive) {
    return _runMutation(
      (gateway) => gateway.setCompetitionActive(competitionId, isActive),
    );
  }

  Future<bool> createSeason(Map<String, dynamic> payload) {
    return _runMutation((gateway) => gateway.createSeason(payload));
  }

  Future<bool> setSeasonActive(String seasonId, bool isActive) {
    return _runMutation(
      (gateway) => gateway.setSeasonActive(seasonId, isActive),
    );
  }

  Future<bool> _runMutation(
    Future<void> Function(AdminCompetitionsGateway gateway) operation,
  ) async {
    if (_busy) return false;
    final previous = state.valueOrNull;
    if (previous == null || !previous.actionsEnabled) return false;
    _busy = true;
    state = AsyncData(previous.copyWith(isMutating: true, clearFailure: true));
    try {
      if (!ConnectivityService.isOnline) {
        throw const AdminCompetitionsFailure(
          AdminCompetitionsFailureKind.offline,
        );
      }
      await operation(
        ref.read(adminCompetitionsGatewayProvider),
      ).timeout(ref.read(adminCompetitionsMutationTimeoutProvider));
      final loaded = await _load();
      state = AsyncData(
        loaded.copyWith(
          regionFilter: previous.regionFilter,
          kindFilter: previous.kindFilter,
        ),
      );
      return true;
    } catch (error, stackTrace) {
      final failure = AdminCompetitionsFailure.fromError(error);
      final uncertain =
          failure.kind == AdminCompetitionsFailureKind.securityTimeout ||
          failure.kind == AdminCompetitionsFailureKind.conflict;
      _applyFailure(
        failure,
        stackTrace,
        previous,
        mutationOutcomeUnconfirmed: uncertain,
      );
      return false;
    } finally {
      _busy = false;
    }
  }

  Future<AdminCompetitionsSnapshot> _load() async {
    if (!ConnectivityService.isOnline) {
      throw const AdminCompetitionsFailure(
        AdminCompetitionsFailureKind.offline,
      );
    }
    try {
      return await ref
          .read(adminCompetitionsGatewayProvider)
          .load()
          .timeout(ref.read(adminCompetitionsLoadTimeoutProvider));
    } catch (error, stackTrace) {
      final failure = AdminCompetitionsFailure.fromError(error);
      AfriLogger.warn(
        'AdminCompetitionsNotifier',
        'Competition workspace load failed.',
        failure,
        stackTrace,
      );
      throw failure;
    }
  }

  void _applyFailure(
    AdminCompetitionsFailure failure,
    StackTrace stackTrace,
    AdminCompetitionsSnapshot? previous, {
    bool mutationOutcomeUnconfirmed = false,
  }) {
    if (failure.kind == AdminCompetitionsFailureKind.permissionDenied) {
      state = AsyncData(
        AdminCompetitionsSnapshot(
          competitions: const <AdminCompetitionItem>[],
          seasons: const <AdminCompetitionSeason>[],
          regionFilter:
              previous?.regionFilter ?? AdminCompetitionRegionFilter.all,
          kindFilter: previous?.kindFilter ?? AdminCompetitionKindFilter.all,
          phase: AdminCompetitionsPhase.degraded,
          failure: failure,
        ),
      );
      return;
    }
    state = previous != null
        ? AsyncData(
            previous.copyWith(
              phase: AdminCompetitionsPhase.degraded,
              failure: failure,
              isMutating: false,
              mutationOutcomeUnconfirmed: mutationOutcomeUnconfirmed,
            ),
          )
        : AsyncError(failure, stackTrace);
  }
}

final adminCompetitionsProvider =
    AsyncNotifierProvider<AdminCompetitionsNotifier, AdminCompetitionsSnapshot>(
      AdminCompetitionsNotifier.new,
    );

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

String _boundedRequiredString(
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

String? _boundedOptionalString(
  Object? value, {
  required String field,
  required int max,
}) {
  if (value == null) return null;
  if (value is! String) throw FormatException('Invalid $field.');
  final normalized = value.trim();
  if (normalized.isEmpty) return null;
  if (normalized.length > max) throw FormatException('Invalid $field.');
  return normalized;
}

String _boundedSlug(Object? value, {required String field}) {
  final slug = _boundedRequiredString(value, field: field, max: 80);
  if (!RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(slug)) {
    throw FormatException('Invalid $field.');
  }
  return slug;
}

String _boundedEnum(
  Object? value, {
  required String field,
  required Set<String> allowed,
}) {
  final normalized = _boundedRequiredString(
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

int? _boundedOptionalYear(Object? value, {required String field}) {
  if (value == null) return null;
  if (value is! num || value.toInt() != value) {
    throw FormatException('Invalid $field.');
  }
  final year = value.toInt();
  if (year < 1900 || year > 2200) throw FormatException('Invalid $field.');
  return year;
}

Map<String, dynamic> _competitionWritePayload(Map<String, dynamic> payload) {
  final countryCode = _boundedOptionalString(
    payload['country_code'],
    field: 'competition.country_code',
    max: 3,
  )?.toUpperCase();
  if (countryCode != null && !RegExp(r'^[A-Z]{2,3}$').hasMatch(countryCode)) {
    throw const FormatException('Invalid competition.country_code.');
  }
  return <String, dynamic>{
    'name': _boundedRequiredString(
      payload['name'],
      field: 'competition.name',
      max: 120,
    ),
    'short_name': _boundedRequiredString(
      payload['short_name'],
      field: 'competition.short_name',
      max: 32,
    ),
    'slug': _boundedSlug(payload['slug'], field: 'competition.slug'),
    'competition_kind': _boundedEnum(
      payload['competition_kind'],
      field: 'competition.kind',
      allowed: const <String>{'league', 'cup', 'tournament'},
    ),
    'region': _boundedEnum(
      payload['region'],
      field: 'competition.region',
      allowed: const <String>{'africa', 'europe', 'international', 'global'},
    ),
    'organizer': _boundedOptionalString(
      payload['organizer'],
      field: 'competition.organizer',
      max: 100,
    ),
    'country_code': countryCode,
    'country_name': _boundedOptionalString(
      payload['country_name'],
      field: 'competition.country_name',
      max: 80,
    ),
    'format_notes': _boundedOptionalString(
      payload['format_notes'],
      field: 'competition.format_notes',
      max: 240,
    ),
    'is_active': _requiredBool(
      payload['is_active'],
      field: 'competition.is_active',
    ),
  };
}

Map<String, dynamic> _seasonWritePayload(Map<String, dynamic> payload) {
  final yearStart = _boundedOptionalYear(
    payload['year_start'],
    field: 'season.year_start',
  );
  final yearEnd = _boundedOptionalYear(
    payload['year_end'],
    field: 'season.year_end',
  );
  if (yearStart != null && yearEnd != null && yearEnd < yearStart) {
    throw const FormatException('Invalid season years.');
  }
  return <String, dynamic>{
    'competition_id': _boundedRequiredString(
      payload['competition_id'],
      field: 'season.competition_id',
      max: 80,
    ),
    'slug': _boundedSlug(payload['slug'], field: 'season.slug'),
    'label': _boundedRequiredString(
      payload['label'],
      field: 'season.label',
      max: 64,
    ),
    'year_start': yearStart,
    'year_end': yearEnd,
    'status': _boundedEnum(
      payload['status'],
      field: 'season.status',
      allowed: const <String>{'planned', 'active', 'finished', 'archived'},
    ),
    'is_active': _requiredBool(payload['is_active'], field: 'season.is_active'),
  };
}
