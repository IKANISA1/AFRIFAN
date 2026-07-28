import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import '../official_membership_tiers.dart';
import '../widgets/contribution_history.dart';

enum MembershipFailureKind {
  permissionDenied,
  conflict,
  securityTimeout,
  unknown,
}

class MembershipFailure implements Exception {
  const MembershipFailure(this.kind);

  final MembershipFailureKind kind;

  static MembershipFailure fromError(Object error) {
    if (error is MembershipFailure) {
      return error;
    }
    if (error is TimeoutException) {
      return const MembershipFailure(MembershipFailureKind.securityTimeout);
    }

    final normalized = error.toString().toLowerCase();
    if (normalized.contains('permission') ||
        normalized.contains('forbidden') ||
        normalized.contains('unauthorized') ||
        normalized.contains('row-level security') ||
        normalized.contains('rls')) {
      return const MembershipFailure(MembershipFailureKind.permissionDenied);
    }
    if (normalized.contains('conflict') ||
        normalized.contains('changed') ||
        normalized.contains('stale') ||
        normalized.contains('revision')) {
      return const MembershipFailure(MembershipFailureKind.conflict);
    }
    return const MembershipFailure(MembershipFailureKind.unknown);
  }

  @override
  String toString() => 'MembershipFailure(${kind.name})';
}

final membershipLoadTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 12),
);

/// M-3: Read-side snapshot for the MembershipScreen.
///
/// Replaces manual `setState` for data loading with a cacheable
/// AsyncNotifier that provides loading/error/data states.
class MembershipSnapshot {
  const MembershipSnapshot({
    required this.packages,
    required this.membership,
    required this.applications,
    required this.contributions,
    this.isStale = false,
    this.recoveryMessage,
  });

  final List<Map<String, dynamic>> packages;
  final Map<String, dynamic>? membership;
  final List<Map<String, dynamic>> applications;
  final List<ContributionRecord> contributions;
  final bool isStale;
  final String? recoveryMessage;

  bool get hasPackages => packages.isNotEmpty;
  bool get hasMembership => membership != null;
  bool get hasAnyContent =>
      packages.isNotEmpty ||
      membership != null ||
      applications.isNotEmpty ||
      contributions.isNotEmpty;

  Map<String, dynamic>? get latestPendingApplication {
    for (final app in applications) {
      final status = (app['status'] ?? '').toString().toLowerCase();
      if (status == 'pending' || status == 'submitted') return app;
    }
    return null;
  }

  MembershipSnapshot copyWith({
    List<Map<String, dynamic>>? packages,
    Map<String, dynamic>? membership,
    List<Map<String, dynamic>>? applications,
    List<ContributionRecord>? contributions,
    bool? isStale,
    String? recoveryMessage,
  }) {
    return MembershipSnapshot(
      packages: packages ?? this.packages,
      membership: membership ?? this.membership,
      applications: applications ?? this.applications,
      contributions: contributions ?? this.contributions,
      isStale: isStale ?? this.isStale,
      recoveryMessage: recoveryMessage ?? this.recoveryMessage,
    );
  }
}

class MembershipNotifier extends AsyncNotifier<MembershipSnapshot> {
  MembershipNotifier({Future<MembershipSnapshot> Function()? loadOverride})
    : _loadOverride = loadOverride;

  final Future<MembershipSnapshot> Function()? _loadOverride;
  bool _connectivityBound = false;
  bool _refreshing = false;
  late bool _wasOnline;

  @override
  Future<MembershipSnapshot> build() async {
    _bindConnectivity();
    return _load();
  }

  Future<MembershipSnapshot> _load() async {
    if (!ConnectivityService.isOnline) {
      throw StateError('Connect to load membership details.');
    }
    try {
      return await _loadRemote().timeout(
        ref.read(membershipLoadTimeoutProvider),
      );
    } catch (error) {
      throw MembershipFailure.fromError(error);
    }
  }

  Future<MembershipSnapshot> _loadRemote() async {
    final loadOverride = _loadOverride;
    if (loadOverride != null) {
      return loadOverride();
    }

    final client = ref.read(supabaseClientProvider);
    final resolver = ClubScopeResolver(client: client);
    final scope = await resolver.requireResolved();

    if (scope.clubId == null) {
      throw StateError('Membership requires a numeric club_id scope.');
    }

    final clubId = scope.clubId!;
    final userId = client.auth.currentUser?.id;

    final packages = await _loadPackages(client: client, clubId: clubId);

    // Load user-specific data
    Map<String, dynamic>? membership;
    List<Map<String, dynamic>> applications = const <Map<String, dynamic>>[];
    List<ContributionRecord> contributions = const <ContributionRecord>[];

    if (userId != null) {
      membership = await client
          .from('fan_memberships')
          .select()
          .eq('user_id', userId)
          .eq('club_id', clubId)
          .order('joined_at', ascending: false)
          .limit(1)
          .maybeSingle();

      applications = List<Map<String, dynamic>>.from(
        await client
            .from('membership_applications')
            .select()
            .eq('user_id', userId)
            .eq('club_id', clubId)
            .order('application_date', ascending: false)
            .limit(12),
      );

      contributions = await _loadContributionHistory(
        client: client,
        clubId: clubId,
        userId: userId,
        membership: membership,
      );
    }

    return MembershipSnapshot(
      packages: packages,
      membership: membership == null
          ? null
          : Map<String, dynamic>.from(membership),
      applications: applications,
      contributions: contributions,
    );
  }

  /// Refresh after a write operation (join, activate, etc.).
  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    final previous = state.valueOrNull;
    state = const AsyncLoading<MembershipSnapshot>().copyWithPrevious(state);
    try {
      state = AsyncData(await _load());
    } catch (error, stackTrace) {
      state = previous != null && previous.hasAnyContent
          ? AsyncData(
              previous.copyWith(
                isStale: true,
                recoveryMessage:
                    'Showing saved membership details. Reconnect and refresh before changing membership.',
              ),
            )
          : AsyncError(error, stackTrace);
    } finally {
      _refreshing = false;
    }
  }

  Future<List<Map<String, dynamic>>> _loadPackages({
    required SupabaseClient client,
    required int clubId,
  }) async {
    try {
      final tiersResponse = await client
          .from('membership_tiers')
          .select()
          .eq('active', true)
          .order('sort_order', ascending: true);
      final tiers = List<Map<String, dynamic>>.from(
        tiersResponse,
      ).map(normalizeMembershipTierRow).toList(growable: false);
      if (tiers.isNotEmpty) {
        return tiers;
      }
    } catch (_) {
      // Fall through to the official launch-safe categories.
    }

    return officialMembershipPackages();
  }

  Future<List<ContributionRecord>> _loadContributionHistory({
    required SupabaseClient client,
    required int clubId,
    required String userId,
    required Map<String, dynamic>? membership,
  }) async {
    final rows = List<Map<String, dynamic>>.from(
      await client
          .from('initiative_contributions')
          .select('initiative_id, amount, status, created_at')
          .eq('user_id', userId)
          .eq('club_id', clubId)
          .order('created_at', ascending: false)
          .limit(8),
    );
    if (rows.isEmpty) return const <ContributionRecord>[];

    final initiativeIds = rows
        .map((row) => row['initiative_id']?.toString())
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);

    final initiativeTitles = <String, String>{};
    if (initiativeIds.isNotEmpty) {
      final initiatives = List<Map<String, dynamic>>.from(
        await client
            .from('initiatives')
            .select('id, title')
            .inFilter('id', initiativeIds),
      );
      for (final initiative in initiatives) {
        final id = initiative['id']?.toString();
        final title = initiative['title']?.toString().trim();
        if (id != null && id.isNotEmpty && title != null && title.isNotEmpty) {
          initiativeTitles[id] = title;
        }
      }
    }

    return rows
        .map(
          (row) => ContributionRecord(
            date: _formatDate(row['created_at']?.toString()),
            amount: (row['amount'] as num?)?.toInt() ?? 0,
            label:
                initiativeTitles[row['initiative_id']?.toString()] ??
                'Club contribution',
            status: _normalizeStatus(row['status']?.toString()),
          ),
        )
        .toList(growable: false);
  }

  static String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final date = DateTime.tryParse(iso);
    if (date == null) return '';
    return '${date.day}/${date.month}/${date.year}';
  }

  static String _normalizeStatus(String? raw) {
    if (raw == null || raw.isEmpty) return 'pending';
    final lower = raw.toLowerCase();
    if (lower == 'confirmed' || lower == 'completed') return 'confirmed';
    if (lower == 'failed' || lower == 'cancelled') return 'failed';
    return 'pending';
  }

  void _bindConnectivity() {
    if (_connectivityBound) return;
    _connectivityBound = true;
    _wasOnline = ConnectivityService.isOnline;
    ConnectivityService.onlineNotifier.addListener(_handleConnectivityChange);
    ref.onDispose(() {
      ConnectivityService.onlineNotifier.removeListener(
        _handleConnectivityChange,
      );
    });
  }

  void _handleConnectivityChange() {
    final isOnline = ConnectivityService.isOnline;
    final restored = !_wasOnline && isOnline;
    _wasOnline = isOnline;

    if (!isOnline) {
      final current = state.valueOrNull;
      if (current != null && current.hasAnyContent) {
        state = AsyncData(
          current.copyWith(
            isStale: true,
            recoveryMessage:
                'Showing saved membership details. Reconnect and refresh before changing membership.',
          ),
        );
      }
      return;
    }

    if (restored) {
      unawaited(refresh());
    }
  }
}

final membershipProvider =
    AsyncNotifierProvider<MembershipNotifier, MembershipSnapshot>(() {
      return MembershipNotifier();
    });
