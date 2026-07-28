import 'dart:async';

import 'package:core_auth/core_auth.dart';
import 'package:core_network/core_network.dart';
import 'package:feat_club/feat_club.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum TicketMatchesFailureKind {
  permissionDenied,
  conflict,
  securityTimeout,
  unknown,
}

class TicketMatchesFailure implements Exception {
  const TicketMatchesFailure(this.kind);

  final TicketMatchesFailureKind kind;

  static TicketMatchesFailure fromError(Object error) {
    if (error is TicketMatchesFailure) {
      return error;
    }
    if (error is TimeoutException) {
      return const TicketMatchesFailure(
        TicketMatchesFailureKind.securityTimeout,
      );
    }

    final normalized = error.toString().toLowerCase();
    if (normalized.contains('permission') ||
        normalized.contains('forbidden') ||
        normalized.contains('unauthorized') ||
        normalized.contains('row-level security') ||
        normalized.contains('rls')) {
      return const TicketMatchesFailure(
        TicketMatchesFailureKind.permissionDenied,
      );
    }
    if (normalized.contains('conflict') ||
        normalized.contains('changed') ||
        normalized.contains('stale') ||
        normalized.contains('revision')) {
      return const TicketMatchesFailure(TicketMatchesFailureKind.conflict);
    }
    return const TicketMatchesFailure(TicketMatchesFailureKind.unknown);
  }

  @override
  String toString() => 'TicketMatchesFailure(${kind.name})';
}

final ticketMatchesTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 12),
);

final ticketMatchesProvider = FutureProvider<List<ClubMatch>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const <ClubMatch>[];
  try {
    return await ref
        .watch(clubRepositoryProvider)
        .getMatches(user.clubId)
        .timeout(ref.watch(ticketMatchesTimeoutProvider));
  } catch (error) {
    throw TicketMatchesFailure.fromError(error);
  }
});

final ticketMatchProvider =
    FutureProvider.family<ClubMatch?, String>((ref, matchId) async {
  final user = ref.watch(currentUserProvider);
  if (user == null || matchId.isEmpty) return null;

  final client = ref.watch(supabaseClientProvider);
  final resolver = ClubScopeResolver(client: client);
  final scope = await resolver.requireResolved(user.clubId);
  var query = client.from('unified_matches').select().eq('id', matchId);
  query = resolver.apply(query, scope);
  final row = await query.maybeSingle();

  if (row == null) return null;
  return ClubMatch.fromJson(Map<String, dynamic>.from(row));
});

final myTicketsProvider = FutureProvider<List<ClubTicket>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const <ClubTicket>[];
  return ref.watch(clubRepositoryProvider).getMyTickets(user.id, user.clubId);
});

final myTicketProvider =
    FutureProvider.family<ClubTicket?, String>((ref, ticketId) async {
  final user = ref.watch(currentUserProvider);
  if (user == null || ticketId.isEmpty) return null;

  final client = ref.watch(supabaseClientProvider);
  final resolver = ClubScopeResolver(client: client);
  final scope = await resolver.requireResolved(user.clubId);
  var query = client
      .from('tickets')
      .select('*, match:matches(*)')
      .eq('user_id', user.id)
      .eq('id', ticketId);
  query = resolver.apply(query, scope);
  final row = await query.maybeSingle();

  if (row == null) return null;
  return ClubTicket.fromJson(Map<String, dynamic>.from(row));
});
