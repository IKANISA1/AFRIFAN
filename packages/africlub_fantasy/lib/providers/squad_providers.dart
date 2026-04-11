import 'package:africlub_fantasy/models/chip_state.dart';
import 'package:africlub_fantasy/models/fantasy_entry.dart';
import 'package:africlub_fantasy/models/fantasy_gameweek_state.dart';
import 'package:africlub_fantasy/models/squad_selection.dart';
import 'package:africlub_fantasy/repositories/squad_repository.dart';
import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef SquadRequest = ({String entryId, String gameweekId});
typedef EntryGameweekRequest = ({String entryId, String gameweekId});

final squadRepositoryProvider = Provider<SquadRepository>((ref) {
  return SquadRepository(ref.watch(supabaseClientProvider));
});

final myEntryProvider = FutureProvider.family<FantasyEntry?, String>((
  ref,
  competitionId,
) {
  return ref.watch(squadRepositoryProvider).getMyEntry(competitionId);
});

final squadForGameweekProvider =
    FutureProvider.family<List<SquadSelection>, SquadRequest>((ref, request) {
      return ref
          .watch(squadRepositoryProvider)
          .getSquadForGameweek(request.entryId, request.gameweekId);
    });

final entryGameweekStateProvider =
    FutureProvider.family<FantasyGameweekState, EntryGameweekRequest>((
      ref,
      request,
    ) {
      return ref
          .watch(squadRepositoryProvider)
          .getEntryGameweekState(
            entryId: request.entryId,
            gameweekId: request.gameweekId,
          );
    });

final chipStatesProvider =
    FutureProvider.family<List<ChipState>, EntryGameweekRequest>((ref, request) {
      return ref.watch(squadRepositoryProvider).getChipStates(
            entryId: request.entryId,
            gameweekId: request.gameweekId,
          );
    });
