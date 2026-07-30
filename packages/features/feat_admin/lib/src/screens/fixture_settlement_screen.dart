import 'dart:async';

import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

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
      builder: (dialogContext) => AfriAlertDialog(
        title: const Text('SETTLE THIS FIXTURE?'),
        content: Text(
          '${fixture.homeTeam.name} ${draft['home_score']} – '
          '${draft['away_score']} ${fixture.awayTeam.name}\n\n'
          'This grades prediction markets and may trigger supporter rewards. '
          'Confirm only from the official result.',
        ),
        actions: [
          AfriTextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('CANCEL'),
          ),
          AfriTextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('SETTLE'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final receipt = await ref
          .read(adminSettlementProvider.notifier)
          .settle(draft);
      if (!mounted || receipt == null) return;
      AfriToast.success(
        context,
        'Settled ${receipt.score} • ${receipt.marketsSettled} markets • '
        '${receipt.totalWon} won • ${receipt.totalLost} lost',
      );
    } on FormatException {
      if (!mounted) return;
      AfriToast.error(context, 'Review the official result and try again.');
    } catch (_) {
      if (!mounted) return;
      AfriToast.error(context, 'Fixture settlement was not confirmed.');
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
      appBar: AfriAppBar(
        backgroundColor: ColorTokens.transparent,
        title: Text('SETTLE FIXTURES', style: TypographyTokens.titleLarge()),
        leading: AfriIconButton(
          icon: AfriIcons.back,
          onTap: () => context.pop(),
          tooltip: 'Back',
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
              padding: const EdgeInsets.all(SpacingTokens.spacing6),
              child: AfriStateView.loading(
                key: const ValueKey<String>('admin-settlement-state-loading'),
                title: 'Loading settlement workspace',
                message: 'Checking controlled fixture information.',
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
    const filters = <String, String>{
      'scheduled': 'SCHEDULED',
      'finished': 'FINISHED',
      'all': 'ALL',
    };

    return AfriRefreshIndicator(
      onRefresh: ref.read(adminSettlementProvider.notifier).refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(SpacingTokens.spacing6),
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
                  'OFFICIAL RESULT CONTROL',
                  style: TypographyTokens.labelLarge(),
                ),
                const SizedBox(height: SpacingTokens.spacing2),
                Text(
                  'Settlement grades prediction markets and may trigger rewards. '
                  'Use only an official, confirmed final score.',
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
              title: 'No fixtures in this view',
              message:
                  'Switch filters or wait for controlled fixture information.',
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
    final score = fixture.homeScore == null
        ? 'VS'
        : '${fixture.homeScore} – ${fixture.awayScore}';
    final detail = <String>[
      DateFormat('dd MMM yyyy, HH:mm').format(fixture.kickoffAt.toLocal()),
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
        semanticsLabel:
            '${fixture.homeTeam.name} $score ${fixture.awayTeam.name}',
        semanticsHint: enabled
            ? 'Open official result confirmation'
            : 'Settlement unavailable',
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
                              ? 'ENTER OFFICIAL RESULT'
                              : 'SETTLEMENT PAUSED',
                          style: TypographyTokens.labelMedium(
                            controlsEnabled
                                ? ColorTokens.onSurface
                                : ColorTokens.onSurfaceVariant,
                          ),
                        )
                      : Text(
                          fixture.status == 'finished'
                              ? 'SETTLED'
                              : 'NOT SETTLEABLE',
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
      padding: const EdgeInsets.all(SpacingTokens.spacing6),
      child: AfriStateView.empty(
        key: const ValueKey<String>('admin-settlement-state-disabled'),
        title: 'Settlement management unavailable',
        message: 'Settlement controls are disabled for this controlled build.',
        icon: AfriIcons.lock,
        actionLabel: 'Back to admin',
        onAction: () => context.pop(),
      ),
    );
  }

  Widget _unavailable(AdminSettlementFailure failure) {
    void retry() =>
        unawaited(ref.read(adminSettlementProvider.notifier).refresh());
    final view = switch (failure.kind) {
      AdminSettlementFailureKind.offline => AfriStateView.offline(
        key: const ValueKey<String>('admin-settlement-state-offline'),
        title: 'Settlement workspace offline',
        message: 'Reconnect before loading private fixture information.',
        actionLabel: 'Try again',
        onAction: retry,
      ),
      AdminSettlementFailureKind.permissionDenied => AfriStateView.error(
        key: const ValueKey<String>('admin-settlement-state-permission-denied'),
        title: 'Settlement access unavailable',
        message: 'This account cannot view or settle prediction fixtures.',
        actionLabel: 'Back to admin',
        onAction: () => context.pop(),
      ),
      AdminSettlementFailureKind.conflict => AfriStateView.error(
        key: const ValueKey<String>('admin-settlement-state-conflict'),
        title: 'Fixture result changed',
        message: 'Refresh before confirming another settlement.',
        actionLabel: 'Refresh',
        onAction: retry,
      ),
      AdminSettlementFailureKind.securityTimeout => AfriStateView.error(
        key: const ValueKey<String>('admin-settlement-state-security-timeout'),
        title: 'Security check timed out',
        message: 'No fixture information was shown. Check your connection.',
        actionLabel: 'Retry',
        onAction: retry,
      ),
      AdminSettlementFailureKind.unknown => AfriStateView.error(
        key: const ValueKey<String>('admin-settlement-state-error'),
        title: 'Settlement workspace unavailable',
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

  Widget? _statusBanner(AsyncValue<AdminSettlementSnapshot> settlement) {
    final snapshot = settlement.valueOrNull;
    if (snapshot == null) return null;
    if (settlement.isLoading || snapshot.isMutating) {
      return const AfriStateBanner(
        key: ValueKey<String>('admin-settlement-state-syncing'),
        icon: AfriIcons.refresh,
        title: 'Checking fixture results',
        subtitle:
            'Showing the last confirmed state while current data is checked.',
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
        AdminSettlementFailureKind.conflict => 'Fixture result changed',
        AdminSettlementFailureKind.securityTimeout =>
          'Security check timed out',
        AdminSettlementFailureKind.offline => 'Settlement workspace offline',
        _ => 'Settlement workspace unavailable',
      },
      subtitle: snapshot.mutationOutcomeUnconfirmed
          ? 'The last settlement is unconfirmed. Controls stay paused until refresh succeeds.'
          : 'Last confirmed fixture information remains visible. Controls are paused.',
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
      setState(() => _validationMessage = 'Enter final scores from 0 to 99.');
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
            'Enter both half-time scores without exceeding the final score.',
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
            Text('ENTER OFFICIAL RESULT', style: TypographyTokens.titleLarge()),
            const SizedBox(height: SpacingTokens.spacing2),
            Text(
              '${widget.fixture.homeTeam.name} vs '
              '${widget.fixture.awayTeam.name}',
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
              semanticsLabel: 'Half-time score',
              semanticsHint: _showHalfTime
                  ? 'Hide half-time score fields'
                  : 'Show half-time score fields',
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
                      'HALF-TIME SCORE (OPTIONAL)',
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
                      label: '${widget.fixture.homeTeam.shortName} HT',
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: SpacingTokens.spacing3),
                  Expanded(
                    child: AfriInputField(
                      controller: _halfTimeAwayController,
                      label: '${widget.fixture.awayTeam.shortName} HT',
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
              label: 'Review settlement',
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
        status.toUpperCase(),
        style: TypographyTokens.labelSmall(color),
      ),
    );
  }
}
