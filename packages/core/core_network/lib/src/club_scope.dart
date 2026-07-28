import 'package:supabase_flutter/supabase_flutter.dart';

class ClubScope {
  const ClubScope({required this.partnerId, required this.clubId});

  final String partnerId;
  final int? clubId;

  bool get isResolved => clubId != null || partnerId.isNotEmpty;
}

/// Resolves the active club tenancy context from auth metadata or partner hints.
class ClubScopeResolver {
  ClubScopeResolver({required SupabaseClient client}) : _client = client;

  final SupabaseClient _client;

  static const _configuredClubId = String.fromEnvironment('CLUB_ID');

  int? get currentClubId {
    final user = _client.auth.currentUser;
    final candidates = <Object?>[
      user?.appMetadata['club_id'],
      user?.userMetadata?['club_id'],
      user?.appMetadata['clubId'],
      user?.userMetadata?['clubId'],
      _configuredClubId,
    ];

    return firstValidClubId(candidates);
  }

  static int? firstValidClubId(Iterable<Object?> candidates) {
    for (final candidate in candidates) {
      final parsed = int.tryParse(candidate?.toString().trim() ?? '');
      if (parsed != null && parsed > 0) {
        return parsed;
      }
    }

    return null;
  }

  Future<ClubScope> resolve(String? partnerId) async {
    final normalized = partnerId?.trim() ?? '';
    final requestingClubId = currentClubId;
    final numericPartnerId = int.tryParse(normalized);
    if (numericPartnerId != null) {
      return ClubScope(partnerId: normalized, clubId: numericPartnerId);
    }

    if (normalized.isNotEmpty) {
      try {
        final row = await _client
            .from('african_football_clubs')
            .select('id')
            .eq('club_slug', normalized)
            .maybeSingle();
        final resolvedClubId = int.tryParse(row?['id']?.toString() ?? '');
        if (resolvedClubId != null) {
          return ClubScope(partnerId: normalized, clubId: resolvedClubId);
        }
      } catch (_) {
        // This lookup is best-effort in tests and partial environments.
      }
    }

    return ClubScope(
      partnerId: normalized.isNotEmpty
          ? normalized
          : (requestingClubId?.toString() ?? ''),
      clubId: requestingClubId,
    );
  }

  Future<ClubScope> requireResolved([String? partnerId]) async {
    final scope = await resolve(partnerId);
    if (scope.isResolved) {
      return scope;
    }
    throw StateError('Could not resolve the active club scope.');
  }

  dynamic apply(dynamic query, ClubScope scope) {
    if (scope.clubId != null) {
      return query.eq('club_id', scope.clubId!);
    }
    if (scope.partnerId.isNotEmpty) {
      return query.eq('partner_id', scope.partnerId);
    }
    return query;
  }

  Map<String, Object?> payload(ClubScope scope) {
    return <String, Object?>{
      if (scope.clubId != null) 'club_id': scope.clubId,
      if (scope.partnerId.isNotEmpty) 'partner_id': scope.partnerId,
    };
  }
}
