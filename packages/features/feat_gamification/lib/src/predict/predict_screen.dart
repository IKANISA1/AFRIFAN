import 'dart:async';
import 'package:core_l10n/core_l10n.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'predict_controller.dart';
import 'predict_fixture_card.dart';
import 'predict_models.dart';
import 'predict_repository.dart';
import 'predict_review_sheet.dart';
export 'predict_fixture_card.dart';

/// One supporter journey: fixture picks, personal history and FET activity.
class PredictScreen extends ConsumerStatefulWidget {
  const PredictScreen({super.key, this.embedded = false});
  final bool embedded;
  @override
  ConsumerState<PredictScreen> createState() => _PredictScreenState();
}

class _PredictScreenState extends ConsumerState<PredictScreen>
    with WidgetsBindingObserver {
  int _section = 0;
  bool _reviewOpen = false;
  String? _competition;
  Timer? _clock;
  DateTime? _nextBoundary;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clock?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(ref.read(predictControllerProvider.notifier).refresh());
      if (mounted) setState(() {});
    }
  }

  void _scheduleBoundary(PredictDashboard? data) {
    final now = DateTime.now();
    final boundaries =
        (data?.fixtures ?? <PredictFixture>[])
            .where((fixture) => fixture.isOpen(now))
            .map(
              (fixture) => fixture.locksAt.isBefore(fixture.kickoffAt)
                  ? fixture.locksAt
                  : fixture.kickoffAt,
            )
            .toList()
          ..sort();
    final next = boundaries.firstOrNull;
    if (next == _nextBoundary) return;
    _nextBoundary = next;
    _clock?.cancel();
    if (next != null) {
      _clock = Timer(
        next.difference(now) + const Duration(milliseconds: 1),
        () {
          if (mounted) setState(() => _nextBoundary = null);
        },
      );
    }
  }

  void _selectSection(int index) {
    final uri = Uri(
      path: '/predict',
      queryParameters: index == 0
          ? null
          : {'section': index == 1 ? 'history' : 'wallet'},
    );
    context.go(uri.toString());
  }

  void _signIn() => context.push('/auth/phone?from=%2Fpredict');

  @override
  Widget build(BuildContext context) {
    final l = context.afriL10n;
    final state = ref.watch(predictControllerProvider);
    final controller = ref.read(predictControllerProvider.notifier);
    final data = state.dashboard;
    final uri = GoRouterState.of(context).uri;
    _section = switch (uri.queryParameters['section']) {
      'history' || 'my' => 1,
      'wallet' || 'activity' => 2,
      _ => 0,
    };
    _scheduleBoundary(data);
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
                    f.isOpen(DateTime.now()) &&
                    (selectedCompetition == null ||
                        f.competitionId == selectedCompetition),
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
              Center(
                child: Text(
                  l.predictTitle,
                  style: TypographyTokens.displaySmall(ColorTokens.onSurface),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: SpacingTokens.spacing2),
              Center(
                child: Text(
                  l.predictIntro,
                  textAlign: TextAlign.center,
                  style: TypographyTokens.bodyMedium(
                    ColorTokens.overviewSecondaryText,
                  ),
                ),
              ),
              if (data?.balanceFet case final balance?) ...[
                const SizedBox(height: SpacingTokens.spacing4),
                Center(
                  child: Semantics(
                    label: '$balance FET',
                    child: Text(
                      '$balance FET',
                      style: TypographyTokens.headlineLarge(
                        ColorTokens.onSurface,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: SpacingTokens.spacing6),
              Wrap(
                spacing: SpacingTokens.spacing2,
                runSpacing: SpacingTokens.spacing2,
                children: [
                  for (final (index, label) in [
                    l.predictFixtures,
                    l.predictHistory,
                    l.predictWallet,
                  ].indexed)
                    AfriChoiceChip(
                      visualDensity: largeText ? VisualDensity.standard : null,
                      padding: largeText
                          ? const EdgeInsets.all(SpacingTokens.spacing2)
                          : null,
                      label: Text(label),
                      selected: _section == index,
                      onSelected: (_) => _selectSection(index),
                    ),
                ],
              ),
              const SizedBox(height: SpacingTokens.spacing6),
              if (!online) ...[
                _notice(l.predictOffline),
                const SizedBox(height: SpacingTokens.spacing4),
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
                const SizedBox(height: SpacingTokens.spacing3),
                AfriButton(
                  label: failure == PredictFailure.signIn
                      ? l.predictSignIn
                      : l.predictRefresh,
                  enabled: online && !state.loading,
                  onTap: failure == PredictFailure.signIn
                      ? _signIn
                      : controller.refresh,
                ),
                const SizedBox(height: SpacingTokens.spacing6),
              ],
              if (state.loading) ...[
                const AfriLinearProgressIndicator(),
                const SizedBox(height: SpacingTokens.spacing3),
                Text(
                  l.predictLoading,
                  style: TypographyTokens.bodyMedium(
                    ColorTokens.overviewSecondaryText,
                  ),
                ),
                const SizedBox(height: SpacingTokens.spacing6),
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
                      AfriListTile(
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
                    AfriDropdownField<String>(
                      initialValue: selectedCompetition ?? '',
                      label: l.predictFixtures,
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
                    const SizedBox(height: SpacingTokens.spacing4),
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
                          onPick: (selection) async {
                            if (data.memberSession) {
                              if (_reviewOpen) return;
                              _reviewOpen = true;
                              try {
                                final confirmed = await showPredictReview(
                                  context,
                                  fixture: fixture,
                                  selection: selection,
                                  balanceFet: data.balanceFet,
                                );
                                if (confirmed == true && mounted) {
                                  await controller.place(fixture, selection);
                                } else {
                                  unawaited(
                                    FirebaseAnalyticsService.logTaskAbandonment(
                                      task: 'predict',
                                      stage: 'review',
                                    ),
                                  );
                                }
                              } finally {
                                _reviewOpen = false;
                              }
                            } else {
                              _signIn();
                            }
                          },
                        ),
                      ),
                ],
                const SizedBox(height: SpacingTokens.spacing6),
                AfriListRow(
                  icon: AfriIcons.statusInfo,
                  title: l.predictEarnUse,
                  onTap: () => showAfriBottomSheet<void>(
                    context: context,
                    builder: (context) => Padding(
                      padding: const EdgeInsets.all(
                        SpacingTokens.screenPadding,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.predictEarnUse,
                            style: TypographyTokens.headlineSmall(),
                          ),
                          const SizedBox(height: SpacingTokens.sectionGap),
                          Text(
                            l.predictEarnUseBody,
                            style: TypographyTokens.bodyLarge(),
                          ),
                          const SizedBox(height: SpacingTokens.sectionGap),
                          Text(
                            l.predictNoRedemptions,
                            style: TypographyTokens.bodyMedium(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Text(
                  l.predictRules,
                  style: TypographyTokens.bodySmall(
                    ColorTokens.overviewSecondaryText,
                  ),
                ),
              ],
              SizedBox(
                height: widget.embedded
                    ? AfriClubBottomNav.contentBottomInset(context)
                    : SpacingTokens.spacing8,
              ),
            ],
          ),
        );
      },
    );
    return AfriScreenScaffold(
      padding: EdgeInsets.zero,
      showBackButton: false,
      showAppBar: false,
      scrollable: false,
      bottomNavigationAware: false,
      bodyWrapper: (child) =>
          GradientBackground(routePath: '/predict', child: child),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                SpacingTokens.spacing4,
                SpacingTokens.spacing2,
                SpacingTokens.spacing4,
                SpacingTokens.spacing2,
              ),
              child: AfriTopCommandBar(
                searchHint: largeText ? '' : l.homeSearchHint,
                searchSemanticsLabel: l.homeSearchHint,
                onSearchTap: () => context.push('/search'),
                onAvatarTap: () => context.go('/settings'),
                actions: [
                  AfriTopCommandAction(
                    icon: AfriIcons.refresh,
                    label: l.predictRefresh,
                    onTap:
                        state.loading ||
                            state.pendingFixture != null ||
                            !ConnectivityService.isOnline
                        ? null
                        : () => unawaited(controller.refresh()),
                  ),
                  AfriTopCommandAction(
                    icon: AfriIcons.wallet,
                    label: l.predictWallet,
                    onTap: () => _selectSection(2),
                  ),
                ],
              ),
            ),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }

  Widget _notice(String text) => Semantics(
    liveRegion: true,
    child: Text(
      text,
      style: TypographyTokens.bodyMedium(ColorTokens.overviewSecondaryText),
    ),
  );
}
