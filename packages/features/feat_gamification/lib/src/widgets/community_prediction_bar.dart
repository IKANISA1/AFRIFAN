import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/fanzone_models.dart';

class CommunityPredictionBar extends StatelessWidget {
  const CommunityPredictionBar({
    super.key,
    required this.picks,
    this.userSelection,
  });

  final List<CommunityPick> picks;
  final String? userSelection;

  @override
  Widget build(BuildContext context) {
    if (picks.isEmpty) {
      return const SizedBox.shrink();
    }

    final sorted = List<CommunityPick>.from(picks)
      ..sort(
        (left, right) => right.pickPercentage.compareTo(left.pickPercentage),
      );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.afriL10n.gameCommunityPicks,
          style: TypographyTokens.labelSmall(
            ColorTokens.onSurfaceVariant,
          ).copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: SpacingTokens.spacing3),
        ...sorted.asMap().entries.map((entry) {
          final pick = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: SpacingTokens.spacing2),
            child: _CommunityPickRow(
              pick: pick,
              isUserPick:
                  userSelection != null &&
                  pick.selectedOutcome.toLowerCase() ==
                      userSelection!.toLowerCase(),
              index: entry.key,
            ),
          );
        }),
      ],
    );
  }
}

class _CommunityPickRow extends StatelessWidget {
  const _CommunityPickRow({
    required this.pick,
    required this.isUserPick,
    required this.index,
  });

  final CommunityPick pick;
  final bool isUserPick;
  final int index;

  @override
  Widget build(BuildContext context) {
    final barColor = isUserPick
        ? ColorTokens.clubAccent
        : ColorTokens.onSurfaceVariant;
    final fraction = (pick.pickPercentage / 100).clamp(0.0, 1.0);

    return Row(
      children: [
        SizedBox(
          width: SpacingTokens.spacing16 + SpacingTokens.spacing2,
          child: Row(
            children: [
              if (isUserPick)
                Padding(
                  padding: const EdgeInsets.only(right: SpacingTokens.spacing1),
                  child: Icon(
                    AfriIcons.profile,
                    size: SpacingTokens.spacing3,
                    color: ColorTokens.clubAccent,
                  ),
                ),
              Flexible(
                child: Text(
                  pick.selectedOutcome.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      TypographyTokens.labelMedium(
                        isUserPick
                            ? ColorTokens.clubAccent
                            : ColorTokens.onSurfaceVariant,
                      ).copyWith(
                        fontWeight: isUserPick
                            ? FontWeight.w800
                            : FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: SpacingTokens.spacing2),
        Expanded(
          child: Stack(
            children: [
              Container(
                height: SpacingTokens.spacing5,
                decoration: BoxDecoration(
                  color: ColorTokens.surfaceContainerHigh.withValues(
                    alpha: 0.3,
                  ),
                  borderRadius: BorderRadius.circular(ShapeTokens.radiusFull),
                ),
              ),
              FractionallySizedBox(
                    widthFactor: fraction,
                    child: Container(
                      height: SpacingTokens.spacing5,
                      decoration: BoxDecoration(
                        color: barColor.withValues(
                          alpha: isUserPick ? 0.25 : 0.12,
                        ),
                        borderRadius: BorderRadius.circular(
                          ShapeTokens.radiusFull,
                        ),
                        border: isUserPick
                            ? BorderTokens.all(
                                color: ColorTokens.clubAccent.withValues(
                                  alpha: 0.4,
                                ),
                              )
                            : null,
                      ),
                    ),
                  )
                  .afriAnimate(context, delay: (index * 100).ms)
                  .scaleX(
                    begin: 0,
                    end: 1,
                    alignment: Alignment.centerLeft,
                    duration: 500.ms,
                    curve: Curves.easeOutCubic,
                  ),
            ],
          ),
        ),
        const SizedBox(width: SpacingTokens.spacing2),
        SizedBox(
          width: SpacingTokens.spacing10,
          child: Text(
            '${pick.pickPercentage.toStringAsFixed(0)}%',
            textAlign: TextAlign.right,
            style: TypographyTokens.labelMedium(
              isUserPick
                  ? ColorTokens.clubAccent
                  : ColorTokens.onSurfaceVariant,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
