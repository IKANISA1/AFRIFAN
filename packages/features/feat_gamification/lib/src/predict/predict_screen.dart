import 'dart:async';
import 'package:core_l10n/core_l10n.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'predict_controller.dart';
import 'predict_models.dart';
import 'predict_repository.dart';

/// Gikundiro's fixture-first Predict contract, using native task surfaces.
class PredictScreen extends ConsumerStatefulWidget {
  const PredictScreen({super.key, this.embedded = false});
  final bool embedded;
  @override
  ConsumerState<PredictScreen> createState() => _PredictScreenState();
}

class _PredictScreenState extends ConsumerState<PredictScreen> {
  int _section = 0;
  String? _competition;
  Timer? _clock;
  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  void _signIn() => context.push('/auth/phone?from=%2Fpredict');

  @override
  Widget build(BuildContext context) {
    final l = context.afriL10n;
    final state = ref.watch(predictControllerProvider);
    final controller = ref.read(predictControllerProvider.notifier);
    final data = state.dashboard;
    final competitions = {
      for (final f in data?.fixtures ?? <PredictFixture>[])
        f.competitionId: f.competition,
    };
    final selectedCompetition = competitions.containsKey(_competition)
        ? _competition
        : null;
    final rows = _section == 1
        ? data?.history ?? <PredictFixture>[]
        : (data?.fixtures ?? <PredictFixture>[])
              .where(
                (f) =>
                    selectedCompetition == null ||
                    f.competitionId == selectedCompetition,
              )
              .toList();
    final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.5;
    final content = ConnectivityBuilder(
      builder: (context, online) {
        final enabled =
            online &&
            !state.loading &&
            state.pendingFixture == null &&
            !state.needsReconciliation &&
            data?.enabled == true;
        return AfriRefreshIndicator(
          onRefresh: controller.refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(SpacingTokens.screenPadding),
            children: [
              if (largeText) ...[
                Text(
                  l.predictTitle,
                  style: TypographyTokens.headlineLarge(ColorTokens.onSurface),
                ),
                if (data?.balanceFet case final balance?)
                  Text(
                    '$balance FET',
                    style: TypographyTokens.titleMedium(ColorTokens.onSurface),
                  ),
              ] else
                Row(
                  children: [
                    if (!widget.embedded && context.canPop())
                      AfriIconButton(
                        icon: AfriIcons.back,
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).backButtonTooltip,
                        onTap: () => context.pop(),
                      ),
                    Expanded(
                      child: Text(
                        l.predictTitle,
                        style: TypographyTokens.headlineLarge(
                          ColorTokens.onSurface,
                        ),
                      ),
                    ),
                    if (data?.balanceFet case final balance?)
                      Text(
                        '$balance FET',
                        style: TypographyTokens.titleMedium(
                          ColorTokens.onSurface,
                        ),
                      ),
                  ],
                ),
              const SizedBox(height: 8),
              Text(
                l.predictIntro,
                style: TypographyTokens.bodyMedium(
                  ColorTokens.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (index, label) in [
                    l.predictFixtures,
                    l.predictHistory,
                    l.predictWallet,
                  ].indexed)
                    AfriChoiceChip(
                      visualDensity: largeText ? VisualDensity.standard : null,
                      padding: largeText ? const EdgeInsets.all(8) : null,
                      label: Text(label),
                      selected: _section == index,
                      onSelected: (_) => setState(() => _section = index),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              if (!online) ...[
                _notice(l.predictOffline),
                const SizedBox(height: 16),
              ],
              if (state.failure case final failure?) ...[
                _notice(switch (failure) {
                  PredictFailure.signIn => l.predictSignIn,
                  PredictFailure.closed => l.predictClosed,
                  PredictFailure.alreadyEntered => l.predictAlreadyEntered,
                  PredictFailure.insufficient => l.predictInsufficient,
                  PredictFailure.uncertain => l.predictUncertain,
                  PredictFailure.unavailable => l.predictUnavailable,
                }),
                const SizedBox(height: 12),
                AfriButton(
                  label: failure == PredictFailure.signIn
                      ? l.predictSignIn
                      : l.predictRefresh,
                  enabled: online && !state.loading,
                  onTap: failure == PredictFailure.signIn
                      ? _signIn
                      : controller.refresh,
                ),
                const SizedBox(height: 24),
              ],
              if (state.loading) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 12),
                Text(
                  l.predictLoading,
                  style: TypographyTokens.bodyMedium(
                    ColorTokens.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
              ],
              if (data != null) ...[
                if (!data.enabled && _section == 0)
                  _notice(l.predictDisabled)
                else if (_section == 2) ...[
                  if (!data.memberSession)
                    AfriButton(
                      label: l.predictSignIn,
                      enabled: online,
                      onTap: _signIn,
                    )
                  else if (data.ledger.isEmpty)
                    _notice(l.predictNoActivity)
                  else
                    for (final entry in data.ledger)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(switch (entry.type) {
                          'predict_welcome' => l.predictWelcome,
                          'predict_entry' => l.predictEntry,
                          'predict_payout' => l.predictPayout,
                          'predict_refund' => l.predictRefund,
                          _ => l.predictActivity,
                        }),
                        subtitle: Text(
                          MaterialLocalizations.of(
                            context,
                          ).formatMediumDate(entry.createdAt.toLocal()),
                        ),
                        trailing: Text(
                          '${entry.deltaFet > 0 ? '+' : ''}${entry.deltaFet} FET',
                        ),
                      ),
                ] else ...[
                  if (_section == 0 && competitions.length > 1) ...[
                    DropdownButtonFormField<String>(
                      initialValue: selectedCompetition ?? '',
                      decoration: InputDecoration(labelText: l.predictFixtures),
                      items: [
                        DropdownMenuItem(value: '', child: Text(l.predictAll)),
                        for (final entry in competitions.entries)
                          DropdownMenuItem(
                            value: entry.key,
                            child: Text(
                              entry.value,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (value) => setState(
                        () => _competition = value == '' ? null : value,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_section == 1 && !data.memberSession)
                    AfriButton(
                      label: l.predictSignIn,
                      enabled: online,
                      onTap: _signIn,
                    )
                  else if (rows.isEmpty)
                    _notice(
                      _section == 1
                          ? l.predictNoHistory
                          : '${l.predictEmpty}\n${l.predictEmptyBody}',
                    )
                  else
                    for (final fixture in rows)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: PredictFixtureCard(
                          fixture: fixture,
                          pending: state.pendingFixture == fixture.id,
                          enabled:
                              enabled &&
                              fixture.isOpen(DateTime.now()) &&
                              fixture.selection == null &&
                              _section == 0,
                          onPick: (selection) {
                            if (data.memberSession) {
                              unawaited(controller.place(fixture, selection));
                            } else {
                              _signIn();
                            }
                          },
                        ),
                      ),
                ],
                const SizedBox(height: 24),
                Text(
                  l.predictRules,
                  style: TypographyTokens.bodySmall(
                    ColorTokens.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
    if (widget.embedded) return content;
    return AfriScreenScaffold(
      padding: EdgeInsets.zero,
      showBackButton: false,
      showAppBar: false,
      scrollable: false,
      constrainContent: false,
      backgroundColor: ColorTokens.background,
      child: SafeArea(child: content),
    );
  }

  Widget _notice(String text) => Semantics(
    liveRegion: true,
    child: Text(
      text,
      style: TypographyTokens.bodyMedium(ColorTokens.onSurfaceVariant),
    ),
  );
}

class PredictFixtureCard extends StatelessWidget {
  const PredictFixtureCard({
    super.key,
    required this.fixture,
    required this.enabled,
    required this.pending,
    required this.onPick,
  });
  final PredictFixture fixture;
  final bool enabled;
  final bool pending;
  final void Function(PredictSelection) onPick;

  @override
  Widget build(BuildContext context) {
    final l = context.afriL10n;
    final local = fixture.kickoffAt.toLocal();
    final material = MaterialLocalizations.of(context);
    return Material(
      color: ColorTokens.surfaceContainer,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              [
                fixture.competition,
                if (fixture.round?.isNotEmpty == true) fixture.round!,
              ].join(' · '),
              style: TypographyTokens.labelMedium(ColorTokens.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            Text(
              '${material.formatMediumDate(local)} · ${material.formatTimeOfDay(TimeOfDay.fromDateTime(local), alwaysUse24HourFormat: true)}',
              style: TypographyTokens.bodyMedium(ColorTokens.onSurface),
            ),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _team(fixture.homeTeam, fixture.homeCrest)),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 20,
                  ),
                  child: Text(
                    'vs',
                    style: TypographyTokens.bodySmall(
                      ColorTokens.onSurfaceVariant,
                    ),
                  ),
                ),
                Expanded(child: _team(fixture.awayTeam, fixture.awayCrest)),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final selection in PredictSelection.values) ...[
                  if (selection != PredictSelection.home)
                    const SizedBox(width: 8),
                  Expanded(
                    child: Semantics(
                      button: true,
                      enabled: enabled,
                      selected: fixture.selection == selection,
                      label:
                          '${fixture.selectionName(selection, l.predictDraw)}, ${fixture.stakeFet} FET',
                      excludeSemantics: true,
                      onTap: enabled ? () => onPick(selection) : null,
                      child: OutlinedButton(
                        key: ValueKey(
                          'predict-${fixture.id}-${selection.name}',
                        ),
                        onPressed: enabled ? () => onPick(selection) : null,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(48, 52),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 12,
                          ),
                          side: BorderSide(
                            color: fixture.selection == selection
                                ? ColorTokens.primary
                                : ColorTokens.outlineVariant,
                            width: fixture.selection == selection ? 2 : 1,
                          ),
                          backgroundColor: fixture.selection == selection
                              ? ColorTokens.primary.withValues(alpha: .16)
                              : ColorTokens.surfaceContainerHigh,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: selection == PredictSelection.draw
                            ? Text(
                                l.predictDraw,
                                textAlign: TextAlign.center,
                                style: TypographyTokens.labelLarge(
                                  ColorTokens.onSurface,
                                ),
                              )
                            : _crest(
                                selection == PredictSelection.home
                                    ? fixture.homeCrest
                                    : fixture.awayCrest,
                                24,
                              ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              child: Text(
                pending
                    ? l.predictPending
                    : fixture.selection != null
                    ? '${fixture.selectionName(fixture.selection!, l.predictDraw)} · ${switch (fixture.outcome) {
                        'won' => '${l.predictWon} +${fixture.payoutFet} FET',
                        'lost' => l.predictLost,
                        'refunded' => '${l.predictRefunded} +${fixture.payoutFet} FET',
                        _ => l.predictPicked,
                      }}'
                    : fixture.isOpen(DateTime.now())
                    ? '${fixture.stakeFet} FET'
                    : l.predictLocked,
                style: TypographyTokens.bodySmall(ColorTokens.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _team(String name, String url) => Column(
    children: [
      _crest(url, 48),
      const SizedBox(height: 10),
      Text(
        name,
        textAlign: TextAlign.center,
        style: TypographyTokens.titleSmall(ColorTokens.onSurface),
      ),
    ],
  );
  Widget _crest(String url, double size) => Image.network(
    url,
    width: size,
    height: size,
    fit: BoxFit.contain,
    excludeFromSemantics: true,
    errorBuilder: (_, __, ___) => SizedBox(
      width: size,
      height: size,
      child: Icon(
        AfriIcons.mediaUnavailable,
        size: size * .6,
        color: ColorTokens.onSurfaceVariant,
      ),
    ),
  );
}
