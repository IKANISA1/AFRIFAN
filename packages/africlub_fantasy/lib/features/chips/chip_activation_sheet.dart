import 'package:africlub_fantasy/core/constants.dart';
import 'package:africlub_fantasy/features/chips/chip_preview_widget.dart';
import 'package:africlub_fantasy/features/shared/fantasy_ui.dart';
import 'package:africlub_fantasy/models/chip_state.dart';
import 'package:africlub_fantasy/providers/competition_providers.dart';
import 'package:africlub_fantasy/providers/scoring_providers.dart';
import 'package:africlub_fantasy/providers/squad_providers.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChipActivationSheet extends ConsumerWidget {
  const ChipActivationSheet({
    required this.entryId,
    required this.gameweekId,
    this.chip,
    this.slug,
    super.key,
  });

  const ChipActivationSheet.standalone({required this.slug, super.key})
    : entryId = '',
      gameweekId = '',
      chip = null;

  final String entryId;
  final String gameweekId;
  final ChipState? chip;
  final String? slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FantasyScaffold(
      title: 'Chips',
      child: _buildResolvedBody(context, ref),
    );
  }

  Widget _buildResolvedBody(BuildContext context, WidgetRef ref) {
    if (entryId.isNotEmpty && gameweekId.isNotEmpty) {
      return _buildBody(
        context,
        ref,
        _ResolvedChipContext(entryId: entryId, gameweekId: gameweekId),
      );
    }

    final slug = this.slug;
    if (slug == null || slug.isEmpty) {
      return const Center(
        child: FantasyStateCard.empty(
          title: 'No fantasy entry found',
          message: 'Build your squad first to activate chips.',
        ),
      );
    }

    final competitionAsync = ref.watch(competitionProvider(slug));
    return competitionAsync.when(
      data: (competition) {
        final entryAsync = ref.watch(myEntryProvider(competition.id));
        final gameweekAsync = ref.watch(
          currentGameweekProvider(competition.id),
        );
        return entryAsync.when(
          data: (entry) => gameweekAsync.when(
            data: (gameweek) {
              if (entry == null || gameweek == null) {
                return const Center(
                  child: FantasyStateCard.empty(
                    title: 'No fantasy entry found',
                    message: 'Build your squad first to activate chips.',
                  ),
                );
              }
              return _buildBody(
                context,
                ref,
                _ResolvedChipContext(
                  entryId: entry.id,
                  gameweekId: gameweek.id,
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
          ),
          loading: () => const Center(child: FantasyStateCard.loading()),
          error: (error, _) => Center(
            child: FantasyStateCard.error(
              title: 'Entry failed to load',
              message: error.toString(),
            ),
          ),
        );
      },
      loading: () => const Center(child: FantasyStateCard.loading()),
      error: (error, _) => Center(
        child: FantasyStateCard.error(
          title: 'Competition failed to load',
          message: error.toString(),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    _ResolvedChipContext resolved,
  ) {
    final request = (
      entryId: resolved.entryId,
      gameweekId: resolved.gameweekId,
    );
    final chipsAsync = ref.watch(chipStatesProvider(request));
    final stateAsync = ref.watch(entryGameweekStateProvider(request));

    return chipsAsync.when(
      data: (chips) => stateAsync.when(
        data: (state) {
          final selectedChip = _resolveChipState(chips);
          if (selectedChip != null) {
            return _buildChipDetail(
              context,
              ref,
              resolved,
              selectedChip,
              state.chipPlayed,
            );
          }

          return _buildChipList(
            context,
            ref,
            resolved,
            chips,
            state.chipPlayed,
          );
        },
        loading: () => const Center(child: FantasyStateCard.loading()),
        error: (error, _) => Center(
          child: FantasyStateCard.error(
            title: 'Chip state failed to load',
            message: error.toString(),
          ),
        ),
      ),
      loading: () => const Center(child: FantasyStateCard.loading()),
      error: (error, _) => Center(
        child: FantasyStateCard.error(
          title: 'Chips failed to load',
          message: error.toString(),
        ),
      ),
    );
  }

  ChipState? _resolveChipState(List<ChipState> chips) {
    if (chip == null) {
      return null;
    }
    for (final item in chips) {
      if (item.chip == chip!.chip) {
        return item;
      }
    }
    return chip;
  }

  Widget _buildChipList(
    BuildContext context,
    WidgetRef ref,
    _ResolvedChipContext resolved,
    List<ChipState> chips,
    String? activeChipKey,
  ) {
    return ListView.separated(
      padding: const EdgeInsets.all(FantasySpacing.md),
      itemBuilder: (context, index) {
        final chipState = chips[index];
        final hasAnotherActiveChip =
            activeChipKey != null && !chipState.isActivated;
        final canActivate =
            chipState.isAvailable &&
            !chipState.isConsumed &&
            !hasAnotherActiveChip;

        return FantasyGlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      _labelForChip(chipState.chip),
                      style: FantasyTypography.h3.copyWith(
                        color: FantasyColors.textPrimary,
                      ),
                    ),
                  ),
                  _ChipStateBadge(chip: chipState),
                ],
              ),
              const SizedBox(height: FantasySpacing.sm),
              Text(
                chipState.description ?? _defaultDescription(chipState.chip),
                style: FantasyTypography.body.copyWith(
                  color: FantasyColors.textSecondary,
                ),
              ),
              if (chipState.projectedPoints > 0) ...<Widget>[
                const SizedBox(height: FantasySpacing.md),
                ChipPreviewWidget(
                  label: 'Projected swing',
                  projectedPoints: chipState.projectedPoints,
                ),
              ],
              if (hasAnotherActiveChip) ...<Widget>[
                const SizedBox(height: FantasySpacing.md),
                Text(
                  '${_labelForChipKey(activeChipKey)!} is already active for this gameweek.',
                  style: FantasyTypography.caption.copyWith(
                    color: FantasyColors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: FantasySpacing.md),
              AfriButton(
                label: chipState.isActivated
                    ? 'Active this gameweek'
                    : chipState.isConsumed
                    ? 'Already used'
                    : canActivate
                    ? 'Activate'
                    : 'Unavailable',
                onTap: canActivate
                    ? () => _confirmActivation(
                        context,
                        ref,
                        resolved.entryId,
                        resolved.gameweekId,
                        chipState,
                      )
                    : () {},
                variant: chipState.isActivated
                    ? AfriButtonVariant.secondary
                    : AfriButtonVariant.accent,
                enabled: canActivate,
              ),
            ],
          ),
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: FantasySpacing.md),
      itemCount: chips.length,
    );
  }

  Widget _buildChipDetail(
    BuildContext context,
    WidgetRef ref,
    _ResolvedChipContext resolved,
    ChipState chip,
    String? activeChipKey,
  ) {
    final label = _labelForChip(chip.chip).toUpperCase();
    final description = chip.description ?? _defaultDescription(chip.chip);
    final hasAnotherActiveChip = activeChipKey != null && !chip.isActivated;
    final canActivate =
        chip.isAvailable && !chip.isConsumed && !hasAnotherActiveChip;

    return ListView(
      padding: const EdgeInsets.all(FantasySpacing.md),
      children: <Widget>[
        Text(
          label,
          style: FantasyTypography.h1.copyWith(
            color: FantasyColors.textPrimary,
          ),
        ),
        const SizedBox(height: FantasySpacing.md),
        Text(
          description,
          style: FantasyTypography.body.copyWith(
            color: FantasyColors.textSecondary,
          ),
        ),
        if (chip.projectedPoints > 0) ...<Widget>[
          const SizedBox(height: FantasySpacing.md),
          ChipPreviewWidget(
            label: 'Projected swing',
            projectedPoints: chip.projectedPoints,
          ),
        ],
        const SizedBox(height: FantasySpacing.md),
        FantasyGlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'What this chip does',
                style: FantasyTypography.h3.copyWith(
                  color: FantasyColors.textPrimary,
                ),
              ),
              const SizedBox(height: FantasySpacing.sm),
              ..._chipRules(chip.chip).map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: FantasySpacing.sm),
                  child: Text(
                    '- $item',
                    style: FantasyTypography.body.copyWith(
                      color: FantasyColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (hasAnotherActiveChip) ...<Widget>[
          const SizedBox(height: FantasySpacing.md),
          Text(
            '${_labelForChipKey(activeChipKey)!} is already active for this gameweek.',
            style: FantasyTypography.caption.copyWith(
              color: FantasyColors.textSecondary,
            ),
          ),
        ],
        const SizedBox(height: FantasySpacing.lg),
        AfriButton(
          label: chip.isActivated
              ? 'Active this gameweek'
              : chip.isConsumed
              ? 'Already used'
              : canActivate
              ? 'Activate'
              : 'Unavailable',
          onTap: canActivate
              ? () => _confirmActivation(
                  context,
                  ref,
                  resolved.entryId,
                  resolved.gameweekId,
                  chip,
                )
              : () {},
          variant: chip.isActivated
              ? AfriButtonVariant.secondary
              : AfriButtonVariant.accent,
          enabled: canActivate,
        ),
        const SizedBox(height: FantasySpacing.sm),
        AfriButton(
          label: 'Back',
          onTap: () => Navigator.of(context).maybePop(),
          variant: AfriButtonVariant.ghost,
        ),
      ],
    );
  }

  Future<void> _confirmActivation(
    BuildContext context,
    WidgetRef ref,
    String resolvedEntryId,
    String resolvedGameweekId,
    ChipState chip,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: FantasyColors.surface,
        title: const Text('Activate chip?'),
        content: Text(
          '${_labelForChip(chip.chip)} will apply to this gameweek only and cannot be switched after the deadline.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Activate'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await ref
        .read(squadRepositoryProvider)
        .activateChip(
          entryId: resolvedEntryId,
          gameweekId: resolvedGameweekId,
          chip: chip.chip,
        );
    ref.invalidate(
      chipStatesProvider((
        entryId: resolvedEntryId,
        gameweekId: resolvedGameweekId,
      )),
    );
    ref.invalidate(
      entryGameweekStateProvider((
        entryId: resolvedEntryId,
        gameweekId: resolvedGameweekId,
      )),
    );
    ref.invalidate(
      gameweekScoreProvider((
        entryId: resolvedEntryId,
        gameweekId: resolvedGameweekId,
      )),
    );
    if (context.mounted) {
      AfriToast.success(context, '${_labelForChip(chip.chip)} activated.');
      Navigator.of(context).maybePop();
    }
  }

  String _labelForChip(ChipType chip) {
    return switch (chip) {
      ChipType.wildcard => 'Wildcard',
      ChipType.freeHit => 'Free Hit',
      ChipType.tripleCaptain => 'Triple Captain',
      ChipType.benchBoost => 'Bench Boost',
    };
  }

  String? _labelForChipKey(String? chipKey) {
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

  String _defaultDescription(ChipType chip) {
    return switch (chip) {
      ChipType.wildcard =>
        'Rebuild your squad without paying transfer hits for this gameweek.',
      ChipType.freeHit =>
        'Pick a one-week-only squad that resets when the gameweek ends.',
      ChipType.tripleCaptain =>
        'Your captain scores triple points instead of double.',
      ChipType.benchBoost =>
        'Bench players count toward your total this gameweek.',
    };
  }

  List<String> _chipRules(ChipType chip) {
    return switch (chip) {
      ChipType.wildcard => const <String>[
        'Unlimited transfers for the current gameweek.',
        'The resulting squad remains in place after the deadline.',
        'Once activated, the wildcard is consumed for this chip window.',
      ],
      ChipType.freeHit => const <String>[
        'Unlimited transfers for the current gameweek.',
        'Your original squad returns after the gameweek finishes.',
        'Transfer hits are waived while the chip is active.',
      ],
      ChipType.tripleCaptain => const <String>[
        'Your captain scores triple instead of double.',
        'Vice-captain fallback still applies if the captain does not play.',
        'The chip is consumed once the deadline passes.',
      ],
      ChipType.benchBoost => const <String>[
        'Bench player points count this gameweek.',
        'Captaincy and vice-captain rules stay the same.',
        'The chip is consumed once the deadline passes.',
      ],
    };
  }
}

class _ResolvedChipContext {
  const _ResolvedChipContext({required this.entryId, required this.gameweekId});

  final String entryId;
  final String gameweekId;
}

class _ChipStateBadge extends StatelessWidget {
  const _ChipStateBadge({required this.chip});

  final ChipState chip;

  @override
  Widget build(BuildContext context) {
    final color = chip.isActivated
        ? FantasyColors.successGreen
        : chip.isConsumed
        ? FantasyColors.textMuted
        : chip.isAvailable
        ? FantasyColors.warningAmber
        : FantasyColors.dangerRed;
    final label = chip.isActivated
        ? 'Active'
        : chip.isConsumed
        ? 'Used'
        : chip.isAvailable
        ? 'Available'
        : 'Unavailable';

    return FantasyStatusBadge(label: label, color: color);
  }
}
