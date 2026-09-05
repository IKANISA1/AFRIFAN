import 'dart:async';

import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../admin_matches_controller.dart';
import '../widgets/match_composer_sheet.dart';

/// Bounded, role-gated match workspace with retained confirmed state.
class MatchManagerScreen extends ConsumerWidget {
  const MatchManagerScreen({this.firstActionFocusNode, super.key});

  final FocusNode? firstActionFocusNode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(adminMatchesEnabledProvider);
    final matches = ref.watch(adminMatchesProvider);
    final snapshot = matches.valueOrNull;
    final denied =
        snapshot?.failure?.kind == AdminMatchesFailureKind.permissionDenied;

    return AfriScreenScaffold(
      backgroundColor: ColorTokens.background,
      title: context.afriL10n.adminMatchesTitle,
      appBar: AfriAppBar(
        backgroundColor: ColorTokens.transparent,
        leading: AfriIconButton(
          icon: AfriIcons.back,
          onTap: () => context.pop(),
          tooltip: context.afriL10n.adminBack,
        ),
      ),
      scrollable: false,
      constrainContent: true,
      child: !enabled
          ? _disabled(context)
          : denied
          ? _unavailable(
              context,
              ref,
              const AdminMatchesFailure(
                AdminMatchesFailureKind.permissionDenied,
              ),
            )
          : matches.isLoading && snapshot == null
          ? Padding(
              padding: const EdgeInsets.symmetric(
                vertical: SpacingTokens.spacing4,
              ),
              child: AfriStateView.loading(
                key: const ValueKey<String>('admin-matches-state-loading'),
                title: context.afriL10n.adminMatchesLoadingTitle,
                message: context.afriL10n.adminMatchesLoadingMessage,
              ),
            )
          : matches.hasError && snapshot == null
          ? _unavailable(
              context,
              ref,
              AdminMatchesFailure.fromError(matches.error!),
            )
          : _content(context, ref, matches),
    );
  }

  Widget _content(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<AdminMatchesSnapshot> matches,
  ) {
    final snapshot = matches.requireValue;
    final visible = snapshot.visibleMatches;
    final controlsEnabled = snapshot.actionsEnabled && !matches.isLoading;
    final canCreate = controlsEnabled && snapshot.partnerId != null;
    final currency = NumberFormat.decimalPattern(context.afriL10n.localeName);
    final currencySymbol = context.afriCurrencySymbol;
    final metricColor = ColorTokens.onSurface;

    return AfriRefreshIndicator(
      onRefresh: ref.read(adminMatchesProvider.notifier).refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: SpacingTokens.spacing4),
        children: [
          if (_statusBanner(context, matches) case final banner?) ...[
            banner,
            const SizedBox(height: SpacingTokens.spacing4),
          ],
          Text(
            context.afriL10n.adminMatchesDescription,
            style: TypographyTokens.bodyMedium(),
          ),
          const SizedBox(height: SpacingTokens.spacing4),
          GlassCard(
            animate: false,
            child: Wrap(
              spacing: SpacingTokens.spacing6,
              runSpacing: SpacingTokens.spacing3,
              children: [
                _Metric(
                  label: context.afriL10n.adminMatchesFixtures,
                  value: '${snapshot.matches.length}',
                  color: metricColor,
                ),
                _Metric(
                  label: context.afriL10n.adminMatchesOnSale,
                  value:
                      '${snapshot.matches.where((match) => match.isOnSale).length}',
                  color: metricColor,
                ),
              ],
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing4),
          Text(
            context.afriL10n.adminMatchesStatus,
            style: TypographyTokens.labelSmall(),
          ),
          const SizedBox(height: SpacingTokens.spacing2),
          Wrap(
            spacing: SpacingTokens.spacing2,
            runSpacing: SpacingTokens.spacing2,
            children: AdminMatchFilter.values
                .map(
                  (filter) => AfriChoiceChip(
                    selected: snapshot.filter == filter,
                    label: Text(_filterLabel(context, filter)),
                    onSelected: controlsEnabled
                        ? (_) => ref
                              .read(adminMatchesProvider.notifier)
                              .selectFilter(filter)
                        : null,
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: SpacingTokens.spacing4),
          if (visible.isEmpty)
            AfriStateView.empty(
              key: const ValueKey<String>('admin-matches-state-empty'),
              title: snapshot.matches.isEmpty
                  ? context.afriL10n.adminMatchesNoneConfigured
                  : context.afriL10n.adminMatchesNoneMatch,
              message: snapshot.matches.isEmpty
                  ? context.afriL10n.adminMatchesNoneConfiguredMessage
                  : context.afriL10n.adminMatchesNoneMatchMessage,
              compact: true,
            )
          else
            ...visible.indexed.map(
              (entry) => _MatchCard(
                match: entry.$2,
                currency: currency,
                currencySymbol: currencySymbol,
                enabled: controlsEnabled,
                focusNode: entry.$1 == 0 ? firstActionFocusNode : null,
                onOpen: () =>
                    unawaited(_openComposer(context, ref, snapshot, entry.$2)),
              ),
            ),
          const SizedBox(height: SpacingTokens.spacing3),
          AfriButton(
            key: const ValueKey<String>('admin-matches-create'),
            label: context.afriL10n.adminMatchesCreate,
            fullWidth: true,
            enabled: canCreate,
            onTap: () => unawaited(_openComposer(context, ref, snapshot, null)),
          ),
          if (snapshot.matches.isEmpty) ...[
            const SizedBox(height: SpacingTokens.spacing2),
            Text(
              context.afriL10n.adminMatchesCreationPaused,
              textAlign: TextAlign.center,
              style: TypographyTokens.bodySmall().copyWith(
                color: ColorTokens.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openComposer(
    BuildContext context,
    WidgetRef ref,
    AdminMatchesSnapshot snapshot,
    AdminMatchItem? existing,
  ) async {
    if (!snapshot.actionsEnabled || snapshot.partnerId == null) return;
    final saved = await showMatchComposerSheet(
      context,
      existing: existing,
      partnerId: snapshot.partnerId,
      onSave: (values, {matchId}) => ref
          .read(adminMatchesProvider.notifier)
          .save(values, matchId: matchId),
    );
    if (saved != true || !context.mounted) return;
    AfriToast.success(
      context,
      existing == null
          ? context.afriL10n.adminMatchesCreated
          : context.afriL10n.adminMatchesUpdated,
    );
  }

  Widget _disabled(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SpacingTokens.spacing4),
      child: AfriStateView.empty(
        key: const ValueKey<String>('admin-matches-state-disabled'),
        title: context.afriL10n.adminMatchesManagementUnavailable,
        message: context.afriL10n.adminMatchesDisabledMessage,
        icon: AfriIcons.lock,
        actionLabel: context.afriL10n.adminBackToAdmin,
        onAction: () => context.pop(),
      ),
    );
  }

  Widget _unavailable(
    BuildContext context,
    WidgetRef ref,
    AdminMatchesFailure failure,
  ) {
    final l10n = context.afriL10n;
    void retry() =>
        unawaited(ref.read(adminMatchesProvider.notifier).refresh());
    final view = switch (failure.kind) {
      AdminMatchesFailureKind.offline => AfriStateView.offline(
        key: const ValueKey<String>('admin-matches-state-offline'),
        title: l10n.adminMatchesWorkspaceOffline,
        message: l10n.adminMatchesWorkspaceOfflineMessage,
        actionLabel: l10n.editProfileTryAgain,
        onAction: retry,
      ),
      AdminMatchesFailureKind.permissionDenied => AfriStateView.error(
        key: const ValueKey<String>('admin-matches-state-permission-denied'),
        title: l10n.adminMatchesAccessUnavailable,
        message: l10n.adminMatchesAccessUnavailableMessage,
        actionLabel: l10n.adminBackToAdmin,
        onAction: () => context.pop(),
      ),
      AdminMatchesFailureKind.conflict => AfriStateView.error(
        key: const ValueKey<String>('admin-matches-state-conflict'),
        title: l10n.adminMatchesInformationChanged,
        message: l10n.adminMatchesInformationChangedMessage,
        actionLabel: l10n.editProfileRefresh,
        onAction: retry,
      ),
      AdminMatchesFailureKind.securityTimeout => AfriStateView.error(
        key: const ValueKey<String>('admin-matches-state-security-timeout'),
        title: l10n.adminSecurityTimeout,
        message: l10n.adminMatchesSecurityTimeoutMessage,
        actionLabel: l10n.retry,
        onAction: retry,
      ),
      AdminMatchesFailureKind.unknown => AfriStateView.error(
        key: const ValueKey<String>('admin-matches-state-error'),
        title: l10n.adminMatchesWorkspaceUnavailable,
        message: l10n.adminMatchesPrivateDataHidden,
        actionLabel: l10n.editProfileTryAgain,
        onAction: retry,
      ),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SpacingTokens.spacing4),
      child: view,
    );
  }

  Widget? _statusBanner(
    BuildContext context,
    AsyncValue<AdminMatchesSnapshot> value,
  ) {
    final l10n = context.afriL10n;
    final snapshot = value.valueOrNull;
    if (snapshot == null) return null;
    if (value.isLoading || snapshot.isMutating) {
      return AfriStateBanner(
        key: const ValueKey<String>('admin-matches-state-syncing'),
        icon: AfriIcons.refresh,
        title: l10n.adminMatchesCheckingTitle,
        subtitle: l10n.adminMatchesCheckingMessage,
        tone: AfriStateBannerTone.info,
      );
    }
    final failure = snapshot.failure;
    if (snapshot.phase != AdminMatchesPhase.degraded || failure == null) {
      return null;
    }
    return AfriStateBanner(
      key: ValueKey<String>('admin-matches-state-${failure.kind.name}'),
      icon: failure.kind == AdminMatchesFailureKind.offline
          ? AfriIcons.offline
          : AfriIcons.statusWarning,
      title: switch (failure.kind) {
        AdminMatchesFailureKind.conflict => l10n.adminMatchesInformationChanged,
        AdminMatchesFailureKind.securityTimeout => l10n.adminSecurityTimeout,
        AdminMatchesFailureKind.offline => l10n.adminMatchesWorkspaceOffline,
        _ => l10n.adminMatchesWorkspaceUnavailable,
      },
      subtitle: snapshot.mutationOutcomeUnconfirmed
          ? l10n.adminMatchesOutcomeUnconfirmed
          : l10n.adminMatchesLastConfirmed,
      tone: AfriStateBannerTone.warning,
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TypographyTokens.labelSmall()),
          Text(value, style: TypographyTokens.displayMedium(color)),
        ],
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({
    required this.match,
    required this.currency,
    required this.currencySymbol,
    required this.enabled,
    required this.onOpen,
    this.focusNode,
  });

  final AdminMatchItem match;
  final NumberFormat currency;
  final String currencySymbol;
  final bool enabled;
  final VoidCallback onOpen;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final liveMinuteLabel = match.isLive && match.liveMinute > 0
        ? context.afriL10n.adminMatchesLiveMinute(match.liveMinute)
        : '';
    final statusColor = switch (match.status) {
      'live' => ColorTokens.success,
      'halftime' => ColorTokens.primaryContainer,
      'fulltime' => ColorTokens.surfaceContainerHigh,
      'postponed' || 'cancelled' => ColorTokens.error,
      _ => ColorTokens.primaryContainer,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: SpacingTokens.spacing3),
      child: AfriPressFeedback(
        key: ValueKey<String>('admin-match-${match.id}'),
        onTap: enabled ? onOpen : null,
        focusNode: focusNode,
        enabled: enabled,
        tooltip: context.afriL10n.adminMatchesOpenTooltip(
          match.homeTeam,
          match.awayTeam,
        ),
        semanticsLabel: context.afriL10n.adminMatchesFixtureSemantic(
          match.homeTeam,
          match.awayTeam,
        ),
        semanticsHint: context.afriL10n.adminMatchesOpenHint,
        child: GlassCard(
          animate: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      context.afriL10n.adminVersus(
                        match.homeTeam,
                        match.awayTeam,
                      ),
                      style: TypographyTokens.titleLarge().copyWith(
                        color: ColorTokens.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: SpacingTokens.spacing2),
                  _MatchChip(
                    label: _statusLabel(context, match.status),
                    color: statusColor,
                  ),
                ],
              ),
              const SizedBox(height: SpacingTokens.spacing2),
              Text(
                context.afriL10n.adminMatchesCompetitionVenue(
                  match.competition,
                  match.venue,
                ),
                style: TypographyTokens.bodyMedium(),
              ),
              const SizedBox(height: SpacingTokens.spacing2),
              Text(
                context.afriL10n.adminMatchesDateKickoff(
                  MaterialLocalizations.of(
                    context,
                  ).formatShortDate(match.matchDate),
                  _formatKickoff(match.kickoffTime),
                ),
                style: TypographyTokens.bodyMedium(),
              ),
              const SizedBox(height: SpacingTokens.spacing3),
              Text(
                context.afriL10n.adminMatchesPrices(
                  currencySymbol,
                  currency.format(match.generalPrice),
                  currency.format(match.vipPrice),
                ),
                style: TypographyTokens.bodyMedium(),
              ),
              const SizedBox(height: SpacingTokens.spacing2),
              Text(
                context.afriL10n.adminMatchesScore(
                  match.homeScore,
                  match.awayScore,
                  liveMinuteLabel,
                ),
                style: TypographyTokens.bodyMedium(),
              ),
              const SizedBox(height: SpacingTokens.spacing2),
              Text(
                context.afriL10n.adminMatchesAllocation(
                  match.soldPercent,
                  match.soldCount,
                  match.capacity,
                ),
                style: TypographyTokens.bodyMedium(),
              ),
              const SizedBox(height: SpacingTokens.spacing3),
              Align(
                alignment: Alignment.centerRight,
                child: AfriTextIconButton(
                  onPressed: enabled ? onOpen : null,
                  icon: Icon(
                    AfriIcons.edit,
                    color: enabled
                        ? ColorTokens.onSurface
                        : ColorTokens.onSurfaceVariant,
                  ),
                  label: Text(
                    match.isOnSale
                        ? context.afriL10n.adminMatchesEditOnSale
                        : context.afriL10n.adminMatchesEdit,
                    style: TypographyTokens.labelLarge(
                      enabled
                          ? ColorTokens.onSurface
                          : ColorTokens.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatKickoff(String value) {
    final parts = value.split(':');
    return parts.length < 2 ? value : '${parts[0]}:${parts[1]}';
  }
}

class _MatchChip extends StatelessWidget {
  const _MatchChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.spacing3,
        vertical: SpacingTokens.spacing1,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: ShapeTokens.buttonRadius,
      ),
      child: Text(label, style: TypographyTokens.labelSmall()),
    );
  }
}

String _filterLabel(BuildContext context, AdminMatchFilter filter) {
  final l10n = context.afriL10n;
  return switch (filter) {
    AdminMatchFilter.all => l10n.adminMatchesFilterAll,
    AdminMatchFilter.live => l10n.adminMatchesFilterLive,
    AdminMatchFilter.upcoming => l10n.adminMatchesFilterUpcoming,
    AdminMatchFilter.onSale => l10n.adminMatchesFilterOnSale,
    AdminMatchFilter.completed => l10n.adminMatchesFilterCompleted,
  };
}

String _statusLabel(BuildContext context, String status) {
  final l10n = context.afriL10n;
  return switch (status) {
    'live' => l10n.adminStatusLive,
    'halftime' => l10n.adminStatusHalfTime,
    'fulltime' => l10n.adminStatusFullTime,
    'postponed' => l10n.adminStatusPostponed,
    'cancelled' => l10n.adminStatusCancelled,
    _ => l10n.adminStatusUpcoming,
  };
}
