import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'admin_providers.dart';
import 'repositories/admin_repository.dart';

enum AdminMatchesPhase { ready, degraded }

enum AdminMatchesFailureKind {
  offline,
  permissionDenied,
  conflict,
  securityTimeout,
  unknown,
}

class AdminMatchesFailure implements Exception {
  const AdminMatchesFailure(this.kind);

  final AdminMatchesFailureKind kind;

  static AdminMatchesFailure fromError(Object error) {
    if (error is AdminMatchesFailure) return error;
    if (error is TimeoutException) {
      return const AdminMatchesFailure(AdminMatchesFailureKind.securityTimeout);
    }
    final normalized = error.toString().toLowerCase();
    if (normalized.contains('socketexception') ||
        normalized.contains('failed host lookup') ||
        normalized.contains('network is unreachable') ||
        normalized.contains('connection refused') ||
        normalized.contains('offline')) {
      return const AdminMatchesFailure(AdminMatchesFailureKind.offline);
    }
    if (normalized.contains('permission') ||
        normalized.contains('forbidden') ||
        normalized.contains('unauthorized') ||
        normalized.contains('admin access required') ||
        normalized.contains('row-level security') ||
        normalized.contains('rls') ||
        normalized.contains('42501')) {
      return const AdminMatchesFailure(
        AdminMatchesFailureKind.permissionDenied,
      );
    }
    if (normalized.contains('conflict') ||
        normalized.contains('changed') ||
        normalized.contains('stale') ||
        normalized.contains('duplicate') ||
        normalized.contains('23505') ||
        normalized.contains('409')) {
      return const AdminMatchesFailure(AdminMatchesFailureKind.conflict);
    }
    return const AdminMatchesFailure(AdminMatchesFailureKind.unknown);
  }

  @override
  String toString() => 'AdminMatchesFailure(${kind.name})';
}

enum AdminMatchFilter {
  all('ALL'),
  live('LIVE'),
  upcoming('UPCOMING'),
  onSale('ON SALE'),
  completed('COMPLETED');

  const AdminMatchFilter(this.label);

  final String label;
}

class AdminMatchItem {
  const AdminMatchItem({
    required this.id,
    required this.homeTeam,
    required this.awayTeam,
    required this.competition,
    required this.venue,
    required this.matchDate,
    required this.kickoffTime,
    required this.isOnSale,
    required this.generalPrice,
    required this.vipPrice,
    required this.capacity,
    required this.soldCount,
    required this.status,
    required this.homeScore,
    required this.awayScore,
    required this.liveMinute,
    this.summary,
    required this.partnerId,
  });

  factory AdminMatchItem.fromJson(Map<String, dynamic> json) {
    return AdminMatchItem(
      id: _requiredString(json['id'], field: 'match.id', max: 80),
      partnerId: _requiredString(
        json['partner_id'],
        field: 'match.partner_id',
        max: 80,
      ),
      homeTeam: _requiredString(
        json['home_team'],
        field: 'match.home_team',
        max: 100,
      ),
      awayTeam: _requiredString(
        json['away_team'],
        field: 'match.away_team',
        max: 100,
      ),
      competition: _requiredString(
        json['competition'],
        field: 'match.competition',
        max: 100,
      ),
      venue: _requiredString(json['venue'], field: 'match.venue', max: 120),
      matchDate: _requiredDate(json['match_date'], field: 'match.match_date'),
      kickoffTime: _requiredTime(
        json['kickoff_time'],
        field: 'match.kickoff_time',
      ),
      isOnSale: _requiredBool(json['is_on_sale'], field: 'match.is_on_sale'),
      generalPrice: _boundedInt(
        json['ticket_general_price'],
        field: 'match.ticket_general_price',
        maximum: 100000000,
      ),
      vipPrice: _boundedInt(
        json['ticket_vip_price'],
        field: 'match.ticket_vip_price',
        maximum: 100000000,
      ),
      capacity: _boundedInt(
        json['capacity'],
        field: 'match.capacity',
        maximum: 1000000,
      ),
      soldCount: _boundedInt(
        json['sold_count'],
        field: 'match.sold_count',
        maximum: 1000000,
      ),
      status: _requiredEnum(
        json['match_status'],
        field: 'match.match_status',
        allowed: const <String>{
          'scheduled',
          'live',
          'halftime',
          'fulltime',
          'postponed',
          'cancelled',
        },
      ),
      homeScore: _boundedInt(
        json['home_score'],
        field: 'match.home_score',
        maximum: 99,
      ),
      awayScore: _boundedInt(
        json['away_score'],
        field: 'match.away_score',
        maximum: 99,
      ),
      liveMinute: json['live_minute'] == null
          ? 0
          : _boundedInt(
              json['live_minute'],
              field: 'match.live_minute',
              maximum: 180,
            ),
      summary: _optionalString(
        json['match_summary'],
        field: 'match.match_summary',
        max: 500,
      ),
    );
  }

  final String id;
  final String partnerId;
  final String homeTeam;
  final String awayTeam;
  final String competition;
  final String venue;
  final DateTime matchDate;
  final String kickoffTime;
  final bool isOnSale;
  final int generalPrice;
  final int vipPrice;
  final int capacity;
  final int soldCount;
  final String status;
  final int homeScore;
  final int awayScore;
  final int liveMinute;
  final String? summary;

  bool get isLive => status == 'live' || status == 'halftime';
  bool get isCompleted => status == 'fulltime';

  String get statusLabel => switch (status) {
    'live' => 'LIVE',
    'halftime' => 'HALF-TIME',
    'fulltime' => 'FULL-TIME',
    'postponed' => 'POSTPONED',
    'cancelled' => 'CANCELLED',
    _ => 'UPCOMING',
  };

  int get soldPercent =>
      capacity <= 0 ? 0 : ((soldCount / capacity) * 100).round();

  Map<String, dynamic> toComposerJson() => <String, dynamic>{
    'id': id,
    'partner_id': partnerId,
    'home_team': homeTeam,
    'away_team': awayTeam,
    'competition': competition,
    'venue': venue,
    'match_date': _dateOnly(matchDate),
    'kickoff_time': kickoffTime,
    'is_on_sale': isOnSale,
    'ticket_general_price': generalPrice,
    'ticket_vip_price': vipPrice,
    'capacity': capacity,
    'sold_count': soldCount,
    'match_status': status,
    'home_score': homeScore,
    'away_score': awayScore,
    'live_minute': liveMinute,
    'match_summary': summary,
  };
}

class AdminMatchDraft {
  const AdminMatchDraft(this.payload);

  factory AdminMatchDraft.fromRaw(Map<String, dynamic> raw) {
    final date = _requiredDate(raw['match_date'], field: 'match.match_date');
    final capacity = _boundedInt(
      raw['capacity'],
      field: 'match.capacity',
      maximum: 1000000,
    );
    final payload = <String, dynamic>{
      'partner_id': _requiredString(
        raw['partner_id'],
        field: 'match.partner_id',
        max: 80,
      ),
      'home_team': _requiredString(
        raw['home_team'],
        field: 'match.home_team',
        max: 100,
      ),
      'away_team': _requiredString(
        raw['away_team'],
        field: 'match.away_team',
        max: 100,
      ),
      'competition': _requiredString(
        raw['competition'],
        field: 'match.competition',
        max: 100,
      ),
      'venue': _requiredString(raw['venue'], field: 'match.venue', max: 120),
      'match_date': _dateOnly(date),
      'kickoff_time': _requiredTime(
        raw['kickoff_time'],
        field: 'match.kickoff_time',
      ),
      'is_on_sale': _requiredBool(raw['is_on_sale'], field: 'match.is_on_sale'),
      'ticket_general_price': _boundedInt(
        raw['ticket_general_price'],
        field: 'match.ticket_general_price',
        maximum: 100000000,
      ),
      'ticket_vip_price': _boundedInt(
        raw['ticket_vip_price'],
        field: 'match.ticket_vip_price',
        maximum: 100000000,
      ),
      'capacity': capacity,
      'match_status': _requiredEnum(
        raw['match_status'],
        field: 'match.match_status',
        allowed: const <String>{
          'scheduled',
          'live',
          'halftime',
          'fulltime',
          'postponed',
          'cancelled',
        },
      ),
      'home_score': _boundedInt(
        raw['home_score'],
        field: 'match.home_score',
        maximum: 99,
      ),
      'away_score': _boundedInt(
        raw['away_score'],
        field: 'match.away_score',
        maximum: 99,
      ),
      'live_minute': _boundedInt(
        raw['live_minute'],
        field: 'match.live_minute',
        maximum: 180,
      ),
      'match_summary':
          _optionalString(
            raw['match_summary'],
            field: 'match.match_summary',
            max: 500,
          ) ??
          '',
    };
    return AdminMatchDraft(Map<String, dynamic>.unmodifiable(payload));
  }

  final Map<String, dynamic> payload;
}

class AdminMatchesSnapshot {
  const AdminMatchesSnapshot({
    required this.matches,
    this.filter = AdminMatchFilter.all,
    this.phase = AdminMatchesPhase.ready,
    this.failure,
    this.isMutating = false,
    this.mutationOutcomeUnconfirmed = false,
  });

  const AdminMatchesSnapshot.empty()
    : matches = const <AdminMatchItem>[],
      filter = AdminMatchFilter.all,
      phase = AdminMatchesPhase.ready,
      failure = null,
      isMutating = false,
      mutationOutcomeUnconfirmed = false;

  factory AdminMatchesSnapshot.fromRaw(Object? raw) {
    final matches = _strictRows(
      raw,
      maximum: 200,
      label: 'matches',
    ).map(AdminMatchItem.fromJson).toList(growable: false);
    final ids = matches.map((match) => match.id).toSet();
    if (ids.length != matches.length) {
      throw const FormatException('Duplicate match.');
    }
    matches.sort((left, right) => left.matchDate.compareTo(right.matchDate));
    return AdminMatchesSnapshot(
      matches: List<AdminMatchItem>.unmodifiable(matches),
    );
  }

  final List<AdminMatchItem> matches;
  final AdminMatchFilter filter;
  final AdminMatchesPhase phase;
  final AdminMatchesFailure? failure;
  final bool isMutating;
  final bool mutationOutcomeUnconfirmed;

  List<AdminMatchItem> get visibleMatches => List<AdminMatchItem>.unmodifiable(
    matches.where(
      (match) => switch (filter) {
        AdminMatchFilter.all => true,
        AdminMatchFilter.live => match.isLive,
        AdminMatchFilter.upcoming =>
          !match.isCompleted &&
              match.status != 'cancelled' &&
              match.status != 'postponed',
        AdminMatchFilter.onSale => match.isOnSale,
        AdminMatchFilter.completed => match.isCompleted,
      },
    ),
  );

  bool get actionsEnabled =>
      phase == AdminMatchesPhase.ready &&
      failure == null &&
      !isMutating &&
      !mutationOutcomeUnconfirmed;

  String? get partnerId => matches.firstOrNull?.partnerId;

  AdminMatchesSnapshot copyWith({
    List<AdminMatchItem>? matches,
    AdminMatchFilter? filter,
    AdminMatchesPhase? phase,
    AdminMatchesFailure? failure,
    bool clearFailure = false,
    bool? isMutating,
    bool? mutationOutcomeUnconfirmed,
  }) {
    return AdminMatchesSnapshot(
      matches: matches ?? this.matches,
      filter: filter ?? this.filter,
      phase: phase ?? this.phase,
      failure: clearFailure ? null : failure ?? this.failure,
      isMutating: isMutating ?? this.isMutating,
      mutationOutcomeUnconfirmed:
          mutationOutcomeUnconfirmed ?? this.mutationOutcomeUnconfirmed,
    );
  }
}

abstract interface class AdminMatchesGateway {
  Future<AdminMatchesSnapshot> load();

  Future<void> save(AdminMatchDraft draft, {String? matchId});
}

class SupabaseAdminMatchesGateway implements AdminMatchesGateway {
  const SupabaseAdminMatchesGateway(this._repository);

  final AdminRepository _repository;

  Future<void> _requireAdmin() async {
    if (!await _repository.isCurrentUserAppMetadataAdmin()) {
      throw const AdminMatchesFailure(AdminMatchesFailureKind.permissionDenied);
    }
  }

  @override
  Future<AdminMatchesSnapshot> load() async {
    await _requireAdmin();
    return AdminMatchesSnapshot.fromRaw(
      await _repository.getManagedMatches(limit: 200),
    );
  }

  @override
  Future<void> save(AdminMatchDraft draft, {String? matchId}) async {
    await _requireAdmin();
    if (matchId == null) {
      await _repository.createManagedMatch(draft.payload);
      return;
    }
    await _repository.updateManagedMatch(
      _requiredString(matchId, field: 'match.id', max: 80),
      draft.payload,
    );
  }
}

final adminMatchesGatewayProvider = Provider<AdminMatchesGateway>((ref) {
  return SupabaseAdminMatchesGateway(ref.watch(adminRepositoryProvider));
});
final adminMatchesLoadTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 12),
);
final adminMatchesMutationTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 12),
);
final adminMatchesEnabledProvider = Provider<bool>((ref) => true);

class AdminMatchesNotifier extends AsyncNotifier<AdminMatchesSnapshot> {
  var _busy = false;

  @override
  Future<AdminMatchesSnapshot> build() => _load();

  Future<void> refresh() async {
    if (_busy) return;
    _busy = true;
    final previous = state.valueOrNull;
    state = const AsyncLoading<AdminMatchesSnapshot>().copyWithPrevious(state);
    try {
      state = AsyncData((await _load()).copyWith(filter: previous?.filter));
    } catch (error, stackTrace) {
      _applyFailure(AdminMatchesFailure.fromError(error), stackTrace, previous);
    } finally {
      _busy = false;
    }
  }

  void selectFilter(AdminMatchFilter filter) {
    final previous = state.valueOrNull;
    if (_busy || previous == null || !previous.actionsEnabled) return;
    state = AsyncData(previous.copyWith(filter: filter));
  }

  Future<bool> save(Map<String, dynamic> raw, {String? matchId}) async {
    if (_busy) return false;
    final previous = state.valueOrNull;
    if (previous == null || !previous.actionsEnabled) return false;
    final draft = AdminMatchDraft.fromRaw(raw);
    _busy = true;
    state = AsyncData(previous.copyWith(isMutating: true, clearFailure: true));
    try {
      _requireOnline();
      await ref
          .read(adminMatchesGatewayProvider)
          .save(draft, matchId: matchId)
          .timeout(ref.read(adminMatchesMutationTimeoutProvider));
      state = AsyncData((await _load()).copyWith(filter: previous.filter));
      return true;
    } catch (error, stackTrace) {
      final failure = AdminMatchesFailure.fromError(error);
      _applyFailure(
        failure,
        stackTrace,
        previous,
        mutationOutcomeUnconfirmed:
            failure.kind == AdminMatchesFailureKind.securityTimeout ||
            failure.kind == AdminMatchesFailureKind.conflict,
      );
      return false;
    } finally {
      _busy = false;
    }
  }

  Future<AdminMatchesSnapshot> _load() async {
    _requireOnline();
    try {
      return await ref
          .read(adminMatchesGatewayProvider)
          .load()
          .timeout(ref.read(adminMatchesLoadTimeoutProvider));
    } catch (error, stackTrace) {
      final failure = AdminMatchesFailure.fromError(error);
      AfriLogger.warn(
        'AdminMatchesNotifier',
        'Match workspace load failed.',
        failure,
        stackTrace,
      );
      throw failure;
    }
  }

  void _applyFailure(
    AdminMatchesFailure failure,
    StackTrace stackTrace,
    AdminMatchesSnapshot? previous, {
    bool mutationOutcomeUnconfirmed = false,
  }) {
    if (failure.kind == AdminMatchesFailureKind.permissionDenied) {
      state = AsyncData(
        AdminMatchesSnapshot(
          matches: const <AdminMatchItem>[],
          filter: previous?.filter ?? AdminMatchFilter.all,
          phase: AdminMatchesPhase.degraded,
          failure: failure,
        ),
      );
      return;
    }
    state = previous != null
        ? AsyncData(
            previous.copyWith(
              phase: AdminMatchesPhase.degraded,
              failure: failure,
              isMutating: false,
              mutationOutcomeUnconfirmed: mutationOutcomeUnconfirmed,
            ),
          )
        : AsyncError(failure, stackTrace);
  }
}

final adminMatchesProvider =
    AsyncNotifierProvider<AdminMatchesNotifier, AdminMatchesSnapshot>(
      AdminMatchesNotifier.new,
    );

void _requireOnline() {
  if (!ConnectivityService.isOnline) {
    throw const AdminMatchesFailure(AdminMatchesFailureKind.offline);
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

int _boundedInt(Object? value, {required String field, required int maximum}) {
  if (value is! num || value.toInt() != value) {
    throw FormatException('Invalid $field.');
  }
  final parsed = value.toInt();
  if (parsed < 0 || parsed > maximum) throw FormatException('Invalid $field.');
  return parsed;
}

DateTime _requiredDate(Object? value, {required String field}) {
  if (value is! String || value.length > 32) {
    throw FormatException('Invalid $field.');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) throw FormatException('Invalid $field.');
  return DateTime.utc(parsed.year, parsed.month, parsed.day);
}

String _requiredTime(Object? value, {required String field}) {
  if (value is! String ||
      !RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d(?::[0-5]\d)?$').hasMatch(value)) {
    throw FormatException('Invalid $field.');
  }
  return value.length == 5 ? '$value:00' : value;
}

String _dateOnly(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
