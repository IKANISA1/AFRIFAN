import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';

class SeatTypeCard extends StatelessWidget {
  const SeatTypeCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String amount;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AfriPressFeedback(
      onTap: onTap,
      builder: (context, state) => AfriSurfaceCard(
        padding: const EdgeInsets.all(SpacingTokens.spacing4),
        child: AnimatedContainer(
          duration: AfriMotion.quick,
          decoration: BoxDecoration(
            color: selected
                ? ColorTokens.clubPrimary.withValues(alpha: 0.1)
                : ColorTokens.transparent,
            borderRadius: ShapeTokens.cardRadius,
            border: BorderTokens.all(
              color:
                  selected ? ColorTokens.clubPrimary : ColorTokens.transparent,
            ),
          ),
          padding: const EdgeInsets.all(SpacingTokens.spacing2),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TypographyTokens.labelLarge()),
                    const SizedBox(height: SpacingTokens.spacing1),
                    Text(subtitle, style: TypographyTokens.bodyMedium()),
                  ],
                ),
              ),
              const SizedBox(width: SpacingTokens.spacing4),
              Text(
                amount,
                style: TypographyTokens.headlineMedium().copyWith(
                  color: selected
                      ? ColorTokens.clubPrimary
                      : ColorTokens.clubAccent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TicketSummaryRow extends StatelessWidget {
  const TicketSummaryRow({
    super.key,
    required this.label,
    required this.value,
    this.highlighted = false,
  });

  final String label;
  final String value;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: SpacingTokens.spacing2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TypographyTokens.bodyMedium()),
          Text(
            value,
            style: highlighted
                ? TypographyTokens.headlineMedium().copyWith(
                    color: ColorTokens.clubAccent,
                  )
                : TypographyTokens.labelLarge(),
          ),
        ],
      ),
    );
  }
}

class MatchDetailEmptyState extends StatelessWidget {
  const MatchDetailEmptyState({
    super.key,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onPressed,
  });

  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(SpacingTokens.spacing8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              AfriIcons.tickets,
              size: 56,
              color: ColorTokens.onSurfaceVariant,
            ),
            const SizedBox(height: SpacingTokens.spacing4),
            Text(title, style: TypographyTokens.headlineSmall()),
            const SizedBox(height: SpacingTokens.spacing2),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TypographyTokens.bodyMedium(),
            ),
            const SizedBox(height: SpacingTokens.spacing6),
            AfriButton(label: actionLabel, onTap: onPressed),
          ],
        ),
      ),
    );
  }
}
