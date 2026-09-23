import 'dart:async';

import 'package:club_data/club_data.dart';
import 'package:core_l10n/core_l10n.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../controllers/group_detail_controller.dart';
import '../widgets/contribution_overlays.dart';
import '../widgets/group_card.dart';

class GroupDetailScreen extends ConsumerStatefulWidget {
  const GroupDetailScreen({
    required this.groupId,
    this.primaryActionFocusNode,
    super.key,
  });

  final String groupId;
  final FocusNode? primaryActionFocusNode;

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen> {
  bool? _lastOnline;

  Future<void> _refresh() =>
      ref.read(groupDetailProvider(widget.groupId).notifier).refresh();

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/contribute/groups');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.afriL10n;
    final detailAsync = ref.watch(groupDetailProvider(widget.groupId));
    final configuredActionsEnabled = ref.watch(
      groupContributionActionsEnabledProvider,
    );

    return ConnectivityBuilder(
      builder: (context, isOnline) {
        final previousOnline = _lastOnline;
        _lastOnline = isOnline;
        if (previousOnline == false && isOnline) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            unawaited(_refresh());
          });
        }

        return AfriScreenScaffold(
          backgroundColor: ColorTokens.background,
          appBar: AfriAppBar(
            backgroundColor: ColorTokens.transparent,
            title: Text(
              l10n.contributionsInitiativeTitle,
              style: TypographyTokens.titleLarge(
                ColorTokens.chromeForeground,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
            leading: AfriIconButton(
              icon: AfriIcons.back,
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onTap: _goBack,
            ),
          ),
          scrollable: false,
          constrainContent: true,
          child: AfriRefreshIndicator(
            onRefresh: _refresh,
            child: detailAsync.when(
              loading: () => ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(SpacingTokens.screenPadding),
                children: [
                  AfriStateView.loading(
                    title: l10n.contributionsInitiativeLoadingTitle,
                    message: l10n.contributionsInitiativeLoadingMessage,
                  ),
                ],
              ),
              error: (error, _) => ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(SpacingTokens.screenPadding),
                children: [_buildFailureView(error, isOnline)],
              ),
              data: (state) => _buildDetail(
                state,
                isOnline: isOnline,
                configuredActionsEnabled: configuredActionsEnabled,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFailureView(Object error, bool isOnline) {
    final l10n = context.afriL10n;
    final failure = GroupDetailFailure.fromError(error);
    final content = _GroupDetailFailureContent.fromFailure(
      failure,
      isOnline,
      l10n,
    );
    final refreshAction = content.canRefresh
        ? () => unawaited(_refresh())
        : null;

    return switch (failure.kind) {
      GroupDetailFailureKind.offline => AfriStateView.offline(
        title: content.title,
        message: content.message,
        actionLabel: content.canRefresh ? l10n.contributionsRefresh : null,
        onAction: refreshAction,
      ),
      GroupDetailFailureKind.notFound => AfriStateView.empty(
        title: content.title,
        message: content.message,
        icon: AfriIcons.groups,
        actionLabel: l10n.contributionsBackToCommunities,
        onAction: _goBack,
      ),
      _ => AfriStateView.error(
        title: content.title,
        message: content.message,
        actionLabel: content.canRefresh ? l10n.contributionsRefresh : null,
        onAction: refreshAction,
      ),
    };
  }

  Widget _buildDetail(
    GroupDetailState state, {
    required bool isOnline,
    required bool configuredActionsEnabled,
  }) {
    final l10n = context.afriL10n;
    final snapshot = state.snapshot;
    final group = snapshot.group;
    final paymentConfigured =
        group.paymentRecipient?.trim().isNotEmpty ?? false;
    final initiativeOpen = !group.isClosed && !group.isExpired;
    final actionsEnabled =
        configuredActionsEnabled &&
        isOnline &&
        !state.actionsBlocked &&
        paymentConfigured &&
        initiativeOpen;
    final children = <Widget>[];

    if (state.phase == GroupDetailPhase.syncing) {
      children.add(
        AfriStateBanner(
          icon: AfriIcons.refresh,
          title: l10n.contributionsInitiativeRefreshingTitle,
          subtitle: l10n.contributionsInitiativeRefreshingMessage,
          tone: AfriStateBannerTone.info,
          compact: true,
        ),
      );
    } else if (!configuredActionsEnabled) {
      children.add(
        AfriStateBanner(
          icon: AfriIcons.lock,
          title: l10n.contributionsReadOnlyTitle,
          subtitle: l10n.contributionsReadOnlyMessage,
          tone: AfriStateBannerTone.warning,
          compact: true,
        ),
      );
    } else if (!isOnline) {
      children.add(
        AfriStateBanner(
          icon: AfriIcons.offline,
          title: l10n.contributionsSavedInitiativeTitle,
          subtitle: l10n.contributionsSavedInitiativeMessage,
          tone: AfriStateBannerTone.warning,
          compact: true,
        ),
      );
    } else if (state.failure != null) {
      children.add(_RetainedGroupDetailFailure(failure: state.failure!));
      if (state.failure!.kind != GroupDetailFailureKind.permissionDenied) {
        children.add(const SizedBox(height: SpacingTokens.spacing3));
        children.add(
          AfriButton(
            key: const ValueKey<String>('group-detail-refresh-action'),
            label: l10n.contributionsRefreshInitiativeUpper,
            icon: AfriIcons.refresh,
            variant: AfriButtonVariant.outline,
            labelMaxLines: 2,
            onTap: _refresh,
          ),
        );
      }
    } else if (!initiativeOpen) {
      children.add(
        AfriStateBanner(
          icon: AfriIcons.lock,
          title: l10n.contributionsClosedTitle,
          subtitle: l10n.contributionsClosedMessage,
          tone: AfriStateBannerTone.info,
          compact: true,
        ),
      );
    } else if (!paymentConfigured) {
      children.add(
        AfriStateBanner(
          icon: AfriIcons.warning,
          title: l10n.contributionsPaymentRouteUnavailableTitle,
          subtitle: l10n.contributionsPaymentRouteUnavailableMessage,
          tone: AfriStateBannerTone.warning,
          compact: true,
        ),
      );
    }

    if (children.isNotEmpty) {
      children.add(const SizedBox(height: SpacingTokens.spacing4));
    }
    children.add(
      _GroupSummaryCard(
        group: group,
        actionEnabled: actionsEnabled,
        actionFocusNode: widget.primaryActionFocusNode,
        actionLabel: _actionLabel(
          state: state,
          isOnline: isOnline,
          configuredActionsEnabled: configuredActionsEnabled,
          initiativeOpen: initiativeOpen,
          paymentConfigured: paymentConfigured,
        ),
        onContribute: () => showMomoAmountEntrySheet(
          context,
          title: group.name,
          groupId: widget.groupId,
          recipientMomo: group.paymentRecipient,
        ),
      ),
    );
    children.add(const SizedBox(height: SpacingTokens.spacing6));
    children.add(
      GroupLedgerSection(
        ledger: snapshot.ledger,
        currencyFormatter: CurrencyFormatter(
          currencyCode: context.afriCurrencyCode,
          currencySymbol: context.afriCurrencySymbol,
        ),
      ),
    );

    return ListView(
      key: const ValueKey<String>('group-detail-scroll-view'),
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.all(SpacingTokens.screenPadding),
      children: children,
    );
  }

  String _actionLabel({
    required GroupDetailState state,
    required bool isOnline,
    required bool configuredActionsEnabled,
    required bool initiativeOpen,
    required bool paymentConfigured,
  }) {
    final l10n = context.afriL10n;
    if (!configuredActionsEnabled) return l10n.contributionsDisabled;
    if (!isOnline) return l10n.connectionRequired;
    if (!initiativeOpen) return l10n.contributionsClosed;
    if (!paymentConfigured) return l10n.contributionsPaymentUnavailable;
    if (state.phase == GroupDetailPhase.syncing) {
      return l10n.contributionsCheckingLatestTotal;
    }
    if (state.phase == GroupDetailPhase.degraded) {
      return l10n.contributionsRefreshBeforeContributing;
    }
    return l10n.contributionsContributeNow;
  }
}

class _GroupSummaryCard extends StatelessWidget {
  const _GroupSummaryCard({
    required this.group,
    required this.actionEnabled,
    required this.actionLabel,
    required this.onContribute,
    this.actionFocusNode,
  });

  final ContributionGroup group;
  final bool actionEnabled;
  final String actionLabel;
  final VoidCallback onContribute;
  final FocusNode? actionFocusNode;

  @override
  Widget build(BuildContext context) {
    final l10n = context.afriL10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GroupCard(
          key: const ValueKey<String>('group-detail-summary-card'),
          group: {
            'name': group.name,
            'image_url': group.imageUrl,
            'current_total': group.currentTotal,
            'target_amount': group.targetAmount,
            'member_count': group.memberCount,
          },
          action: AfriButton(
            key: const ValueKey<String>('group-detail-contribute-action'),
            label: actionLabel,
            semanticsLabel: actionEnabled
                ? l10n.contributionsContributeToSemantic(group.name)
                : l10n.contributionsPaymentUnavailableSemantic(actionLabel),
            fullWidth: true,
            labelMaxLines: 3,
            focusNode: actionFocusNode,
            onTap: onContribute,
            enabled: actionEnabled,
          ),
        ),
        if (group.description?.trim().isNotEmpty ?? false) ...[
          const SizedBox(height: SpacingTokens.spacing4),
          Text(group.description!, style: TypographyTokens.bodyMedium()),
        ],
      ],
    );
  }
}

class GroupLedgerSection extends StatelessWidget {
  const GroupLedgerSection({
    required this.ledger,
    required this.currencyFormatter,
    super.key,
  });

  final List<GroupLedgerEntry> ledger;
  final CurrencyFormatter currencyFormatter;

  @override
  Widget build(BuildContext context) {
    final l10n = context.afriL10n;
    final contributions = ledger
        .where((entry) => entry.status == GroupLedgerStatus.confirmed)
        .toList();
    return Column(
      key: const ValueKey<String>('group-detail-ledger'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.contributionsPublicLedgerTitle,
          style: TypographyTokens.titleLarge().copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: TypographyTokens.trackingNone,
          ),
        ),
        const SizedBox(height: SpacingTokens.spacing2),
        Text(
          l10n.contributionsPublicLedgerPrivacy,
          style: TypographyTokens.bodySmall(ColorTokens.onSurfaceVariant),
        ),
        const SizedBox(height: SpacingTokens.spacing3),
        if (contributions.isEmpty)
          GlassCard(
            key: const ValueKey<String>('group-ledger-empty'),
            animate: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.contributionsLedgerEmptyTitle),
                const SizedBox(height: SpacingTokens.spacing1),
                Text(l10n.contributionsLedgerEmptyMessage),
              ],
            ),
          )
        else
          ...contributions.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: SpacingTokens.spacing3),
              child: _LedgerRow(
                entry: entry,
                amount: currencyFormatter.format(entry.amount),
              ),
            ),
          ),
      ],
    );
  }
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({required this.entry, required this.amount});

  final GroupLedgerEntry entry;
  final String amount;

  @override
  Widget build(BuildContext context) {
    final metricAccent = ColorTokens.accessibleMetricColor(
      ColorTokens.primaryContainer,
    );
    final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.5;
    final date = AfriDateFormatter.formatDate(entry.createdAt);
    return GlassCard(
      animate: false,
      child: Semantics(
        container: true,
        label: '${entry.publicAlias}, $amount, $date',
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (largeText) ...[
              Text(entry.publicAlias, style: TypographyTokens.titleMedium()),
              const SizedBox(height: SpacingTokens.spacing2),
              Text(
                amount,
                style: TypographyTokens.headlineMedium(
                  metricAccent,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      entry.publicAlias,
                      style: TypographyTokens.titleMedium(),
                    ),
                  ),
                  const SizedBox(width: SpacingTokens.spacing3),
                  Flexible(
                    child: Text(
                      amount,
                      textAlign: TextAlign.end,
                      style: TypographyTokens.headlineMedium(
                        metricAccent,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: SpacingTokens.spacing3),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: SpacingTokens.spacing3,
              runSpacing: SpacingTokens.spacing2,
              children: [
                Text(
                  date,
                  style: TypographyTokens.bodySmall(
                    ColorTokens.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupDetailFailureContent {
  const _GroupDetailFailureContent({
    required this.title,
    required this.message,
    required this.canRefresh,
  });

  final String title;
  final String message;
  final bool canRefresh;

  factory _GroupDetailFailureContent.fromFailure(
    GroupDetailFailure failure,
    bool isOnline,
    AfriLocalizations l10n,
  ) {
    return switch (failure.kind) {
      GroupDetailFailureKind.offline => _GroupDetailFailureContent(
        title: isOnline
            ? l10n.contributionsConnectionRestoredTitle
            : l10n.contributionsInitiativeOfflineTitle,
        message: isOnline
            ? l10n.contributionsConnectionRestoredMessage
            : l10n.contributionsInitiativeOfflineMessage,
        canRefresh: isOnline,
      ),
      GroupDetailFailureKind.notFound => _GroupDetailFailureContent(
        title: l10n.contributionsInitiativeNotFoundTitle,
        message: l10n.contributionsInitiativeNotFoundMessage,
        canRefresh: false,
      ),
      GroupDetailFailureKind.permissionDenied => _GroupDetailFailureContent(
        title: l10n.contributionsInitiativeUnavailableTitle,
        message: l10n.contributionsInitiativeAccessMessage,
        canRefresh: false,
      ),
      GroupDetailFailureKind.conflict => _GroupDetailFailureContent(
        title: l10n.contributionsInitiativeChangedTitle,
        message: l10n.contributionsInitiativeChangedMessage,
        canRefresh: true,
      ),
      GroupDetailFailureKind.securityTimeout => _GroupDetailFailureContent(
        title: l10n.contributionsInitiativeTimeoutTitle,
        message: l10n.contributionsInitiativeTimeoutMessage,
        canRefresh: true,
      ),
      GroupDetailFailureKind.unknown => _GroupDetailFailureContent(
        title: l10n.contributionsInitiativeUnavailableTitle,
        message: l10n.contributionsInitiativeUnavailableMessage,
        canRefresh: true,
      ),
    };
  }
}

class _RetainedGroupDetailFailure extends StatelessWidget {
  const _RetainedGroupDetailFailure({required this.failure});

  final GroupDetailFailure failure;

  @override
  Widget build(BuildContext context) {
    final content = _GroupDetailFailureContent.fromFailure(
      failure,
      true,
      context.afriL10n,
    );
    return AfriStateBanner(
      icon: failure.kind == GroupDetailFailureKind.permissionDenied
          ? AfriIcons.lock
          : AfriIcons.warning,
      title: content.title,
      subtitle: content.message,
      tone: AfriStateBannerTone.warning,
      compact: true,
    );
  }
}
