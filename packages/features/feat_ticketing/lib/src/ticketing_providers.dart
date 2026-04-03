import 'package:core_auth/core_auth.dart';
import 'package:core_network/core_network.dart';
import 'package:feat_club/feat_club.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final ticketMatchesProvider = FutureProvider<List<ClubMatch>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const <ClubMatch>[];
  return ref.watch(clubRepositoryProvider).getMatches(user.clubId);
});

final ticketMatchProvider =
    FutureProvider.family<ClubMatch?, String>((ref, matchId) async {
  final user = ref.watch(currentUserProvider);
  if (user == null || matchId.isEmpty) return null;

  final client = ref.watch(supabaseClientProvider);
  var row = await client
      .from('matches')
      .select()
      .eq('partner_id', user.clubId)
      .eq('id', matchId)
      .maybeSingle();

  row ??= await client.from('matches').select().eq('id', matchId).maybeSingle();

  if (row == null) return null;
  return ClubMatch.fromJson(Map<String, dynamic>.from(row));
});

final myTicketsProvider = FutureProvider<List<ClubTicket>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const <ClubTicket>[];
  return ref.watch(clubRepositoryProvider).getMyTickets(user.id);
});

final myTicketProvider =
    FutureProvider.family<ClubTicket?, String>((ref, ticketId) async {
  final user = ref.watch(currentUserProvider);
  if (user == null || ticketId.isEmpty) return null;

  final row = await ref
      .watch(supabaseClientProvider)
      .from('tickets')
      .select('*, match:matches(*)')
      .eq('user_id', user.id)
      .eq('id', ticketId)
      .maybeSingle();

  if (row == null) return null;
  return ClubTicket.fromJson(Map<String, dynamic>.from(row));
});
