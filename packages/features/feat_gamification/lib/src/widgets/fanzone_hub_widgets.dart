import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/fet_models.dart';
import '../models/partner_pool_models.dart';
import '../models/prediction_models.dart';

// ══════════════════════════════════════════════════════════════════════════════
// Hero Stats
// ══════════════════════════════════════════════════════════════════════════════

/// Top-of-hub metrics — live count, points balance, accuracy, streak.
class HubHeroStats extends StatelessWidget {
  const HubHeroStats({
    super.key,
    required this.dashboard,
    required this.wallet,
  });

  final PredictionDashboard? dashboard;
  final FetWalletSummary? wallet;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Stat row ──
        AfriStatRow(
          stats: [
            AfriStat(
              label: 'ACTIVE',
              value: '${dashboard?.activeCount ?? 0}',
              icon: AfriIcons.live,
              accentColor: ColorTokens.success,
            ),
            AfriStat(
              label: 'ACCURACY',
              value: '${dashboard?.winRate.toStringAsFixed(0) ?? '0'}%',
              icon: AfriIcons.predict,
            ),
            AfriStat(
              label: 'POINTS',
              value: '${wallet?.balance ?? 0}',
              icon: AfriIcons.earn,
              accentColor: ColorTokens.clubAccent,
            ),
          ],
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Quick Routes
// ══════════════════════════════════════════════════════════════════════════════

/// Ranked links to compact Fan Zone surfaces.
///
/// The first row keeps the top three actions prominent. Secondary routes move
/// into compact chips so the hub no longer presents every destination at the
/// same weight.
class HubQuickRoutes extends StatelessWidget {
  const HubQuickRoutes({super.key, required this.onMore});

  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final primaryItems = <({String label, IconData icon, String route})>[
      (label: 'TV Code', icon: AfriIcons.live, route: '/fanzone/game'),
      (
        label: 'Fans',
        icon: AfriIcons.profile,
        route: '/fanzone?section=supporters',
      ),
      (
        label: 'League',
        icon: AfriIcons.league,
        route: '/fanzone?section=league',
      ),
    ];
    final secondaryItems = <({String label, IconData icon, String route})>[
      (
        label: 'Wallet',
        icon: AfriIcons.wallet,
        route: '/fanzone?section=wallet',
      ),
    ];
    final primaryWidth =
        (MediaQuery.of(context).size.width -
            (SpacingTokens.screenPadding * 2) -
            (SpacingTokens.listItemGap * 2)) /
        3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: SpacingTokens.listItemGap,
          runSpacing: SpacingTokens.listItemGap,
          children: [
            ...primaryItems.map(
              (item) => SizedBox(
                width: primaryWidth,
                child: AfriActionRow(
                  icon: item.icon,
                  label: item.label,
                  onTap: () => context.push(item.route),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: SpacingTokens.spacing3),
        Wrap(
          spacing: SpacingTokens.spacing2,
          runSpacing: SpacingTokens.spacing2,
          children: [
            ...secondaryItems.map(
              (item) => AfriInfoChip(
                label: item.label,
                icon: item.icon,
                color: ColorTokens.onSurfaceVariant,
                onTap: () => context.push(item.route),
              ),
            ),
            AfriInfoChip(
              label: 'More',
              icon: AfriIcons.more,
              color: ColorTokens.onSurfaceVariant,
              onTap: onMore,
            ),
          ],
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Hub Fixture Row
// ══════════════════════════════════════════════════════════════════════════════

/// Compact fixture row used in the Today / This Week / Live sections.
class HubFixtureRow extends StatelessWidget {
  const HubFixtureRow({
    super.key,
    required this.fixture,
    required this.onTap,
    this.isLive = false,
    this.showDate = false,
  });

  final FixtureSummary fixture;
  final VoidCallback onTap;
  final bool isLive;
  final bool showDate;

  String _kickoffTime() {
    final kickoff = fixture.kickoffAt;
    if (kickoff == null) return 'TBD';
    final local = kickoff.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  String _dateLabel() {
    final kickoff = fixture.kickoffAt;
    if (kickoff == null) return '';
    final local = kickoff.toLocal();
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${dayNames[local.weekday - 1]} ${local.day}/${local.month}';
  }

  @override
  Widget build(BuildContext context) {
    return AfriPressFeedback(
      onTap: onTap,
      tooltip: fixture.fixtureLabel,
      semanticsLabel: fixture.fixtureLabel,
      excludeChildSemantics: true,
      builder: (context, state) => GlassCard(
        animate: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fixture.fixtureLabel,
                    style: TypographyTokens.titleSmall(),
                  ),
                  const SizedBox(height: SpacingTokens.spacing1),
                  Text(
                    showDate
                        ? '${fixture.competitionName}  ·  ${_dateLabel()} ${_kickoffTime()}'
                        : '${fixture.competitionName}  ·  ${_kickoffTime()}',
                    style: TypographyTokens.bodySmall(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (fixture.homeScore != null && fixture.awayScore != null)
              Text(
                '${fixture.homeScore} - ${fixture.awayScore}',
                style: TypographyTokens.titleLarge().copyWith(
                  fontWeight: FontWeight.w800,
                ),
              )
            else
              AfriInfoChip(
                label: isLive ? 'LIVE' : 'ROUND',
                color: isLive ? ColorTokens.success : ColorTokens.clubAccent,
              ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Leaderboard Row
// ══════════════════════════════════════════════════════════════════════════════

/// Single leaderboard entry row (rank, name, stats, points earned).
class HubLeaderboardRow extends StatelessWidget {
  const HubLeaderboardRow({super.key, required this.entry});

  final PredictionLeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: SpacingTokens.spacing8 + SpacingTokens.spacing1 / 2,
          child: Text(
            '#${entry.rank}',
            style: TypographyTokens.titleLarge(
              entry.rank == 1 ? ColorTokens.clubAccent : ColorTokens.onSurface,
            ).copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(width: SpacingTokens.inlineGap),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(entry.displayName, style: TypographyTokens.titleSmall()),
              Text(
                '${entry.winRate.toStringAsFixed(0)}% · ${entry.totalSettled} rounds',
                style: TypographyTokens.bodySmall(),
              ),
            ],
          ),
        ),
        Text(
          '+${entry.totalFetEarned}',
          style: TypographyTokens.titleLarge(
            ColorTokens.clubAccent,
          ).copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class HubPartnerPoolRow extends StatelessWidget {
  const HubPartnerPoolRow({super.key, required this.pool, this.onJoin});

  final PartnerPredictionPool pool;
  final VoidCallback? onJoin;

  @override
  Widget build(BuildContext context) {
    final viewerEntry = pool.viewerEntry;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: SpacingTokens.spacing9,
              height: SpacingTokens.spacing9,
              decoration: BoxDecoration(
                color: ColorTokens.clubAccent.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(ShapeTokens.radiusMd),
              ),
              alignment: Alignment.center,
              child: Icon(
                AfriIcons.predict,
                size: SpacingTokens.spacing5,
                color: ColorTokens.clubAccent,
              ),
            ),
            const SizedBox(width: SpacingTokens.listItemGap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(pool.title, style: TypographyTokens.titleSmall()),
                  const SizedBox(height: SpacingTokens.spacing1),
                  Text(
                    '${pool.partnerName} · ${pool.eligibilityLabel}',
                    style: TypographyTokens.bodySmall(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${pool.partnerStakeFet}',
                  style: TypographyTokens.titleMedium(
                    ColorTokens.clubAccent,
                  ).copyWith(fontWeight: FontWeight.w800),
                ),
                Text('points round', style: TypographyTokens.labelSmall()),
              ],
            ),
          ],
        ),
        const SizedBox(height: SpacingTokens.spacing3),
        Wrap(
          spacing: SpacingTokens.spacing2,
          runSpacing: SpacingTokens.spacing2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            AfriInfoChip(
              label: '${pool.fanEntryFet} point entry',
              color: ColorTokens.info,
            ),
            AfriInfoChip(
              label: '${pool.totalEntries} fans',
              color: ColorTokens.onSurfaceVariant,
            ),
            if (viewerEntry != null)
              AfriInfoChip(
                label: viewerEntry.selectedOutcome.label,
                icon: AfriIcons.check,
                color: ColorTokens.success,
              )
            else if (pool.isOpen)
              AfriInfoChip(
                label: 'Choose W/D/W',
                icon: AfriIcons.forward,
                color: ColorTokens.clubAccent,
                onTap: onJoin,
              )
            else
              AfriInfoChip(
                label: pool.status.toUpperCase(),
                color: ColorTokens.onSurfaceVariant,
              ),
          ],
        ),
        if (!pool.hasJoined && pool.isOpen && onJoin != null) ...[
          const SizedBox(height: SpacingTokens.spacing3),
          AfriButton(
            label: 'Join round',
            icon: AfriIcons.predict,
            variant: AfriButtonVariant.secondary,
            onTap: onJoin!,
          ),
        ],
      ],
    );
  }
}

class PartnerPoolOutcomeOption extends StatelessWidget {
  const PartnerPoolOutcomeOption({
    super.key,
    required this.outcome,
    required this.isSelected,
    required this.onTap,
  });

  final PartnerPoolOutcome outcome;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? ColorTokens.clubAccent : ColorTokens.ghostBorder;

    return AfriPressFeedback(
      onTap: onTap,
      tooltip: outcome.label,
      semanticsLabel: outcome.label,
      builder: (context, state) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(SpacingTokens.spacing4),
        decoration: BoxDecoration(
          color: isSelected
              ? ColorTokens.clubAccent.withValues(alpha: 0.14)
              : ColorTokens.surfaceContainerLow,
          border: BorderTokens.all(color: color),
          borderRadius: BorderRadius.circular(ShapeTokens.radiusMd),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? AfriIcons.check : AfriIcons.predict,
              color: isSelected
                  ? ColorTokens.clubAccent
                  : ColorTokens.onSurfaceVariant,
              size: SpacingTokens.spacing5,
            ),
            const SizedBox(width: SpacingTokens.spacing3),
            Expanded(
              child: Text(
                outcome.label,
                style: TypographyTokens.titleSmall(
                  isSelected ? ColorTokens.clubAccent : ColorTokens.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Challenge Row
// ══════════════════════════════════════════════════════════════════════════════

/// Single challenge entry row showing name, description, and point value.
class HubChallengeRow extends StatelessWidget {
  const HubChallengeRow({super.key, required this.item});

  final FetCatalogItem item;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: SpacingTokens.spacing9,
          height: SpacingTokens.spacing9,
          decoration: BoxDecoration(
            color: ColorTokens.clubAccent.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(ShapeTokens.radiusMd),
          ),
          alignment: Alignment.center,
          child: Icon(
            AfriIcons.earn,
            size: SpacingTokens.spacing5,
            color: ColorTokens.clubAccent,
          ),
        ),
        const SizedBox(width: SpacingTokens.listItemGap),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.itemName, style: TypographyTokens.titleSmall()),
              const SizedBox(height: SpacingTokens.spacing1),
              Text(
                item.description.isEmpty
                    ? item.triggerCondition
                    : item.description,
                style: TypographyTokens.bodySmall(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        Text(
          '+${item.fetValue}',
          style: TypographyTokens.titleMedium(
            ColorTokens.clubAccent,
          ).copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}
