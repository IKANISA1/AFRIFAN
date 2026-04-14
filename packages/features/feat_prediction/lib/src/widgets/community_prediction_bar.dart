import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/prediction_catalog_models.dart';

/// Displays community prediction distribution for a fixture market.
/// Shows how other fans picked, with horizontal bar percentages.
class CommunityPredictionBar extends StatelessWidget {
  const CommunityPredictionBar({
    super.key,
    required this.picks,
    this.userSelection,
  });

  /// List of {outcome, pick_count, pick_percentage}.
  final List<CommunityPick> picks;

  /// The current user's selected outcome (to highlight).
  final String? userSelection;

  @override
  Widget build(BuildContext context) {
    if (picks.isEmpty) return const SizedBox.shrink();

    final sorted = List<CommunityPick>.from(picks)
      ..sort((a, b) => b.percentage.compareTo(a.percentage));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'COMMUNITY PICKS',
          style: TypographyTokens.editorialFont(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: ColorTokens.onSurfaceVariant,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: SpacingTokens.spacing3),
        ...sorted.asMap().entries.map((entry) {
          final pick = entry.value;
          final isUserPick = pick.outcome == userSelection;
          return Padding(
            padding: const EdgeInsets.only(bottom: SpacingTokens.spacing2),
            child: _PickBar(
              pick: pick,
              isUserPick: isUserPick,
              index: entry.key,
            ),
          );
        }),
      ],
    );
  }
}

class _PickBar extends StatelessWidget {
  const _PickBar({
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
    final fraction = (pick.percentage / 100).clamp(0.0, 1.0);

    return Row(
      children: [
        // Outcome label
        SizedBox(
          width: 72,
          child: Row(
            children: [
              if (isUserPick)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(
                    Icons.person_rounded,
                    size: 12,
                    color: ColorTokens.clubAccent,
                  ),
                ),
              Flexible(
                child: Text(
                  pick.outcome.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TypographyTokens.monolithFont(
                    fontSize: 12,
                    fontWeight: isUserPick ? FontWeight.w800 : FontWeight.w600,
                    color: isUserPick
                        ? ColorTokens.clubAccent
                        : ColorTokens.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: SpacingTokens.spacing2),

        // Bar
        Expanded(
          child: Stack(
            children: [
              // Background
              Container(
                height: 20,
                decoration: BoxDecoration(
                  color: ColorTokens.surfaceContainerHigh.withValues(
                    alpha: 0.3,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              // Fill
              FractionallySizedBox(
                    widthFactor: fraction,
                    child: Container(
                      height: 20,
                      decoration: BoxDecoration(
                        color: barColor.withValues(
                          alpha: isUserPick ? 0.25 : 0.12,
                        ),
                        borderRadius: BorderRadius.circular(10),
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
                  .animate(delay: (index * 100).ms)
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

        // Percentage
        SizedBox(
          width: 40,
          child: Text(
            '${pick.percentage.toStringAsFixed(0)}%',
            textAlign: TextAlign.right,
            style: TypographyTokens.monolithFont(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isUserPick
                  ? ColorTokens.clubAccent
                  : ColorTokens.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
