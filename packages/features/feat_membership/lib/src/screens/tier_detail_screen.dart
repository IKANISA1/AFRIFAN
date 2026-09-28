import 'dart:async';

import 'package:core_l10n/core_l10n.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/tier_detail_provider.dart';

class TierDetailScreen extends ConsumerStatefulWidget {
  const TierDetailScreen({required this.tierId, super.key});

  final String tierId;

  @override
  ConsumerState<TierDetailScreen> createState() => _TierDetailScreenState();
}

class _TierDetailScreenState extends ConsumerState<TierDetailScreen> {
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
        ref
            .read(tierDetailProvider(widget.tierId).notifier)
            .connectionRestored(),
      );
    }
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/membership');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.afriL10n;
    final enabled = ref.watch(tierDetailEnabledProvider);
    final asyncDetail = ref.watch(tierDetailProvider(widget.tierId));

    return AfriScreenScaffold(
      backgroundColor: ColorTokens.background,
      appBar: AfriAppBar(
        backgroundColor: ColorTokens.transparent,
        title: Text(
          l10n.tierTitle,
          style: TypographyTokens.headlineSmall().copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: AfriIconButton(
          key: const ValueKey<String>('tier-detail-back'),
          icon: AfriIcons.back,
          onTap: _close,
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        ),
      ),
      scrollable: false,
      constrainContent: true,
      child: !enabled
          ? _TierConsequence(
              title: l10n.tierUnavailableTitle,
              body: l10n.tierDisabledMessage,
              actionLabel: l10n.backToMembership,
              onAction: _close,
            )
          : asyncDetail.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(SpacingTokens.spacing6),
                child: AfriSkeletonList(),
              ),
              error: (error, _) => _buildFailure(error),
              data: (snapshot) {
                final detail = snapshot.data;
                if (detail == null) {
                  return _TierConsequence(
                    title: l10n.tierNotFoundTitle,
                    body: l10n.tierNotFoundMessage,
                    actionLabel: l10n.backToMembership,
                    onAction: _close,
                  );
                }
                return _buildContent(detail, snapshot);
              },
            ),
    );
  }

  Widget _buildFailure(Object error) {
    final l10n = context.afriL10n;
    final failure = TierDetailFailure.fromError(error);
    return switch (failure.kind) {
      TierDetailFailureKind.offline => _TierConsequence(
        title: l10n.tierOfflineTitle,
        body: l10n.tierOfflineMessage,
        actionLabel: l10n.backToMembership,
        onAction: _close,
        offline: true,
      ),
      TierDetailFailureKind.permissionDenied => _TierConsequence(
        title: l10n.tierAccessDeniedTitle,
        body: l10n.tierAccessDeniedMessage,
        actionLabel: l10n.backToMembership,
        onAction: _close,
      ),
      TierDetailFailureKind.securityTimeout => _TierConsequence(
        title: l10n.tierTimeoutTitle,
        body: l10n.tierTimeoutMessage,
        actionLabel: l10n.tryAgain,
        onAction: () =>
            ref.read(tierDetailProvider(widget.tierId).notifier).refresh(),
      ),
      TierDetailFailureKind.conflict => _TierConsequence(
        title: l10n.tierChangedTitle,
        body: l10n.tierChangedMessage,
        actionLabel: l10n.tryAgain,
        onAction: () =>
            ref.read(tierDetailProvider(widget.tierId).notifier).refresh(),
      ),
      TierDetailFailureKind.unknown => _TierConsequence(
        title: l10n.tierUnavailableTitle,
        body: l10n.tierLoadUnavailableMessage,
        actionLabel: l10n.tryAgain,
        onAction: () =>
            ref.read(tierDetailProvider(widget.tierId).notifier).refresh(),
      ),
    };
  }

  Widget _buildContent(TierDetailData detail, TierDetailState snapshot) {
    final l10n = context.afriL10n;
    return AfriRefreshIndicator(
      onRefresh: () =>
          ref.read(tierDetailProvider(widget.tierId).notifier).refresh(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          SpacingTokens.spacing6,
          SpacingTokens.spacing4,
          SpacingTokens.spacing6,
          SpacingTokens.spacing12,
        ),
        children: [
          if (_statusFor(snapshot) case final status?) ...[
            status,
            const SizedBox(height: SpacingTokens.spacing4),
          ],
          Semantics(
            selected: true,
            label: l10n.tierSelected(detail.title),
            child: GlassCard(
              animate: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          detail.title,
                          style: TypographyTokens.headlineMedium(),
                        ),
                      ),
                      if (RuntimeBranding.displayHomeTeamName.isNotEmpty) ...[
                        const SizedBox(width: SpacingTokens.spacing3),
                        AfriTeamCrest(
                          name: RuntimeBranding.displayHomeTeamName,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: SpacingTokens.spacing2),
                  _TierPriceLabel(label: detail.priceLabel),
                  if (detail.subtitle.isNotEmpty) ...[
                    const SizedBox(height: SpacingTokens.spacing2),
                    Text(
                      detail.subtitle,
                      style: TypographyTokens.bodyMedium(
                        ColorTokens.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (detail.description.isNotEmpty) ...[
            const SizedBox(height: SpacingTokens.spacing4),
            GlassCard(
              animate: false,
              child: Text(
                detail.description,
                style: TypographyTokens.bodyLarge(),
              ),
            ),
          ],
          const SizedBox(height: SpacingTokens.spacing4),
          _PerkCard(title: l10n.tierPerks, items: detail.benefits),
          const SizedBox(height: SpacingTokens.spacing4),
          _PerkCard(title: l10n.tierAccess, items: detail.accessItems),
        ],
      ),
    );
  }

  Widget? _statusFor(TierDetailState snapshot) {
    final l10n = context.afriL10n;
    if (!ConnectivityService.isOnline ||
        snapshot.failure?.kind == TierDetailFailureKind.offline) {
      return AfriStateBanner(
        icon: AfriIcons.offline,
        title: l10n.tierShowingOfficialTitle,
        subtitle: l10n.tierOfflineStatusMessage,
        tone: AfriStateBannerTone.warning,
      );
    }
    if (snapshot.phase == TierDetailPhase.syncing) {
      return AfriStateBanner(
        icon: AfriIcons.refresh,
        title: l10n.tierRefreshingTitle,
        subtitle: l10n.tierRefreshingMessage,
        tone: AfriStateBannerTone.info,
      );
    }
    return switch (snapshot.failure?.kind) {
      TierDetailFailureKind.permissionDenied => AfriStateBanner(
        icon: AfriIcons.warning,
        title: l10n.tierUpdateDeniedTitle,
        subtitle: l10n.tierUpdateDeniedMessage,
        tone: AfriStateBannerTone.danger,
      ),
      TierDetailFailureKind.conflict => AfriStateBanner(
        icon: AfriIcons.warning,
        title: l10n.tierChangedTitle,
        subtitle: l10n.tierChangedStatusMessage,
        tone: AfriStateBannerTone.warning,
        onTap: () =>
            ref.read(tierDetailProvider(widget.tierId).notifier).refresh(),
      ),
      TierDetailFailureKind.securityTimeout => AfriStateBanner(
        icon: AfriIcons.warning,
        title: l10n.tierRefreshTimeoutTitle,
        subtitle: l10n.tierRefreshTimeoutMessage,
        tone: AfriStateBannerTone.danger,
        onTap: () =>
            ref.read(tierDetailProvider(widget.tierId).notifier).refresh(),
      ),
      TierDetailFailureKind.unknown => AfriStateBanner(
        icon: AfriIcons.warning,
        title: l10n.tierOutdatedTitle,
        subtitle: l10n.tierOutdatedMessage,
        tone: AfriStateBannerTone.warning,
        onTap: () =>
            ref.read(tierDetailProvider(widget.tierId).notifier).refresh(),
      ),
      _ when snapshot.phase == TierDetailPhase.degraded => AfriStateBanner(
        icon: AfriIcons.warning,
        title: l10n.tierShowingOfficialTitle,
        subtitle: l10n.tierDegradedMessage,
        tone: AfriStateBannerTone.warning,
        onTap: () =>
            ref.read(tierDetailProvider(widget.tierId).notifier).refresh(),
      ),
      _ => null,
    };
  }
}

class _TierConsequence extends StatelessWidget {
  const _TierConsequence({
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
    this.offline = false,
  });

  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onAction;
  final bool offline;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(SpacingTokens.spacing6),
        child: offline
            ? AfriStateView.offline(
                title: title,
                message: body,
                actionLabel: actionLabel,
                onAction: onAction,
              )
            : AfriStateView.empty(
                title: title,
                message: body,
                actionLabel: actionLabel,
                onAction: onAction,
              ),
      ),
    );
  }
}

class _PerkCard extends StatelessWidget {
  const _PerkCard({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      animate: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TypographyTokens.headlineSmall().copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing3),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: SpacingTokens.spacing2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: SpacingTokens.spacing1),
                    child: Icon(
                      AfriIcons.checkGroup,
                      color: ColorTokens.success,
                      size: SizeTokens.iconSm,
                    ),
                  ),
                  const SizedBox(width: SpacingTokens.spacing2),
                  Expanded(
                    child: Text(item, style: TypographyTokens.bodyLarge()),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TierPriceLabel extends StatelessWidget {
  const _TierPriceLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final parts = label.split(' / ');
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(parts.first, style: TypographyTokens.headlineMedium()),
          if (parts.length > 1) ...[
            const SizedBox(height: SpacingTokens.spacing1),
            Text(
              '/ ${parts.skip(1).join(' / ')}',
              style: TypographyTokens.bodyMedium(ColorTokens.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}
