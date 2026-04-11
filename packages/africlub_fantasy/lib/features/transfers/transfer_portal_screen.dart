import 'package:africlub_fantasy/core/constants.dart';
import 'package:africlub_fantasy/core/exceptions.dart';
import 'package:africlub_fantasy/features/shared/fantasy_ui.dart';
import 'package:africlub_fantasy/features/squad_builder/player_picker_sheet.dart';
import 'package:africlub_fantasy/features/transfers/transfer_cost_widget.dart';
import 'package:africlub_fantasy/features/transfers/transfer_panel_widget.dart';
import 'package:africlub_fantasy/models/chip_state.dart';
import 'package:africlub_fantasy/models/fantasy_gameweek_state.dart';
import 'package:africlub_fantasy/models/fantasy_player.dart';
import 'package:africlub_fantasy/models/squad_selection.dart';
import 'package:africlub_fantasy/providers/competition_providers.dart';
import 'package:africlub_fantasy/providers/player_providers.dart';
import 'package:africlub_fantasy/providers/scoring_providers.dart';
import 'package:africlub_fantasy/providers/squad_providers.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class TransferPortalScreen extends ConsumerStatefulWidget {
  const TransferPortalScreen({required this.slug, super.key});

  final String slug;

  @override
  ConsumerState<TransferPortalScreen> createState() =>
      _TransferPortalScreenState();
}

class _TransferPortalScreenState extends ConsumerState<TransferPortalScreen> {
  SquadSelection? _selectedOut;
  FantasyPlayer? _selectedIn;
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    final competitionAsync = ref.watch(competitionProvider(widget.slug));

    return competitionAsync.when(
      data: (competition) {
        final entryAsync = ref.watch(myEntryProvider(competition.id));
        final gameweekAsync = ref.watch(
          currentGameweekProvider(competition.id),
        );
        final playersAsync = ref.watch(
          competitionPlayersProvider(competition.id),
        );
        final entry = entryAsync.valueOrNull;
        final gameweek = gameweekAsync.valueOrNull;
        final state = entry != null && gameweek != null
            ? ref
                  .watch(
                    entryGameweekStateProvider((
                      entryId: entry.id,
                      gameweekId: gameweek.id,
                    )),
                  )
                  .valueOrNull
            : null;

        return FantasyScaffold(
          title: 'Transfers',
          bottomNavigationBar: state == null
              ? null
              : TransferCostWidget(
                  freeRemaining: _projectedFreeTransfers(state),
                  freeRemainingLabel: _projectedFreeTransfersLabel(state),
                  transferCost: _projectedTransferCost(state),
                  statusLabel: _transferStatusLabel(state),
                  bankBalance: state.bankBalance,
                  teamValue: state.teamValue,
                ),
          child: entryAsync.when(
            data: (entry) {
              if (entry == null) {
                return const Center(
                  child: FantasyStateCard.empty(
                    title: 'No entry found',
                    message: 'Build a squad before attempting transfers.',
                  ),
                );
              }

              return gameweekAsync.when(
                data: (gameweek) {
                  if (gameweek == null) {
                    return const Center(
                      child: FantasyStateCard.empty(
                        title: 'No active gameweek',
                        message: 'Transfers open when a valid gameweek exists.',
                      ),
                    );
                  }

                  final request = (entryId: entry.id, gameweekId: gameweek.id);
                  final squadAsync = ref.watch(
                    squadForGameweekProvider(request),
                  );
                  final stateAsync = ref.watch(
                    entryGameweekStateProvider(request),
                  );
                  final chipStatesAsync = ref.watch(
                    chipStatesProvider(request),
                  );

                  return playersAsync.when(
                    data: (players) => stateAsync.when(
                      data: (state) => chipStatesAsync.when(
                        data: (chips) => squadAsync.when(
                          data: (squad) => _buildContent(
                            context,
                            competitionId: competition.id,
                            entryId: entry.id,
                            gameweekId: gameweek.id,
                            players: players,
                            squad: squad,
                            state: state,
                            chips: chips,
                          ),
                          loading: () =>
                              const Center(child: FantasyStateCard.loading()),
                          error: (error, _) => Center(
                            child: FantasyStateCard.error(
                              title: 'Squad failed to load',
                              message: error.toString(),
                            ),
                          ),
                        ),
                        loading: () =>
                            const Center(child: FantasyStateCard.loading()),
                        error: (error, _) => Center(
                          child: FantasyStateCard.error(
                            title: 'Chips failed to load',
                            message: error.toString(),
                          ),
                        ),
                      ),
                      loading: () =>
                          const Center(child: FantasyStateCard.loading()),
                      error: (error, _) => Center(
                        child: FantasyStateCard.error(
                          title: 'Transfer state failed to load',
                          message: error.toString(),
                        ),
                      ),
                    ),
                    loading: () =>
                        const Center(child: FantasyStateCard.loading()),
                    error: (error, _) => Center(
                      child: FantasyStateCard.error(
                        title: 'Players failed to load',
                        message: error.toString(),
                      ),
                    ),
                  );
                },
                loading: () => const Center(child: FantasyStateCard.loading()),
                error: (error, _) => Center(
                  child: FantasyStateCard.error(
                    title: 'Gameweek failed to load',
                    message: error.toString(),
                  ),
                ),
              );
            },
            loading: () => const Center(child: FantasyStateCard.loading()),
            error: (error, _) => Center(
              child: FantasyStateCard.error(
                title: 'Entry failed to load',
                message: error.toString(),
              ),
            ),
          ),
        );
      },
      loading: () => const FantasyScaffold(
        title: 'Transfers',
        child: Center(child: FantasyStateCard.loading()),
      ),
      error: (error, _) => FantasyScaffold(
        title: 'Transfers',
        child: Center(
          child: FantasyStateCard.error(
            title: 'Competition failed to load',
            message: error.toString(),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context, {
    required String competitionId,
    required String entryId,
    required String gameweekId,
    required List<FantasyPlayer> players,
    required List<SquadSelection> squad,
    required FantasyGameweekState state,
    required List<ChipState> chips,
  }) {
    final currentSquad = squad
        .where((slot) => slot.player != null)
        .toList(growable: false);
    final availableBudget =
        state.bankBalance + (_selectedOut?.purchasePrice ?? 0);
    final remainingBudget = availableBudget - (_selectedIn?.price ?? 0);
    final clubCounts = <int, int>{};

    for (final slot in currentSquad) {
      clubCounts.update(
        slot.player!.teamId,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }

    final selectedOutgoing = _selectedOut;
    if (selectedOutgoing?.player != null) {
      final teamId = selectedOutgoing!.player!.teamId;
      final updatedCount = (clubCounts[teamId] ?? 1) - 1;
      if (updatedCount <= 0) {
        clubCounts.remove(teamId);
      } else {
        clubCounts[teamId] = updatedCount;
      }
    }

    final activeChipLabel = _chipLabelFromKey(state.chipPlayed);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        FantasySpacing.md,
        FantasySpacing.md,
        FantasySpacing.md,
        120,
      ),
      children: <Widget>[
        TransferPanelWidget(
          title: 'SELLING',
          subtitle: _selectedOut == null
              ? 'Select a player to sell from your current squad.'
              : 'Sell price £${(_selectedOut!.purchasePrice / 10).toStringAsFixed(1)}M',
          players: currentSquad,
          selectedPlayerId: _selectedOut?.playerId,
          onSelect: (selection) {
            setState(() {
              _selectedOut = selection;
              _selectedIn = null;
            });
          },
        ),
        const SizedBox(height: FantasySpacing.md),
        FantasyGlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              FantasySectionHeader(
                title: 'BUYING',
                subtitle: _selectedOut == null
                    ? 'Choose a player to sell first.'
                    : 'Replacement list for ${_selectedOut!.position.name.toUpperCase()}',
              ),
              const SizedBox(height: FantasySpacing.md),
              if (_selectedOut == null)
                const FantasyStateCard.empty(
                  title: 'Select a player to sell',
                  message:
                      'The buying panel unlocks once a player is selected.',
                )
              else
                SizedBox(
                  height: 420,
                  child: PlayerPickerList(
                    players: players
                        .where(
                          (player) => player.position == _selectedOut!.position,
                        )
                        .toList(growable: false),
                    initialPosition: _selectedOut!.position,
                    budgetRemaining: availableBudget,
                    selectedPlayerIds: squad
                        .map((slot) => slot.playerId)
                        .where((id) => id != _selectedOut!.playerId)
                        .toSet(),
                    clubCounts: clubCounts,
                    maxPerClub: 3,
                    onSelected: (player) {
                      setState(() => _selectedIn = player);
                    },
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: FantasySpacing.md),
        FantasyGlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              FantasySectionHeader(
                title: 'Transfer mode',
                subtitle: activeChipLabel == null
                    ? 'Regular transfer rules apply for this gameweek.'
                    : '$activeChipLabel is active for this gameweek.',
              ),
              const SizedBox(height: FantasySpacing.md),
              Wrap(
                spacing: FantasySpacing.sm,
                runSpacing: FantasySpacing.sm,
                children: <Widget>[
                  ...chips.map(
                    (chip) => _ChipStatusPill(
                      label: _chipLabel(chip.chip),
                      active: chip.isActivated,
                      available: chip.isAvailable && !chip.isConsumed,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () =>
                        context.push('/fantasy/${widget.slug}/chips'),
                    icon: const Icon(Icons.bolt_rounded),
                    label: const Text('Manage chips'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: FantasySpacing.md),
        AfriButton(
          label: 'Confirm Transfer',
          onTap: _selectedOut == null || _selectedIn == null || _submitting
              ? () {}
              : () => _confirmTransfer(
                  context,
                  competitionId: competitionId,
                  entryId: entryId,
                  gameweekId: gameweekId,
                ),
          variant: AfriButtonVariant.accent,
          enabled: _selectedOut != null && _selectedIn != null && !_submitting,
          isLoading: _submitting,
        ),
        if (_selectedIn != null) ...<Widget>[
          const SizedBox(height: FantasySpacing.sm),
          Text(
            remainingBudget >= 0
                ? 'Transfer leaves £${(remainingBudget / 10).toStringAsFixed(1)}M in the bank.'
                : 'Transfer exceeds your bank balance.',
            style: FantasyTypography.caption.copyWith(
              color: remainingBudget >= 0
                  ? FantasyColors.successGreen
                  : FantasyColors.dangerRed,
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _confirmTransfer(
    BuildContext context, {
    required String competitionId,
    required String entryId,
    required String gameweekId,
  }) async {
    final outgoing = _selectedOut;
    final incoming = _selectedIn;
    if (outgoing == null || incoming == null) return;

    setState(() => _submitting = true);
    try {
      await ref
          .read(squadRepositoryProvider)
          .makeTransfer(
            entryId: entryId,
            gameweekId: gameweekId,
            playerOutId: outgoing.playerId,
            playerInId: incoming.externalId,
          );
      ref.invalidate(
        entryGameweekStateProvider((entryId: entryId, gameweekId: gameweekId)),
      );
      ref.invalidate(
        chipStatesProvider((entryId: entryId, gameweekId: gameweekId)),
      );
      ref.invalidate(
        squadForGameweekProvider((entryId: entryId, gameweekId: gameweekId)),
      );
      ref.invalidate(myEntryProvider(competitionId));
      ref.invalidate(
        gameweekScoreProvider((entryId: entryId, gameweekId: gameweekId)),
      );
      if (!mounted) return;
      AfriToast.success(this.context, 'Transfer saved.');
      setState(() {
        _selectedOut = null;
        _selectedIn = null;
      });
    } on FantasyException catch (error) {
      if (mounted) {
        AfriToast.error(this.context, error.message);
      }
    } catch (error) {
      if (mounted) {
        AfriToast.error(this.context, error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  bool get _hasPendingTransfer => _selectedOut != null && _selectedIn != null;

  int _projectedFreeTransfers(FantasyGameweekState state) {
    if (state.hasUnlimitedTransfers) {
      return state.freeTransfersRemaining;
    }
    if (!_hasPendingTransfer) {
      return state.freeTransfersRemaining;
    }
    return (state.freeTransfersRemaining - 1).clamp(0, 99);
  }

  String? _projectedFreeTransfersLabel(FantasyGameweekState state) {
    if (state.hasUnlimitedTransfers) {
      return 'Unlimited this gameweek';
    }
    return null;
  }

  int _projectedTransferCost(FantasyGameweekState state) {
    if (state.hasUnlimitedTransfers) {
      return 0;
    }
    if (!_hasPendingTransfer || state.freeTransfersRemaining > 0) {
      return state.transferCost;
    }
    return state.transferCost - 4;
  }

  String? _transferStatusLabel(FantasyGameweekState state) {
    if (state.chipPlayed == 'wildcard') {
      return 'Wildcard active';
    }
    if (state.chipPlayed == 'free_hit') {
      return 'Free Hit active';
    }
    if (_hasPendingTransfer) {
      return 'Pending transfer';
    }
    return null;
  }

  String _chipLabel(ChipType chip) {
    return switch (chip) {
      ChipType.wildcard => 'Wildcard',
      ChipType.freeHit => 'Free Hit',
      ChipType.tripleCaptain => 'Triple Captain',
      ChipType.benchBoost => 'Bench Boost',
    };
  }

  String? _chipLabelFromKey(String? chipKey) {
    switch (chipKey) {
      case 'wildcard':
        return 'Wildcard';
      case 'free_hit':
        return 'Free Hit';
      case 'triple_captain':
        return 'Triple Captain';
      case 'bench_boost':
        return 'Bench Boost';
      default:
        return null;
    }
  }
}

class _ChipStatusPill extends StatelessWidget {
  const _ChipStatusPill({
    required this.label,
    required this.active,
    required this.available,
  });

  final String label;
  final bool active;
  final bool available;

  @override
  Widget build(BuildContext context) {
    final color = active
        ? FantasyColors.successGreen
        : available
        ? FantasyColors.warningAmber
        : FantasyColors.textMuted;
    final suffix = active
        ? 'Active'
        : available
        ? 'Ready'
        : 'Used';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: FantasySpacing.sm,
        vertical: FantasySpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Text(
        '$label · $suffix',
        style: FantasyTypography.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
