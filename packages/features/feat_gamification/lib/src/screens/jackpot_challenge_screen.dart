import 'dart:async';

import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/prediction_models.dart';
import '../prediction_providers.dart';
import '../widgets/jackpot_countdown_timer.dart';
import '../widgets/market_option_pill.dart';
import 'package:core_utils/core_utils.dart';

class JackpotChallengeScreen extends ConsumerStatefulWidget {
  const JackpotChallengeScreen({super.key});

  @override
  ConsumerState<JackpotChallengeScreen> createState() =>
      _JackpotChallengeScreenState();
}

class _JackpotChallengeScreenState
    extends ConsumerState<JackpotChallengeScreen> {
  PredictionJackpotRound? _round;
  List<PredictionLeaderboardEntry> _leaders =
      const <PredictionLeaderboardEntry>[];
  final Map<String, String> _selections = <String, String>{};
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _selections.clear();
    });

    try {
      final repo = ref.read(predictionRepositoryProvider);
      final results = await Future.wait<Object?>([
        repo.loadActiveJackpotRound(),
        repo.loadLeaderboard(limit: 5),
      ]);

      if (!mounted) {
        return;
      }

      final round = results[0] as PredictionJackpotRound?;
      setState(() {
        _round = round;
        _leaders = results[1]! as List<PredictionLeaderboardEntry>;
        _isLoading = false;
        _error = round == null || round.fixtures.isEmpty
            ? 'Jackpot round activation is pending.'
            : null;
      });
    } catch (error, stackTrace) {
      AfriLogger.warn(
        'JackpotChallengeScreen',
        'Operation failed (non-critical).',
        error,
        stackTrace,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _error = 'Jackpot challenge is temporarily unavailable.';
      });
    }
  }

  String _submissionKey(PredictionJackpotRound round) {
    final selectionParts = _selections.entries.toList()
      ..sort((left, right) => left.key.compareTo(right.key));
    final payload = selectionParts
        .map((entry) => '${entry.key}:${entry.value}')
        .join('|');
    return 'jackpot-${round.id}-$payload';
  }

  Future<void> _submit() async {
    final round = _round;
    if (round == null ||
        round.fixtures.isEmpty ||
        _selections.length != round.fixtures.length ||
        _isSubmitting ||
        !round.canEnter) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final repo = ref.read(predictionRepositoryProvider);
      final result = await repo.placeJackpotEntry(
        roundId: round.id,
        selections: round.fixtures
            .map(
              (fixture) => <String, String>{
                'fixture_market_id': fixture.fixtureMarketId,
                'selected_outcome': _selections[fixture.fixtureMarketId] ?? '',
              },
            )
            .toList(growable: false),
        idempotencyKey: _submissionKey(round),
      );

      if (!mounted) {
        return;
      }

      if (result.isSuccess) {
        await showDialog<void>(
          context: context,
          builder: (context) => AfriAlertDialog(
            title: const Text('Entry submitted'),
            content: Text(
              result.message.isEmpty
                  ? 'Your jackpot entry is now live.'
                  : result.message,
            ),
            actions: [
              AfriTextButton(
                onPressed: () => context.pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
        await _load();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.message.isEmpty
                  ? 'Could not submit the jackpot entry right now.'
                  : result.message,
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  String _kickoffLabel(DateTime? value) {
    if (value == null) {
      return 'Kickoff TBD';
    }
    final local = value.toLocal();
    return '${local.day}/${local.month} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final round = _round;
    final fixtureCount = round?.fixtures.length ?? 0;
    final completion = fixtureCount == 0
        ? 0.0
        : _selections.length / fixtureCount;

    return Scaffold(
      backgroundColor: ColorTokens.background,
      appBar: AfriAppBar(
        backgroundColor: ColorTokens.transparent,
        title: Text(
          'Jackpot',
          style: TypographyTokens.headlineSmall().copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
          ),
        ),
        leading: AfriIconButton(
          icon: AfriIcons.back,
          onTap: () => context.pop(),
          tooltip: 'Back',
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            SpacingTokens.spacing6,
            0,
            SpacingTokens.spacing6,
            SpacingTokens.spacing6,
          ),
          child: AfriButton(
            onTap:
                fixtureCount > 0 &&
                    _selections.length == fixtureCount &&
                    !_isSubmitting &&
                    (round?.canEnter ?? false)
                ? _submit
                : () {},
            label: _isSubmitting
                ? 'Submitting...'
                : round?.canEnter == false
                ? 'Entries closed'
                : 'Submit entry',
            enabled:
                fixtureCount > 0 &&
                _selections.length == fixtureCount &&
                !_isSubmitting &&
                (round?.canEnter ?? false),
            isLoading: _isSubmitting,
          ),
        ),
      ),
      body: _isLoading
          ? const Padding(
              padding: EdgeInsets.all(SpacingTokens.spacing6),
              child: AfriSkeletonList(),
            )
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(SpacingTokens.spacing6),
                child: AfriStateView.offline(
                  title: 'Jackpot unavailable',
                  message: _error!,
                  actionLabel: 'Retry',
                  onAction: _load,
                ),
              ),
            )
          : AfriRefreshIndicator(
              onRefresh: _load,
              color: ColorTokens.clubAccent,
              child: ListView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: const EdgeInsets.all(SpacingTokens.spacing6),
                children: [
                  AfriSurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Prize pool',
                          style: TypographyTokens.labelSmall(
                            ColorTokens.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: SpacingTokens.spacing2),
                        Text(
                          round == null
                              ? '0 FET'
                              : '${_formatFet(round.prizePoolFet)} FET',
                          style: TypographyTokens.displaySmall(
                            ColorTokens.clubAccent,
                          ).copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: SpacingTokens.spacing2),
                        Text(
                          round?.description.isNotEmpty == true
                              ? round!.description
                              : 'Pick every featured fixture before the round locks.',
                          style: TypographyTokens.bodyMedium(),
                        ),
                        if (round?.entryDeadlineAt != null) ...[
                          const SizedBox(height: SpacingTokens.spacing4),
                          JackpotCountdownTimer(
                            deadline: round!.entryDeadlineAt!,
                            onExpired: () {
                              unawaited(_load());
                            },
                          ),
                        ],
                        const SizedBox(height: SpacingTokens.spacing4),
                        AfriLinearProgressIndicator(
                          value: completion,
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(999),
                          color: ColorTokens.clubAccent,
                          backgroundColor: ColorTokens.surfaceContainerHighest,
                        ),
                        const SizedBox(height: SpacingTokens.spacing2),
                        Text(
                          '${_selections.length} of $fixtureCount picks complete',
                          style: TypographyTokens.bodySmall(),
                        ),
                        if ((round?.remainingEntries ?? 0) > 0) ...[
                          const SizedBox(height: 2),
                          Text(
                            '${round!.remainingEntries} entries remaining',
                            style: TypographyTokens.bodySmall(),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: SpacingTokens.spacing4),
                  AfriSectionCard(
                    title: 'Fixtures',
                    child: round == null || round.fixtures.isEmpty
                        ? const SizedBox.shrink()
                        : Column(
                            children: round.fixtures
                                .asMap()
                                .entries
                                .map((entry) {
                                  final data = entry.value;
                                  final selection =
                                      _selections[data.fixtureMarketId];
                                  return Column(
                                    children: [
                                      if (entry.key > 0) const AfriDivider(),
                                      _JackpotFixtureRow(
                                        fixtureLabel: data.fixtureLabel,
                                        details:
                                            '${data.competitionName} · ${_kickoffLabel(data.kickoffAt)}',
                                        selection: selection,
                                        isLocked: !(round.canEnter),
                                        outcomes: data.outcomes,
                                        onSelect: (outcomeKey) {
                                          if (!round.canEnter) {
                                            return;
                                          }
                                          setState(() {
                                            _selections[data.fixtureMarketId] =
                                                outcomeKey;
                                          });
                                        },
                                      ),
                                    ],
                                  );
                                })
                                .toList(growable: false),
                          ),
                  ),
                  if (_leaders.isNotEmpty) ...[
                    const SizedBox(height: SpacingTokens.spacing4),
                    AfriSectionCard(
                      title: 'Leaders',
                      child: Column(
                        children: _leaders
                            .take(5)
                            .toList(growable: false)
                            .asMap()
                            .entries
                            .map((entry) {
                              final leader = entry.value;
                              return Column(
                                children: [
                                  if (entry.key > 0) const AfriDivider(),
                                  _LeaderRow(
                                    rank: leader.rank,
                                    name: leader.displayName,
                                    total: '+${leader.totalFetEarned} FET',
                                  ),
                                ],
                              );
                            })
                            .toList(growable: false),
                      ),
                    ),
                  ],
                  const SizedBox(height: 120),
                ],
              ),
            ),
    );
  }
}

class _JackpotFixtureRow extends StatelessWidget {
  const _JackpotFixtureRow({
    required this.fixtureLabel,
    required this.details,
    required this.selection,
    required this.isLocked,
    required this.outcomes,
    required this.onSelect,
  });

  final String fixtureLabel;
  final String details;
  final String? selection;
  final bool isLocked;
  final List<MarketOutcomeOption> outcomes;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SpacingTokens.spacing3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(fixtureLabel, style: TypographyTokens.titleSmall()),
          const SizedBox(height: 2),
          Text(details, style: TypographyTokens.bodySmall()),
          const SizedBox(height: SpacingTokens.spacing3),
          Wrap(
            spacing: SpacingTokens.spacing2,
            runSpacing: SpacingTokens.spacing2,
            children: outcomes
                .map((outcome) {
                  return MarketOptionPill(
                    label: outcome.label,
                    isSelected: selection == outcome.key,
                    onTap: isLocked ? () {} : () => onSelect(outcome.key),
                  );
                })
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}

class _LeaderRow extends StatelessWidget {
  const _LeaderRow({
    required this.rank,
    required this.name,
    required this.total,
  });

  final int rank;
  final String name;
  final String total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SpacingTokens.spacing3),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '#$rank',
              style: TypographyTokens.titleSmall().copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: SpacingTokens.spacing3),
          Expanded(child: Text(name, style: TypographyTokens.titleSmall())),
          Text(
            total,
            style: TypographyTokens.titleSmall(
              ColorTokens.clubAccent,
            ).copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

String _formatFet(int value) {
  if (value >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(1)}M';
  }
  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}k';
  }
  return value.toString();
}
