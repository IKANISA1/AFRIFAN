import 'dart:async';
import 'package:core_l10n/core_l10n.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../admin_predict_controller.dart';

class PredictOpsScreen extends ConsumerStatefulWidget {
  const PredictOpsScreen({super.key});
  @override
  ConsumerState<PredictOpsScreen> createState() => _PredictOpsScreenState();
}

class _PredictOpsScreenState extends ConsumerState<PredictOpsScreen> {
  String _status = 'all';
  Future<void> _act(
    PredictAdminAction action, [
    AdminPredictFixture? fixture,
  ]) async {
    final state = ref.read(adminPredictProvider);
    if (!state.canAct) return;
    final params = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (_) => _PredictAdminForm(
        action: action,
        fixture: fixture,
        data: state.data!,
      ),
    );
    if (mounted && params != null) {
      await ref.read(adminPredictProvider.notifier).command(action, params);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.afriL10n;
    final state = ref.watch(adminPredictProvider);
    final controller = ref.read(adminPredictProvider.notifier);
    final labels = {
      'all': l.predictAdminAll,
      'no_pool': l.predictAdminNoPool,
      'open': l.predictAdminOpen,
      'locked': l.predictAdminLocked,
      'settled': l.predictAdminSettled,
      'refunded': l.predictAdminRefunded,
    };
    final rows =
        state.data?.fixtures
            .where((f) => _status == 'all' || f.status == _status)
            .toList() ??
        <AdminPredictFixture>[];
    return AfriScreenScaffold(
      title: l.predictAdminTitle,
      scrollable: false,
      constrainContent: false,
      child: ConnectivityBuilder(
        builder: (context, online) => AfriRefreshIndicator(
          onRefresh: controller.refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                l.predictAdminIntro,
                style: TypographyTokens.bodyMedium(
                  ColorTokens.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              AfriButton(
                label: l.predictAdminSettings,
                enabled: state.canAct && online,
                onTap: () => _act(PredictAdminAction.settings),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in labels.entries)
                    AfriChoiceChip(
                      label: Text(entry.value),
                      selected: _status == entry.key,
                      onSelected: (_) => setState(() => _status = entry.key),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              if (!online) Text(l.predictOffline),
              if (state.loading || state.busy)
                const AfriLinearProgressIndicator(),
              if (state.failed) ...[
                Semantics(
                  liveRegion: true,
                  child: Text(
                    state.denied ? l.predictAdminDenied : l.predictAdminFailed,
                  ),
                ),
                const SizedBox(height: 12),
                AfriButton(
                  label: l.predictRefresh,
                  enabled: online && !state.loading,
                  onTap: controller.refresh,
                ),
              ],
              if (rows.isEmpty && state.data != null) Text(l.predictAdminEmpty),
              for (final row in rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: GlassCard(
                    animate: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AfriFixtureTeams(
                          homeTeam: row.home,
                          awayTeam: row.away,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${row.competition} · ${labels[row.status] ?? l.predictUnavailable}',
                        ),
                        if (row.kickoff case final kickoff?)
                          Text(
                            MaterialLocalizations.of(
                              context,
                            ).formatFullDate(kickoff.toLocal()),
                          ),
                        const SizedBox(height: 12),
                        Text(row.economicsVersion == 'free_v1' ? l.predictAdminFreeTotals : l.predictAdminTotals),
                        Text(
                          row.economicsVersion == 'free_v1'
                              ? '${row.entries} · ${l.predictFreeEntry}'
                              : '${row.entries} / ${row.staked} FET / ${row.paid} FET',
                        ),
                        const SizedBox(height: 16),
                        if (row.poolId == null)
                          AfriButton(
                            label: l.predictAdminPrepare,
                            enabled:
                                state.canAct &&
                                online &&
                                row.kickoff?.isAfter(DateTime.now()) == true,
                            onTap: () => _act(PredictAdminAction.prepare, row),
                          )
                        else if (row.economicsVersion != 'free_v1')
                          Text(l.predictAdminLegacyService)
                        else if (!row.completed) ...[
                          Text(
                            row.hasFinalScore
                                ? '${l.predictAdminFinalScore} · ${row.homeScore}–${row.awayScore}'
                                : l.predictAdminAwaitingResult,
                            style: TypographyTokens.titleMedium(),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l.predictAdminAutomaticResults,
                            style: TypographyTokens.bodyMedium(
                              ColorTokens.onSurfaceVariant,
                            ),
                          ),
                          if (row.hasFinalScore && !row.confirmed) ...[
                            const SizedBox(height: 8),
                            AfriButton(
                              label: l.predictAdminConfirm,
                              enabled: state.canAct && online,
                              onTap: () =>
                                  _act(PredictAdminAction.confirmResult, row),
                            ),
                          ],
                          if (row.confirmed && row.hasFinalScore) ...[
                            const SizedBox(height: 8),
                            AfriButton(
                              label: l.predictAdminSettle,
                              enabled: state.canAct && online,
                              onTap: () => _act(PredictAdminAction.settle, row),
                            ),
                          ],
                          const SizedBox(height: 8),
                          AfriButton(
                            label: l.predictAdminVoid,
                            enabled: state.canAct && online,
                            variant: AfriButtonVariant.secondary,
                            onTap: () => _act(PredictAdminAction.refund, row),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PredictAdminForm extends StatefulWidget {
  const _PredictAdminForm({
    required this.action,
    required this.data,
    this.fixture,
  });
  final PredictAdminAction action;
  final AdminPredictFixture? fixture;
  final AdminPredictData data;
  @override
  State<_PredictAdminForm> createState() => _PredictAdminFormState();
}

class _PredictAdminFormState extends State<_PredictAdminForm> {
  late final TextEditingController input = TextEditingController(text: '');
  late bool enabled = widget.data.enabled;
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  bool get valid {
    final value = input.text.trim();
    return switch (widget.action) {
      PredictAdminAction.settings => true,
      PredictAdminAction.prepare || PredictAdminAction.confirmResult =>
        value.length <= 2000 &&
            Uri.tryParse(value)?.scheme == 'https' &&
            (Uri.tryParse(value)?.host.isNotEmpty ?? false),
      PredictAdminAction.refund => value.length >= 8 && value.length <= 500,
      PredictAdminAction.settle => true,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = context.afriL10n;
    final label = switch (widget.action) {
      PredictAdminAction.settings => l.predictAdminSave,
      PredictAdminAction.prepare => l.predictAdminPrepare,
      PredictAdminAction.confirmResult => l.predictAdminConfirm,
      PredictAdminAction.settle => l.predictAdminSettle,
      PredictAdminAction.refund => l.predictAdminVoid,
    };
    return AfriAlertDialog(
      title: Text(label),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.fixture case final fixture?)
            AfriFixtureTeams(homeTeam: fixture.home, awayTeam: fixture.away),
          if (widget.action == PredictAdminAction.settings) ...[
            AfriSwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.predictAdminEnabled),
              value: enabled,
              onChanged: (value) => setState(() => enabled = value),
            ),
            Text(l.predictAdminPriceNote),
          ],
          if (widget.action == PredictAdminAction.prepare)
            Text(l.predictFreeEntry),
          if (widget.action == PredictAdminAction.refund)
            Text(l.predictAdminVoidBody),
          if (widget.action == PredictAdminAction.settle)
            Text(l.predictAdminSettleBody)
          else if (widget.action != PredictAdminAction.settings)
            AfriTextFormField(
              controller: input,
              onChanged: (_) => setState(() {}),
              keyboardType: widget.action == PredictAdminAction.settings
                  ? TextInputType.number
                  : widget.action == PredictAdminAction.refund
                  ? TextInputType.text
                  : TextInputType.url,
              label: widget.action == PredictAdminAction.settings
                  ? l.predictAdminEntryPrice
                  : widget.action == PredictAdminAction.refund
                  ? l.predictAdminReason
                  : l.predictAdminSource,
            ),
        ],
      ),
      actions: [
        AfriTextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.predictAdminCancel),
        ),
        AfriTextButton(
          onPressed: valid
              ? () => Navigator.pop(context, <String, Object?>{
                  if (widget.action == PredictAdminAction.settings) ...{
                    'p_enabled': enabled,
                    'p_entry_fet': 0,
                  },
                  if (widget.action == PredictAdminAction.prepare)
                    'p_fixture_id': widget.fixture!.id,
                  if (widget.action != PredictAdminAction.prepare &&
                      widget.action != PredictAdminAction.settings)
                    'p_pool_id': widget.fixture!.poolId,
                  if (widget.action == PredictAdminAction.prepare)
                    'p_source_url': input.text.trim(),
                  if (widget.action == PredictAdminAction.confirmResult) ...{
                    'p_home_score': widget.fixture!.homeScore,
                    'p_away_score': widget.fixture!.awayScore,
                    'p_source_url': input.text.trim(),
                  },
                  if (widget.action == PredictAdminAction.refund)
                    'p_void_reason': input.text.trim(),
                })
              : null,
          child: Text(label),
        ),
      ],
    );
  }
}
