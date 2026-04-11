import 'dart:math' as math;

import 'package:africlub_fantasy/core/constants.dart';
import 'package:africlub_fantasy/core/exceptions.dart';
import 'package:africlub_fantasy/features/shared/fantasy_ui.dart';
import 'package:africlub_fantasy/features/squad_builder/budget_bar_widget.dart';
import 'package:africlub_fantasy/features/squad_builder/formation_selector_widget.dart';
import 'package:africlub_fantasy/features/squad_builder/pitch_layout_widget.dart';
import 'package:africlub_fantasy/features/squad_builder/player_picker_sheet.dart';
import 'package:africlub_fantasy/models/fantasy_entry.dart';
import 'package:africlub_fantasy/models/fantasy_player.dart';
import 'package:africlub_fantasy/models/squad_selection.dart';
import 'package:africlub_fantasy/providers/competition_providers.dart';
import 'package:africlub_fantasy/providers/player_providers.dart';
import 'package:africlub_fantasy/providers/squad_providers.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SquadBuilderScreen extends ConsumerStatefulWidget {
  const SquadBuilderScreen({required this.slug, super.key});

  final String slug;

  @override
  ConsumerState<SquadBuilderScreen> createState() => _SquadBuilderScreenState();
}

class _SquadBuilderScreenState extends ConsumerState<SquadBuilderScreen> {
  final List<_EditableSelection> _draft = <_EditableSelection>[];
  String _formation = '4-3-3';
  bool _initialized = false;
  bool _saving = false;
  String? _offlineMessage;

  @override
  Widget build(BuildContext context) {
    final competitionAsync = ref.watch(competitionProvider(widget.slug));

    return FantasyScaffold(
      title: 'Squad Builder',
      child: competitionAsync.when(
        data: (competition) {
          final entryAsync = ref.watch(myEntryProvider(competition.id));
          final playersAsync = ref.watch(
            competitionPlayersProvider(competition.id),
          );
          final gameweekAsync = ref.watch(
            currentGameweekProvider(competition.id),
          );

          return entryAsync.when(
            data: (entry) => gameweekAsync.when(
              data: (gameweek) {
                if (gameweek == null) {
                  return const Center(
                    child: FantasyStateCard.empty(
                      title: 'No active gameweek',
                      message:
                          'This competition does not have a buildable gameweek yet.',
                    ),
                  );
                }

                final squadAsync = entry == null
                    ? const AsyncValue<List<SquadSelection>>.data(
                        <SquadSelection>[],
                      )
                    : ref.watch(
                        squadForGameweekProvider((
                          entryId: entry.id,
                          gameweekId: gameweek.id,
                        )),
                      );

                return playersAsync.when(
                  data: (players) => squadAsync.when(
                    data: (selections) {
                      _bootstrapDraft(
                        entry: entry,
                        competitionBudget:
                            (competition.squadConfig['budget'] as num?)
                                ?.toInt() ??
                            1000,
                        selections: selections,
                      );
                      return _buildEditor(
                        context,
                        competitionId: competition.id,
                        gameweekId: gameweek.id,
                        players: players,
                        entry: entry,
                        allowedFormations:
                            (competition.squadConfig['formations']
                                    as List<dynamic>?)
                                ?.map((item) => item.toString())
                                .toList(growable: false) ??
                            const <String>['4-3-3', '3-4-3', '3-5-2'],
                        maxPerClub:
                            (competition.squadConfig['max_per_club'] as num?)
                                ?.toInt() ??
                            3,
                        totalBudget: entry == null
                            ? (competition.squadConfig['budget'] as num?)
                                      ?.toInt() ??
                                  1000
                            : math.max(
                                entry.teamValue + entry.bankBalance,
                                (competition.squadConfig['budget'] as num?)
                                        ?.toInt() ??
                                    1000,
                              ),
                      );
                    },
                    loading: () => _loadingState(),
                    error: (error, _) {
                      _offlineMessage = error.toString();
                      return _buildEditor(
                        context,
                        competitionId: competition.id,
                        gameweekId: gameweek.id,
                        players: players,
                        entry: entry,
                        allowedFormations:
                            (competition.squadConfig['formations']
                                    as List<dynamic>?)
                                ?.map((item) => item.toString())
                                .toList(growable: false) ??
                            const <String>['4-3-3', '3-4-3', '3-5-2'],
                        maxPerClub:
                            (competition.squadConfig['max_per_club'] as num?)
                                ?.toInt() ??
                            3,
                        totalBudget:
                            (competition.squadConfig['budget'] as num?)
                                ?.toInt() ??
                            1000,
                      );
                    },
                  ),
                  loading: _loadingState,
                  error: (error, _) => Center(
                    child: FantasyStateCard.error(
                      title: 'Players failed to load',
                      message: error.toString(),
                      onRetry: () {
                        ref.invalidate(
                          competitionPlayersProvider(competition.id),
                        );
                      },
                    ),
                  ),
                );
              },
              loading: _loadingState,
              error: (error, _) => Center(
                child: FantasyStateCard.error(
                  title: 'Gameweek unavailable',
                  message: error.toString(),
                  onRetry: () {
                    ref.invalidate(currentGameweekProvider(competition.id));
                  },
                ),
              ),
            ),
            loading: _loadingState,
            error: (error, _) => Center(
              child: FantasyStateCard.error(
                title: 'Entry failed to load',
                message: error.toString(),
                onRetry: () => ref.invalidate(myEntryProvider(competition.id)),
              ),
            ),
          );
        },
        loading: _loadingState,
        error: (error, _) => Center(
          child: FantasyStateCard.error(
            title: 'Competition failed to load',
            message: error.toString(),
            onRetry: () => ref.invalidate(competitionProvider(widget.slug)),
          ),
        ),
      ),
    );
  }

  Widget _loadingState() {
    return ListView(
      padding: const EdgeInsets.all(FantasySpacing.md),
      children: const <Widget>[
        FantasySkeletonCard(height: 520),
        SizedBox(height: FantasySpacing.md),
        FantasySkeletonCard(height: 180),
      ],
    );
  }

  void _bootstrapDraft({
    required FantasyEntry? entry,
    required int competitionBudget,
    required List<SquadSelection> selections,
  }) {
    if (_initialized) return;

    if (selections.isEmpty) {
      _draft
        ..clear()
        ..addAll(_emptyTemplate());
    } else {
      _draft
        ..clear()
        ..addAll(
          selections
              .map(_EditableSelection.fromSelection)
              .toList(growable: false),
        );
      _formation = _formationFromDraft();
    }

    if (_draft.isEmpty) {
      _draft.addAll(_emptyTemplate());
    }

    _initialized = true;
  }

  List<_EditableSelection> _emptyTemplate() {
    return <_EditableSelection>[
      _EditableSelection(position: PlayerPosition.gk, isStarter: true),
      _EditableSelection(position: PlayerPosition.def, isStarter: true),
      _EditableSelection(position: PlayerPosition.def, isStarter: true),
      _EditableSelection(position: PlayerPosition.def, isStarter: true),
      _EditableSelection(position: PlayerPosition.def, isStarter: true),
      _EditableSelection(position: PlayerPosition.mid, isStarter: true),
      _EditableSelection(position: PlayerPosition.mid, isStarter: true),
      _EditableSelection(position: PlayerPosition.mid, isStarter: true),
      _EditableSelection(position: PlayerPosition.fwd, isStarter: true),
      _EditableSelection(position: PlayerPosition.fwd, isStarter: true),
      _EditableSelection(position: PlayerPosition.fwd, isStarter: true),
      _EditableSelection(
        position: PlayerPosition.gk,
        isStarter: false,
        benchOrder: 1,
      ),
      _EditableSelection(
        position: PlayerPosition.def,
        isStarter: false,
        benchOrder: 2,
      ),
      _EditableSelection(
        position: PlayerPosition.mid,
        isStarter: false,
        benchOrder: 3,
      ),
      _EditableSelection(
        position: PlayerPosition.fwd,
        isStarter: false,
        benchOrder: 4,
      ),
    ];
  }

  Widget _buildEditor(
    BuildContext context, {
    required String competitionId,
    required String gameweekId,
    required List<FantasyPlayer> players,
    required FantasyEntry? entry,
    required List<String> allowedFormations,
    required int maxPerClub,
    required int totalBudget,
  }) {
    final starters = _draft
        .where((slot) => slot.isStarter)
        .toList(growable: false);
    final bench =
        _draft.where((slot) => !slot.isStarter).toList(growable: false)..sort(
          (left, right) =>
              (left.benchOrder ?? 9).compareTo(right.benchOrder ?? 9),
        );
    final spent = _draft.fold<int>(
      0,
      (sum, slot) => sum + (slot.player?.price ?? 0),
    );
    final remaining = totalBudget - spent;
    final hasCaptain = _draft.any(
      (slot) => slot.isCaptain && slot.player != null,
    );
    final hasVice = _draft.any(
      (slot) => slot.isViceCaptain && slot.player != null,
    );
    final selectedIds = _draft
        .where((slot) => slot.player != null)
        .map((slot) => slot.player!.externalId)
        .toSet();
    final clubCounts = <int, int>{};
    for (final slot in _draft.where((item) => item.player != null)) {
      clubCounts.update(
        slot.player!.teamId,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }

    final starterRows = _rowsForFormation(starters);
    _wireStarterRowCallbacks(
      rows: starterRows,
      players: players,
      remainingBudget: remaining,
      selectedIds: selectedIds,
      clubCounts: clubCounts,
      maxPerClub: maxPerClub,
    );
    final benchSlots = bench
        .map(
          (slot) => PitchSlotData(
            label:
                'Bench ${slot.benchOrder ?? ''} ${slot.position.name.toUpperCase()}',
            position: slot.position,
            player: slot.player,
            onTap: () => _onSlotPressed(
              slot: slot,
              players: players,
              remainingBudget: remaining + (slot.player?.price ?? 0),
              selectedIds: selectedIds,
              clubCounts: clubCounts,
              maxPerClub: maxPerClub,
            ),
            isCaptain: slot.isCaptain,
            isViceCaptain: slot.isViceCaptain,
            isBench: true,
          ),
        )
        .toList(growable: false);

    return Stack(
      children: <Widget>[
        ListView(
          padding: const EdgeInsets.fromLTRB(
            FantasySpacing.md,
            FantasySpacing.sm,
            FantasySpacing.md,
            220,
          ),
          children: <Widget>[
            if (_offlineMessage != null) const FantasyOfflineBanner(),
            FantasySectionHeader(
              title: entry?.teamName ?? 'New Fantasy Entry',
              subtitle: entry == null
                  ? 'Build your first squad before the deadline.'
                  : 'Choose starters, bench order, and captaincy.',
            ),
            const SizedBox(height: FantasySpacing.md),
            PitchLayoutWidget(rows: starterRows, bench: benchSlots),
            const SizedBox(height: FantasySpacing.lg),
            FantasyGlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const FantasySectionHeader(
                    title: 'Validation',
                    subtitle:
                        'Your lineup must be legal before it can be saved.',
                  ),
                  const SizedBox(height: FantasySpacing.md),
                  _ValidationRow(
                    label: '11 starters selected',
                    ok:
                        starters.where((slot) => slot.player != null).length ==
                        11,
                  ),
                  _ValidationRow(
                    label: 'Budget not exceeded',
                    ok: remaining >= 0,
                  ),
                  _ValidationRow(label: 'Captain selected', ok: hasCaptain),
                  _ValidationRow(label: 'Vice-captain selected', ok: hasVice),
                ],
              ),
            ),
          ],
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            decoration: BoxDecoration(
              color: FantasyColors.background.withValues(alpha: 0.96),
              border: const Border(
                top: BorderSide(color: FantasyColors.border),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(
              FantasySpacing.md,
              FantasySpacing.md,
              FantasySpacing.md,
              FantasySpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                BudgetBarWidget(remaining: remaining, total: totalBudget),
                const SizedBox(height: FantasySpacing.md),
                FormationSelectorWidget(
                  formations: allowedFormations.take(3).toList(growable: false),
                  selectedFormation: _formation,
                  onSelect: (formation) {
                    setState(() {
                      _formation = formation;
                      _applyFormation();
                    });
                  },
                ),
                const SizedBox(height: FantasySpacing.md),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: AfriButton(
                        label: 'Auto-fill',
                        onTap: () => _autoFill(
                          players: players,
                          totalBudget: totalBudget,
                          maxPerClub: maxPerClub,
                        ),
                        variant: AfriButtonVariant.secondary,
                      ),
                    ),
                    const SizedBox(width: FantasySpacing.sm),
                    Expanded(
                      child: AfriButton(
                        label: 'Confirm squad',
                        onTap: _saving
                            ? () {}
                            : () => _confirmSquad(
                                competitionId: competitionId,
                                gameweekId: gameweekId,
                                entry: entry,
                                totalBudget: totalBudget,
                                maxPerClub: maxPerClub,
                              ),
                        variant: AfriButtonVariant.accent,
                        isLoading: _saving,
                        enabled: !_saving,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<List<PitchSlotData>> _rowsForFormation(
    List<_EditableSelection> starters,
  ) {
    final grouped = <PlayerPosition, List<_EditableSelection>>{
      PlayerPosition.gk: starters
          .where((slot) => slot.position == PlayerPosition.gk)
          .toList(growable: false),
      PlayerPosition.def: starters
          .where((slot) => slot.position == PlayerPosition.def)
          .toList(growable: false),
      PlayerPosition.mid: starters
          .where((slot) => slot.position == PlayerPosition.mid)
          .toList(growable: false),
      PlayerPosition.fwd: starters
          .where((slot) => slot.position == PlayerPosition.fwd)
          .toList(growable: false),
    };

    final groupedRows = <List<_EditableSelection>>[
      grouped[PlayerPosition.gk]!,
      grouped[PlayerPosition.def]!,
      grouped[PlayerPosition.mid]!,
      grouped[PlayerPosition.fwd]!,
    ];

    return groupedRows
        .map((row) {
          return row
              .map(
                (slot) => PitchSlotData(
                  label: 'Add ${slot.position.name.toUpperCase()}',
                  position: slot.position,
                  player: slot.player,
                  onTap: () {},
                  isCaptain: slot.isCaptain,
                  isViceCaptain: slot.isViceCaptain,
                ),
              )
              .toList(growable: false);
        })
        .toList(growable: false);
  }

  void _wireStarterRowCallbacks({
    required List<List<PitchSlotData>> rows,
    required List<FantasyPlayer> players,
    required int remainingBudget,
    required Set<int> selectedIds,
    required Map<int, int> clubCounts,
    required int maxPerClub,
  }) {
    var rowIndex = 0;
    for (final row in rows) {
      var slotIndex = 0;
      for (final slot in row) {
        final editable = _starterSlots[rowIndex][slotIndex];
        row[slotIndex] = PitchSlotData(
          label: slot.label,
          position: slot.position,
          player: slot.player,
          onTap: () => _onSlotPressed(
            slot: editable,
            players: players,
            remainingBudget: remainingBudget + (editable.player?.price ?? 0),
            selectedIds: selectedIds,
            clubCounts: clubCounts,
            maxPerClub: maxPerClub,
          ),
          isCaptain: editable.isCaptain,
          isViceCaptain: editable.isViceCaptain,
        );
        slotIndex++;
      }
      rowIndex++;
    }
  }

  List<List<_EditableSelection>> get _starterSlots {
    final starters = _draft
        .where((slot) => slot.isStarter)
        .toList(growable: false);
    return <List<_EditableSelection>>[
      starters
          .where((slot) => slot.position == PlayerPosition.gk)
          .toList(growable: false),
      starters
          .where((slot) => slot.position == PlayerPosition.def)
          .toList(growable: false),
      starters
          .where((slot) => slot.position == PlayerPosition.mid)
          .toList(growable: false),
      starters
          .where((slot) => slot.position == PlayerPosition.fwd)
          .toList(growable: false),
    ];
  }

  Future<void> _onSlotPressed({
    required _EditableSelection slot,
    required List<FantasyPlayer> players,
    required int remainingBudget,
    required Set<int> selectedIds,
    required Map<int, int> clubCounts,
    required int maxPerClub,
  }) async {
    if (slot.player == null) {
      final player = await showPlayerPickerSheet(
        context: context,
        players: players,
        initialPosition: slot.position,
        budgetRemaining: remainingBudget,
        selectedPlayerIds: selectedIds,
        clubCounts: clubCounts,
        maxPerClub: maxPerClub,
      );
      if (player == null) return;
      setState(() => slot.player = player);
      return;
    }

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => AfriBottomSheet(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              slot.player!.name,
              style: FantasyTypography.h3.copyWith(
                color: FantasyColors.textPrimary,
              ),
            ),
            const SizedBox(height: FantasySpacing.md),
            _ActionSheetButton(
              label: 'Captain',
              onTap: () => Navigator.of(context).pop('captain'),
            ),
            _ActionSheetButton(
              label: 'Vice-Captain',
              onTap: () => Navigator.of(context).pop('vice'),
            ),
            _ActionSheetButton(
              label: 'Transfer Out',
              onTap: () => Navigator.of(context).pop('remove'),
            ),
            _ActionSheetButton(
              label: 'View Stats',
              onTap: () => Navigator.of(context).pop('stats'),
            ),
          ],
        ),
      ),
    );

    if (action == null) return;
    switch (action) {
      case 'captain':
        setState(() {
          for (final item in _draft) {
            item.isCaptain = false;
          }
          slot.isCaptain = true;
          if (slot.isViceCaptain) slot.isViceCaptain = false;
        });
        break;
      case 'vice':
        setState(() {
          for (final item in _draft) {
            item.isViceCaptain = false;
          }
          slot.isViceCaptain = true;
          if (slot.isCaptain) slot.isCaptain = false;
        });
        break;
      case 'remove':
        setState(() {
          slot.player = null;
          slot.isCaptain = false;
          slot.isViceCaptain = false;
        });
        break;
      case 'stats':
        if (!mounted) return;
        context.push(
          '/fantasy/${widget.slug}/player/${slot.player!.externalId}',
        );
        break;
    }
  }

  void _applyFormation() {
    final parts = _formation.split('-').map(int.parse).toList(growable: false);
    if (parts.length != 3) return;

    final defenders = parts[0];
    final midfielders = parts[1];
    final forwards = parts[2];

    final startersByPosition = <PlayerPosition, int>{
      PlayerPosition.gk: 1,
      PlayerPosition.def: defenders,
      PlayerPosition.mid: midfielders,
      PlayerPosition.fwd: forwards,
    };

    for (final position in PlayerPosition.values) {
      final slots = _draft
          .where((slot) => slot.position == position)
          .toList(growable: false);
      final starterCount = startersByPosition[position] ?? 0;
      for (var index = 0; index < slots.length; index++) {
        slots[index].isStarter = index < starterCount;
      }
    }

    final bench = _draft
        .where((slot) => !slot.isStarter)
        .toList(growable: false);
    var order = 1;
    for (final slot in bench) {
      slot.benchOrder = order++;
    }
  }

  void _autoFill({
    required List<FantasyPlayer> players,
    required int totalBudget,
    required int maxPerClub,
  }) {
    final sorted = players.toList(growable: false)
      ..sort((left, right) => left.price.compareTo(right.price));
    final clubCounts = <int, int>{};

    setState(() {
      for (final slot in _draft) {
        slot.player = null;
        slot.isCaptain = false;
        slot.isViceCaptain = false;
      }

      var spent = 0;
      for (final slot in _draft) {
        final candidate = sorted.firstWhere(
          (player) =>
              player.position == slot.position &&
              !_draft.any(
                (item) => item.player?.externalId == player.externalId,
              ) &&
              spent + player.price <= totalBudget &&
              (clubCounts[player.teamId] ?? 0) < maxPerClub,
          orElse: () =>
              sorted.firstWhere((player) => player.position == slot.position),
        );

        slot.player = candidate;
        spent += candidate.price;
        clubCounts.update(
          candidate.teamId,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
      }

      final firstForward = _draft.firstWhere(
        (slot) => slot.position == PlayerPosition.fwd && slot.player != null,
      );
      final firstMid = _draft.firstWhere(
        (slot) => slot.position == PlayerPosition.mid && slot.player != null,
      );
      firstForward.isCaptain = true;
      firstMid.isViceCaptain = true;
      _applyFormation();
    });
  }

  Future<void> _confirmSquad({
    required String competitionId,
    required String gameweekId,
    required FantasyEntry? entry,
    required int totalBudget,
    required int maxPerClub,
  }) async {
    final startersSelected = _draft
        .where((slot) => slot.isStarter && slot.player != null)
        .length;
    final hasCaptain = _draft.any(
      (slot) => slot.isCaptain && slot.player != null,
    );
    final hasVice = _draft.any(
      (slot) => slot.isViceCaptain && slot.player != null,
    );
    final spent = _draft.fold<int>(
      0,
      (sum, slot) => sum + (slot.player?.price ?? 0),
    );
    final remaining = totalBudget - spent;

    if (startersSelected < 11 || !hasCaptain || !hasVice || remaining < 0) {
      AfriToast.error(
        context,
        'The squad is incomplete. Check starters, budget, and captaincy.',
      );
      return;
    }

    final clubCounts = <int, int>{};
    for (final player
        in _draft.map((slot) => slot.player).whereType<FantasyPlayer>()) {
      clubCounts.update(player.teamId, (value) => value + 1, ifAbsent: () => 1);
    }
    if (clubCounts.values.any((count) => count > maxPerClub)) {
      AfriToast.error(
        context,
        'You cannot pick more than $maxPerClub players from one club.',
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final repo = ref.read(squadRepositoryProvider);
      final resolvedEntry = entry ?? await _createEntry(widget.slug);
      final payload = _draft
          .where((slot) => slot.player != null)
          .map(
            (slot) => <String, dynamic>{
              'player_id': slot.player!.externalId,
              'position': slot.position.dbValue,
              'is_starter': slot.isStarter,
              'bench_order': slot.isStarter ? null : slot.benchOrder,
              'is_captain': slot.isCaptain,
              'is_vice_captain': slot.isViceCaptain,
              'purchase_price': slot.player!.price,
              'multiplier': slot.isCaptain ? 2 : 1,
            },
          )
          .toList(growable: false);

      await repo.saveSquad(
        entryId: resolvedEntry.id,
        gameweekId: gameweekId,
        selections: payload,
      );
      if (!mounted) return;
      AfriToast.success(context, 'Squad confirmed.');
      ref.invalidate(myEntryProvider(competitionId));
      ref.invalidate(
        squadForGameweekProvider((
          entryId: resolvedEntry.id,
          gameweekId: gameweekId,
        )),
      );
      context.go('/fantasy/${widget.slug}/live');
    } on FantasyException catch (error) {
      if (mounted) {
        AfriToast.error(context, error.message);
      }
    } catch (error) {
      if (mounted) {
        AfriToast.error(context, error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<FantasyEntry> _createEntry(String competitionSlug) async {
    final controller = TextEditingController(text: 'My Team');
    final teamName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: FantasyColors.surface,
        title: Text(
          'Name your team',
          style: FantasyTypography.h3.copyWith(
            color: FantasyColors.textPrimary,
          ),
        ),
        content: TextField(
          controller: controller,
          style: FantasyTypography.body.copyWith(
            color: FantasyColors.textPrimary,
          ),
          decoration: const InputDecoration(
            hintText: 'Team name',
            hintStyle: FantasyTypography.body,
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (teamName == null || teamName.trim().isEmpty) {
      throw const FantasyException('Team creation cancelled.');
    }

    return ref
        .read(squadRepositoryProvider)
        .createEntry(
          competitionSlug: competitionSlug,
          teamName: teamName,
        );
  }

  String _formationFromDraft() {
    final def = _draft
        .where((slot) => slot.isStarter && slot.position == PlayerPosition.def)
        .length;
    final mid = _draft
        .where((slot) => slot.isStarter && slot.position == PlayerPosition.mid)
        .length;
    final fwd = _draft
        .where((slot) => slot.isStarter && slot.position == PlayerPosition.fwd)
        .length;
    return '$def-$mid-$fwd';
  }
}

class _ValidationRow extends StatelessWidget {
  const _ValidationRow({required this.label, required this.ok});

  final String label;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: FantasySpacing.sm),
      child: Row(
        children: <Widget>[
          Icon(
            ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: ok ? FantasyColors.successGreen : FantasyColors.dangerRed,
            size: 18,
          ),
          const SizedBox(width: FantasySpacing.sm),
          Text(
            label,
            style: FantasyTypography.caption.copyWith(
              color: FantasyColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionSheetButton extends StatelessWidget {
  const _ActionSheetButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: FantasySpacing.sm),
      child: AfriButton(
        label: label,
        onTap: onTap,
        variant: AfriButtonVariant.secondary,
      ),
    );
  }
}

class _EditableSelection {
  _EditableSelection({
    required this.position,
    required this.isStarter,
    this.benchOrder,
    this.player,
    this.isCaptain = false,
    this.isViceCaptain = false,
  });

  factory _EditableSelection.fromSelection(SquadSelection selection) {
    return _EditableSelection(
      position: selection.position,
      isStarter: selection.isStarter,
      benchOrder: selection.benchOrder,
      player: selection.player,
      isCaptain: selection.isCaptain,
      isViceCaptain: selection.isViceCaptain,
    );
  }

  final PlayerPosition position;
  bool isStarter;
  int? benchOrder;
  FantasyPlayer? player;
  bool isCaptain;
  bool isViceCaptain;
}

extension on PlayerPosition {
  String get dbValue {
    switch (this) {
      case PlayerPosition.gk:
        return 'GK';
      case PlayerPosition.def:
        return 'DEF';
      case PlayerPosition.mid:
        return 'MID';
      case PlayerPosition.fwd:
        return 'FWD';
    }
  }
}
