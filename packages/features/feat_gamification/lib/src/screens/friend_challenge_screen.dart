import 'dart:async';

import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../fet_providers.dart';
import '../game_result_copy.dart';
import '../models/fet_models.dart';
import '../models/prediction_models.dart';
import '../prediction_providers.dart';
import '../widgets/market_option_pill.dart';

class FriendChallengeScreen extends ConsumerStatefulWidget {
  const FriendChallengeScreen({super.key, this.selectedOpponentUserId});

  final String? selectedOpponentUserId;

  @override
  ConsumerState<FriendChallengeScreen> createState() =>
      _FriendChallengeScreenState();
}

class _FriendChallengeScreenState extends ConsumerState<FriendChallengeScreen> {
  List<FetFriendProfile> _friends = const <FetFriendProfile>[];
  List<_ChallengeFixture> _fixtures = const <_ChallengeFixture>[];
  FetFriendProfile? _selectedSupporter;
  _ChallengeFixture? _selectedFixture;
  String? _selectedOutcome;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final predictionRepo = ref.read(predictionRepositoryProvider);
      final fetRepo = ref.read(fetRepositoryProvider);
      final friends = await fetRepo.loadFriends(limit: 24);
      final now = DateTime.now();
      final weekLater = now.add(const Duration(days: 7));

      final fixtures = await predictionRepo.loadFixturesByDate(
        dateFrom: now,
        dateTo: weekLater,
        status: 'scheduled',
        limit: 5,
      );
      final marketResults = await Future.wait<List<FixtureMarket>>(
        fixtures.map(
          (fixture) => predictionRepo.loadFixtureMarkets(fixture.id),
        ),
      );

      final challengeFixtures = <_ChallengeFixture>[];
      for (var index = 0; index < fixtures.length; index++) {
        final market = marketResults[index].cast<FixtureMarket?>().firstWhere(
          (entry) =>
              entry != null &&
              entry.outcomes.isNotEmpty &&
              entry.marketGroup == MarketGroup.matchResult,
          orElse: () => null,
        );
        if (market != null) {
          challengeFixtures.add(
            _ChallengeFixture(fixture: fixtures[index], market: market),
          );
        }
      }

      if (!mounted) {
        return;
      }

      final acceptedFriends = friends
          .where((friend) => friend.isFriend)
          .toList(growable: false);
      final initialSupporter = acceptedFriends
          .cast<FetFriendProfile?>()
          .firstWhere(
            (friend) => friend?.userId == widget.selectedOpponentUserId,
            orElse: () =>
                acceptedFriends.isEmpty ? null : acceptedFriends.first,
          );

      setState(() {
        _friends = acceptedFriends;
        _fixtures = challengeFixtures;
        _selectedSupporter = initialSupporter;
        _selectedFixture = challengeFixtures.isEmpty
            ? null
            : challengeFixtures.first;
        _isLoading = false;
        _error = null;
      });
    } catch (error, stackTrace) {
      AfriLogger.warn(
        'FriendChallengeScreen',
        'Operation failed (non-critical).',
        error,
        stackTrace,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _error = context.afriL10n.gameChallengeFlowTemporarilyUnavailable;
      });
    }
  }

  Future<void> _sendChallenge() async {
    final supporter = _selectedSupporter;
    final fixture = _selectedFixture;
    final outcome = _selectedOutcome;
    if (supporter == null ||
        fixture == null ||
        outcome == null ||
        _isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final result = await ref
        .read(predictionRepositoryProvider)
        .createFriendChallenge(
          opponentUserId: supporter.userId,
          fixtureMarketId: fixture.market.fixtureMarketId,
          selectedOutcome: outcome,
          message: context.afriL10n.gameHeadToHeadMessage(
            RuntimeBranding.displayAppName,
            fixture.fixture.homeTeamShort,
            fixture.fixture.awayTeamShort,
          ),
        );

    if (!mounted) {
      return;
    }

    if (result.isSuccess) {
      await showDialog<void>(
        context: context,
        builder: (context) => AfriAlertDialog(
          title: Text(context.afriL10n.gameChallengeSent),
          content: Text(
            result.message.isEmpty
                ? context.afriL10n.gameChallengeWaiting
                : context.localizeGameResultMessage(result.message),
          ),
          actions: [
            AfriTextButton(
              onPressed: () => context.pop(),
              child: Text(context.afriL10n.gameClose),
            ),
          ],
        ),
      );
    } else {
      AfriToast.error(
        context,
        result.message.isEmpty
            ? context.afriL10n.gameCouldNotSendChallenge
            : context.localizeGameResultMessage(result.message),
      );
    }

    if (mounted) {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AfriScreenScaffold(
      backgroundColor: ColorTokens.background,
      appBar: AfriAppBar(
        backgroundColor: ColorTokens.transparent,
        title: Text(
          context.afriL10n.gameChallenge,
          style: TypographyTokens.headlineSmall().copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
          ),
        ),
        leading: AfriIconButton(
          icon: AfriIcons.back,
          onTap: () => context.pop(),
          tooltip: context.afriL10n.gameBack,
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
                _selectedSupporter != null &&
                    _selectedFixture != null &&
                    _selectedOutcome != null &&
                    !_isSubmitting
                ? _sendChallenge
                : () {},
            label: _isSubmitting
                ? context.afriL10n.gameSending
                : context.afriL10n.gameSendChallenge,
            enabled:
                _selectedSupporter != null &&
                _selectedFixture != null &&
                _selectedOutcome != null &&
                !_isSubmitting,
            isLoading: _isSubmitting,
          ),
        ),
      ),
      scrollable: false,
      constrainContent: true,
      child: _isLoading
          ? const Padding(
              padding: EdgeInsets.all(SpacingTokens.spacing6),
              child: AfriSkeletonList(),
            )
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(SpacingTokens.spacing6),
                child: AfriStateView.offline(
                  title: context.afriL10n.gameChallengeUnavailable,
                  message: _error!,
                  actionLabel: context.afriL10n.gameRetry,
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
                  if (_friends.isEmpty)
                    AfriSectionCard(
                      title: context.afriL10n.gameSupporter,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.afriL10n.gameAddFriendsBeforeChallenge,
                            style: TypographyTokens.bodyMedium(),
                          ),
                          const SizedBox(height: SpacingTokens.spacing4),
                          AfriButton(
                            onTap: () => context.push('/fanzone'),
                            label: context.afriL10n.gameFindFriends,
                            variant: AfriButtonVariant.secondary,
                          ),
                        ],
                      ),
                    )
                  else
                    AfriSectionCard(
                      title: context.afriL10n.gameSupporter,
                      child: Wrap(
                        spacing: SpacingTokens.spacing2,
                        runSpacing: SpacingTokens.spacing2,
                        children: _friends
                            .map((supporter) {
                              final isSelected =
                                  supporter.userId ==
                                  _selectedSupporter?.userId;
                              final label = supporter.publicUserId == null
                                  ? supporter.displayName
                                  : '${supporter.displayName} · #${supporter.publicUserId}';
                              return _SelectionChip(
                                label: label,
                                isSelected: isSelected,
                                onTap: () {
                                  setState(() {
                                    _selectedSupporter = supporter;
                                  });
                                },
                              );
                            })
                            .toList(growable: false),
                      ),
                    ),
                  const SizedBox(height: SpacingTokens.spacing4),
                  AfriSectionCard(
                    title: context.afriL10n.gameFixture,
                    child: _fixtures.isEmpty
                        ? const SizedBox.shrink()
                        : Column(
                            children: _fixtures
                                .asMap()
                                .entries
                                .map((entry) {
                                  final fixture = entry.value;
                                  final isSelected =
                                      fixture.fixture.id ==
                                      _selectedFixture?.fixture.id;
                                  return Column(
                                    children: [
                                      if (entry.key > 0) const AfriDivider(),
                                      _FixtureRow(
                                        fixtureLabel:
                                            fixture.fixture.fixtureLabel,
                                        competitionLabel:
                                            fixture.fixture.competitionName,
                                        kickoffLabel: _kickoffLabel(
                                          context,
                                          fixture.fixture.kickoffAt,
                                        ),
                                        isSelected: isSelected,
                                        onTap: () {
                                          setState(() {
                                            _selectedFixture = fixture;
                                            _selectedOutcome = null;
                                          });
                                        },
                                      ),
                                    ],
                                  );
                                })
                                .toList(growable: false),
                          ),
                  ),
                  if (_selectedFixture != null) ...[
                    const SizedBox(height: SpacingTokens.spacing4),
                    AfriSectionCard(
                      title: context.afriL10n.gamePick,
                      child: Wrap(
                        spacing: SpacingTokens.spacing2,
                        runSpacing: SpacingTokens.spacing2,
                        children: _selectedFixture!.market.outcomes
                            .map((outcome) {
                              return MarketOptionPill(
                                label: outcome.label,
                                isSelected: _selectedOutcome == outcome.key,
                                onTap: () {
                                  setState(() {
                                    _selectedOutcome = outcome.key;
                                  });
                                },
                              );
                            })
                            .toList(growable: false),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  String _kickoffLabel(BuildContext context, DateTime? value) {
    if (value == null) {
      return context.afriL10n.gameKickoffTbd;
    }
    final local = value.toLocal();
    final materialL10n = MaterialLocalizations.of(context);
    return '${materialL10n.formatShortDate(local)} • '
        '${materialL10n.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
  }
}

class _SelectionChip extends StatelessWidget {
  const _SelectionChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AfriPressFeedback(
      onTap: onTap,
      builder: (context, _) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: SpacingTokens.spacing3,
          vertical: SpacingTokens.spacing2,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? ColorTokens.clubAccent.withValues(alpha: 0.12)
              : ColorTokens.surfaceContainerLow,
          borderRadius: BorderRadius.circular(ShapeTokens.radiusFull),
          border: BorderTokens.all(
            color: isSelected
                ? ColorTokens.clubAccent
                : ColorTokens.ghostBorder,
            opacity: isSelected ? 0.35 : 1,
          ),
        ),
        child: Text(
          label,
          style: TypographyTokens.labelSmall(
            isSelected ? ColorTokens.clubAccent : ColorTokens.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _FixtureRow extends StatelessWidget {
  const _FixtureRow({
    required this.fixtureLabel,
    required this.competitionLabel,
    required this.kickoffLabel,
    required this.isSelected,
    required this.onTap,
  });

  final String fixtureLabel;
  final String competitionLabel;
  final String kickoffLabel;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AfriPressFeedback(
      onTap: onTap,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: SpacingTokens.spacing3),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(fixtureLabel, style: TypographyTokens.titleSmall()),
                  const SizedBox(height: SpacingTokens.spacing1 / 2),
                  Text(
                    context.afriL10n.gamePair(competitionLabel, kickoffLabel),
                    style: TypographyTokens.bodySmall(),
                  ),
                ],
              ),
            ),
            Text(
              isSelected
                  ? context.afriL10n.gameSelected
                  : context.afriL10n.gameChoose,
              style: TypographyTokens.labelSmall(
                isSelected
                    ? ColorTokens.clubAccent
                    : ColorTokens.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChallengeFixture {
  const _ChallengeFixture({required this.fixture, required this.market});

  final FixtureSummary fixture;
  final FixtureMarket market;
}
