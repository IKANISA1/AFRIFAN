import 'package:africlub_fantasy/core/constants.dart';
import 'package:flutter/material.dart';

class PlayerSlotWidget extends StatelessWidget {
  const PlayerSlotWidget({
    required this.label,
    required this.onTap,
    this.playerName,
    this.teamShort,
    this.priceLabel,
    this.isCaptain = false,
    this.isViceCaptain = false,
    this.isBench = false,
    this.trailing,
    super.key,
  });

  final String label;
  final VoidCallback onTap;
  final String? playerName;
  final String? teamShort;
  final String? priceLabel;
  final bool isCaptain;
  final bool isViceCaptain;
  final bool isBench;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final filled = playerName != null;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 96),
        padding: const EdgeInsets.all(FantasySpacing.sm),
        decoration: BoxDecoration(
          color: filled
              ? FantasyColors.surface.withValues(alpha: 0.88)
              : FantasyColors.surfaceAlt.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: filled
                ? FantasyColors.border
                : FantasyColors.textMuted.withValues(alpha: 0.4),
            style: filled ? BorderStyle.solid : BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Stack(
              alignment: Alignment.center,
              children: <Widget>[
                Icon(
                  isBench ? Icons.event_seat_rounded : Icons.shield_rounded,
                  size: 34,
                  color: filled
                      ? FantasyColors.textPrimary
                      : FantasyColors.textMuted,
                ),
                if (isCaptain || isViceCaptain)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isCaptain
                            ? FantasyColors.successGreen
                            : FantasyColors.warningAmber,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        isCaptain ? 'C' : 'VC',
                        style: FantasyTypography.label.copyWith(
                          color: FantasyColors.textPrimary,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: FantasySpacing.sm),
            Text(
              playerName ?? label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: FantasyTypography.caption.copyWith(
                color: filled
                    ? FantasyColors.textPrimary
                    : FantasyColors.textSecondary,
                fontWeight: filled ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            if (teamShort != null || priceLabel != null) ...<Widget>[
              const SizedBox(height: FantasySpacing.xs),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  if (teamShort != null)
                    Flexible(
                      child: Text(
                        teamShort!,
                        overflow: TextOverflow.ellipsis,
                        style: FantasyTypography.label.copyWith(
                          color: FantasyColors.textMuted,
                        ),
                      ),
                    ),
                  if (teamShort != null && priceLabel != null)
                    const SizedBox(width: FantasySpacing.xs),
                  if (priceLabel != null)
                    Text(
                      priceLabel!,
                      style: FantasyTypography.label.copyWith(
                        color: FantasyColors.textMuted,
                      ),
                    ),
                ],
              ),
            ],
            if (trailing != null) ...<Widget>[
              const SizedBox(height: FantasySpacing.xs),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}
