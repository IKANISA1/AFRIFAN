import 'dart:async';

import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../admin_settlement_controller.dart';

/// Bounded, role-gated prediction settlement workspace.
class FixtureSettlementScreen extends ConsumerStatefulWidget {
  const FixtureSettlementScreen({this.firstActionFocusNode, super.key});

  final FocusNode? firstActionFocusNode;

  @override
  ConsumerState<FixtureSettlementScreen> createState() =>
      _FixtureSettlementScreenState();
}

class _FixtureSettlementScreenState
    extends ConsumerState<FixtureSettlementScreen> {
  String _statusFilter = 'scheduled';

  List<AdminSettlementFixture> _filtered(AdminSettlementSnapshot snapshot) {
    if (_statusFilter == 'all') return snapshot.fixtures;
    return snapshot.fixtures
        .where((fixture) => fixture.status == _statusFilter)
        .toList(growable: false);
  }

  Future<void> _openSettlement(AdminSettlementFixture fixture) async {
    final draft = await showAfriBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SettlementSheet(fixture: fixture),
    );
    if (draft == null || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final l10n = dialogContext.afriL10n;
        return AfriAlertDialog(
          title: Text(l10n.adminSettlementConfirmTitle),
          content: Text(
            l10n.adminSettlementConfirmMessage(
              fixture.homeTeam.name,
              draft['home_score'] as int,
              draft['away_score'] as int,
              fixture.awayTeam.name,
            ),
          ),
          actions: [
            AfriTextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.adminCancelUpper),
            ),
            AfriTextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.adminSettlementSettleUpper),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    try {
      final receipt = await ref
          .read(adminSettlementProvider.notifier)
          .settle(draft);
      if (!mounted || receipt == null) return;
      AfriToast.success(
        context,
        context.afriL10n.adminSettlementReceipt(
          receipt.score,
          receipt.marketsSettled,
          receipt.totalWon,
          receipt.totalLost,
        ),
      );
    } on FormatException {
      if (!mounted) return;
      AfriToast.error(
        context,
        context.afriL10n.adminSettlementReviewOfficialResult,
      );
    } catch (_) {
      if (!mounted) return;
      AfriToast.error(context, context.afriL10n.adminSettlementNotConfirmed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(adminSettlementEnabledProvider);
    final settlement = ref.watch(adminSettlementProvider);
    final snapshot = settlement.valueOrNull;
    final denied =
        snapshot?.failure?.kind == AdminSettlementFailureKind.permissionDenied;

    return AfriScreenScaffold(
      backgroundColor: ColorTokens.background,
      title: context.afriL10n.adminSettlementTitle,
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
          ? _disabled()
          : denied
          ? _unavailable(
              const AdminSettlementFailure(
                AdminSettlementFailureKind.permissionDenied,
              ),
            )
          : settlement.isLoading && snapshot == null
          ? Padding(
              padding: const EdgeInsets.symmetric(
                vertical: SpacingTokens.spacing4,
              ),
              child: AfriStateView.loading(
                key: const ValueKey<String>('admin-settlement-state-loading'),
                title: context.afriL10n.adminSettlementLoadingTitle,
                message: context.afriL10n.adminSettlementLoadingMessage,
              ),
            )
          : settlement.hasError && snapshot == null
          ? _unavailable(AdminSettlementFailure.fromError(settlement.error!))
          : _content(settlement),
    );
  }

  Widget _content(AsyncValue<AdminSettlementSnapshot> settlement) {
    final snapshot = settlement.requireValue;
    final controlsEnabled = snapshot.actionsEnabled && !settlement.isLoading;
    final fixtures = _filtered(snapshot);
    final filters = <String, String>{
      'scheduled': context.afriL10n.adminSettlementFilterScheduled,
      'finished': context.afriL10n.adminSettlementFilterFinished,
      'all': context.afriL10n.adminSettlementFilterAll,
    };

    return AfriRefreshIndicator(
      onRefresh: ref.read(adminSettlementProvider.notifier).refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: SpacingTokens.spacing4),
        children: [
          if (_statusBanner(settlement) case final banner?) ...[
            banner,
            const SizedBox(height: SpacingTokens.spacing4),
          ],
          GlassCard(
            animate: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.afriL10n.adminSettlementControlTitle,
                  style: TypographyTokens.labelLarge(),
                ),
                const SizedBox(height: SpacingTokens.spacing2),
                Text(
                  context.afriL10n.adminSettlementControlMessage,
                  style: TypographyTokens.bodyMedium(),
                ),
              ],
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing4),
          Wrap(
            spacing: SpacingTokens.spacing2,
            runSpacing: SpacingTokens.spacing2,
            children: filters.entries
                .map(
                  (entry) => AfriChoiceChip(
                    selected: _statusFilter == entry.key,
                    label: Text(entry.value),
                    onSelected: controlsEnabled
                        ? (_) => setState(() => _statusFilter = entry.key)
                        : null,
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: SpacingTokens.spacing4),
          if (fixtures.isEmpty)
            AfriStateView.empty(
              key: const ValueKey<String>('admin-settlement-state-empty'),
              title: context.afriL10n.adminSettlementEmptyTitle,
              message: context.afriL10n.adminSettlementEmptyMessage,
              compact: true,
            )
          else
            ...fixtures.indexed.map(
              (entry) => _fixtureCard(
                entry.$2,
                controlsEnabled: controlsEnabled,
                focusNode: entry.$1 == 0 ? widget.firstActionFocusNode : null,
              ),
            ),
        ],
      ),
    );
  }

  Widget _fixtureCard(
    AdminSettlementFixture fixture, {
    required bool controlsEnabled,
    FocusNode? focusNode,
  }) {
    final enabled = controlsEnabled && fixture.canSettle;
    final localKickoff = fixture.kickoffAt.toLocal();
    final materialL10n = MaterialLocalizations.of(context);
    final score = fixture.homeScore == null
        ? context.afriL10n.adminSettlementVersusShort
        : context.afriL10n.adminScore(fixture.homeScore!, fixture.awayScore!);
    final detail = <String>[
      '${materialL10n.formatShortDate(localKickoff)} '
          '${materialL10n.formatTimeOfDay(TimeOfDay.fromDateTime(localKickoff))}',
      if (fixture.venueCity != null) fixture.venueCity!,
      if (fixture.stageName != null) fixture.stageName!,
      if (fixture.groupName != null) fixture.groupName!,
    ].join(' • ');

    return Padding(
      padding: const EdgeInsets.only(bottom: SpacingTokens.spacing3),
      child: AfriPressFeedback(
        key: ValueKey<String>('admin-settlement-fixture-${fixture.id}'),
        focusNode: focusNode,
        enabled: enabled,
        onTap: enabled ? () => unawaited(_openSettlement(fixture)) : null,
        semanticsLabel: context.afriL10n.adminMetricSemantic(
          fixture.homeTeam.name,
          context.afriL10n.adminMetricSemantic(score, fixture.awayTeam.name),
        ),
        semanticsHint: enabled
            ? context.afriL10n.adminSettlementOpenHint
            : context.afriL10n.adminSettlementUnavailableHint,
        builder: (context, state) => DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: ShapeTokens.cardRadius,
            border: BorderTokens.all(
              color: state.isFocused
                  ? ColorTokens.primaryContainer
                  : state.isPressed
                  ? ColorTokens.primaryContainer
                  : ColorTokens.transparent,
              width: state.isFocused || state.isPressed ? 2 : 0,
            ),
          ),
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
                        fixture.competition.shortName,
                        style: TypographyTokens.labelSmall(),
                      ),
                    ),
                    _StatusChip(status: fixture.status),
                  ],
                ),
                const SizedBox(height: SpacingTokens.spacing3),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        fixture.homeTeam.name,
                        style: TypographyTokens.titleMedium(
                          ColorTokens.onSurface,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: SpacingTokens.spacing2,
                      ),
                      child: Text(
                        score,
                        style: TypographyTokens.titleLarge(
                          ColorTokens.onSurface,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        fixture.awayTeam.name,
                        textAlign: TextAlign.end,
                        style: TypographyTokens.titleMedium(
                          ColorTokens.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: SpacingTokens.spacing2),
                Text(detail, style: TypographyTokens.bodySmall()),
                const SizedBox(height: SpacingTokens.spacing3),
                Align(
                  alignment: Alignment.centerRight,
                  child: fixture.canSettle
                      ? Text(
                          controlsEnabled
                              ? context
                                    .afriL10n
                                    .adminSettlementEnterOfficialResult
                              : context.afriL10n.adminSettlementPaused,
                          style: TypographyTokens.labelMedium(
                            controlsEnabled
                                ? ColorTokens.onSurface
                                : ColorTokens.onSurfaceVariant,
                          ),
                        )
                      : Text(
                          fixture.status == 'finished'
                              ? context.afriL10n.adminSettlementSettled
                              : context.afriL10n.adminSettlementNotSettleable,
                          style: TypographyTokens.labelMedium(
                            fixture.status == 'finished'
                                ? ColorTokens.success
                                : ColorTokens.onSurfaceVariant,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _disabled() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SpacingTokens.spacing4),
      child: AfriStateView.empty(
        key: const ValueKey<String>('admin-settlement-state-disabled'),
        title: context.afriL10n.adminSettlementManagementUnavailable,
        message: context.afriL10n.adminSettlementDisabledMessage,
        icon: AfriIcons.lock,
        actionLabel: context.afriL10n.adminBackToAdmin,
        onAction: () => context.pop(),
      ),
    );
  }

  Widget _unavailable(AdminSettlementFailure failure) {
    final l10n = context.afriL10n;
    void retry() =>
        unawaited(ref.read(adminSettlementProvider.notifier).refresh());
    final view = switch (failure.kind) {
      AdminSettlementFailureKind.offline => AfriStateView.offline(
        key: const ValueKey<String>('admin-settlement-state-offline'),
        title: l10n.adminSettlementWorkspaceOffline,
        message: l10n.adminSettlementWorkspaceOfflineMessage,
        actionLabel: l10n.editProfileTryAgain,
        onAction: retry,
      ),
      AdminSettlementFailureKind.permissionDenied => AfriStateView.error(
        key: const ValueKey<String>('admin-settlement-state-permission-denied'),
        title: l10n.adminSettlementAccessUnavailable,
        message: l10n.adminSettlementAccessUnavailableMessage,
        actionLabel: l10n.adminBackToAdmin,
        onAction: () => context.pop(),
      ),
      AdminSettlementFailureKind.conflict => AfriStateView.error(
        key: const ValueKey<String>('admin-settlement-state-conflict'),
        title: l10n.adminSettlementResultChanged,
        message: l10n.adminSettlementResultChangedMessage,
        actionLabel: l10n.editProfileRefresh,
        onAction: retry,
      ),
      AdminSettlementFailureKind.securityTimeout => AfriStateView.error(
        key: const ValueKey<String>('admin-settlement-state-security-timeout'),
        title: l10n.adminSecurityTimeout,
        message: l10n.adminSettlementSecurityTimeoutMessage,
        actionLabel: l10n.retry,
        onAction: retry,
      ),
      AdminSettlementFailureKind.unknown => AfriStateView.error(
        key: const ValueKey<String>('admin-settlement-state-error'),
        title: l10n.adminSettlementWorkspaceUnavailable,
        message: l10n.adminSettlementPrivateDataHidden,
        actionLabel: l10n.editProfileTryAgain,
        onAction: retry,
      ),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SpacingTokens.spacing4),
      child: view,
    );
  }

  Widget? _statusBanner(AsyncValue<AdminSettlementSnapshot> settlement) {
    final l10n = context.afriL10n;
    final snapshot = settlement.valueOrNull;
    if (snapshot == null) return null;
    if (settlement.isLoading || snapshot.isMutating) {
      return AfriStateBanner(
        key: const ValueKey<String>('admin-settlement-state-syncing'),
        icon: AfriIcons.refresh,
        title: l10n.adminSettlementCheckingResults,
        subtitle: l10n.adminSettlementCheckingResultsMessage,
        tone: AfriStateBannerTone.info,
      );
    }
    final failure = snapshot.failure;
    if (snapshot.phase != AdminSettlementPhase.degraded || failure == null) {
      return null;
    }
    return AfriStateBanner(
      key: ValueKey<String>('admin-settlement-state-${failure.kind.name}'),
      icon: failure.kind == AdminSettlementFailureKind.offline
          ? AfriIcons.offline
          : AfriIcons.statusWarning,
      title: switch (failure.kind) {
        AdminSettlementFailureKind.conflict =>
          l10n.adminSettlementResultChanged,
        AdminSettlementFailureKind.securityTimeout => l10n.adminSecurityTimeout,
        AdminSettlementFailureKind.offline =>
          l10n.adminSettlementWorkspaceOffline,
        _ => l10n.adminSettlementWorkspaceUnavailable,
      },
      subtitle: snapshot.mutationOutcomeUnconfirmed
          ? l10n.adminSettlementOutcomeUnconfirmed
          : l10n.adminSettlementLastConfirmedMessage,
      tone: AfriStateBannerTone.warning,
    );
  }
}

class _SettlementSheet extends StatefulWidget {
  const _SettlementSheet({required this.fixture});

  final AdminSettlementFixture fixture;

  @override
  State<_SettlementSheet> createState() => _SettlementSheetState();
}

class _SettlementSheetState extends State<_SettlementSheet> {
  final _homeScoreController = TextEditingController(text: '0');
  final _awayScoreController = TextEditingController(text: '0');
  final _halfTimeHomeController = TextEditingController();
  final _halfTimeAwayController = TextEditingController();
  bool _showHalfTime = false;
  String? _validationMessage;

  @override
  void dispose() {
    _homeScoreController.dispose();
    _awayScoreController.dispose();
    _halfTimeHomeController.dispose();
    _halfTimeAwayController.dispose();
    super.dispose();
  }

  void _submit() {
    final home = int.tryParse(_homeScoreController.text.trim());
    final away = int.tryParse(_awayScoreController.text.trim());
    final halfHome = int.tryParse(_halfTimeHomeController.text.trim());
    final halfAway = int.tryParse(_halfTimeAwayController.text.trim());
    if (home == null ||
        away == null ||
        home < 0 ||
        away < 0 ||
        home > 99 ||
        away > 99) {
      setState(
        () => _validationMessage =
            context.afriL10n.adminSettlementFinalScoreValidation,
      );
      return;
    }
    if (_showHalfTime &&
        (halfHome == null ||
            halfAway == null ||
            halfHome < 0 ||
            halfAway < 0 ||
            halfHome > home ||
            halfAway > away)) {
      setState(
        () => _validationMessage =
            context.afriL10n.adminSettlementHalfTimeValidation,
      );
      return;
    }
    context.pop(<String, dynamic>{
      'fixture_id': widget.fixture.id,
      'home_score': home,
      'away_score': away,
      if (_showHalfTime) 'half_time_home_score': halfHome,
      if (_showHalfTime) 'half_time_away_score': halfAway,
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: SpacingTokens.spacing6,
          right: SpacingTokens.spacing6,
          top: SpacingTokens.spacing6,
          bottom:
              MediaQuery.of(context).viewInsets.bottom + SpacingTokens.spacing6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.afriL10n.adminSettlementEnterOfficialResult,
              style: TypographyTokens.titleLarge(),
            ),
            const SizedBox(height: SpacingTokens.spacing2),
            Text(
              context.afriL10n.adminVersus(
                widget.fixture.homeTeam.name,
                widget.fixture.awayTeam.name,
              ),
              style: TypographyTokens.bodyLarge(),
            ),
            const SizedBox(height: SpacingTokens.spacing5),
            Row(
              children: [
                Expanded(
                  child: AfriInputField(
                    controller: _homeScoreController,
                    label: widget.fixture.homeTeam.shortName,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: SpacingTokens.spacing3),
                Expanded(
                  child: AfriInputField(
                    controller: _awayScoreController,
                    label: widget.fixture.awayTeam.shortName,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            const SizedBox(height: SpacingTokens.spacing4),
            AfriPressFeedback(
              key: const ValueKey<String>('admin-settlement-half-time-toggle'),
              onTap: () => setState(() {
                _showHalfTime = !_showHalfTime;
                _validationMessage = null;
              }),
              selected: _showHalfTime,
              semanticsLabel: context.afriL10n.adminSettlementHalfTimeScore,
              semanticsHint: _showHalfTime
                  ? context.afriL10n.adminSettlementHideHalfTime
                  : context.afriL10n.adminSettlementShowHalfTime,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: SpacingTokens.spacing3,
                ),
                child: Row(
                  children: [
                    Icon(
                      _showHalfTime ? AfriIcons.up : AfriIcons.down,
                      color: ColorTokens.onSurfaceVariant,
                    ),
                    const SizedBox(width: SpacingTokens.spacing2),
                    Text(
                      context.afriL10n.adminSettlementHalfTimeOptional,
                      style: TypographyTokens.labelMedium(),
                    ),
                  ],
                ),
              ),
            ),
            if (_showHalfTime) ...[
              const SizedBox(height: SpacingTokens.spacing3),
              Row(
                children: [
                  Expanded(
                    child: AfriInputField(
                      controller: _halfTimeHomeController,
                      label: context.afriL10n.adminSettlementHalfTimeLabel(
                        widget.fixture.homeTeam.shortName,
                      ),
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: SpacingTokens.spacing3),
                  Expanded(
                    child: AfriInputField(
                      controller: _halfTimeAwayController,
                      label: context.afriL10n.adminSettlementHalfTimeLabel(
                        widget.fixture.awayTeam.shortName,
                      ),
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ],
            if (_validationMessage != null) ...[
              const SizedBox(height: SpacingTokens.spacing3),
              Semantics(
                liveRegion: true,
                child: Text(
                  _validationMessage!,
                  style: TypographyTokens.bodyMedium(ColorTokens.error),
                ),
              ),
            ],
            const SizedBox(height: SpacingTokens.spacing5),
            AfriButton(
              key: const ValueKey<String>('admin-settlement-review-result'),
              label: context.afriL10n.adminSettlementReviewAction,
              fullWidth: true,
              onTap: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'finished' => ColorTokens.success,
      'scheduled' || 'live' => ColorTokens.onSurface,
      'cancelled' || 'postponed' => ColorTokens.error,
      _ => ColorTokens.onSurfaceVariant,
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.spacing3,
        vertical: SpacingTokens.spacing1,
      ),
      decoration: BoxDecoration(
        color: ColorTokens.surfaceContainer,
        borderRadius: ShapeTokens.buttonRadius,
        border: BorderTokens.all(
          color: color.withValues(alpha: 0.7),
          width: BorderTokens.standard,
        ),
      ),
      child: Text(
        _statusLabel(context, status),
        style: TypographyTokens.labelSmall(color),
      ),
    );
  }
}

String _statusLabel(BuildContext context, String status) {
  final l10n = context.afriL10n;
  return switch (status) {
    'finished' => l10n.adminStatusFinished,
    'scheduled' => l10n.adminStatusScheduled,
    'live' => l10n.adminStatusLive,
    'cancelled' => l10n.adminStatusCancelled,
    'postponed' => l10n.adminStatusPostponed,
    _ => status.toUpperCase(),
  };
}
