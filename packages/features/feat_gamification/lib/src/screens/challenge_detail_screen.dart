import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../controllers/challenge_detail_controller.dart';
import '../models/challenge_models.dart';

class ChallengeDetailScreen extends ConsumerWidget {
  const ChallengeDetailScreen({super.key, required this.id});

  final String id;

  void _showJoinSheet(BuildContext context, WidgetRef ref, Challenge challenge) {
    showAfriBottomSheet(
      context: context,
      builder: (context) => _JoinChallengeSheet(challengeId: id, challenge: challenge),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(challengeDetailProvider(id));

    return Scaffold(
      appBar: AppBar(
        title: const Text('CHALLENGE DETAIL'),
      ),
      body: stateAsync.when(
        loading: () => const Center(child: AfriLoadingIndicator()),
        error: (err, _) => Center(
          child: AfriStateView.error(
            title: 'Load Failed',
            message: err.toString(),
            onAction: () => ref.read(challengeDetailProvider(id).notifier).load(),
            actionLabel: 'Retry',
          ),
        ),
        data: (state) {
          final challenge = state.challenge;
          final fixture = challenge.fixture;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(SpacingTokens.screenPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Hero Section ──
                if (fixture != null)
                  _FixtureHero(fixture: fixture, status: challenge.status),

                const SizedBox(height: SpacingTokens.sectionGap),

                // ── Metrics Row ──
                _PoolMetrics(challenge: challenge),

                const SizedBox(height: SpacingTokens.sectionGap),

                // ── Status / Result Card ──
                if (challenge.isSettled)
                  _ResultCard(challenge: challenge, userEntry: state.userEntry),

                const SizedBox(height: SpacingTokens.sectionGap),

                // ── My Participation ──
                if (state.hasJoined)
                  _MyEntryCard(entry: state.userEntry!)
                else if (challenge.isOpen)
                  AfriButton(
                    label: 'JOIN CHALLENGE',
                    icon: AfriIcons.join,
                    onTap: () => _showJoinSheet(context, ref, challenge),
                  ),

                const SizedBox(height: SpacingTokens.sectionGap),

                // ── Participants ──
                _SectionHeader(title: 'PARTICIPANTS (${state.entries.length})'),
                const SizedBox(height: SpacingTokens.spacing3),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: state.entries.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final entry = state.entries[index];
                    return _ParticipantRow(entry: entry);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FixtureHero extends StatelessWidget {
  const _FixtureHero({required this.fixture, required this.status});
  final dynamic fixture;
  final ChallengeStatus status;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        children: [
          Text(
            fixture.competitionName.toUpperCase(),
            style: TypographyTokens.labelSmall(),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _TeamHeader(name: fixture.homeTeamShort),
              _ScoreHeader(
                status: fixture.status,
                homeScore: fixture.homeScore,
                awayScore: fixture.awayScore,
              ),
              _TeamHeader(name: fixture.awayTeamShort),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            status.name.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: ColorTokens.clubAccent,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamHeader extends StatelessWidget {
  const _TeamHeader({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Text(
      name.toUpperCase(),
      style: TypographyTokens.monolithFont(fontSize: 20, fontWeight: FontWeight.w900),
    );
  }
}

class _ScoreHeader extends StatelessWidget {
  const _ScoreHeader({required this.status, this.homeScore, this.awayScore});
  final String status;
  final int? homeScore;
  final int? awayScore;

  @override
  Widget build(BuildContext context) {
    final s = status.toLowerCase();
    if (s != 'live' && s != 'finished') {
      return Text(
        'VS',
        style: TypographyTokens.monolithFont(fontSize: 16, color: ColorTokens.clubAccent),
      );
    }
    return Text(
      '${homeScore ?? 0} - ${awayScore ?? 0}',
      style: TypographyTokens.monolithFont(fontSize: 24, fontWeight: FontWeight.w900),
    );
  }
}

class _PoolMetrics extends StatelessWidget {
  const _PoolMetrics({required this.challenge});
  final Challenge challenge;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _MetricItem(label: 'STAKE', value: '${challenge.stakeFet}'),
        const Spacer(),
        _MetricItem(label: 'PLAYERS', value: '${challenge.totalParticipants}'),
        const Spacer(),
        _MetricItem(label: 'TOTAL POOL', value: '${challenge.totalPoolFet}', accent: true),
      ],
    );
  }
}

class _MetricItem extends StatelessWidget {
  const _MetricItem({required this.label, required this.value, this.accent = false});
  final String label;
  final String value;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: TypographyTokens.labelSmall()),
        const SizedBox(height: 4),
        Text(
          value,
          style: TypographyTokens.monolithFont(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: accent ? ColorTokens.clubAccent : ColorTokens.onSurface,
          ),
        ),
      ],
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.challenge, this.userEntry});
  final Challenge challenge;
  final ChallengeEntry? userEntry;

  @override
  Widget build(BuildContext context) {
    final isWinner = userEntry?.status == ChallengeEntryStatus.winner;
    final isLoser = userEntry?.status == ChallengeEntryStatus.loser;
    final isRefunded = userEntry?.status == ChallengeEntryStatus.refunded;

    Color color = ColorTokens.onSurfaceVariant;
    String title = 'CHALLENGE FINISHED';
    String message = 'The match has concluded.';

    if (isWinner) {
      color = ColorTokens.success;
      title = 'YOU WON!';
      message = 'You earned ${userEntry?.payoutFet} FET!';
    } else if (isLoser) {
      color = ColorTokens.error;
      title = 'YOU LOST';
      message = 'Better luck next time.';
    } else if (isRefunded) {
      color = ColorTokens.clubAccent;
      title = 'REFUNDED';
      message = 'Stakes have been returned.';
    }

    return ClayCard(
      child: Column(
        children: [
          Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 8),
          Text(message, style: TypographyTokens.bodyMedium(), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _MyEntryCard extends StatelessWidget {
  const _MyEntryCard({required this.entry});
  final ChallengeEntry entry;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      animate: false,
      child: Row(
        children: [
          const Icon(AfriIcons.predict, color: ColorTokens.clubAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('YOUR PREDICTION', style: TypographyTokens.labelSmall()),
                Text(
                  '${entry.predictedHomeScore} - ${entry.predictedAwayScore}',
                  style: TypographyTokens.monolithFont(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          _StatusLabel(status: entry.status),
        ],
      ),
    );
  }
}

class _StatusLabel extends StatelessWidget {
  const _StatusLabel({required this.status});
  final ChallengeEntryStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      ChallengeEntryStatus.active => ColorTokens.warning,
      ChallengeEntryStatus.winner => ColorTokens.success,
      ChallengeEntryStatus.loser => ColorTokens.error,
      _ => ColorTokens.onSurfaceVariant,
    };
    return Text(
      status.name.toUpperCase(),
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: color),
    );
  }
}

class _ParticipantRow extends StatelessWidget {
  const _ParticipantRow({required this.entry});
  final ChallengeEntry entry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white10),
          alignment: Alignment.center,
          child: Text(
            (entry.userName ?? '?').substring(0, 1).toUpperCase(),
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(entry.userName ?? 'Supporter', style: TypographyTokens.bodyMedium()),
        ),
        Text(
          '${entry.predictedHomeScore} - ${entry.predictedAwayScore}',
          style: TypographyTokens.monolithFont(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TypographyTokens.editorialFont(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: ColorTokens.onSurfaceVariant,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _JoinChallengeSheet extends StatefulWidget {
  const _JoinChallengeSheet({required this.challengeId, required this.challenge});
  final String challengeId;
  final Challenge challenge;

  @override
  State<_JoinChallengeSheet> createState() => _JoinChallengeSheetState();
}

class _JoinChallengeSheetState extends State<_JoinChallengeSheet> {
  int _home = 2;
  int _away = 1;
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _Counter(value: _home, onChanged: (v) => setState(() => _home = v)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(':', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900)),
            ),
            _Counter(value: _away, onChanged: (v) => setState(() => _away = v)),
          ],
        ),
        const SizedBox(height: 32),
        AfriButton(
          label: 'CONFIRM JOIN (${widget.challenge.stakeFet} FET)',
          isLoading: _submitting,
          onTap: () async {
            setState(() => _submitting = true);
            final success = await ProviderScope.containerOf(context)
                .read(challengeDetailProvider(widget.challengeId).notifier)
                .join(_home, _away);
            
            if (mounted) {
              Navigator.pop(context);
              if (!success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Failed to join challenge.')),
                );
              }
            }
          },
        ),
      ],
    );
  }
}

class _Counter extends StatelessWidget {
  const _Counter({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(onPressed: value > 0 ? () => onChanged(value - 1) : null, icon: const Icon(Icons.remove)),
        Text('$value', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900)),
        IconButton(onPressed: () => onChanged(value + 1), icon: const Icon(Icons.add)),
      ],
    );
  }
}
