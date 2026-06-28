import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/fet_models.dart';
import '../models/prediction_models.dart';

// ══════════════════════════════════════════════════════════════════════════════
// Hero Stats
// ══════════════════════════════════════════════════════════════════════════════

/// Top-of-hub metrics — live count, FET balance, win rate, streak.
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
              label: 'WIN RATE',
              value: '${dashboard?.winRate.toStringAsFixed(0) ?? '0'}%',
              icon: AfriIcons.predict,
            ),
            AfriStat(
              label: 'BALANCE',
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

/// Horizontal chips linking to top-level fanzone routes (capped at 6 + More).
class HubQuickRoutes extends StatelessWidget {
  const HubQuickRoutes({super.key, required this.onMore});

  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final items = <({String label, IconData icon, String route})>[
      (label: 'Fixtures', icon: AfriIcons.fixture, route: '/fanzone/fixtures'),
      (label: 'My Picks', icon: AfriIcons.myPicks, route: '/fanzone/my'),
      (
        label: 'Leaderboard',
        icon: AfriIcons.leaderboard,
        route: '/fanzone/leaderboard',
      ),
      (label: 'Wallet', icon: AfriIcons.wallet, route: '/fanzone/wallet'),
      (label: 'Jackpot', icon: AfriIcons.rank, route: '/fanzone/jackpot'),
      (label: 'Offers', icon: AfriIcons.offers, route: '/fanzone/offers'),
    ];

    return Wrap(
      spacing: SpacingTokens.listItemGap,
      runSpacing: SpacingTokens.listItemGap,
      children: [
        ...items.map(
          (item) => SizedBox(
            width:
                (MediaQuery.of(context).size.width -
                    (SpacingTokens.screenPadding * 2) -
                    (SpacingTokens.listItemGap * 2)) /
                3,
            child: AfriActionRow(
              icon: item.icon,
              label: item.label,
              onTap: () => context.push(item.route),
            ),
          ),
        ),
        SizedBox(
          width:
              (MediaQuery.of(context).size.width -
                  (SpacingTokens.screenPadding * 2) -
                  (SpacingTokens.listItemGap * 2)) /
              3,
          child: AfriActionRow(
            icon: AfriIcons.more,
            label: 'More',
            onTap: onMore,
            accentColor: ColorTokens.onSurfaceVariant,
          ),
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
                label: isLive ? 'LIVE' : 'PREDICT',
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

/// Single leaderboard entry row (rank, name, stats, FET earned).
class HubLeaderboardRow extends StatelessWidget {
  const HubLeaderboardRow({super.key, required this.entry});

  final PredictionLeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 34,
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
                '${entry.winRate.toStringAsFixed(0)}% · ${entry.totalSettled} settled',
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

// ══════════════════════════════════════════════════════════════════════════════
// Challenge Row
// ══════════════════════════════════════════════════════════════════════════════

/// Single challenge entry row showing name, description, and FET value.
class HubChallengeRow extends StatelessWidget {
  const HubChallengeRow({super.key, required this.item});

  final FetCatalogItem item;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: ColorTokens.clubAccent.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Icon(AfriIcons.earn, size: 18, color: ColorTokens.clubAccent),
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
