import 'package:supabase_flutter/supabase_flutter.dart';

class ClubScope {
  const ClubScope({required this.partnerId, required this.clubId});

  /// Legacy commercial-partner metadata.
  ///
  /// This value may be retained on compatibility payloads, but it is never a
  /// tenant boundary. Club-owned reads and writes are authorized by [clubId].
  final String partnerId;
  final int? clubId;

  bool get isResolved => clubId != null && clubId! > 0;

  int get requiredClubId {
    final value = clubId;
    if (value == null || value <= 0) {
      throw StateError('Could not resolve the required club_id scope.');
    }
    return value;
  }

  Map<String, Object?> toWritePayload() {
    return <String, Object?>{
      'club_id': requiredClubId,
      if (partnerId.isNotEmpty) 'partner_id': partnerId,
    };
  }
}

/// Resolves the active club tenancy context from trusted auth metadata or a
/// numeric club id / public club slug hint.
///
/// `partner_id` is compatibility metadata only. It must never be accepted as
/// the sole tenant boundary for a club-owned query or mutation.
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

  Future<ClubScope> resolve(String? clubScopeHint) async {
    final normalized = clubScopeHint?.trim() ?? '';
    final requestingClubId = currentClubId;
    final numericClubId = int.tryParse(normalized);

    if (requestingClubId != null) {
      if (numericClubId != null &&
          numericClubId > 0 &&
          numericClubId != requestingClubId) {
        throw StateError(
          'Requested club scope does not match the authenticated club.',
        );
      }
      return ClubScope(
        partnerId: numericClubId == null ? normalized : '',
        clubId: requestingClubId,
      );
    }

    if (numericClubId != null && numericClubId > 0) {
      return ClubScope(partnerId: '', clubId: numericClubId);
    }

    if (normalized.isNotEmpty) {
      try {
        final row = await _client
            .from('african_football_clubs')
            .select('id')
            .eq('club_slug', normalized)
            .maybeSingle();
        final resolvedClubId = int.tryParse(row?['id']?.toString() ?? '');
        if (resolvedClubId != null && resolvedClubId > 0) {
          return ClubScope(partnerId: '', clubId: resolvedClubId);
        }
      } catch (_) {
        // This lookup is best-effort in tests and partial environments.
      }
    }

    return ClubScope(partnerId: normalized, clubId: null);
  }

  Future<ClubScope> requireResolved([String? clubScopeHint]) async {
    final scope = await resolve(clubScopeHint);
    if (scope.isResolved) {
      return scope;
    }
    throw StateError('Could not resolve the active club scope.');
  }

  dynamic apply(dynamic query, ClubScope scope) {
    return query.eq('club_id', scope.requiredClubId);
  }

  Map<String, Object?> payload(ClubScope scope) {
    return scope.toWritePayload();
  }
}
