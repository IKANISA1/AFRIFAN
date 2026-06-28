import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';

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
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: ColorTokens.clubAccent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'FEATURED CHAPTER',
              style: TypographyTokens.labelSmall(
                ColorTokens.clubAccent,
              ).copyWith(fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            (club['name']?.toString() ?? 'FAN CLUB').toUpperCase(),
            style: TypographyTokens.displaySmall(ColorTokens.borrowedInk)
                .copyWith(
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                  height: 0.9,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            club['description']?.toString() ?? 'Official supporter chapter.',
            maxLines: 2,
            style: TypographyTokens.bodySmall(
              ColorTokens.borrowedInkMuted,
            ).copyWith(height: 1.4),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildBorrowedMeta(
                'REGION',
                club['region']?.toString() ?? 'Unknown',
              ),
              _buildBorrowedMeta(
                'MEMBERS',
                '${(club['member_count'] as num?)?.toInt() ?? 0}',
              ),
              _buildBorrowedMeta(
                'RATING',
                '${(club['rating'] as num?)?.toDouble() ?? 0.0}',
              ),
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
        const SizedBox(height: 2),
        Text(
          value.toUpperCase(),
          style: TypographyTokens.titleSmall(
            ColorTokens.borrowedInk,
          ).copyWith(fontWeight: FontWeight.w900, letterSpacing: 0),
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
    final members = (club['member_count'] as num?)?.toInt() ?? 0;

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
                  size: 20,
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${club['region']} • $members Members'.toUpperCase(),
            style: TypographyTokens.labelSmall(
              ColorTokens.onSurfaceVariant,
            ).copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: AfriButton(
                  label: isJoined ? 'Joined' : 'Join',
                  onTap: onJoinToggled,
                  isLoading: isPending,
                  variant: isJoined
                      ? AfriButtonVariant.outline
                      : AfriButtonVariant.primary,
                ),
              ),
              const SizedBox(width: 12),
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
