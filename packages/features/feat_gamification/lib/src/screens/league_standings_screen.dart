import 'dart:async';

import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/fanzone_models.dart';
import '../prediction_providers.dart';

class LeagueStandingsScreen extends ConsumerStatefulWidget {
  const LeagueStandingsScreen({super.key, required this.competitionSlug});

  final String competitionSlug;

  @override
  ConsumerState<LeagueStandingsScreen> createState() =>
      _LeagueStandingsScreenState();
}

class _LeagueStandingsScreenState extends ConsumerState<LeagueStandingsScreen> {
  CompetitionCatalogItem? _competition;
  List<LeagueStandingEntry> _standings = const <LeagueStandingEntry>[];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final repo = ref.read(predictionRepositoryProvider);
      final results = await Future.wait<Object?>([
        repo.loadCompetition(widget.competitionSlug),
        repo.loadStandings(competitionSlug: widget.competitionSlug, limit: 32),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _competition = results[0] as CompetitionCatalogItem?;
        _standings = results[1]! as List<LeagueStandingEntry>;
        _isLoading = false;
        _error = _competition == null
            ? context.afriL10n.gameCompetitionNotFound
            : null;
      });
    } catch (error, stackTrace) {
      AfriLogger.warn(
        'LeagueStandingsScreen',
        'Operation failed (non-critical).',
        error,
        stackTrace,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _error = context.afriL10n.gameStandingsTemporarilyUnavailable;
      });
    }
  }

  Color _formColor(String token) {
    return switch (token.toUpperCase()) {
      'W' => ColorTokens.success,
      'D' => ColorTokens.warning,
      'L' => ColorTokens.error,
      _ => ColorTokens.onSurfaceVariant,
    };
  }

  @override
  Widget build(BuildContext context) {
    return AfriScreenScaffold(
      backgroundColor: ColorTokens.background,
      appBar: AfriAppBar(
        backgroundColor: ColorTokens.transparent,
        title: Text(
          _competition?.shortName.toUpperCase() ??
              context.afriL10n.gameStandingsTitle,
          style: TypographyTokens.headlineSmall().copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: TypographyTokens.trackingNone,
          ),
        ),
        leading: AfriIconButton(
          icon: AfriIcons.back,
          onTap: () => context.pop(),
          tooltip: context.afriL10n.gameBack,
        ),
      ),
      scrollable: false,
      constrainContent: true,
      child: _isLoading
          ? const Padding(
              padding: EdgeInsets.all(SpacingTokens.spacing6),
              child: AfriSkeletonList(),
            )
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(SpacingTokens.spacing6),
                child: AfriStateView.offline(
                  title: context.afriL10n.gameStandingsUnavailable,
                  message: _error!,
                  actionLabel: context.afriL10n.gameRetry,
                  onAction: _load,
                ),
              ),
            )
          : AfriRefreshIndicator(
              onRefresh: _load,
              color: ColorTokens.primaryContainer,
              child: ListView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: const EdgeInsets.all(SpacingTokens.spacing6),
                children: [
                  AfriSurfaceCard(
                    child: Row(
                      children: [
                        SizedBox(
                          width: SpacingTokens.spacing8,
                          child: Text(context.afriL10n.gamePositionShort),
                        ),
                        Expanded(
                          child: Text(
                            context.afriL10n.gameTeamUpper,
                            style: TypographyTokens.labelMedium(
                              ColorTokens.onSurfaceVariant,
                            ),
                          ),
                        ),
                        SizedBox(
                          width:
                              SpacingTokens.spacing10 +
                              (SpacingTokens.spacing1 / 2),
                          child: Text(
                            context.afriL10n.gamePointsShort,
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: SpacingTokens.spacing3),
                  ..._standings.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(
                        bottom: SpacingTokens.spacing3,
                      ),
                      child: AfriPressFeedback(
                        onTap: () =>
                            context.push('/fanzone/team/${entry.teamSlug}'),
                        builder: (context, _) => GlassCard(
                          animate: false,
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  SizedBox(
                                    width: SpacingTokens.spacing8,
                                    child: Text(
                                      entry.position.toString(),
                                      style: TypographyTokens.titleLarge(
                                        entry.position <= 3
                                            ? ColorTokens.primaryContainer
                                            : ColorTokens.onSurface,
                                      ).copyWith(fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          entry.teamName,
                                          style: TypographyTokens.titleSmall(),
                                        ),
                                        const SizedBox(
                                          height: SpacingTokens.spacing1 / 2,
                                        ),
                                        Text(
                                          context.afriL10n.gameStandingRecord(
                                            entry.played,
                                            entry.goalsFor,
                                            entry.goalsAgainst,
                                            entry.goalDifference,
                                          ),
                                          style: TypographyTokens.bodySmall(),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: SpacingTokens.spacing3),
                                  Text(
                                    entry.points.toString(),
                                    style: TypographyTokens.titleLarge()
                                        .copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                              if (entry.formTokens.isNotEmpty) ...[
                                const SizedBox(height: SpacingTokens.spacing3),
                                Row(
                                  children: entry.formTokens
                                      .take(5)
                                      .map((token) {
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            right: SpacingTokens.spacing1,
                                          ),
                                          child: Container(
                                            width: SpacingTokens.spacing6,
                                            height: SpacingTokens.spacing6,
                                            decoration: BoxDecoration(
                                              color: _formColor(
                                                token,
                                              ).withValues(alpha: 0.18),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    ShapeTokens.radiusFull,
                                                  ),
                                            ),
                                            alignment: Alignment.center,
                                            child: Text(
                                              token,
                                              style:
                                                  TypographyTokens.labelSmall(
                                                    _formColor(token),
                                                  ),
                                            ),
                                          ),
                                        );
                                      })
                                      .toList(growable: false),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }
}
