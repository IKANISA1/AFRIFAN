import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'admin_providers.dart';
import 'repositories/admin_repository.dart';

enum AdminCmsPhase { ready, degraded }

enum AdminCmsFailureKind {
  offline,
  permissionDenied,
  conflict,
  securityTimeout,
  unknown,
}

class AdminCmsFailure implements Exception {
  const AdminCmsFailure(this.kind);

  final AdminCmsFailureKind kind;

  static AdminCmsFailure fromError(Object error) {
    if (error is AdminCmsFailure) return error;
    if (error is TimeoutException) {
      return const AdminCmsFailure(AdminCmsFailureKind.securityTimeout);
    }
    final normalized = error.toString().toLowerCase();
    if (normalized.contains('socketexception') ||
        normalized.contains('failed host lookup') ||
        normalized.contains('network is unreachable') ||
        normalized.contains('connection refused') ||
        normalized.contains('offline')) {
      return const AdminCmsFailure(AdminCmsFailureKind.offline);
    }
    if (normalized.contains('permission') ||
        normalized.contains('forbidden') ||
        normalized.contains('unauthorized') ||
        normalized.contains('admin access required') ||
        normalized.contains('row-level security') ||
        normalized.contains('rls') ||
        normalized.contains('42501')) {
      return const AdminCmsFailure(AdminCmsFailureKind.permissionDenied);
    }
    if (normalized.contains('conflict') ||
        normalized.contains('changed') ||
        normalized.contains('stale') ||
        normalized.contains('revision') ||
        normalized.contains('409')) {
      return const AdminCmsFailure(AdminCmsFailureKind.conflict);
    }
    return const AdminCmsFailure(AdminCmsFailureKind.unknown);
  }

  @override
  String toString() => 'AdminCmsFailure(${kind.name})';
}

class AdminCmsSnapshot {
  const AdminCmsSnapshot({
    required this.articles,
    required this.quickActions,
    required this.partners,
    required this.partnerServices,
    required this.predictionCompetitions,
    required this.competitionCatalog,
    required this.contentBlocks,
    required this.platformFeatures,
    required this.auditLogs,
    this.phase = AdminCmsPhase.ready,
    this.failure,
    this.isMutating = false,
    this.mutationOutcomeUnconfirmed = false,
  });

  const AdminCmsSnapshot.empty()
    : articles = const <Map<String, dynamic>>[],
      quickActions = const <Map<String, dynamic>>[],
      partners = const <Map<String, dynamic>>[],
      partnerServices = const <Map<String, dynamic>>[],
      predictionCompetitions = const <Map<String, dynamic>>[],
      competitionCatalog = const <Map<String, dynamic>>[],
      contentBlocks = const <Map<String, dynamic>>[],
      platformFeatures = const <Map<String, dynamic>>[],
      auditLogs = const <Map<String, dynamic>>[],
      phase = AdminCmsPhase.ready,
      failure = null,
      isMutating = false,
      mutationOutcomeUnconfirmed = false;

  factory AdminCmsSnapshot.fromRawCollections(List<Object?> results) {
    if (results.length != 9) {
      throw const FormatException('Invalid CMS workspace.');
    }
    return AdminCmsSnapshot(
      articles: _strictRows(results[0], maximum: 50, fields: _articleFields),
      quickActions: _strictRows(
        results[1],
        maximum: 50,
        fields: _quickActionFields,
      ),
      partners: _strictRows(results[2], maximum: 100, fields: _partnerFields),
      partnerServices: _strictRows(
        results[3],
        maximum: 200,
        fields: _partnerServiceFields,
        nestedFields: const <String, Set<String>>{
          'partner': <String>{'id', 'name', 'slug'},
        },
      ),
      predictionCompetitions: _strictRows(
        results[4],
        maximum: 200,
        fields: _predictionCompetitionFields,
      ),
      competitionCatalog: _strictRows(
        results[5],
        maximum: 200,
        fields: _competitionFields,
      ),
      contentBlocks: _strictRows(
        results[6],
        maximum: 100,
        fields: _contentBlockFields,
        nestedFields: const <String, Set<String>>{
          'content': <String>{'component'},
          'feature': <String>{'id', 'feature_key', 'display_name'},
        },
      ),
      platformFeatures: _strictRows(
        results[7],
        maximum: 100,
        fields: _platformFeatureFields,
      ),
      auditLogs: _strictRows(
        results[8],
        maximum: 100,
        fields: _auditLogFields,
        nestedFields: const <String, Set<String>>{
          'feature': <String>{'id', 'feature_key', 'display_name'},
        },
      ),
    );
  }

  final List<Map<String, dynamic>> articles;
  final List<Map<String, dynamic>> quickActions;
  final List<Map<String, dynamic>> partners;
  final List<Map<String, dynamic>> partnerServices;
  final List<Map<String, dynamic>> predictionCompetitions;
  final List<Map<String, dynamic>> competitionCatalog;
  final List<Map<String, dynamic>> contentBlocks;
  final List<Map<String, dynamic>> platformFeatures;
  final List<Map<String, dynamic>> auditLogs;
  final AdminCmsPhase phase;
  final AdminCmsFailure? failure;
  final bool isMutating;
  final bool mutationOutcomeUnconfirmed;

  bool get isEmpty =>
      articles.isEmpty &&
      quickActions.isEmpty &&
      partners.isEmpty &&
      partnerServices.isEmpty &&
      predictionCompetitions.isEmpty &&
      contentBlocks.isEmpty;

  bool get actionsEnabled =>
      phase == AdminCmsPhase.ready &&
      failure == null &&
      !isMutating &&
      !mutationOutcomeUnconfirmed;

  AdminCmsSnapshot copyWith({
    AdminCmsPhase? phase,
    AdminCmsFailure? failure,
    bool clearFailure = false,
    bool? isMutating,
    bool? mutationOutcomeUnconfirmed,
  }) {
    return AdminCmsSnapshot(
      articles: articles,
      quickActions: quickActions,
      partners: partners,
      partnerServices: partnerServices,
      predictionCompetitions: predictionCompetitions,
      competitionCatalog: competitionCatalog,
      contentBlocks: contentBlocks,
      platformFeatures: platformFeatures,
      auditLogs: auditLogs,
      phase: phase ?? this.phase,
      failure: clearFailure ? null : failure ?? this.failure,
      isMutating: isMutating ?? this.isMutating,
      mutationOutcomeUnconfirmed:
          mutationOutcomeUnconfirmed ?? this.mutationOutcomeUnconfirmed,
    );
  }
}

abstract interface class AdminCmsGateway {
  Future<AdminCmsSnapshot> load();
}

class SupabaseAdminCmsGateway implements AdminCmsGateway {
  const SupabaseAdminCmsGateway(this._repository);

  final AdminRepository _repository;

  @override
  Future<AdminCmsSnapshot> load() async {
    if (!await _repository.isCurrentUserAdmin()) {
      throw const AdminCmsFailure(AdminCmsFailureKind.permissionDenied);
    }

    final results = await Future.wait<dynamic>(<Future<dynamic>>[
      _repository.getNewsArticles(limit: 50),
      _repository.getQuickActions(limit: 50),
      _repository.getPartners(limit: 100),
      _repository.getPartnerServices(limit: 200),
      _repository.getPredictionSupportedCompetitions(limit: 200),
      _repository.getFootballCompetitions(limit: 200),
      _repository.getPlatformContentBlocks(limit: 100),
      _repository.getPlatformFeatures(limit: 100),
      _repository.getPlatformFeatureAuditLogs(limit: 100),
    ]);

    return AdminCmsSnapshot.fromRawCollections(results);
  }
}

final adminCmsGatewayProvider = Provider<AdminCmsGateway>((ref) {
  return SupabaseAdminCmsGateway(ref.watch(adminRepositoryProvider));
});

final adminCmsLoadTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 12),
);

final adminCmsMutationTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 12),
);

final adminCmsEnabledProvider = Provider<bool>((ref) => true);

class AdminCmsNotifier extends AsyncNotifier<AdminCmsSnapshot> {
  var _busy = false;

  @override
  Future<AdminCmsSnapshot> build() => _load();

  Future<void> refresh() async {
    if (_busy) return;
    _busy = true;
    final previous = state.valueOrNull;
    state = const AsyncLoading<AdminCmsSnapshot>().copyWithPrevious(state);
    try {
      state = AsyncData(await _load());
    } catch (error, stackTrace) {
      _applyFailure(AdminCmsFailure.fromError(error), stackTrace, previous);
    } finally {
      _busy = false;
    }
  }

  Future<bool> runMutation(
    Future<void> Function(AdminRepository repository) mutation,
  ) async {
    if (_busy) return false;
    final previous = state.valueOrNull;
    if (previous == null || !previous.actionsEnabled) return false;

    _busy = true;
    state = AsyncData(previous.copyWith(isMutating: true));
    try {
      if (!ConnectivityService.isOnline) {
        throw const AdminCmsFailure(AdminCmsFailureKind.offline);
      }
      final repository = ref.read(adminRepositoryProvider);
      if (!await repository.isCurrentUserAdmin().timeout(
        ref.read(adminCmsMutationTimeoutProvider),
      )) {
        throw const AdminCmsFailure(AdminCmsFailureKind.permissionDenied);
      }
      await mutation(
        repository,
      ).timeout(ref.read(adminCmsMutationTimeoutProvider));
      state = AsyncData(await _load());
      return true;
    } catch (error, stackTrace) {
      final failure = AdminCmsFailure.fromError(error);
      final uncertain =
          failure.kind == AdminCmsFailureKind.securityTimeout ||
          failure.kind == AdminCmsFailureKind.conflict;
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

  Future<AdminCmsSnapshot> _load() async {
    if (!ConnectivityService.isOnline) {
      throw const AdminCmsFailure(AdminCmsFailureKind.offline);
    }
    try {
      return await ref
          .read(adminCmsGatewayProvider)
          .load()
          .timeout(ref.read(adminCmsLoadTimeoutProvider));
    } catch (error, stackTrace) {
      final failure = AdminCmsFailure.fromError(error);
      AfriLogger.warn(
        'AdminCmsNotifier',
        'CMS workspace load failed.',
        failure,
        stackTrace,
      );
      throw failure;
    }
  }

  void _applyFailure(
    AdminCmsFailure failure,
    StackTrace stackTrace,
    AdminCmsSnapshot? previous, {
    bool mutationOutcomeUnconfirmed = false,
  }) {
    if (failure.kind == AdminCmsFailureKind.permissionDenied) {
      state = AsyncData(
        AdminCmsSnapshot(
          articles: const <Map<String, dynamic>>[],
          quickActions: const <Map<String, dynamic>>[],
          partners: const <Map<String, dynamic>>[],
          partnerServices: const <Map<String, dynamic>>[],
          predictionCompetitions: const <Map<String, dynamic>>[],
          competitionCatalog: const <Map<String, dynamic>>[],
          contentBlocks: const <Map<String, dynamic>>[],
          platformFeatures: const <Map<String, dynamic>>[],
          auditLogs: const <Map<String, dynamic>>[],
          phase: AdminCmsPhase.degraded,
          failure: failure,
        ),
      );
      return;
    }
    state = previous != null
        ? AsyncData(
            previous.copyWith(
              phase: AdminCmsPhase.degraded,
              failure: failure,
              isMutating: false,
              mutationOutcomeUnconfirmed: mutationOutcomeUnconfirmed,
            ),
          )
        : AsyncError(failure, stackTrace);
  }
}

final adminCmsProvider =
    AsyncNotifierProvider<AdminCmsNotifier, AdminCmsSnapshot>(
      AdminCmsNotifier.new,
    );

List<Map<String, dynamic>> _strictRows(
  Object? value, {
  required int maximum,
  required Set<String> fields,
  Map<String, Set<String>> nestedFields = const <String, Set<String>>{},
}) {
  if (value is! List || value.length > maximum) {
    throw const FormatException('Invalid CMS collection.');
  }
  final seenIds = <String>{};
  return List<Map<String, dynamic>>.unmodifiable(
    value.map((raw) {
      if (raw is! Map) throw const FormatException('Invalid CMS record.');
      final source = Map<String, dynamic>.from(raw);
      final output = <String, dynamic>{};
      for (final field in fields) {
        final fieldValue = source[field];
        if (fieldValue == null) continue;
        if (nestedFields.containsKey(field)) {
          if (fieldValue is! Map) {
            throw const FormatException('Invalid CMS relationship.');
          }
          final nested = Map<String, dynamic>.from(fieldValue);
          output[field] = <String, dynamic>{
            for (final nestedField in nestedFields[field]!)
              if (nested[nestedField] != null)
                nestedField: _boundedScalar(nested[nestedField]),
          };
        } else {
          output[field] = _boundedScalar(fieldValue);
        }
      }
      final identity = output['id'] ?? output['support_id'];
      if (identity != null) {
        final id = identity.toString();
        if (id.length > 128 || !seenIds.add(id)) {
          throw const FormatException('Invalid CMS record identity.');
        }
      }
      return Map<String, dynamic>.unmodifiable(output);
    }),
  );
}

Object _boundedScalar(Object value) {
  if (value is bool) return value;
  if (value is num) {
    if (!value.isFinite || value.abs() > 1000000000000) {
      throw const FormatException('Invalid CMS number.');
    }
    return value;
  }
  if (value is String) {
    final normalized = value.trim();
    if (normalized.length > 4000) {
      throw const FormatException('Invalid CMS text.');
    }
    return normalized;
  }
  throw const FormatException('Invalid CMS value.');
}

const _articleFields = <String>{
  'id',
  'title',
  'subtitle',
  'body',
  'category',
  'image_url',
  'is_published',
  'is_featured',
  'sort_order',
  'published_at',
  'created_at',
};
const _quickActionFields = <String>{
  'id',
  'action_key',
  'title',
  'subtitle',
  'route',
  'icon_key',
  'emoji',
  'country',
  'sort_order',
  'is_active',
};
const _partnerFields = <String>{
  'id',
  'name',
  'slug',
  'category',
  'country',
  'emoji',
  'subtitle',
  'description',
  'is_active',
  'sort_order',
  'gamification_enabled',
};
const _partnerServiceFields = <String>{
  'id',
  'partner_id',
  'title',
  'service_slug',
  'subtitle',
  'emoji',
  'category',
  'cta_label',
  'cta_action',
  'country',
  'sort_order',
  'is_active',
  'gamification_enabled',
  'partner',
};
const _predictionCompetitionFields = <String>{
  'support_id',
  'competition_id',
  'name',
  'competition_kind',
  'fixture_count',
  'format_notes',
  'highlight_label',
  'support_sort_order',
  'is_supported',
};
const _competitionFields = <String>{
  'id',
  'name',
  'competition_kind',
  'fixture_count',
  'format_notes',
};
const _contentBlockFields = <String>{
  'id',
  'block_key',
  'block_type',
  'title',
  'subtitle',
  'content',
  'target_channel',
  'placement_key',
  'feature_id',
  'is_active',
  'sort_order',
  'feature',
};
const _platformFeatureFields = <String>{
  'id',
  'feature_key',
  'display_name',
  'is_enabled',
};
const _auditLogFields = <String>{
  'id',
  'action',
  'notes',
  'created_at',
  'feature',
};
