import 'dart:async';

import 'package:core_feature_config/core_feature_config.dart';
import 'package:core_l10n/core_l10n.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../controllers/challenge_controller.dart';
import '../controllers/challenge_create_controller.dart';
import '../controllers/challenge_my_controller.dart';
import '../models/challenge_models.dart';
import '../models/prediction_models.dart';
import '../providers/fet_wallet_provider.dart';
import '../widgets/challenge_card.dart';

class CreateChallengeScreen extends ConsumerStatefulWidget {
  const CreateChallengeScreen({super.key, this.createFocusNode});

  final FocusNode? createFocusNode;

  @override
  ConsumerState<CreateChallengeScreen> createState() =>
      _CreateChallengeScreenState();
}

class _CreateChallengeScreenState extends ConsumerState<CreateChallengeScreen> {
  String? _selectedFixtureId;
  int _homeScore = 2;
  int _awayScore = 1;
  int _stakeFet = 0;
  bool? _lastOnline;

  Future<void> _confirmAndSubmit({
    required FixtureSummary fixture,
    required int stakeFet,
    required int balance,
  }) async {
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
                  context.afriL10n.challengeConfirmTitle,
                  style: TypographyTokens.titleMedium().copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: SpacingTokens.spacing4),
                _SummaryCard(
                  fixture: fixture,
                  homeScore: _homeScore,
                  awayScore: _awayScore,
                  stakeFet: stakeFet,
                  balance: balance,
                ),
                const SizedBox(height: SpacingTokens.spacing4),
                AfriButton(
                  key: const ValueKey<String>(
                    'challenge-create-confirm-action',
                  ),
                  label: context.afriL10n.challengeConfirmPoints(stakeFet),
                  icon: AfriIcons.checkGroup,
                  labelMaxLines: 2,
                  onTap: () => context.pop(true),
                ),
                const SizedBox(height: SpacingTokens.spacing3),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed != true || !mounted) return;

    final outcome = await ref
        .read(challengeCreateProvider.notifier)
        .create(
          matchId: fixture.id,
          homeScore: _homeScore,
          awayScore: _awayScore,
          stakeFet: stakeFet,
        );
    if (!mounted || !outcome.isSuccess || outcome.challenge == null) return;

    ref.invalidate(challengeFeedProvider);
    ref.invalidate(myChallengesProvider);
    context.go('/challenge/${outcome.challenge!.id}');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.afriL10n;
    final createAsync = ref.watch(challengeCreateProvider);
    final walletAsync = ref.watch(fetWalletProvider);
    final configuredActionsEnabled = ref.watch(
      challengeCreateActionsEnabledProvider,
    );

    return ConnectivityBuilder(
      builder: (context, isOnline) {
        final previousOnline = _lastOnline;
        _lastOnline = isOnline;
        if (previousOnline == false && isOnline) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            unawaited(ref.read(challengeCreateProvider.notifier).refresh());
          });
        }

        return AfriScreenScaffold(
          backgroundColor: ColorTokens.background,
          title: l10n.challengeCreateTitle,
          scrollable: false,
          constrainContent: true,
          child: createAsync.when(
            loading: () => Padding(
              padding: const EdgeInsets.symmetric(
                vertical: SpacingTokens.screenPadding,
              ),
              child: AfriStateView.loading(
                title: l10n.challengeFindingFixtures,
                message: l10n.challengeFindingFixturesBody,
              ),
            ),
            error: (error, _) => Padding(
              padding: const EdgeInsets.symmetric(
                vertical: SpacingTokens.screenPadding,
              ),
              child: _buildFailureView(error, isOnline),
            ),
            data: (state) {
              if (state.fixtures.isEmpty) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    vertical: SpacingTokens.screenPadding,
                  ),
                  children: [
                    AfriStateView.empty(
                      title: l10n.challengeNoFixtures,
                      message: l10n.challengeNoFixturesBody,
                      icon: AfriIcons.versus,
                      actionLabel: isOnline
                          ? l10n.challengeRefreshFixtures
                          : null,
                      onAction: isOnline
                          ? () => ref
                                .read(challengeCreateProvider.notifier)
                                .refresh()
                          : null,
                    ),
                  ],
                );
              }

              return _buildCreateForm(
                state,
                walletAsync,
                isOnline: isOnline,
                configuredActionsEnabled: configuredActionsEnabled,
                isRefreshing: createAsync.isRefreshing,
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildFailureView(Object error, bool isOnline) {
    final l10n = context.afriL10n;
    final failure = ChallengeCreateFailure.fromError(error);
    final content = _CreateFailureContent.fromFailure(failure, isOnline, l10n);
    final onAction = content.canRefresh
        ? () => unawaited(ref.read(challengeCreateProvider.notifier).refresh())
        : null;
    return switch (failure.kind) {
      ChallengeCreateFailureKind.offline => AfriStateView.offline(
        title: content.title,
        message: content.message,
        actionLabel: content.canRefresh ? l10n.gameRefresh : null,
        onAction: onAction,
      ),
      _ => AfriStateView.error(
        title: content.title,
        message: content.message,
        actionLabel: content.canRefresh ? l10n.gameRefresh : null,
        onAction: onAction,
      ),
    };
  }

  Widget _buildCreateForm(
    ChallengeCreateState state,
    AsyncValue<FetWalletSnapshot> walletAsync, {
    required bool isOnline,
    required bool configuredActionsEnabled,
    required bool isRefreshing,
  }) {
    final l10n = context.afriL10n;
    final fixtures = state.fixtures;
    final selectedFixture = fixtures
        .where((fixture) => fixture.id == _selectedFixtureId)
        .firstOrNull;
    final fixture = selectedFixture ?? fixtures.first;
    final wallet = walletAsync.valueOrNull?.wallet;
    final stakeOptions =
        ref
            .watch(featureConfigProvider)
            .valueOrNull
            ?.intOptions('challenge_stake_fet') ??
        const <int>[];
    final selectedStakeFet = _stakeFet > 0 && stakeOptions.contains(_stakeFet)
        ? _stakeFet
        : (stakeOptions.isNotEmpty ? stakeOptions.first : 0);
    final hasStakePolicy = selectedStakeFet > 0;
    final hasBalance =
        hasStakePolicy && (wallet?.balance ?? 0) >= selectedStakeFet;
    final actionsEnabled =
        configuredActionsEnabled &&
        isOnline &&
        !state.actionsBlocked &&
        walletAsync.hasValue;
    final isSubmitting = state.phase == ChallengeCreatePhase.syncing;
    final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.5;

    return AfriRefreshIndicator(
      onRefresh: () => ref.read(challengeCreateProvider.notifier).refresh(),
      child: ListView(
        key: const ValueKey<String>('challenge-create-scroll-view'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(
          vertical: SpacingTokens.screenPadding,
        ),
        children: [
          if (isRefreshing || isSubmitting) ...[
            AfriStateBanner(
              icon: AfriIcons.refresh,
              title: l10n.challengeCreating,
              subtitle: l10n.challengeCreatingBody,
              tone: AfriStateBannerTone.info,
              compact: true,
            ),
            const SizedBox(height: SpacingTokens.spacing4),
          ],
          if (!configuredActionsEnabled) ...[
            AfriStateBanner(
              icon: AfriIcons.lock,
              title: l10n.challengeCreationUnavailable,
              subtitle: l10n.challengeCreationDisabledBody,
              tone: AfriStateBannerTone.warning,
              compact: true,
            ),
            const SizedBox(height: SpacingTokens.spacing4),
          ] else if (!isOnline) ...[
            AfriStateBanner(
              icon: AfriIcons.offline,
              title: l10n.challengeShowingSavedFixtures,
              subtitle: l10n.challengeShowingSavedFixturesBody,
              tone: AfriStateBannerTone.warning,
              compact: true,
            ),
            const SizedBox(height: SpacingTokens.spacing4),
          ] else if (state.failure != null) ...[
            _RetainedCreateFailureBanner(failure: state.failure!),
            if (state.failure!.kind !=
                ChallengeCreateFailureKind.permissionDenied) ...[
              const SizedBox(height: SpacingTokens.spacing3),
              AfriButton(
                key: const ValueKey<String>('challenge-create-refresh-action'),
                label: l10n.challengeRefreshFixturesUpper,
                icon: AfriIcons.refresh,
                variant: AfriButtonVariant.outline,
                labelMaxLines: 2,
                onTap: () =>
                    ref.read(challengeCreateProvider.notifier).refresh(),
              ),
            ],
            const SizedBox(height: SpacingTokens.spacing4),
          ],
          Text(
            l10n.gameFixture,
            style: TypographyTokens.labelSmall(ColorTokens.onSurfaceVariant),
          ),
          const SizedBox(height: SpacingTokens.spacing2),
          _FixtureDropdown(
            fixtures: fixtures,
            selected: fixture,
            enabled: actionsEnabled,
            onChanged: (selected) =>
                setState(() => _selectedFixtureId = selected?.id),
          ),
          const SizedBox(height: SpacingTokens.sectionGap),
          Text(
            l10n.challengeExactScore,
            style: TypographyTokens.labelSmall(ColorTokens.onSurfaceVariant),
          ),
          const SizedBox(height: SpacingTokens.spacing3),
          Semantics(
            selected: true,
            label: l10n.challengeSelectedScore(_homeScore, _awayScore),
            child: largeText
                ? Column(
                    children: [
                      _ScoreCounter(
                        label: fixture.homeTeamShort,
                        value: _homeScore,
                        enabled: actionsEnabled,
                        onChanged: (value) =>
                            setState(() => _homeScore = value),
                      ),
                      const SizedBox(height: SpacingTokens.spacing3),
                      Text(
                        l10n.challengeVersusUpper,
                        style: TypographyTokens.labelSmall(
                          ColorTokens.primaryContainer,
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: SpacingTokens.spacing3),
                      _ScoreCounter(
                        label: fixture.awayTeamShort,
                        value: _awayScore,
                        enabled: actionsEnabled,
                        onChanged: (value) =>
                            setState(() => _awayScore = value),
                      ),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Align(
                          child: _ScoreCounter(
                            label: fixture.homeTeamShort,
                            value: _homeScore,
                            enabled: actionsEnabled,
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
                          style: TypographyTokens.metricValue(
                            ColorTokens.primaryContainer,
                          ).copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Expanded(
                        child: Align(
                          child: _ScoreCounter(
                            label: fixture.awayTeamShort,
                            value: _awayScore,
                            enabled: actionsEnabled,
                            onChanged: (value) =>
                                setState(() => _awayScore = value),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: SpacingTokens.sectionGap),
          Text(
            l10n.challengeEntryPoints,
            style: TypographyTokens.labelSmall(ColorTokens.onSurfaceVariant),
          ),
          const SizedBox(height: SpacingTokens.spacing3),
          if (stakeOptions.isEmpty)
            Text(
              l10n.challengeEntryOptionsUnavailable,
              style: TypographyTokens.labelSmall(ColorTokens.onSurfaceVariant),
            )
          else
            Wrap(
              spacing: SpacingTokens.spacing2,
              runSpacing: SpacingTokens.spacing2,
              children: stakeOptions.map((amount) {
                return AfriChoiceChip(
                  selected: selectedStakeFet == amount,
                  label: Text(l10n.challengeStakePoints(amount)),
                  onSelected: actionsEnabled
                      ? (_) => setState(() => _stakeFet = amount)
                      : null,
                );
              }).toList(),
            ),
          const SizedBox(height: SpacingTokens.sectionGap),
          _SummaryCard(
            fixture: fixture,
            homeScore: _homeScore,
            awayScore: _awayScore,
            stakeFet: selectedStakeFet,
            balance: wallet?.balance ?? 0,
          ),
          const SizedBox(height: SpacingTokens.spacing4),
          if (walletAsync.isLoading)
            Text(
              l10n.challengeCheckingBalance,
              style: TypographyTokens.labelSmall(ColorTokens.onSurfaceVariant),
            )
          else if (walletAsync.hasError)
            Text(
              l10n.challengeBalanceUnavailable,
              style: TypographyTokens.labelSmall(ColorTokens.error),
            )
          else if (!hasBalance)
            Text(
              l10n.challengeBalanceInsufficient,
              style: TypographyTokens.labelSmall(ColorTokens.error),
            ),
          const SizedBox(height: SpacingTokens.spacing4),
          AfriButton(
            key: const ValueKey<String>('challenge-create-action'),
            label: isSubmitting
                ? l10n.challengeCreatingUpper
                : l10n.challengeCreateTitle,
            icon: AfriIcons.versus,
            isLoading: isSubmitting,
            enabled: actionsEnabled && hasBalance && !isSubmitting,
            focusNode: widget.createFocusNode,
            labelMaxLines: 2,
            onTap: () => _confirmAndSubmit(
              fixture: fixture,
              stakeFet: selectedStakeFet,
              balance: wallet?.balance ?? 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateFailureContent {
  const _CreateFailureContent({
    required this.title,
    required this.message,
    required this.canRefresh,
  });

  final String title;
  final String message;
  final bool canRefresh;

  factory _CreateFailureContent.fromFailure(
    ChallengeCreateFailure failure,
    bool isOnline,
    AfriLocalizations l10n,
  ) {
    return switch (failure.kind) {
      ChallengeCreateFailureKind.offline => _CreateFailureContent(
        title: isOnline
            ? l10n.gameConnectionRestored
            : l10n.challengeCreationOffline,
        message: isOnline
            ? l10n.challengeRefreshLatestFixtures
            : l10n.challengeReconnectFixtures,
        canRefresh: isOnline,
      ),
      ChallengeCreateFailureKind.permissionDenied => _CreateFailureContent(
        title: l10n.challengeCreationUnavailable,
        message: l10n.challengeAccessDeniedBody,
        canRefresh: false,
      ),
      ChallengeCreateFailureKind.conflict => _CreateFailureContent(
        title: l10n.challengeDetailsChanged,
        message: l10n.challengeDetailsChangedBody,
        canRefresh: true,
      ),
      ChallengeCreateFailureKind.securityTimeout => _CreateFailureContent(
        title: l10n.challengeSecurityTimedOut,
        message: l10n.challengeSecurityTimedOutBody,
        canRefresh: true,
      ),
      ChallengeCreateFailureKind.unknown => _CreateFailureContent(
        title: l10n.challengeCreationUnavailable,
        message: l10n.challengeTryAgainBody,
        canRefresh: true,
      ),
    };
  }
}

class _RetainedCreateFailureBanner extends StatelessWidget {
  const _RetainedCreateFailureBanner({required this.failure});

  final ChallengeCreateFailure failure;

  @override
  Widget build(BuildContext context) {
    final content = _CreateFailureContent.fromFailure(
      failure,
      true,
      context.afriL10n,
    );
    return AfriStateBanner(
      icon: failure.kind == ChallengeCreateFailureKind.permissionDenied
          ? AfriIcons.lock
          : AfriIcons.warning,
      title: content.title,
      subtitle: content.message,
      tone: AfriStateBannerTone.warning,
      compact: true,
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
    final l10n = context.afriL10n;
    final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.5;
    if (largeText) {
      return Semantics(
        label: l10n.challengePreviewSemantics(
          fixture.homeTeamName,
          fixture.awayTeamName,
          homeScore,
          awayScore,
          stakeFet,
          balance,
        ),
        child: GlassCard(
          animate: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.challengePreview,
                style: TypographyTokens.labelSmall(
                  ColorTokens.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: SpacingTokens.spacing2),
              Text(
                l10n.gameTeamsVersusMultiline(
                  fixture.homeTeamName,
                  fixture.awayTeamName,
                ),
                style: TypographyTokens.titleMedium().copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: SpacingTokens.spacing2),
              Text(
                fixture.competitionName,
                style: TypographyTokens.bodyMedium(
                  ColorTokens.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: SpacingTokens.spacing3),
              Wrap(
                spacing: SpacingTokens.spacing2,
                runSpacing: SpacingTokens.spacing2,
                children: [
                  StakeBadge(stakeFet: stakeFet),
                  ScorePredictionPill(
                    homeScore: homeScore,
                    awayScore: awayScore,
                    label: l10n.challengeYourPick,
                    accent: ColorTokens.primaryContainer,
                  ),
                  _MetaChip(label: l10n.challengeBalancePoints(balance)),
                  _MetaChip(label: l10n.challengeLocksAtKickoff),
                ],
              ),
            ],
          ),
        ),
      );
    }

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
        ChallengeCard(challenge: challenge, compact: true, enabled: false),
        const SizedBox(height: SpacingTokens.spacing3),
        Wrap(
          spacing: SpacingTokens.spacing2,
          runSpacing: SpacingTokens.spacing2,
          children: [
            StakeBadge(stakeFet: stakeFet),
            ScorePredictionPill(
              homeScore: homeScore,
              awayScore: awayScore,
              label: l10n.challengeYourPick,
              accent: ColorTokens.primaryContainer,
            ),
            _MetaChip(label: l10n.challengeBalancePoints(balance)),
            _MetaChip(label: l10n.challengeLocksAtKickoff),
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
    required this.enabled,
    required this.onChanged,
  });

  final List<FixtureSummary> fixtures;
  final FixtureSummary? selected;
  final bool enabled;
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
                context.afriL10n.challengeFixtureOption(
                  fixture.homeTeamShort,
                  fixture.awayTeamShort,
                  fixture.competitionName,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TypographyTokens.bodyMedium(),
              ),
            );
          }).toList(),
          onChanged: enabled ? onChanged : null,
        ),
      ),
    );
  }
}

class _ScoreCounter extends StatelessWidget {
  const _ScoreCounter({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final int value;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: TypographyTokens.labelSmall()),
        const SizedBox(height: SpacingTokens.spacing2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AfriIconButton(
              icon: AfriIcons.remove,
              onTap: enabled && value > 0 ? () => onChanged(value - 1) : null,
              tooltip: context.afriL10n.challengeDecrease(label),
            ),
            Text(
              '$value',
              style: TypographyTokens.headlineLarge().copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            AfriIconButton(
              icon: AfriIcons.add,
              onTap: enabled && value < 20 ? () => onChanged(value + 1) : null,
              tooltip: context.afriL10n.challengeIncrease(label),
            ),
          ],
        ),
      ],
    );
  }
}
