import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/fantasy_models.dart';
import '../providers/fantasy_providers.dart';

class FantasySquadBuilderScreen extends ConsumerStatefulWidget {
  const FantasySquadBuilderScreen({super.key, required this.slug});

  final String slug;

  @override
  ConsumerState<FantasySquadBuilderScreen> createState() =>
      _FantasySquadBuilderScreenState();
}

class _FantasySquadBuilderScreenState
    extends ConsumerState<FantasySquadBuilderScreen> {
  static const List<_SlotTemplate> _slotTemplates = [
    _SlotTemplate(
      position: FantasyPlayerPosition.gk,
      label: 'Goalkeeper 1',
      isStarter: true,
    ),
    _SlotTemplate(
      position: FantasyPlayerPosition.gk,
      label: 'Bench GK',
      isStarter: false,
      benchOrder: 1,
    ),
    _SlotTemplate(
      position: FantasyPlayerPosition.def,
      label: 'Defender 1',
      isStarter: true,
    ),
    _SlotTemplate(
      position: FantasyPlayerPosition.def,
      label: 'Defender 2',
      isStarter: true,
    ),
    _SlotTemplate(
      position: FantasyPlayerPosition.def,
      label: 'Defender 3',
      isStarter: true,
    ),
    _SlotTemplate(
      position: FantasyPlayerPosition.def,
      label: 'Bench DEF 1',
      isStarter: false,
      benchOrder: 2,
    ),
    _SlotTemplate(
      position: FantasyPlayerPosition.def,
      label: 'Bench DEF 2',
      isStarter: false,
      benchOrder: 4,
    ),
    _SlotTemplate(
      position: FantasyPlayerPosition.mid,
      label: 'Midfielder 1',
      isStarter: true,
    ),
    _SlotTemplate(
      position: FantasyPlayerPosition.mid,
      label: 'Midfielder 2',
      isStarter: true,
    ),
    _SlotTemplate(
      position: FantasyPlayerPosition.mid,
      label: 'Midfielder 3',
      isStarter: true,
    ),
    _SlotTemplate(
      position: FantasyPlayerPosition.mid,
      label: 'Midfielder 4',
      isStarter: true,
    ),
    _SlotTemplate(
      position: FantasyPlayerPosition.mid,
      label: 'Bench MID',
      isStarter: false,
      benchOrder: 3,
    ),
    _SlotTemplate(
      position: FantasyPlayerPosition.fwd,
      label: 'Forward 1',
      isStarter: true,
    ),
    _SlotTemplate(
      position: FantasyPlayerPosition.fwd,
      label: 'Forward 2',
      isStarter: true,
    ),
    _SlotTemplate(
      position: FantasyPlayerPosition.fwd,
      label: 'Forward 3',
      isStarter: true,
    ),
  ];

  List<_DraftSlot> _slots = const <_DraftSlot>[];
  String _seedKey = '';
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final builderAsync = ref.watch(fantasySquadBuilderProvider(widget.slug));

    return Scaffold(
      backgroundColor: ColorTokens.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Squad builder'),
      ),
      body: GradientBackground(
        child: SafeArea(
          top: false,
          child: builderAsync.when(
            data: (data) {
              if (data == null) {
                return _StateScaffold(
                  title: 'Fantasy context is unavailable.',
                  body:
                      'The app could not resolve the current competition context yet.',
                  primaryLabel: 'Back to fantasy',
                  onPrimary: () => context.go('/fantasy'),
                );
              }

              _seedDraftIfNeeded(data);

              final contextData = data.context;
              if (!contextData.hasEntry) {
                return _StateScaffold(
                  title: 'Create your entry first.',
                  body:
                      'A squad can only be saved after the competition entry exists for this manager account.',
                  primaryLabel: 'Create entry',
                  onPrimary: () =>
                      context.go('/fantasy/competition/${widget.slug}/entry'),
                );
              }

              if (contextData.gameweek == null) {
                return _StateScaffold(
                  title: 'No gameweek is active yet.',
                  body:
                      'Add or schedule a gameweek in admin before managers can lock squads.',
                  primaryLabel: 'Back to competition',
                  onPrimary: () =>
                      context.go('/fantasy/competition/${widget.slug}'),
                );
              }

              if (data.playerPool.isEmpty) {
                return _StateScaffold(
                  title: 'No fantasy players are priced yet.',
                  body:
                      'Load the player pool and prices for this competition in admin before squad selection opens.',
                  primaryLabel: 'Back to competition',
                  onPrimary: () =>
                      context.go('/fantasy/competition/${widget.slug}'),
                );
              }

              final totalBudget = contextData.budget;
              final usedBudget = _slots.fold<int>(
                0,
                (sum, slot) => sum + (slot.player?.purchasePrice ?? 0),
              );
              final remainingBudget = totalBudget - usedBudget;
              final selectedCount = _slots
                  .where((slot) => slot.player != null)
                  .length;
              final captainCount = _slots
                  .where((slot) => slot.isCaptain)
                  .length;
              final viceCaptainCount = _slots
                  .where((slot) => slot.isViceCaptain)
                  .length;
              final canSave =
                  !_isSaving &&
                  selectedCount == _slotTemplates.length &&
                  captainCount == 1 &&
                  viceCaptainCount == 1 &&
                  remainingBudget >= 0;

              return ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(SpacingTokens.spacing6),
                children: [
                  _SummaryCard(
                    teamName: contextData.teamName ?? 'My Fantasy XI',
                    gameweek: contextData.gameweek!,
                    selectedCount: selectedCount,
                    totalSlots: _slotTemplates.length,
                    totalBudget: totalBudget,
                    usedBudget: usedBudget,
                    remainingBudget: remainingBudget,
                    overallPoints: contextData.overallPoints,
                    overallRank: contextData.overallRank,
                  ),
                  const SizedBox(height: SpacingTokens.spacing4),
                  GlassCard(
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'This builder saves a production-valid 3-4-3 squad with a fixed bench order. It is designed to make the live fantasy stack usable now, without waiting for the full transfer and formation editor.',
                            style: TypographyTokens.bodyMedium(),
                          ),
                        ),
                        const SizedBox(width: SpacingTokens.spacing4),
                        FilledButton.icon(
                          onPressed: canSave
                              ? () => _saveSquad(contextData)
                              : null,
                          icon: const Icon(Icons.save_rounded),
                          label: Text(_isSaving ? 'Saving…' : 'Save squad'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: SpacingTokens.spacing4),
                  for (final position in FantasyPlayerPosition.values) ...[
                    _PositionSection(
                      title: position.label,
                      subtitle: position.code,
                      children: _slotIndexesFor(position)
                          .map(
                            (index) => Padding(
                              padding: const EdgeInsets.only(
                                bottom: SpacingTokens.spacing3,
                              ),
                              child: _SlotCard(
                                slot: _slots[index],
                                onSelect: () =>
                                    _pickPlayer(index, data.playerPool),
                                onClear: _slots[index].player == null
                                    ? null
                                    : () => _clearSlot(index),
                                onSetCaptain:
                                    _slots[index].player != null &&
                                        _slots[index].template.isStarter
                                    ? () => _setCaptain(index)
                                    : null,
                                onSetViceCaptain:
                                    _slots[index].player != null &&
                                        _slots[index].template.isStarter
                                    ? () => _setViceCaptain(index)
                                    : null,
                              ),
                            ),
                          )
                          .toList(growable: false),
                    ),
                    const SizedBox(height: SpacingTokens.spacing4),
                  ],
                  FilledButton.icon(
                    onPressed: canSave ? () => _saveSquad(contextData) : null,
                    icon: const Icon(Icons.check_circle_rounded),
                    label: Text(
                      _isSaving ? 'Saving squad…' : 'Lock squad for gameweek',
                    ),
                  ),
                  const SizedBox(height: SpacingTokens.spacing12),
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(SpacingTokens.spacing6),
              child: AfriSkeletonList(itemCount: 4),
            ),
            error: (_, __) => _StateScaffold(
              title: 'Squad builder failed to load.',
              body:
                  'The fantasy squad surface is temporarily unavailable. Refresh and try again.',
              primaryLabel: 'Back to fantasy',
              onPrimary: () => context.go('/fantasy'),
            ),
          ),
        ),
      ),
    );
  }

  List<int> _slotIndexesFor(FantasyPlayerPosition position) {
    return _slots
        .asMap()
        .entries
        .where((entry) => entry.value.template.position == position)
        .map((entry) => entry.key)
        .toList(growable: false);
  }

  void _seedDraftIfNeeded(FantasySquadBuilderData data) {
    final nextSeedKey = [
      data.context.entryId ?? 'none',
      data.context.gameweek?.id ?? 'none',
      data.squad
          .map(
            (selection) =>
                '${selection.playerId}:${selection.isStarter}:${selection.benchOrder}:${selection.isCaptain}:${selection.isViceCaptain}',
          )
          .join('|'),
    ].join('::');

    if (_seedKey == nextSeedKey) {
      return;
    }

    final startersByPosition =
        <FantasyPlayerPosition, List<FantasySquadSelection>>{
          for (final position in FantasyPlayerPosition.values)
            position: <FantasySquadSelection>[],
        };
    final benchByPosition =
        <FantasyPlayerPosition, List<FantasySquadSelection>>{
          for (final position in FantasyPlayerPosition.values)
            position: <FantasySquadSelection>[],
        };

    for (final selection in data.squad) {
      if (selection.isStarter) {
        startersByPosition[selection.position]!.add(selection);
      } else {
        benchByPosition[selection.position]!.add(selection);
      }
    }

    for (final entries in benchByPosition.values) {
      entries.sort((left, right) {
        final leftOrder = left.benchOrder ?? 99;
        final rightOrder = right.benchOrder ?? 99;
        return leftOrder.compareTo(rightOrder);
      });
    }

    _slots = _slotTemplates
        .map((template) {
          final source = template.isStarter
              ? startersByPosition[template.position]!
              : benchByPosition[template.position]!;
          FantasySquadSelection? selection;
          if (!template.isStarter && template.benchOrder != null) {
            final matchIndex = source.indexWhere(
              (item) => item.benchOrder == template.benchOrder,
            );
            if (matchIndex >= 0) {
              selection = source.removeAt(matchIndex);
            }
          }
          selection ??= source.isNotEmpty ? source.removeAt(0) : null;
          return _DraftSlot(template: template, player: selection);
        })
        .toList(growable: false);
    _seedKey = nextSeedKey;
  }

  Future<void> _pickPlayer(
    int slotIndex,
    List<FantasyPlayerPoolItem> playerPool,
  ) async {
    final slot = _slots[slotIndex];
    final selectedPlayerIds = _slots
        .asMap()
        .entries
        .where((entry) => entry.key != slotIndex)
        .map((entry) => entry.value.player?.playerId)
        .whereType<int>()
        .toSet();

    final candidates = playerPool
        .where((player) => player.position == slot.template.position)
        .toList(growable: false);

    final chosen = await showModalBottomSheet<FantasyPlayerPoolItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ColorTokens.surface,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              SpacingTokens.spacing6,
              SpacingTokens.spacing5,
              SpacingTokens.spacing6,
              SpacingTokens.spacing6,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Select ${slot.template.position.label}'.toUpperCase(),
                  style: TypographyTokens.titleLarge().copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: SpacingTokens.spacing4),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: candidates.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: SpacingTokens.spacing2),
                    itemBuilder: (context, index) {
                      final player = candidates[index];
                      final isTaken = selectedPlayerIds.contains(
                        player.playerId,
                      );
                      return ListTile(
                        enabled: !isTaken,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        tileColor: ColorTokens.background.withValues(
                          alpha: 0.65,
                        ),
                        title: Text(player.displayName),
                        subtitle: Text(
                          '${player.teamName} • ${_formatBudget(player.price)}',
                        ),
                        trailing: isTaken
                            ? const Icon(Icons.block_rounded)
                            : const Icon(Icons.add_circle_outline_rounded),
                        onTap: isTaken
                            ? null
                            : () => Navigator.pop(context, player),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (chosen == null) {
      return;
    }

    setState(() {
      final previous = _slots[slotIndex];
      _slots[slotIndex] = previous.copyWith(
        player: FantasySquadSelection(
          playerId: chosen.playerId,
          name: chosen.name,
          shortName: chosen.shortName,
          position: chosen.position,
          teamName: chosen.teamName,
          teamShort: chosen.teamShort,
          purchasePrice: chosen.price,
          isStarter: previous.template.isStarter,
          benchOrder: previous.template.benchOrder,
          isCaptain: previous.player?.isCaptain ?? false,
          isViceCaptain: previous.player?.isViceCaptain ?? false,
          multiplier: (previous.player?.isCaptain ?? false) ? 2 : 1,
          photoUrl: chosen.photoUrl,
          teamLogoUrl: chosen.teamLogoUrl,
        ),
      );
    });
  }

  void _clearSlot(int slotIndex) {
    setState(() {
      _slots[slotIndex] = _slots[slotIndex].copyWith(player: null);
    });
  }

  void _setCaptain(int slotIndex) {
    setState(() {
      for (var index = 0; index < _slots.length; index += 1) {
        final player = _slots[index].player;
        if (player == null) {
          continue;
        }
        _slots[index] = _slots[index].copyWith(
          player: player.copyWith(
            isCaptain: index == slotIndex,
            isViceCaptain: index == slotIndex ? false : player.isViceCaptain,
            multiplier: index == slotIndex ? 2 : 1,
          ),
        );
      }
    });
  }

  void _setViceCaptain(int slotIndex) {
    setState(() {
      for (var index = 0; index < _slots.length; index += 1) {
        final player = _slots[index].player;
        if (player == null) {
          continue;
        }
        _slots[index] = _slots[index].copyWith(
          player: player.copyWith(
            isCaptain: index == slotIndex ? false : player.isCaptain,
            isViceCaptain: index == slotIndex,
            multiplier: index == slotIndex ? 1 : player.multiplier,
          ),
        );
      }
    });
  }

  Future<void> _saveSquad(FantasyEntryContext contextData) async {
    final entryId = contextData.entryId;
    final gameweekId = contextData.gameweek?.id;
    if (entryId == null || gameweekId == null) {
      return;
    }

    final selections = _slots
        .map((slot) => slot.player)
        .whereType<FantasySquadSelection>()
        .toList(growable: false);
    if (selections.length != _slotTemplates.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Complete all 15 slots before saving.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final savedCount = await ref
        .read(fantasyRepositoryProvider)
        .saveSquadSelections(
          entryId: entryId,
          gameweekId: gameweekId,
          selections: selections,
        );
    if (!mounted) {
      return;
    }
    setState(() => _isSaving = false);

    if (savedCount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Squad could not be saved. Check pricing, max-per-club, and captain settings.',
          ),
        ),
      );
      return;
    }

    ref.invalidate(fantasySquadBuilderProvider(widget.slug));
    ref.invalidate(
      fantasySquadProvider(
        FantasySquadQuery(entryId: entryId, gameweekId: gameweekId),
      ),
    );
    ref.invalidate(fantasyCompetitionContextProvider(widget.slug));
    ref.invalidate(fantasyCompetitionsProvider);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved $savedCount squad selections.')),
    );
  }
}

class _StateScaffold extends StatelessWidget {
  const _StateScaffold({
    required this.title,
    required this.body,
    required this.primaryLabel,
    required this.onPrimary,
  });

  final String title;
  final String body;
  final String primaryLabel;
  final VoidCallback onPrimary;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(SpacingTokens.spacing6),
      children: [
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.toUpperCase(),
                style: TypographyTokens.titleLarge().copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: SpacingTokens.spacing3),
              Text(body, style: TypographyTokens.bodyMedium()),
              const SizedBox(height: SpacingTokens.spacing5),
              FilledButton.icon(
                onPressed: onPrimary,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: Text(primaryLabel),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.teamName,
    required this.gameweek,
    required this.selectedCount,
    required this.totalSlots,
    required this.totalBudget,
    required this.usedBudget,
    required this.remainingBudget,
    required this.overallPoints,
    required this.overallRank,
  });

  final String teamName;
  final FantasyGameweekSummary gameweek;
  final int selectedCount;
  final int totalSlots;
  final int totalBudget;
  final int usedBudget;
  final int remainingBudget;
  final int overallPoints;
  final int? overallRank;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            teamName.toUpperCase(),
            style: TypographyTokens.monolithFont(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: ColorTokens.onSurface,
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing2),
          Text(
            'GW ${gameweek.number} • ${gameweek.name} • ${gameweek.status.toUpperCase()}',
            style: TypographyTokens.labelLarge().copyWith(
              color: ColorTokens.clubAccent,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing4),
          Wrap(
            spacing: SpacingTokens.spacing3,
            runSpacing: SpacingTokens.spacing3,
            children: [
              _SummaryPill(
                label: 'Selected',
                value: '$selectedCount/$totalSlots',
              ),
              _SummaryPill(label: 'Budget', value: _formatBudget(totalBudget)),
              _SummaryPill(label: 'Used', value: _formatBudget(usedBudget)),
              _SummaryPill(
                label: 'Left',
                value: _formatBudget(remainingBudget),
                danger: remainingBudget < 0,
              ),
              _SummaryPill(label: 'Points', value: '$overallPoints'),
              _SummaryPill(
                label: 'Rank',
                value: overallRank == null ? 'Unranked' : '#$overallRank',
              ),
            ],
          ),
          if (gameweek.deadlineAt != null) ...[
            const SizedBox(height: SpacingTokens.spacing4),
            Text(
              'Deadline: ${gameweek.deadlineAt!.toLocal()}',
              style: TypographyTokens.bodySmall(),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({
    required this.label,
    required this.value,
    this.danger = false,
  });

  final String label;
  final String value;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.spacing4,
        vertical: SpacingTokens.spacing3,
      ),
      decoration: BoxDecoration(
        color: ColorTokens.surface.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(18),
        border: BorderTokens.ghost(opacity: 0.12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TypographyTokens.labelSmall().copyWith(
              letterSpacing: 0.8,
              color: danger ? Colors.redAccent : ColorTokens.clubAccent,
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing1),
          Text(
            value,
            style: TypographyTokens.titleMedium().copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _PositionSection extends StatelessWidget {
  const _PositionSection({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$title • $subtitle'.toUpperCase(),
            style: TypographyTokens.titleMedium().copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing4),
          ...children,
        ],
      ),
    );
  }
}

class _SlotCard extends StatelessWidget {
  const _SlotCard({
    required this.slot,
    required this.onSelect,
    required this.onClear,
    required this.onSetCaptain,
    required this.onSetViceCaptain,
  });

  final _DraftSlot slot;
  final VoidCallback onSelect;
  final VoidCallback? onClear;
  final VoidCallback? onSetCaptain;
  final VoidCallback? onSetViceCaptain;

  @override
  Widget build(BuildContext context) {
    final player = slot.player;

    return Container(
      padding: const EdgeInsets.all(SpacingTokens.spacing4),
      decoration: BoxDecoration(
        color: ColorTokens.background.withValues(alpha: 0.66),
        borderRadius: BorderRadius.circular(20),
        border: BorderTokens.ghost(opacity: 0.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: ColorTokens.clubAccent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  slot.template.position.code,
                  style: TypographyTokens.labelLarge().copyWith(
                    fontWeight: FontWeight.w900,
                    color: ColorTokens.clubAccent,
                  ),
                ),
              ),
              const SizedBox(width: SpacingTokens.spacing3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      slot.template.label,
                      style: TypographyTokens.labelMedium().copyWith(
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: SpacingTokens.spacing1),
                    Text(
                      player?.displayName ??
                          'Select ${slot.template.position.label}',
                      style: TypographyTokens.titleMedium().copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: SpacingTokens.spacing1),
                    Text(
                      player == null
                          ? slot.template.isStarter
                                ? 'Starting slot'
                                : 'Bench order ${slot.template.benchOrder}'
                          : '${player.teamName} • ${_formatBudget(player.purchasePrice)}',
                      style: TypographyTokens.bodySmall(),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                onPressed: onSelect,
                icon: Icon(
                  player == null
                      ? Icons.add_circle_outline_rounded
                      : Icons.swap_horiz_rounded,
                ),
                tooltip: player == null ? 'Select player' : 'Replace player',
              ),
              if (player != null)
                IconButton(
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Clear slot',
                ),
            ],
          ),
          if (player != null && slot.template.isStarter) ...[
            const SizedBox(height: SpacingTokens.spacing3),
            Wrap(
              spacing: SpacingTokens.spacing2,
              runSpacing: SpacingTokens.spacing2,
              children: [
                _MiniActionChip(
                  label: slot.isCaptain ? 'Captain' : 'Set captain',
                  selected: slot.isCaptain,
                  onTap: onSetCaptain,
                ),
                _MiniActionChip(
                  label: slot.isViceCaptain
                      ? 'Vice-captain'
                      : 'Set vice-captain',
                  selected: slot.isViceCaptain,
                  onTap: onSetViceCaptain,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniActionChip extends StatelessWidget {
  const _MiniActionChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: SpacingTokens.spacing3,
          vertical: SpacingTokens.spacing2,
        ),
        decoration: BoxDecoration(
          color: selected
              ? ColorTokens.clubAccent.withValues(alpha: 0.18)
              : ColorTokens.surface.withValues(alpha: 0.52),
          borderRadius: BorderRadius.circular(999),
          border: BorderTokens.ghost(opacity: 0.1),
        ),
        child: Text(
          label,
          style: TypographyTokens.labelMedium().copyWith(
            color: selected ? ColorTokens.clubAccent : ColorTokens.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _SlotTemplate {
  const _SlotTemplate({
    required this.position,
    required this.label,
    required this.isStarter,
    this.benchOrder,
  });

  final FantasyPlayerPosition position;
  final String label;
  final bool isStarter;
  final int? benchOrder;
}

class _DraftSlot {
  const _DraftSlot({required this.template, required this.player});

  final _SlotTemplate template;
  final FantasySquadSelection? player;

  bool get isCaptain => player?.isCaptain ?? false;
  bool get isViceCaptain => player?.isViceCaptain ?? false;

  _DraftSlot copyWith({required FantasySquadSelection? player}) {
    return _DraftSlot(template: template, player: player);
  }
}

String _formatBudget(int amount) {
  final negative = amount < 0;
  final absolute = amount.abs();
  final whole = absolute ~/ 10;
  final decimal = absolute % 10;
  return '${negative ? '-' : ''}$whole.$decimal';
}
