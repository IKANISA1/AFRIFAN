import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import '../widgets/contribution_history.dart';

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
  });

  final List<Map<String, dynamic>> packages;
  final Map<String, dynamic>? membership;
  final List<Map<String, dynamic>> applications;
  final List<ContributionRecord> contributions;

  bool get hasPackages => packages.isNotEmpty;
  bool get hasMembership => membership != null;

  Map<String, dynamic>? get latestPendingApplication {
    for (final app in applications) {
      final status = (app['status'] ?? '').toString().toLowerCase();
      if (status == 'pending' || status == 'submitted') return app;
    }
    return null;
  }
}

class MembershipNotifier extends AsyncNotifier<MembershipSnapshot> {
  @override
  Future<MembershipSnapshot> build() async {
    final client = ref.read(supabaseClientProvider);
    final resolver = ClubScopeResolver(client: client);
    final scope = await resolver.requireResolved();

    if (scope.clubId == null) {
      throw StateError('Membership requires a numeric club_id scope.');
    }

    final clubId = scope.clubId!;
    final userId = client.auth.currentUser?.id;

    // Load packages (always)
    final packagesResponse = await client
        .from('membership_packages')
        .select()
        .eq('club_id', clubId)
        .eq('is_active', true)
        .order('sort_order', ascending: true);

    final packages = List<Map<String, dynamic>>.from(packagesResponse);

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
    state = const AsyncLoading<MembershipSnapshot>();
    state = await AsyncValue.guard(build);
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
}

final membershipProvider =
    AsyncNotifierProvider<MembershipNotifier, MembershipSnapshot>(() {
      return MembershipNotifier();
    });
