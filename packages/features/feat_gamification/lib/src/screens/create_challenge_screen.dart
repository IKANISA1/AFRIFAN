import 'dart:async';

import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../controllers/challenge_controller.dart';
import '../models/challenge_models.dart';
import '../models/prediction_models.dart';
import '../prediction_providers.dart';
import '../providers/fet_wallet_provider.dart';
import '../widgets/challenge_card.dart';
import 'package:core_utils/core_utils.dart';

class CreateChallengeScreen extends ConsumerStatefulWidget {
  const CreateChallengeScreen({super.key});

  @override
  ConsumerState<CreateChallengeScreen> createState() =>
      _CreateChallengeScreenState();
}

class _CreateChallengeScreenState extends ConsumerState<CreateChallengeScreen> {
  static const _stakeOptions = <int>[500, 1000, 3000, 5000, 10000];

  FixtureSummary? _selectedFixture;
  int _homeScore = 2;
  int _awayScore = 1;
  int _stakeFet = 1000;
  bool _loadingFixtures = true;
  bool _submitting = false;
  List<FixtureSummary> _fixtures = const <FixtureSummary>[];

  @override
  void initState() {
    super.initState();
    unawaited(_loadFixtures());
  }

  Future<void> _loadFixtures() async {
    setState(() => _loadingFixtures = true);
    try {
      final fixtures = await ref
          .read(challengeFixturesGatewayProvider)
          .loadFixtures(status: 'scheduled', limit: 60);
      if (!mounted) {
        return;
      }
      setState(() {
        _fixtures = fixtures.where((fixture) => fixture.isPredictable).toList();
        if (_fixtures.isNotEmpty) {
          _selectedFixture = _fixtures.first;
        }
        _loadingFixtures = false;
      });
    } catch (error, stackTrace) {
      AfriLogger.warn(
        'CreateChallengeScreen',
        'Operation failed (non-critical).',
        error,
        stackTrace,
      );
      if (!mounted) {
        return;
      }
      setState(() => _loadingFixtures = false);
    }
  }

  Future<void> _confirmAndSubmit() async {
    final fixture = _selectedFixture;
    if (fixture == null || _submitting) {
      return;
    }

    final wallet = ref.read(fetWalletProvider).valueOrNull?.wallet;
    final confirmed = await showAfriBottomSheet<bool>(
      context: context,
      builder: (context) {
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(SpacingTokens.screenPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CONFIRM CHALLENGE',
                  style: TypographyTokens.titleMedium().copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: SpacingTokens.spacing4),
                _SummaryCard(
                  fixture: fixture,
                  homeScore: _homeScore,
                  awayScore: _awayScore,
                  stakeFet: _stakeFet,
                  balance: wallet?.balance ?? 0,
                ),
                const SizedBox(height: SpacingTokens.spacing4),
                AfriButton(
                  label: 'LOCK $_stakeFet FET',
                  icon: AfriIcons.checkGroup,
                  onTap: () => context.pop(true),
                ),
                const SizedBox(height: SpacingTokens.spacing3),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() => _submitting = true);
    final result = await ref
        .read(challengeRepositoryProvider)
        .createChallenge(
          matchId: fixture.id,
          homeScore: _homeScore,
          awayScore: _awayScore,
          stakeFet: _stakeFet,
        );

    if (!mounted) {
      return;
    }

    setState(() => _submitting = false);

    if (!result.isSuccess || result.challenge == null) {
      AfriToast.error(
        context,
        'Could not create the challenge. Check your FET balance.',
      );
      return;
    }

    ref.invalidate(challengeFeedProvider);
    ref.invalidate(myChallengesProvider);
    context.go('/challenge/${result.challenge!.id}');
  }

  @override
  Widget build(BuildContext context) {
    final walletAsync = ref.watch(fetWalletProvider);
    final wallet = walletAsync.valueOrNull?.wallet;
    final hasBalance = (wallet?.balance ?? 0) >= _stakeFet;

    return Scaffold(
      appBar: AfriAppBar(
        title: Text(
          'CREATE CHALLENGE',
          style: TypographyTokens.titleLarge().copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: _loadingFixtures
          ? const Center(child: AfriLoadingIndicator())
          : AfriRefreshIndicator(
              onRefresh: _loadFixtures,
              child: ListView(
                padding: const EdgeInsets.all(SpacingTokens.screenPadding),
                children: [
                  if (_fixtures.isEmpty)
                    const SizedBox.shrink()
                  else ...[
                    Text(
                      'Fixture',
                      style: TypographyTokens.labelSmall(
                        ColorTokens.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: SpacingTokens.spacing2),
                    _FixtureDropdown(
                      fixtures: _fixtures,
                      selected: _selectedFixture,
                      onChanged: (fixture) =>
                          setState(() => _selectedFixture = fixture),
                    ),
                    const SizedBox(height: SpacingTokens.sectionGap),
                    Text(
                      'Exact score',
                      style: TypographyTokens.labelSmall(
                        ColorTokens.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: SpacingTokens.spacing3),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Align(
                            child: _ScoreCounter(
                              label: _selectedFixture?.homeTeamShort ?? 'HOME',
                              value: _homeScore,
                              onChanged: (value) =>
                                  setState(() => _homeScore = value),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: SpacingTokens.spacing3,
                            vertical: SpacingTokens.spacing4,
                          ),
                          child: Text(
                            ':',
                            style: TypographyTokens.metricValue().copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Align(
                            child: _ScoreCounter(
                              label: _selectedFixture?.awayTeamShort ?? 'AWAY',
                              value: _awayScore,
                              onChanged: (value) =>
                                  setState(() => _awayScore = value),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: SpacingTokens.sectionGap),
                    Text(
                      'Stake',
                      style: TypographyTokens.labelSmall(
                        ColorTokens.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: SpacingTokens.spacing3),
                    Wrap(
                      spacing: SpacingTokens.spacing2,
                      runSpacing: SpacingTokens.spacing2,
                      children: _stakeOptions.map((stake) {
                        return AfriChoiceChip(
                          selected: _stakeFet == stake,
                          label: Text('$stake FET'),
                          onSelected: (_) => setState(() => _stakeFet = stake),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: SpacingTokens.sectionGap),
                    if (_selectedFixture != null)
                      _SummaryCard(
                        fixture: _selectedFixture!,
                        homeScore: _homeScore,
                        awayScore: _awayScore,
                        stakeFet: _stakeFet,
                        balance: wallet?.balance ?? 0,
                      ),
                    const SizedBox(height: SpacingTokens.spacing4),
                    if (!hasBalance)
                      Text(
                        'Your current FET balance does not cover this stake.',
                        style: TypographyTokens.labelSmall(ColorTokens.error),
                      ),
                    const SizedBox(height: SpacingTokens.spacing4),
                    AfriButton(
                      label: 'CREATE CHALLENGE',
                      icon: AfriIcons.versus,
                      isLoading: _submitting,
                      enabled: hasBalance,
                      onTap: _confirmAndSubmit,
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.fixture,
    required this.homeScore,
    required this.awayScore,
    required this.stakeFet,
    required this.balance,
  });

  final FixtureSummary fixture;
  final int homeScore;
  final int awayScore;
  final int stakeFet;
  final int balance;

  @override
  Widget build(BuildContext context) {
    final challenge = Challenge(
      id: 'preview',
      matchId: fixture.id,
      creatorUserId: 'me',
      stakeFet: stakeFet,
      status: ChallengeStatus.open,
      lockAt: fixture.kickoffAt ?? DateTime.now().add(const Duration(hours: 1)),
      totalParticipants: 1,
      totalPoolFet: stakeFet,
      clubId: 0,
      fixture: fixture,
      creatorName: 'You',
      creatorPrediction: ChallengeScorePrediction(
        homeScore: homeScore,
        awayScore: awayScore,
      ),
      permissions: const ChallengePermissions(isCreator: true),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ChallengeCard(challenge: challenge, compact: true),
        const SizedBox(height: SpacingTokens.spacing3),
        Wrap(
          spacing: SpacingTokens.spacing2,
          runSpacing: SpacingTokens.spacing2,
          children: [
            StakeBadge(stakeFet: stakeFet),
            ScorePredictionPill(
              homeScore: homeScore,
              awayScore: awayScore,
              label: 'Your pick',
              accent: ColorTokens.clubAccent,
            ),
            _MetaChip(label: 'Balance $balance FET'),
            const _MetaChip(label: 'Locks at kickoff'),
          ],
        ),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.spacing3,
        vertical: SpacingTokens.spacing2 - SpacingTokens.spacing1 / 2,
      ),
      decoration: BoxDecoration(
        color: ColorTokens.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(ShapeTokens.radiusFull),
        border: BorderTokens.all(color: ColorTokens.ghostBorder),
      ),
      child: Text(label, style: TypographyTokens.labelSmall()),
    );
  }
}

class _FixtureDropdown extends StatelessWidget {
  const _FixtureDropdown({
    required this.fixtures,
    required this.selected,
    required this.onChanged,
  });

  final List<FixtureSummary> fixtures;
  final FixtureSummary? selected;
  final ValueChanged<FixtureSummary?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.spacing4),
      decoration: BoxDecoration(
        color: ColorTokens.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(ShapeTokens.radiusLg),
        border: BorderTokens.all(color: ColorTokens.ghostBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<FixtureSummary>(
          value: selected,
          isExpanded: true,
          dropdownColor: ColorTokens.surfaceContainerHigh,
          items: fixtures.map((fixture) {
            return DropdownMenuItem<FixtureSummary>(
              value: fixture,
              child: Text(
                '${fixture.homeTeamShort} vs ${fixture.awayTeamShort} • ${fixture.competitionName}',
                style: TypographyTokens.bodyMedium(),
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _ScoreCounter extends StatelessWidget {
  const _ScoreCounter({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: TypographyTokens.labelSmall()),
        const SizedBox(height: SpacingTokens.spacing2),
        Row(
          children: [
            AfriIconButton(
              icon: AfriIcons.remove,
              onTap: value > 0 ? () => onChanged(value - 1) : null,
              tooltip: 'Decrease $label',
            ),
            Text(
              '$value',
              style: TypographyTokens.headlineLarge().copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            AfriIconButton(
              icon: AfriIcons.add,
              onTap: value < 20 ? () => onChanged(value + 1) : null,
              tooltip: 'Increase $label',
            ),
          ],
        ),
      ],
    );
  }
}
