import 'dart:async';

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
      appBar: AfriAppBar(
        backgroundColor: ColorTokens.transparent,
        title: Text('MATCHES', style: TypographyTokens.titleLarge()),
        leading: AfriIconButton(
          icon: AfriIcons.back,
          onTap: () => context.pop(),
          tooltip: 'Back',
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
              padding: const EdgeInsets.all(SpacingTokens.spacing6),
              child: AfriStateView.loading(
                key: const ValueKey<String>('admin-matches-state-loading'),
                title: 'Loading match workspace',
                message: 'Checking controlled fixture information.',
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
    final currency = NumberFormat.decimalPattern();
    final currencySymbol = context.afriCurrencySymbol;
    final metricColor = Theme.of(context).brightness == Brightness.dark
        ? ColorTokens.clubAccent
        : ColorTokens.onSurface;

    return AfriRefreshIndicator(
      onRefresh: ref.read(adminMatchesProvider.notifier).refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(SpacingTokens.spacing6),
        children: [
          if (_statusBanner(matches) case final banner?) ...[
            banner,
            const SizedBox(height: SpacingTokens.spacing4),
          ],
          Text(
            'Manage fixtures, sale status, ticket allocation, and live scores from confirmed data.',
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
                  label: 'FIXTURES',
                  value: '${snapshot.matches.length}',
                  color: metricColor,
                ),
                _Metric(
                  label: 'ON SALE',
                  value:
                      '${snapshot.matches.where((match) => match.isOnSale).length}',
                  color: metricColor,
                ),
              ],
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing4),
          Text('STATUS', style: TypographyTokens.labelSmall()),
          const SizedBox(height: SpacingTokens.spacing2),
          Wrap(
            spacing: SpacingTokens.spacing2,
            runSpacing: SpacingTokens.spacing2,
            children: AdminMatchFilter.values
                .map(
                  (filter) => AfriChoiceChip(
                    selected: snapshot.filter == filter,
                    label: Text(filter.label),
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
                  ? 'No fixtures configured'
                  : 'No fixtures match',
              message: snapshot.matches.isEmpty
                  ? 'A confirmed club fixture must exist before this workspace can infer its partner scope.'
                  : 'Choose another status filter.',
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
            label: 'Create match',
            fullWidth: true,
            enabled: canCreate,
            onTap: () => unawaited(_openComposer(context, ref, snapshot, null)),
          ),
          if (snapshot.matches.isEmpty) ...[
            const SizedBox(height: SpacingTokens.spacing2),
            Text(
              'Creation stays paused until a confirmed partner scope is available.',
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
          ? 'Match created successfully.'
          : 'Match updated successfully.',
    );
  }

  Widget _disabled(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(SpacingTokens.spacing6),
      child: AfriStateView.empty(
        key: const ValueKey<String>('admin-matches-state-disabled'),
        title: 'Match management unavailable',
        message: 'Match controls are disabled for this controlled build.',
        icon: AfriIcons.lock,
        actionLabel: 'Back to admin',
        onAction: () => context.pop(),
      ),
    );
  }

  Widget _unavailable(
    BuildContext context,
    WidgetRef ref,
    AdminMatchesFailure failure,
  ) {
    void retry() =>
        unawaited(ref.read(adminMatchesProvider.notifier).refresh());
    final view = switch (failure.kind) {
      AdminMatchesFailureKind.offline => AfriStateView.offline(
        key: const ValueKey<String>('admin-matches-state-offline'),
        title: 'Match workspace offline',
        message: 'Reconnect before loading private fixture information.',
        actionLabel: 'Try again',
        onAction: retry,
      ),
      AdminMatchesFailureKind.permissionDenied => AfriStateView.error(
        key: const ValueKey<String>('admin-matches-state-permission-denied'),
        title: 'Match access unavailable',
        message: 'This account cannot view or change fixture information.',
        actionLabel: 'Back to admin',
        onAction: () => context.pop(),
      ),
      AdminMatchesFailureKind.conflict => AfriStateView.error(
        key: const ValueKey<String>('admin-matches-state-conflict'),
        title: 'Fixture information changed',
        message: 'Refresh before making another fixture change.',
        actionLabel: 'Refresh',
        onAction: retry,
      ),
      AdminMatchesFailureKind.securityTimeout => AfriStateView.error(
        key: const ValueKey<String>('admin-matches-state-security-timeout'),
        title: 'Security check timed out',
        message: 'No fixture information was shown. Check your connection.',
        actionLabel: 'Retry',
        onAction: retry,
      ),
      AdminMatchesFailureKind.unknown => AfriStateView.error(
        key: const ValueKey<String>('admin-matches-state-error'),
        title: 'Match workspace unavailable',
        message: 'Private fixture information remains hidden. Try again.',
        actionLabel: 'Try again',
        onAction: retry,
      ),
    };
    return Padding(
      padding: const EdgeInsets.all(SpacingTokens.spacing6),
      child: view,
    );
  }

  Widget? _statusBanner(AsyncValue<AdminMatchesSnapshot> value) {
    final snapshot = value.valueOrNull;
    if (snapshot == null) return null;
    if (value.isLoading || snapshot.isMutating) {
      return const AfriStateBanner(
        key: ValueKey<String>('admin-matches-state-syncing'),
        icon: AfriIcons.refresh,
        title: 'Checking fixture information',
        subtitle:
            'Showing the last confirmed state while current data is checked.',
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
        AdminMatchesFailureKind.conflict => 'Fixture information changed',
        AdminMatchesFailureKind.securityTimeout => 'Security check timed out',
        AdminMatchesFailureKind.offline => 'Match workspace offline',
        _ => 'Match workspace unavailable',
      },
      subtitle: snapshot.mutationOutcomeUnconfirmed
          ? 'The last change is unconfirmed. Controls stay paused until refresh succeeds.'
          : 'Last confirmed fixture information remains visible. Controls are paused.',
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
        ? "  •  ${match.liveMinute}'"
        : '';
    final statusColor = switch (match.status) {
      'live' => ColorTokens.success,
      'halftime' => ColorTokens.clubAccent,
      'fulltime' => ColorTokens.surfaceContainerHigh,
      'postponed' || 'cancelled' => ColorTokens.error,
      _ => ColorTokens.clubAccent,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: SpacingTokens.spacing3),
      child: AfriPressFeedback(
        key: ValueKey<String>('admin-match-${match.id}'),
        onTap: enabled ? onOpen : null,
        focusNode: focusNode,
        enabled: enabled,
        tooltip: 'Open ${match.homeTeam} versus ${match.awayTeam}',
        semanticsLabel: '${match.homeTeam} versus ${match.awayTeam} fixture',
        semanticsHint: 'Opens controlled fixture settings',
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
                      '${match.homeTeam} vs ${match.awayTeam}'.toUpperCase(),
                      style: TypographyTokens.titleLarge().copyWith(
                        color: ColorTokens.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: SpacingTokens.spacing2),
                  _MatchChip(label: match.statusLabel, color: statusColor),
                ],
              ),
              const SizedBox(height: SpacingTokens.spacing2),
              Text(
                '${match.competition}  •  ${match.venue}',
                style: TypographyTokens.bodyMedium(),
              ),
              const SizedBox(height: SpacingTokens.spacing2),
              Text(
                '${DateFormat('dd MMM yyyy').format(match.matchDate)}'
                '  •  ${_formatKickoff(match.kickoffTime)}',
                style: TypographyTokens.bodyMedium(),
              ),
              const SizedBox(height: SpacingTokens.spacing3),
              Text(
                'GENERAL $currencySymbol ${currency.format(match.generalPrice)}'
                '  •  VIP $currencySymbol ${currency.format(match.vipPrice)}',
                style: TypographyTokens.bodyMedium(),
              ),
              const SizedBox(height: SpacingTokens.spacing2),
              Text(
                'Score ${match.homeScore}-${match.awayScore}$liveMinuteLabel',
                style: TypographyTokens.bodyMedium(),
              ),
              const SizedBox(height: SpacingTokens.spacing2),
              Text(
                '${match.soldPercent}% allocation  •  '
                '${match.soldCount} / ${match.capacity} tickets',
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
                    match.isOnSale ? 'EDIT ON-SALE FIXTURE' : 'EDIT FIXTURE',
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
