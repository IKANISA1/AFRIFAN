import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:feat_club/feat_club.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../controllers/group_detail_controller.dart';
import '../widgets/contribution_overlays.dart';

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
              'PUBLIC INITIATIVE',
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
                    title: 'Loading public initiative',
                    message:
                        'Checking the confirmed total and public contribution ledger.',
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
    final failure = GroupDetailFailure.fromError(error);
    final content = _GroupDetailFailureContent.fromFailure(failure, isOnline);
    final refreshAction = content.canRefresh
        ? () => unawaited(_refresh())
        : null;

    return switch (failure.kind) {
      GroupDetailFailureKind.offline => AfriStateView.offline(
        title: content.title,
        message: content.message,
        actionLabel: content.canRefresh ? 'Refresh' : null,
        onAction: refreshAction,
      ),
      GroupDetailFailureKind.notFound => AfriStateView.empty(
        title: content.title,
        message: content.message,
        icon: AfriIcons.groups,
        actionLabel: 'Back to communities',
        onAction: _goBack,
      ),
      _ => AfriStateView.error(
        title: content.title,
        message: content.message,
        actionLabel: content.canRefresh ? 'Refresh' : null,
        onAction: refreshAction,
      ),
    };
  }

  Widget _buildDetail(
    GroupDetailState state, {
    required bool isOnline,
    required bool configuredActionsEnabled,
  }) {
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
        const AfriStateBanner(
          icon: AfriIcons.refresh,
          title: 'Refreshing initiative',
          subtitle:
              'Keeping the last confirmed total and ledger visible while new activity is checked.',
          tone: AfriStateBannerTone.info,
          compact: true,
        ),
      );
    } else if (!configuredActionsEnabled) {
      children.add(
        const AfriStateBanner(
          icon: AfriIcons.lock,
          title: 'Contributions are read-only',
          subtitle:
              'Confirmed public activity remains visible, but starting a payment is disabled for this build.',
          tone: AfriStateBannerTone.warning,
          compact: true,
        ),
      );
    } else if (!isOnline) {
      children.add(
        const AfriStateBanner(
          icon: AfriIcons.offline,
          title: 'Showing saved initiative data',
          subtitle:
              'Reconnect and refresh before starting a payment or relying on the latest total.',
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
            label: 'REFRESH INITIATIVE',
            icon: AfriIcons.refresh,
            variant: AfriButtonVariant.outline,
            labelMaxLines: 2,
            onTap: _refresh,
          ),
        );
      }
    } else if (!initiativeOpen) {
      children.add(
        const AfriStateBanner(
          icon: AfriIcons.lock,
          title: 'Contributions are closed',
          subtitle:
              'The confirmed total and public ledger remain available for review.',
          tone: AfriStateBannerTone.info,
          compact: true,
        ),
      );
    } else if (!paymentConfigured) {
      children.add(
        const AfriStateBanner(
          icon: AfriIcons.warning,
          title: 'Payment route unavailable',
          subtitle:
              'No payment will start until the club publishes a verified recipient.',
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
    if (!configuredActionsEnabled) return 'Contributions disabled';
    if (!isOnline) return 'Connection required';
    if (!initiativeOpen) return 'Contributions closed';
    if (!paymentConfigured) return 'Payment unavailable';
    if (state.phase == GroupDetailPhase.syncing) return 'Checking latest total';
    if (state.phase == GroupDetailPhase.degraded) {
      return 'Refresh before contributing';
    }
    return 'Contribute now';
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
    final currency = CurrencyFormatter(
      currencyCode: context.afriCurrencyCode,
      currencySymbol: context.afriCurrencySymbol,
    );
    final description = group.description?.trim();
    final progress = group.progress;
    final metricAccent = ColorTokens.accessibleMetricColor(
      ColorTokens.clubAccent,
    );

    return GlassCard(
      key: const ValueKey<String>('group-detail-summary-card'),
      animate: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            group.name,
            style: TypographyTokens.headlineMedium().copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          if (description != null && description.isNotEmpty) ...[
            const SizedBox(height: SpacingTokens.spacing2),
            Text(description, style: TypographyTokens.bodyMedium()),
          ],
          const SizedBox(height: SpacingTokens.spacing5),
          Text(
            'Confirmed total',
            style: TypographyTokens.labelMedium(ColorTokens.onSurfaceVariant),
          ),
          const SizedBox(height: SpacingTokens.spacing1),
          Text(
            currency.format(group.currentTotal),
            style: TypographyTokens.displayLarge(
              metricAccent,
            ).copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: SpacingTokens.spacing2),
          Text(
            'Target ${currency.format(group.targetAmount)} · '
            '${(progress * 100).round()}%',
            style: TypographyTokens.bodyMedium(),
          ),
          const SizedBox(height: SpacingTokens.spacing3),
          Semantics(
            label:
                '${(progress * 100).round()} percent of the contribution target confirmed',
            child: AfriLinearProgressIndicator(
              value: progress,
              minHeight: 10,
              borderRadius: ShapeTokens.buttonRadius,
              color: ColorTokens.accessibleChartColor(ColorTokens.clubAccent),
              backgroundColor: ColorTokens.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing4),
          Wrap(
            spacing: SpacingTokens.spacing4,
            runSpacing: SpacingTokens.spacing3,
            children: [
              _GroupMetaStat(
                label: 'TYPE',
                value: group.groupType.label.toUpperCase(),
              ),
              _GroupMetaStat(
                label: 'CONTRIBUTORS',
                value: '${group.memberCount}',
              ),
            ],
          ),
          const SizedBox(height: SpacingTokens.spacing5),
          AfriButton(
            key: const ValueKey<String>('group-detail-contribute-action'),
            label: actionLabel,
            semanticsLabel: actionEnabled
                ? 'Contribute to ${group.name}'
                : '$actionLabel. Payment is unavailable.',
            fullWidth: true,
            labelMaxLines: 2,
            focusNode: actionFocusNode,
            onTap: onContribute,
            enabled: actionEnabled,
          ),
        ],
      ),
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
    return Column(
      key: const ValueKey<String>('group-detail-ledger'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PUBLIC LEDGER',
          style: TypographyTokens.titleLarge().copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: SpacingTokens.spacing2),
        Text(
          'Public supporter aliases only. Payment references and account details are never shown.',
          style: TypographyTokens.bodySmall(ColorTokens.onSurfaceVariant),
        ),
        const SizedBox(height: SpacingTokens.spacing3),
        if (ledger.isEmpty)
          const GlassCard(
            key: ValueKey<String>('group-ledger-empty'),
            animate: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('No contributions yet'),
                SizedBox(height: SpacingTokens.spacing1),
                Text(
                  'Confirmed public activity will appear here without exposing payment details.',
                ),
              ],
            ),
          )
        else
          ...ledger.map(
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

class _GroupMetaStat extends StatelessWidget {
  const _GroupMetaStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label, $value',
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 112),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TypographyTokens.labelSmall()),
            const SizedBox(height: SpacingTokens.spacing1),
            Text(value, style: TypographyTokens.labelLarge()),
          ],
        ),
      ),
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
      ColorTokens.clubAccent,
    );
    final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.5;
    final tone = switch (entry.status) {
      GroupLedgerStatus.confirmed => AfriStatusTone.success,
      GroupLedgerStatus.processing => AfriStatusTone.warning,
      GroupLedgerStatus.failed => AfriStatusTone.error,
    };
    return GlassCard(
      animate: false,
      child: Semantics(
        container: true,
        label:
            '${entry.publicAlias}, $amount, ${entry.status.label}, '
            '${AfriDateFormatter.formatDate(entry.createdAt)}',
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
                ).copyWith(fontWeight: FontWeight.w800),
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
                      ).copyWith(fontWeight: FontWeight.w800),
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
                AfriStatusChip(label: entry.status.label, tone: tone),
                Text(
                  AfriDateFormatter.formatDate(entry.createdAt),
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
  ) {
    return switch (failure.kind) {
      GroupDetailFailureKind.offline => _GroupDetailFailureContent(
        title: isOnline ? 'Connection restored' : 'Initiative offline',
        message: isOnline
            ? 'Refresh to check the latest confirmed total and public ledger.'
            : 'Reconnect to load this public initiative.',
        canRefresh: isOnline,
      ),
      GroupDetailFailureKind.notFound => const _GroupDetailFailureContent(
        title: 'Initiative not found',
        message:
            'This contribution initiative may have closed or the link may no longer be valid.',
        canRefresh: false,
      ),
      GroupDetailFailureKind.permissionDenied => const _GroupDetailFailureContent(
        title: 'Initiative unavailable',
        message:
            'Your current club access does not allow this contribution initiative.',
        canRefresh: false,
      ),
      GroupDetailFailureKind.conflict => const _GroupDetailFailureContent(
        title: 'Initiative changed',
        message:
            'Refresh and review the latest total before starting a contribution.',
        canRefresh: true,
      ),
      GroupDetailFailureKind.securityTimeout =>
        const _GroupDetailFailureContent(
          title: 'Initiative check timed out',
          message:
              'No total was confirmed. Refresh before starting a contribution.',
          canRefresh: true,
        ),
      GroupDetailFailureKind.unknown => const _GroupDetailFailureContent(
        title: 'Initiative unavailable',
        message: 'Refresh and try again when the public ledger is available.',
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
    final content = _GroupDetailFailureContent.fromFailure(failure, true);
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
