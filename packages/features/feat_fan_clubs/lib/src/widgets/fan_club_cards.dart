import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';

import '../official_fanclub_register.dart';

class FanClubFeaturedCard extends StatelessWidget {
  const FanClubFeaturedCard({
    super.key,
    required this.club,
    required this.onTap,
  });

  final Map<String, dynamic> club;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AfriPanelCard(
      backgroundColor: ColorTokens.borrowedPaper,
      borderColor: ColorTokens.transparent,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: SpacingTokens.spacing3,
              vertical: SpacingTokens.spacing1,
            ),
            decoration: BoxDecoration(
              color: ColorTokens.clubAccent.withValues(alpha: 0.15),
              borderRadius: ShapeTokens.chipRadius,
            ),
            child: Text(
              'FEATURED CHAPTER',
              style: TypographyTokens.labelSmall(
                ColorTokens.clubAccent,
              ).copyWith(fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing4),
          Text(
            (club['name']?.toString() ?? 'FAN CLUB').toUpperCase(),
            style: TypographyTokens.displaySmall(ColorTokens.borrowedInk)
                .copyWith(
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                  height: TypographyTokens.lineHeightHero,
                ),
          ),
          const SizedBox(height: SpacingTokens.spacing2),
          Text(
            club['description']?.toString() ?? 'Official supporter chapter.',
            maxLines: 2,
            style: TypographyTokens.bodySmall(ColorTokens.borrowedInkMuted),
          ),
          const SizedBox(height: SpacingTokens.spacing6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildBorrowedMeta(
                'REGION',
                club['region']?.toString() ?? 'Unknown',
              ),
              _buildBorrowedMeta('MEMBERS', fanclubMemberLabel(club)),
              _buildBorrowedMeta('STATUS', fanclubStatusLabel(club)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBorrowedMeta(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TypographyTokens.labelSmall(
            ColorTokens.borrowedInkFaint,
          ).copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: SpacingTokens.spacing1),
        Text(
          value.toUpperCase(),
          style: TypographyTokens.titleSmall(
            ColorTokens.borrowedInk,
          ).copyWith(fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}

class FanClubListItem extends StatelessWidget {
  const FanClubListItem({
    super.key,
    required this.club,
    required this.isJoined,
    required this.isPending,
    required this.isOfficial,
    required this.onTap,
    required this.onJoinToggled,
  });

  final Map<String, dynamic> club;
  final bool isJoined;
  final bool isPending;
  final bool isOfficial;
  final VoidCallback onTap;
  final VoidCallback onJoinToggled;

  @override
  Widget build(BuildContext context) {
    final members = fanclubMemberLabel(club);
    final memberCopy =
        members.toLowerCase().contains('member') ||
            members.toLowerCase().contains('pending')
        ? members
        : '$members Members';
    final region = club['region']?.toString() ?? 'Unknown';

    return AfriPanelCard(
      onTap: onTap,
      padding: const EdgeInsets.all(SpacingTokens.spacing5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  (club['name']?.toString() ?? 'Fan Club').toUpperCase(),
                  style: TypographyTokens.headlineSmall().copyWith(
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              if (isOfficial)
                Icon(
                  AfriIcons.verified,
                  color: ColorTokens.clubAccent,
                  size: SizeTokens.iconMd,
                ),
            ],
          ),
          const SizedBox(height: SpacingTokens.spacing1),
          Text(
            '$region • $memberCopy'.toUpperCase(),
            style: TypographyTokens.labelSmall(
              ColorTokens.onSurfaceVariant,
            ).copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: SpacingTokens.spacing4),
          Row(
            children: [
              Expanded(
                child: AfriButton(
                  label: isJoined ? 'Review requested' : 'Request review',
                  onTap: onJoinToggled,
                  isLoading: isPending,
                  variant: isJoined
                      ? AfriButtonVariant.outline
                      : AfriButtonVariant.primary,
                ),
              ),
              const SizedBox(width: SpacingTokens.spacing3),
              AfriButton(
                label: 'Details',
                onTap: onTap,
                fullWidth: false,
                variant: AfriButtonVariant.secondary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
