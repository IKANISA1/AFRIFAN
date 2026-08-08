import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';

import '../models/fet_models.dart';
import '../models/prediction_models.dart';

/// Formats a number with comma separators (e.g. 1,234).
String formatLeaderboardNumber(int value) {
  if (value < 1000) return value.toString();
  final s = value.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

// ═════════════════════════════════════════════════════════════════════════════
// SHARED
// ═════════════════════════════════════════════════════════════════════════════

/// Period filter chip (ALL TIME / WEEKLY / MONTHLY).
class LeaderboardPeriodChip extends StatelessWidget {
  const LeaderboardPeriodChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AfriPressFeedback(
      onTap: onTap,
      tooltip: label,
      semanticsLabel: label,
      semanticsHint: selected
          ? context.afriL10n.gameSelectedLeaderboardPeriod
          : context.afriL10n.gameSelectPeriod,
      selected: selected,
      scaleEnd: 0.98,
      child: AnimatedContainer(
        duration: AfriMotion.standard,
        constraints: const BoxConstraints(
          minHeight: SpacingTokens.spacing10 + SpacingTokens.spacing1,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: SpacingTokens.spacing3,
          vertical: SpacingTokens.spacing3 / 2,
        ),
        decoration: BoxDecoration(
          color: selected
              ? ColorTokens.clubAccent.withValues(alpha: 0.15)
              : ColorTokens.surfaceContainerLow,
          borderRadius: BorderRadius.circular(ShapeTokens.radiusLg),
          border: selected
              ? BorderTokens.all(
                  color: ColorTokens.clubAccent.withValues(alpha: 0.4),
                )
              : BorderTokens.ghost(),
        ),
        child: Text(
          label,
          style:
              TypographyTokens.labelSmall(
                selected
                    ? ColorTokens.clubAccent
                    : ColorTokens.onSurfaceVariant,
              ).copyWith(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: 0.8,
              ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// FET-SPECIFIC WIDGETS
// ═════════════════════════════════════════════════════════════════════════════

/// Podium card for FET ranking (top 3).
class FetPodiumCard extends StatelessWidget {
  const FetPodiumCard({super.key, required this.entry, this.featured = false});

  final PredictionLeaderboardEntry? entry;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    final rank = entry?.rank;

    return GlassCard(
      animate: false,
      child: Column(
        children: [
          _RankBadge(rank: rank),
          const SizedBox(height: SpacingTokens.spacing2),
          Text(
            entry == null
                ? '--'
                : context.afriL10n.gameRankLabel(
                    entry!.rank.toString().padLeft(2, '0'),
                  ),
            style:
                (featured
                        ? TypographyTokens.headlineLarge(ColorTokens.clubAccent)
                        : TypographyTokens.headlineMedium(
                            ColorTokens.onSurfaceVariant,
                          ))
                    .copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: SpacingTokens.spacing2),
          Text(
            entry?.displayName ?? context.afriL10n.gameRankPending,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TypographyTokens.bodyMedium(),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: SpacingTokens.spacing2),
          Text(
            entry == null
                ? context.afriL10n.gamePointBalance(0)
                : context.afriL10n.gamePoints(entry!.totalFetEarned),
            style:
                (featured
                        ? TypographyTokens.headlineSmall(ColorTokens.clubAccent)
                        : TypographyTokens.titleLarge(ColorTokens.clubAccent))
                    .copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

/// Pinned "YOU" row for points ranking.
class FetUserRow extends StatelessWidget {
  const FetUserRow({super.key, required this.entry});

  final PredictionLeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(SpacingTokens.spacing3),
      decoration: BoxDecoration(
        color: ColorTokens.clubAccent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(ShapeTokens.radiusLg),
        border: BorderTokens.all(
          color: ColorTokens.clubAccent.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: SpacingTokens.spacing10 + SpacingTokens.spacing1,
            child: Text(
              context.afriL10n.gameRankLabel(
                entry.rank.toString().padLeft(2, '0'),
              ),
              style: TypographyTokens.headlineSmall(
                ColorTokens.clubAccent,
              ).copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: SpacingTokens.spacing3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      entry.displayName,
                      style: TypographyTokens.titleSmall(),
                    ),
                    const SizedBox(width: SpacingTokens.spacing2),
                    _LeaderboardBadge(
                      label: context.afriL10n.gameYouUpper,
                      selected: true,
                    ),
                  ],
                ),
                const SizedBox(height: SpacingTokens.spacing1 / 2),
                Text(
                  context.afriL10n.gameAccuracyWins(
                    entry.winRate.toStringAsFixed(1),
                    entry.wins,
                  ),
                  style: TypographyTokens.bodySmall(),
                ),
              ],
            ),
          ),
          Text(
            context.afriL10n.gamePoints(entry.totalFetEarned),
            style: TypographyTokens.titleLarge(
              ColorTokens.clubAccent,
            ).copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

/// Standard list row for points ranking.
class FetListRow extends StatelessWidget {
  const FetListRow({super.key, required this.entry, required this.isMe});

  final PredictionLeaderboardEntry entry;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(SpacingTokens.spacing3),
      decoration: BoxDecoration(
        color: isMe
            ? ColorTokens.clubAccent.withValues(alpha: 0.10)
            : ColorTokens.surfaceContainerLow,
        borderRadius: BorderRadius.circular(ShapeTokens.radiusLg),
        border: isMe
            ? BorderTokens.all(
                color: ColorTokens.clubAccent.withValues(alpha: 0.3),
              )
            : BorderTokens.ghost(),
      ),
      child: Row(
        children: [
          SizedBox(
            width: SpacingTokens.spacing10 + SpacingTokens.spacing1,
            child: Text(
              context.afriL10n.gameRankLabel(
                entry.rank.toString().padLeft(2, '0'),
              ),
              style: TypographyTokens.headlineSmall(
                entry.rank <= 3
                    ? ColorTokens.clubAccent
                    : ColorTokens.onSurface,
              ).copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: SpacingTokens.spacing3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.displayName,
                        style: TypographyTokens.titleSmall(),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: SpacingTokens.spacing2),
                      _LeaderboardBadge(
                        label: context.afriL10n.gameYouUpper,
                        selected: true,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: SpacingTokens.spacing1 / 2),
                Text(
                  context.afriL10n.gameAccuracyWins(
                    entry.winRate.toStringAsFixed(1),
                    entry.wins,
                  ),
                  style: TypographyTokens.bodySmall(),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                context.afriL10n.gamePoints(entry.totalFetEarned),
                style: TypographyTokens.titleLarge(
                  ColorTokens.clubAccent,
                ).copyWith(fontWeight: FontWeight.w800),
              ),
              Text(
                context.afriL10n.gameSettledCount(entry.totalSettled),
                style: TypographyTokens.bodySmall(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SUPPORTER-SPECIFIC WIDGETS
// ═════════════════════════════════════════════════════════════════════════════

/// Podium card for supporter ranking (top 3).
class SupporterPodiumCard extends StatelessWidget {
  const SupporterPodiumCard({
    super.key,
    required this.entry,
    this.featured = false,
  });

  final FetLeaderboardRow? entry;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    final rank = entry?.rank;

    return GlassCard(
      animate: false,
      child: Column(
        children: [
          _RankBadge(rank: rank),
          const SizedBox(height: SpacingTokens.spacing2),
          Text(
            entry == null
                ? '--'
                : context.afriL10n.gameRankLabel(
                    entry!.rank.toString().padLeft(2, '0'),
                  ),
            style:
                (featured
                        ? TypographyTokens.headlineLarge(ColorTokens.clubAccent)
                        : TypographyTokens.headlineMedium(
                            ColorTokens.onSurfaceVariant,
                          ))
                    .copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: SpacingTokens.spacing2),
          Text(
            entry?.displayName ?? context.afriL10n.gameRankPending,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TypographyTokens.bodyMedium(),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: SpacingTokens.spacing2),
          Text(
            entry == null
                ? context.afriL10n.gamePointBalance(0)
                : context.afriL10n.gameFormattedPoints(
                    formatLeaderboardNumber(entry!.totalFet),
                  ),
            style:
                (featured
                        ? TypographyTokens.headlineSmall(ColorTokens.clubAccent)
                        : TypographyTokens.titleLarge(ColorTokens.clubAccent))
                    .copyWith(fontWeight: FontWeight.w800),
          ),
          if (entry != null) ...[
            const SizedBox(height: SpacingTokens.spacing1),
            _LeaderboardBadge(label: entry!.tier.toUpperCase()),
          ],
        ],
      ),
    );
  }
}

/// Pinned "YOU" row for supporter ranking.
class SupporterUserRow extends StatelessWidget {
  const SupporterUserRow({super.key, required this.entry});

  final FetLeaderboardRow entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(SpacingTokens.spacing3),
      decoration: BoxDecoration(
        color: ColorTokens.clubAccent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(ShapeTokens.radiusLg),
        border: BorderTokens.all(
          color: ColorTokens.clubAccent.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: SpacingTokens.spacing10 + SpacingTokens.spacing1,
            child: Text(
              context.afriL10n.gameRankLabel(
                entry.rank.toString().padLeft(2, '0'),
              ),
              style: TypographyTokens.headlineSmall(
                ColorTokens.clubAccent,
              ).copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: SpacingTokens.spacing3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      entry.displayName,
                      style: TypographyTokens.titleSmall(),
                    ),
                    const SizedBox(width: SpacingTokens.spacing2),
                    _LeaderboardBadge(
                      label: context.afriL10n.gameYouUpper,
                      selected: true,
                    ),
                  ],
                ),
                const SizedBox(height: SpacingTokens.spacing1 / 2),
                Text(
                  context.afriL10n.gameTierAlias(
                    entry.tier.toUpperCase(),
                    entry.supporterAlias,
                  ),
                  style: TypographyTokens.bodySmall(),
                ),
              ],
            ),
          ),
          Text(
            context.afriL10n.gameFormattedPoints(
              formatLeaderboardNumber(entry.totalFet),
            ),
            style: TypographyTokens.titleLarge(
              ColorTokens.clubAccent,
            ).copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

/// Standard list row for supporter ranking.
class SupporterListRow extends StatelessWidget {
  const SupporterListRow({super.key, required this.entry, required this.isMe});

  final FetLeaderboardRow entry;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(SpacingTokens.spacing3),
      decoration: BoxDecoration(
        color: isMe
            ? ColorTokens.clubAccent.withValues(alpha: 0.10)
            : ColorTokens.surfaceContainerLow,
        borderRadius: BorderRadius.circular(ShapeTokens.radiusLg),
        border: isMe
            ? BorderTokens.all(
                color: ColorTokens.clubAccent.withValues(alpha: 0.3),
              )
            : BorderTokens.ghost(),
      ),
      child: Row(
        children: [
          SizedBox(
            width: SpacingTokens.spacing10 + SpacingTokens.spacing1,
            child: Text(
              context.afriL10n.gameRankLabel(
                entry.rank.toString().padLeft(2, '0'),
              ),
              style: TypographyTokens.headlineSmall(
                entry.rank <= 3
                    ? ColorTokens.clubAccent
                    : ColorTokens.onSurface,
              ).copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: SpacingTokens.spacing3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.displayName,
                        style: TypographyTokens.titleSmall(),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: SpacingTokens.spacing2),
                      _LeaderboardBadge(
                        label: context.afriL10n.gameYouUpper,
                        selected: true,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: SpacingTokens.spacing1 / 2),
                Text(
                  context.afriL10n.gameTierAlias(
                    entry.tier.toUpperCase(),
                    entry.supporterAlias,
                  ),
                  style: TypographyTokens.bodySmall(),
                ),
              ],
            ),
          ),
          Text(
            context.afriL10n.gameFormattedPoints(
              formatLeaderboardNumber(entry.totalFet),
            ),
            style: TypographyTokens.titleLarge(
              ColorTokens.clubAccent,
            ).copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank});

  final int? rank;

  @override
  Widget build(BuildContext context) {
    if (rank == null || rank! > 3) {
      return const SizedBox(height: SpacingTokens.spacing7);
    }

    return Semantics(
      label: context.afriL10n.gamePodiumRank(rank!),
      image: true,
      child: Icon(
        AfriIcons.rank,
        size: SpacingTokens.spacing7,
        color: rank == 1
            ? ColorTokens.clubAccent
            : ColorTokens.onSurfaceVariant,
      ),
    );
  }
}

class _LeaderboardBadge extends StatelessWidget {
  const _LeaderboardBadge({required this.label, this.selected = false});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.spacing3 / 2,
        vertical: SpacingTokens.spacing1 / 2,
      ),
      decoration: BoxDecoration(
        color: selected
            ? ColorTokens.clubAccent
            : ColorTokens.surfaceContainerLow,
        borderRadius: BorderRadius.circular(ShapeTokens.radiusSm),
      ),
      child: Text(
        label,
        style:
            TypographyTokens.labelSmall(
              selected ? ColorTokens.background : ColorTokens.onSurfaceVariant,
            ).copyWith(
              fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
              letterSpacing: selected ? 1.2 : 1.0,
            ),
      ),
    );
  }
}
