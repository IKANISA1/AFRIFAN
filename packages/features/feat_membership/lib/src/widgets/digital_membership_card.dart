import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';

/// The actual club member card using the LIVE-048 object-card pattern.
/// Own club identity and membership fields replace the reference financial card.
class DigitalMembershipCardFull extends StatelessWidget {
  const DigitalMembershipCardFull({
    super.key,
    required this.clubName,
    required this.tier,
    required this.fanId,
    this.statusLabel,
    this.memberSince,
    this.onShare,
  });

  final String clubName;
  final String tier;
  final String fanId;
  final String? statusLabel;
  final String? memberSince;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    final l10n = context.afriL10n;
    return Container(
      constraints: const BoxConstraints(
        minHeight: AfriComponentSizes.membershipCardMinHeight,
      ),
      padding: const EdgeInsets.all(SpacingTokens.spacing6),
      decoration: BoxDecoration(
        borderRadius: ShapeTokens.cardRadius,
        gradient: ColorTokens.membershipCardGradient(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  clubName,
                  style: TypographyTokens.bodyLarge(ColorTokens.onDark),
                ),
              ),
              if (onShare != null)
                AfriIconButton(
                  icon: AfriIcons.share,
                  tooltip: l10n.shareMembershipCard,
                  onTap: onShare,
                ),
            ],
          ),
          if (statusLabel != null) ...[
            const SizedBox(height: SpacingTokens.spacing2),
            Text(
              statusLabel!,
              style: TypographyTokens.bodySmall(ColorTokens.onDark),
            ),
          ],
          const SizedBox(height: SpacingTokens.spacing10),
          Text(
            fanId,
            style: TypographyTokens.headlineLarge(
              ColorTokens.onDark,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: SpacingTokens.spacing4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tier,
                      style: TypographyTokens.bodyLarge(ColorTokens.onDark),
                    ),
                    if (memberSince != null) ...[
                      const SizedBox(height: SpacingTokens.spacing1),
                      Text(
                        l10n.membershipSince(memberSince!),
                        style: TypographyTokens.bodySmall(ColorTokens.onDark),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: SpacingTokens.spacing4),
              const AfriBrandMark(size: 40),
            ],
          ),
        ],
      ),
    );
  }
}
