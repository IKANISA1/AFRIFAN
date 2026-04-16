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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? ColorTokens.clubAccent.withValues(alpha: 0.15)
              : ColorTokens.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          border: selected
              ? BorderTokens.all(
                  color: ColorTokens.clubAccent.withValues(alpha: 0.4),
                )
              : BorderTokens.ghost(),
        ),
        child: Text(
          label,
          style: TypographyTokens.editorialFont(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected
                ? ColorTokens.clubAccent
                : ColorTokens.onSurfaceVariant,
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
  const FetPodiumCard({
    super.key,
    required this.entry,
    this.featured = false,
  });

  final PredictionLeaderboardEntry? entry;
  final bool featured;

  String get _medal {
    if (entry == null) return '';
    return switch (entry!.rank) {
      1 => '🥇',
      2 => '🥈',
      3 => '🥉',
      _ => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      animate: false,
      child: Column(
        children: [
          if (_medal.isNotEmpty)
            Text(_medal, style: const TextStyle(fontSize: 28)),
          if (_medal.isEmpty) const SizedBox(height: 28),
          const SizedBox(height: SpacingTokens.spacing2),
          Text(
            entry == null
                ? '--'
                : '#${entry!.rank.toString().padLeft(2, '0')}',
            style: TypographyTokens.monolithFont(
              fontSize: featured ? 28 : 22,
              fontWeight: FontWeight.w800,
              color: featured
                  ? ColorTokens.clubAccent
                  : ColorTokens.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing2),
          Text(
            entry?.displayName ?? 'No rank',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TypographyTokens.bodyMedium(),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: SpacingTokens.spacing2),
          Text(
            entry == null ? '0 FET' : '+${entry!.totalFetEarned} FET',
            style: TypographyTokens.monolithFont(
              fontSize: featured ? 22 : 18,
              fontWeight: FontWeight.w800,
              color: ColorTokens.clubAccent,
            ),
          ),
        ],
      ),
    );
  }
}

/// Pinned "YOU" row for FET ranking.
class FetUserRow extends StatelessWidget {
  const FetUserRow({super.key, required this.entry});

  final PredictionLeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(SpacingTokens.spacing3),
      decoration: BoxDecoration(
        color: ColorTokens.clubAccent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: BorderTokens.all(
          color: ColorTokens.clubAccent.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(
              '#${entry.rank.toString().padLeft(2, '0')}',
              style: TypographyTokens.monolithFont(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: ColorTokens.clubAccent,
              ),
            ),
          ),
          const SizedBox(width: SpacingTokens.spacing3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(entry.displayName,
                        style: TypographyTokens.titleSmall()),
                    const SizedBox(width: SpacingTokens.spacing2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: ColorTokens.clubAccent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'YOU',
                        style: TypographyTokens.editorialFont(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: ColorTokens.background,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${entry.winRate.toStringAsFixed(1)}% accuracy · ${entry.wins} wins',
                  style: TypographyTokens.bodySmall(),
                ),
              ],
            ),
          ),
          Text(
            '+${entry.totalFetEarned} FET',
            style: TypographyTokens.monolithFont(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: ColorTokens.clubAccent,
            ),
          ),
        ],
      ),
    );
  }
}

/// Standard list row for FET ranking.
class FetListRow extends StatelessWidget {
  const FetListRow({
    super.key,
    required this.entry,
    required this.isMe,
  });

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
        borderRadius: BorderRadius.circular(16),
        border: isMe
            ? BorderTokens.all(
                color: ColorTokens.clubAccent.withValues(alpha: 0.3),
              )
            : BorderTokens.ghost(),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(
              '#${entry.rank.toString().padLeft(2, '0')}',
              style: TypographyTokens.monolithFont(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color:
                    entry.rank <= 3 ? ColorTokens.clubAccent : ColorTokens.onSurface,
              ),
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
                      child: Text(entry.displayName,
                          style: TypographyTokens.titleSmall(),
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: SpacingTokens.spacing2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: ColorTokens.clubAccent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'YOU',
                          style: TypographyTokens.editorialFont(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: ColorTokens.background,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${entry.winRate.toStringAsFixed(1)}% accuracy · ${entry.wins} wins',
                  style: TypographyTokens.bodySmall(),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '+${entry.totalFetEarned} FET',
                style: TypographyTokens.monolithFont(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: ColorTokens.clubAccent,
                ),
              ),
              Text(
                '${entry.totalSettled} settled',
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

  String get _medal {
    if (entry == null) return '';
    return switch (entry!.rank) {
      1 => '🥇',
      2 => '🥈',
      3 => '🥉',
      _ => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      animate: false,
      child: Column(
        children: [
          if (_medal.isNotEmpty)
            Text(_medal, style: const TextStyle(fontSize: 28)),
          if (_medal.isEmpty) const SizedBox(height: 28),
          const SizedBox(height: SpacingTokens.spacing2),
          Text(
            entry == null
                ? '--'
                : '#${entry!.rank.toString().padLeft(2, '0')}',
            style: TypographyTokens.monolithFont(
              fontSize: featured ? 28 : 22,
              fontWeight: FontWeight.w800,
              color: featured
                  ? ColorTokens.clubAccent
                  : ColorTokens.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing2),
          Text(
            entry?.displayName ?? 'No rank',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TypographyTokens.bodyMedium(),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: SpacingTokens.spacing2),
          Text(
            entry == null
                ? '0 FET'
                : '${formatLeaderboardNumber(entry!.totalFet)} FET',
            style: TypographyTokens.monolithFont(
              fontSize: featured ? 22 : 18,
              fontWeight: FontWeight.w800,
              color: ColorTokens.clubAccent,
            ),
          ),
          if (entry != null) ...[
            const SizedBox(height: SpacingTokens.spacing1),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: ColorTokens.surfaceContainerLow,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                entry!.tier.toUpperCase(),
                style: TypographyTokens.editorialFont(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: ColorTokens.onSurfaceVariant,
                  letterSpacing: 1.0,
                ),
              ),
            ),
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
        borderRadius: BorderRadius.circular(16),
        border: BorderTokens.all(
          color: ColorTokens.clubAccent.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(
              '#${entry.rank.toString().padLeft(2, '0')}',
              style: TypographyTokens.monolithFont(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: ColorTokens.clubAccent,
              ),
            ),
          ),
          const SizedBox(width: SpacingTokens.spacing3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(entry.displayName,
                        style: TypographyTokens.titleSmall()),
                    const SizedBox(width: SpacingTokens.spacing2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: ColorTokens.clubAccent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'YOU',
                        style: TypographyTokens.editorialFont(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: ColorTokens.background,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${entry.tier.toUpperCase()} tier · ${entry.supporterAlias}',
                  style: TypographyTokens.bodySmall(),
                ),
              ],
            ),
          ),
          Text(
            '${formatLeaderboardNumber(entry.totalFet)} FET',
            style: TypographyTokens.monolithFont(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: ColorTokens.clubAccent,
            ),
          ),
        ],
      ),
    );
  }
}

/// Standard list row for supporter ranking.
class SupporterListRow extends StatelessWidget {
  const SupporterListRow({
    super.key,
    required this.entry,
    required this.isMe,
  });

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
        borderRadius: BorderRadius.circular(16),
        border: isMe
            ? BorderTokens.all(
                color: ColorTokens.clubAccent.withValues(alpha: 0.3),
              )
            : BorderTokens.ghost(),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(
              '#${entry.rank.toString().padLeft(2, '0')}',
              style: TypographyTokens.monolithFont(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color:
                    entry.rank <= 3 ? ColorTokens.clubAccent : ColorTokens.onSurface,
              ),
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
                      child: Text(entry.displayName,
                          style: TypographyTokens.titleSmall(),
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: SpacingTokens.spacing2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: ColorTokens.clubAccent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'YOU',
                          style: TypographyTokens.editorialFont(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: ColorTokens.background,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${entry.tier.toUpperCase()} tier · ${entry.supporterAlias}',
                  style: TypographyTokens.bodySmall(),
                ),
              ],
            ),
          ),
          Text(
            '${formatLeaderboardNumber(entry.totalFet)} FET',
            style: TypographyTokens.monolithFont(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: ColorTokens.clubAccent,
            ),
          ),
        ],
      ),
    );
  }
}
