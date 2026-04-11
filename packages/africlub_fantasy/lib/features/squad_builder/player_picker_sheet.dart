import 'dart:async';

import 'package:africlub_fantasy/core/constants.dart';
import 'package:africlub_fantasy/models/fantasy_player.dart';
import 'package:africlub_fantasy/features/shared/fantasy_ui.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';

enum PlayerSortOption { priceDesc, pointsDesc, formDesc, ownershipDesc }

Future<FantasyPlayer?> showPlayerPickerSheet({
  required BuildContext context,
  required List<FantasyPlayer> players,
  PlayerPosition? initialPosition,
  required int budgetRemaining,
  required Set<int> selectedPlayerIds,
  required Map<int, int> clubCounts,
  required int maxPerClub,
}) {
  return showAfriBottomSheet<FantasyPlayer>(
    context: context,
    isScrollControlled: true,
    builder: (_) => SizedBox(
      height: MediaQuery.of(context).size.height * 0.92,
      child: PlayerPickerList(
        players: players,
        initialPosition: initialPosition,
        budgetRemaining: budgetRemaining,
        selectedPlayerIds: selectedPlayerIds,
        clubCounts: clubCounts,
        maxPerClub: maxPerClub,
        onSelected: (player) => Navigator.of(context).pop(player),
      ),
    ),
  );
}

class PlayerPickerList extends StatefulWidget {
  const PlayerPickerList({
    required this.players,
    required this.budgetRemaining,
    required this.selectedPlayerIds,
    required this.clubCounts,
    required this.maxPerClub,
    required this.onSelected,
    this.initialPosition,
    super.key,
  });

  final List<FantasyPlayer> players;
  final PlayerPosition? initialPosition;
  final int budgetRemaining;
  final Set<int> selectedPlayerIds;
  final Map<int, int> clubCounts;
  final int maxPerClub;
  final ValueChanged<FantasyPlayer> onSelected;

  @override
  State<PlayerPickerList> createState() => _PlayerPickerListState();
}

class _PlayerPickerListState extends State<PlayerPickerList> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  PlayerPosition? _position;
  PlayerSortOption _sort = PlayerSortOption.priceDesc;
  String _query = '';
  Timer? _debounce;
  int _page = 1;

  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _position = widget.initialPosition;
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 180) {
      final next = _page + 1;
      if (next != _page) {
        setState(() => _page = next);
      }
    }
  }

  List<FantasyPlayer> get _filteredPlayers {
    final normalizedQuery = _query.trim().toLowerCase();
    final filtered = widget.players
        .where((player) {
          final matchesPosition =
              _position == null || player.position == _position;
          final matchesQuery =
              normalizedQuery.isEmpty ||
              player.name.toLowerCase().contains(normalizedQuery) ||
              player.teamName.toLowerCase().contains(normalizedQuery);
          return matchesPosition && matchesQuery;
        })
        .toList(growable: false);

    filtered.sort((left, right) {
      switch (_sort) {
        case PlayerSortOption.priceDesc:
          return right.price.compareTo(left.price);
        case PlayerSortOption.pointsDesc:
          return right.totalPoints.compareTo(left.totalPoints);
        case PlayerSortOption.formDesc:
          return right.formPoints.compareTo(left.formPoints);
        case PlayerSortOption.ownershipDesc:
          return right.ownershipPercent.compareTo(left.ownershipPercent);
      }
    });

    final max = (_page * _pageSize).clamp(0, filtered.length);
    return filtered.take(max).toList(growable: false);
  }

  bool _canAdd(FantasyPlayer player) {
    final clubCount = widget.clubCounts[player.teamId] ?? 0;
    if (widget.selectedPlayerIds.contains(player.externalId)) return false;
    if (player.price > widget.budgetRemaining) return false;
    if (clubCount >= widget.maxPerClub) return false;
    return true;
  }

  String _sortLabel(PlayerSortOption sort) {
    switch (sort) {
      case PlayerSortOption.priceDesc:
        return 'Price ↓';
      case PlayerSortOption.pointsDesc:
        return 'Points ↓';
      case PlayerSortOption.formDesc:
        return 'Form ↓';
      case PlayerSortOption.ownershipDesc:
        return 'Ownership ↓';
    }
  }

  @override
  Widget build(BuildContext context) {
    final players = _filteredPlayers;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Pick a player',
          style: FantasyTypography.h2.copyWith(
            color: FantasyColors.textPrimary,
          ),
        ),
        const SizedBox(height: FantasySpacing.md),
        FantasySearchField(
          controller: _searchController,
          hintText: 'Search player or team',
          onChanged: (value) {
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 300), () {
              if (!mounted) return;
              setState(() {
                _query = value;
                _page = 1;
              });
            });
          },
        ),
        const SizedBox(height: FantasySpacing.md),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: <Widget>[
              FantasyChipChoice(
                label: 'ALL',
                selected: _position == null,
                onTap: () => setState(() => _position = null),
              ),
              const SizedBox(width: FantasySpacing.sm),
              ...PlayerPosition.values.map(
                (position) => Padding(
                  padding: const EdgeInsets.only(right: FantasySpacing.sm),
                  child: FantasyChipChoice(
                    label: position.name.toUpperCase(),
                    selected: _position == position,
                    onTap: () => setState(() => _position = position),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: FantasySpacing.sm),
        Align(
          alignment: Alignment.centerRight,
          child: DropdownButtonHideUnderline(
            child: DropdownButton<PlayerSortOption>(
              value: _sort,
              dropdownColor: FantasyColors.surface,
              style: FantasyTypography.caption.copyWith(
                color: FantasyColors.textPrimary,
              ),
              items: PlayerSortOption.values
                  .map(
                    (sort) => DropdownMenuItem<PlayerSortOption>(
                      value: sort,
                      child: Text(_sortLabel(sort)),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _sort = value);
              },
            ),
          ),
        ),
        const SizedBox(height: FantasySpacing.sm),
        Expanded(
          child: players.isEmpty
              ? const FantasyStateCard.empty(
                  title: 'No players found',
                  message: 'Try a different filter or search query.',
                )
              : ListView.separated(
                  controller: _scrollController,
                  itemCount: players.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: FantasySpacing.sm),
                  itemBuilder: (BuildContext context, int index) {
                    final player = players[index];
                    final canAdd = _canAdd(player);
                    final budgetAfter = widget.budgetRemaining - player.price;

                    return FantasyGlassCard(
                      padding: const EdgeInsets.all(FantasySpacing.sm),
                      child: Row(
                        children: <Widget>[
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: FantasyColors.surfaceAlt,
                            child: Text(
                              player.shortName.substring(0, 1),
                              style: FantasyTypography.body.copyWith(
                                color: FantasyColors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: FantasySpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: Text(
                                        player.name,
                                        style: FantasyTypography.body.copyWith(
                                          color: FantasyColors.textPrimary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: FantasyColors.surfaceAlt,
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Text(
                                        player.positionLabel,
                                        style: FantasyTypography.label.copyWith(
                                          color: FantasyColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: FantasySpacing.xs),
                                Text(
                                  '${player.teamName} · ${player.priceDisplay}',
                                  style: FantasyTypography.caption.copyWith(
                                    color: FantasyColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: FantasySpacing.sm),
                                Row(
                                  children: <Widget>[
                                    SizedBox(
                                      width: 56,
                                      height: 20,
                                      child: _MiniSparkline(
                                        seed: player.externalId,
                                      ),
                                    ),
                                    const SizedBox(width: FantasySpacing.sm),
                                    Expanded(
                                      child: Text(
                                        '${player.ownershipPercent.toStringAsFixed(1)}% ownership · ${player.totalPoints} pts',
                                        style: FantasyTypography.label.copyWith(
                                          color: FantasyColors.textMuted,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: FantasySpacing.xs),
                                Text(
                                  'Budget after: £${(budgetAfter / 10).toStringAsFixed(1)}M',
                                  style: FantasyTypography.label.copyWith(
                                    color: canAdd
                                        ? FantasyColors.successGreen
                                        : FantasyColors.dangerRed,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: FantasySpacing.sm),
                          IconButton(
                            onPressed: canAdd
                                ? () => widget.onSelected(player)
                                : null,
                            icon: const Icon(Icons.add_circle_rounded),
                            color: canAdd
                                ? FantasyColors.successGreen
                                : FantasyColors.textMuted,
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _MiniSparkline extends StatelessWidget {
  const _MiniSparkline({required this.seed});

  final int seed;

  @override
  Widget build(BuildContext context) {
    final values = List<double>.generate(
      5,
      (index) => ((seed + (index * 7)) % 12 + 1).toDouble(),
      growable: false,
    );
    final maxValue = values.reduce((a, b) => a > b ? a : b);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: values
          .map(
            (value) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Container(
                  height: (value / maxValue) * 20,
                  decoration: BoxDecoration(
                    color: FantasyColors.successGreen.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}
