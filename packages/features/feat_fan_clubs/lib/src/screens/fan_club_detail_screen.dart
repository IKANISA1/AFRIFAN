import 'dart:async';

import 'package:core_l10n/core_l10n.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../official_fanclub_register.dart';
import '../providers/fan_club_detail_provider.dart';

class FanClubDetailScreen extends ConsumerStatefulWidget {
  const FanClubDetailScreen({required this.clubId, super.key});

  final String clubId;

  @override
  ConsumerState<FanClubDetailScreen> createState() =>
      _FanClubDetailScreenState();
}

class _FanClubDetailScreenState extends ConsumerState<FanClubDetailScreen> {
  late bool _wasOnline;

  @override
  void initState() {
    super.initState();
    _wasOnline = ConnectivityService.isOnline;
    ConnectivityService.onlineNotifier.addListener(_handleConnectivityChange);
  }

  @override
  void dispose() {
    ConnectivityService.onlineNotifier.removeListener(
      _handleConnectivityChange,
    );
    super.dispose();
  }

  void _handleConnectivityChange() {
    final isOnline = ConnectivityService.isOnline;
    final restored = !_wasOnline && isOnline;
    _wasOnline = isOnline;
    if (!mounted) return;
    setState(() {});
    if (restored) {
      unawaited(
        ref.read(fanClubDetailProvider(widget.clubId).notifier).refresh(),
      );
    }
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/fan-clubs');
    }
  }

  Future<void> _copyShareLink() async {
    const websiteUrl = String.fromEnvironment(
      'APP_WEBSITE_URL',
      defaultValue: '',
    );
    final normalizedWebsite = websiteUrl.trim().replaceAll(RegExp(r'/$'), '');
    final website = Uri.tryParse(normalizedWebsite);
    final club = ref
        .read(fanClubDetailProvider(widget.clubId))
        .valueOrNull
        ?.data
        ?.club;
    final publicId = club?['id']?.toString() ?? widget.clubId;
    final shareTarget =
        website?.scheme == 'https' &&
            website!.host.isNotEmpty &&
            website.userInfo.isEmpty
        ? website
              .replace(
                path: '/fan-clubs',
                query: '',
                fragment: 'fan-club-$publicId',
              )
              .toString()
        : context.afriL10n.fanClubShareFallback(RuntimeBranding.displayAppName);
    await Clipboard.setData(
      ClipboardData(
        text: context.afriL10n.fanClubShareText(
          RuntimeBranding.displayAppName,
          shareTarget,
        ),
      ),
    );
    if (!mounted) return;
    AfriToast.success(context, context.afriL10n.fanClubLinkCopied);
  }

  @override
  Widget build(BuildContext context) {
    final accessEnabled = ref.watch(fanClubDetailAccessEnabledProvider);
    final detailAsync = ref.watch(fanClubDetailProvider(widget.clubId));

    return AfriScreenScaffold(
      backgroundColor: ColorTokens.background,
      showAppBar: false,
      showBackButton: false,
      scrollable: false,
      constrainContent: false,
      child: !accessEnabled
          ? _FanClubConsequence(
              title: context.afriL10n.fanClubPreviewUnavailableTitle,
              body: context.afriL10n.fanClubPreviewUnavailableMessage,
              actionLabel: context.afriL10n.fanClubBackToSupporters,
              onAction: _close,
            )
          : detailAsync.when(
              loading: () => const SafeArea(
                child: Padding(
                  padding: EdgeInsets.all(SpacingTokens.spacing6),
                  child: AfriSkeletonList(),
                ),
              ),
              error: (error, _) => _failureConsequence(error),
              data: (detail) {
                final data = detail.data;
                if (data == null) {
                  return _FanClubConsequence(
                    title: context.afriL10n.fanClubUnavailableTitle,
                    body: context.afriL10n.fanClubUnavailableMessage,
                    actionLabel: context.afriL10n.fanClubBackToSupporters,
                    onAction: _close,
                  );
                }
                return _buildReady(detail, data);
              },
            ),
    );
  }

  Widget _buildReady(FanClubDetailState detail, FanClubDetailData data) {
    final club = data.club;
    final primary = ColorTokens.primaryContainer;
    final name =
        club['name']?.toString() ?? context.afriL10n.fanClubFallbackName;
    final description = club['description']?.toString() ?? '';
    final region =
        club['region']?.toString() ?? context.afriL10n.fanClubUnknownRegion;
    final members = fanclubMemberLabel(club);
    final isActive = club['is_active'] as bool? ?? true;
    final match = data.upcomingMatch;
    final stackContent = MediaQuery.textScalerOf(context).scale(16) >= 28;

    return AfriRefreshIndicator(
      onRefresh: () =>
          ref.read(fanClubDetailProvider(widget.clubId).notifier).refresh(),
      color: primary,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          if (_retainedBanner(detail) case final banner?)
            SliverToBoxAdapter(child: SafeArea(bottom: false, child: banner)),
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.all(SpacingTokens.screenPadding),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: AfriIconButton(
                    key: const ValueKey<String>('fan-club-detail-back'),
                    icon: AfriIcons.back,
                    onTap: _close,
                    tooltip: context.afriL10n.authBack,
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(SpacingTokens.spacing6),
              child: Column(
                children: [
                  Semantics(
                    selected: true,
                    label: context.afriL10n.fanClubCurrentSemantic(name),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        name,
                        style: TypographyTokens.headlineLarge(),
                      ),
                    ),
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: SpacingTokens.spacing3),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        description,
                        style: TypographyTokens.bodyMedium(),
                      ),
                    ),
                  ],
                  const SizedBox(height: SpacingTokens.spacing6),
                  _DetailStats(
                    members: members,
                    region: region,
                    stacked: stackContent,
                  ),
                  const SizedBox(height: SpacingTokens.spacing6),
                  FanClubMatchdayAgendaSection(
                    isActive: isActive,
                    match: match,
                  ),
                  const SizedBox(height: SpacingTokens.spacing6),
                  if (isActive)
                    AfriButton(
                      label: context.afriL10n.fanClubCopyLink,
                      icon: AfriIcons.share,
                      enabled: !detail.actionsBlocked,
                      onTap: _copyShareLink,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _failureConsequence(Object error) {
    final failure = error is FanClubDetailFailure
        ? error
        : FanClubDetailFailure.fromError(error);
    return switch (failure.kind) {
      FanClubDetailFailureKind.offline => _FanClubConsequence(
        title: context.afriL10n.fanClubUnavailableOfflineTitle,
        body: context.afriL10n.fanClubUnavailableOfflineMessage,
        actionLabel: context.afriL10n.fanClubBackToSupporters,
        onAction: _close,
      ),
      FanClubDetailFailureKind.permissionDenied => _FanClubConsequence(
        title: context.afriL10n.fanClubAccessDeniedTitle,
        body: context.afriL10n.fanClubAccessDeniedMessage,
        actionLabel: context.afriL10n.fanClubBackToSupporters,
        onAction: _close,
      ),
      FanClubDetailFailureKind.conflict => _FanClubConsequence(
        title: context.afriL10n.fanClubDetailsChangedTitle,
        body: context.afriL10n.fanClubRefreshBeforeSupporters,
        actionLabel: context.afriL10n.fanClubRefreshAction,
        onAction: () =>
            ref.read(fanClubDetailProvider(widget.clubId).notifier).load(),
      ),
      FanClubDetailFailureKind.securityTimeout => _FanClubConsequence(
        title: context.afriL10n.fanClubSecurityTimeoutTitle,
        body: context.afriL10n.fanClubSecurityTimeoutMessage,
        actionLabel: context.afriL10n.fanClubTryAgainAction,
        onAction: () =>
            ref.read(fanClubDetailProvider(widget.clubId).notifier).load(),
      ),
      FanClubDetailFailureKind.unknown => _FanClubConsequence(
        title: context.afriL10n.fanClubLoadFailureTitle,
        body: context.afriL10n.fanClubLoadFailureMessage,
        actionLabel: context.afriL10n.fanClubTryAgainAction,
        onAction: () =>
            ref.read(fanClubDetailProvider(widget.clubId).notifier).load(),
      ),
    };
  }

  Widget? _retainedBanner(FanClubDetailState detail) {
    if (!ConnectivityService.isOnline) {
      return _FanClubStatus(
        title: context.afriL10n.fanClubShowingSavedTitle,
        body: context.afriL10n.fanClubSavedDetailsMayChange,
      );
    }
    if (detail.phase == FanClubDetailPhase.syncing) {
      return _FanClubStatus(
        title: context.afriL10n.fanClubRefreshingTitle,
        body: context.afriL10n.fanClubLastConfirmedVisible,
        tone: AfriStateBannerTone.info,
      );
    }
    final failure = detail.failure;
    if (failure == null) return null;
    return switch (failure.kind) {
      FanClubDetailFailureKind.conflict => _FanClubStatus(
        title: context.afriL10n.fanClubDetailsChangedTitle,
        body: context.afriL10n.fanClubLastConfirmedRefresh,
        actionLabel: context.afriL10n.fanClubRefreshAction,
        onAction: () =>
            ref.read(fanClubDetailProvider(widget.clubId).notifier).refresh(),
      ),
      FanClubDetailFailureKind.securityTimeout => _FanClubStatus(
        title: context.afriL10n.fanClubCheckTimedOutTitle,
        body: context.afriL10n.fanClubLastConfirmedRefresh,
        actionLabel: context.afriL10n.fanClubRefreshAction,
        onAction: () =>
            ref.read(fanClubDetailProvider(widget.clubId).notifier).refresh(),
      ),
      FanClubDetailFailureKind.permissionDenied => _FanClubStatus(
        title: context.afriL10n.fanClubAccessChangedTitle,
        body: context.afriL10n.fanClubAccessChangedMessage,
        tone: AfriStateBannerTone.danger,
      ),
      FanClubDetailFailureKind.offline => _FanClubStatus(
        title: context.afriL10n.fanClubShowingSavedTitle,
        body: context.afriL10n.fanClubSavedDetailsMayChange,
      ),
      FanClubDetailFailureKind.unknown => _FanClubStatus(
        title: context.afriL10n.fanClubRefreshFailedTitle,
        body: context.afriL10n.fanClubLastConfirmedRefresh,
        actionLabel: context.afriL10n.fanClubRefreshAction,
        onAction: () =>
            ref.read(fanClubDetailProvider(widget.clubId).notifier).refresh(),
      ),
    };
  }
}

class FanClubMatchdayAgendaSection extends StatelessWidget {
  const FanClubMatchdayAgendaSection({
    required this.isActive,
    required this.match,
    super.key,
  });

  final bool isActive;
  final Map<String, dynamic>? match;

  @override
  Widget build(BuildContext context) {
    final agendaMatch = match;
    if (!isActive || agendaMatch == null) {
      return const SizedBox.shrink(
        key: ValueKey<String>('fan-club-matchday-agenda-empty'),
      );
    }

    return GlassCard(
      animate: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.afriL10n.fanClubMatchdayAgenda,
            style: TypographyTokens.titleLarge().copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing3),
          AfriFixtureTeams(
            homeTeam: agendaMatch['home_team']?.toString() ?? '',
            awayTeam: agendaMatch['away_team']?.toString() ?? '',
          ),
          const SizedBox(height: SpacingTokens.spacing2),
          Text(
            context.afriL10n.fanClubMatchMeta(
              agendaMatch['competition']?.toString() ?? '',
              agendaMatch['venue']?.toString() ?? '',
            ),
            style: TypographyTokens.bodyMedium(),
          ),
          const SizedBox(height: SpacingTokens.spacing2),
          Text(
            context.afriL10n.fanClubMatchSchedule(
              agendaMatch['match_date']?.toString() ?? '',
              agendaMatch['kickoff_time']?.toString() ?? '',
            ),
            style: TypographyTokens.bodySmall(),
          ),
        ],
      ),
    );
  }
}

class _DetailStats extends StatelessWidget {
  const _DetailStats({
    required this.members,
    required this.region,
    required this.stacked,
  });

  final String members;
  final String region;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      _DetailStat(label: context.afriL10n.fanClubMembersLabel, value: members),
      _DetailStat(label: context.afriL10n.fanClubRegionLabel, value: region),
    ];
    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < cards.length; index++) ...[
            if (index > 0) const SizedBox(height: SpacingTokens.spacing3),
            cards[index],
          ],
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: cards[0]),
            const SizedBox(width: SpacingTokens.spacing3),
            Expanded(child: cards[1]),
          ],
        ),
      ],
    );
  }
}

class _FanClubConsequence extends StatelessWidget {
  const _FanClubConsequence({
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(SpacingTokens.spacing8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                AfriIcons.groups,
                size: SizeTokens.iconXxl,
                color: ColorTokens.onSurfaceVariant,
              ),
              const SizedBox(height: SpacingTokens.spacing4),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TypographyTokens.headlineSmall(),
              ),
              const SizedBox(height: SpacingTokens.spacing2),
              Text(
                body,
                textAlign: TextAlign.center,
                style: TypographyTokens.bodyMedium(),
              ),
              const SizedBox(height: SpacingTokens.spacing6),
              AfriButton(label: actionLabel, onTap: onAction),
            ],
          ),
        ),
      ),
    );
  }
}

class _FanClubStatus extends StatelessWidget {
  const _FanClubStatus({
    required this.title,
    required this.body,
    this.tone = AfriStateBannerTone.warning,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String body;
  final AfriStateBannerTone tone;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SpacingTokens.spacing4,
        SpacingTokens.spacing2,
        SpacingTokens.spacing4,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AfriStateBanner(
            icon: tone == AfriStateBannerTone.danger
                ? AfriIcons.statusError
                : AfriIcons.statusWarning,
            title: title,
            subtitle: body,
            tone: tone,
            compact: true,
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: SpacingTokens.spacing2),
            AfriButton(label: actionLabel!, onTap: onAction!),
          ],
        ],
      ),
    );
  }
}

class _DetailStat extends StatelessWidget {
  const _DetailStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      animate: false,
      child: Column(
        children: [
          Text(label, style: TypographyTokens.labelSmall()),
          const SizedBox(height: SpacingTokens.spacing2),
          Text(
            value,
            style: TypographyTokens.headlineLarge(
              ColorTokens.onSurface,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
