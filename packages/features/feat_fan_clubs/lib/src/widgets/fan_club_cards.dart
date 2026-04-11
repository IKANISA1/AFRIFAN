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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.spacing6),
      child: GlassCard(
        padding: EdgeInsets.zero,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 200),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                ColorTokens.clubPrimary.withValues(alpha: 0.33),
                ColorTokens.background.withValues(alpha: 0.67),
                ColorTokens.surfaceContainerLowest,
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(SpacingTokens.spacing6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: ColorTokens.clubAccent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'FEATURED CLUB',
                    style: TypographyTokens.editorialFont(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: ColorTokens.clubAccent,
                      letterSpacing: 1.3,
                    ),
                  ),
                ),
                const SizedBox(height: SpacingTokens.spacing3),
                Text(
                  (club['name']?.toString() ?? 'FAN CLUB').toUpperCase(),
                  style: TypographyTokens.monolithFont(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: ColorTokens.onSurface,
                    letterSpacing: 0.6,
                    height: 1,
                  ),
                ),
                const SizedBox(height: SpacingTokens.spacing2),
                Text(
                  club['description']?.toString() ?? 'View chapter details.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TypographyTokens.bodyMedium().copyWith(
                    color: ColorTokens.onSurface.withValues(alpha: 0.88),
                  ),
                ),
                const SizedBox(height: SpacingTokens.spacing4),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final itemWidth =
                        (constraints.maxWidth - (SpacingTokens.spacing3 * 2)) /
                        3;

                    return Wrap(
                      spacing: SpacingTokens.spacing3,
                      runSpacing: SpacingTokens.spacing3,
                      children: [
                        SizedBox(
                          width: itemWidth,
                          child: FanClubFeaturedMeta(
                            label: 'REGION',
                            value: club['region']?.toString() ?? 'Unknown',
                          ),
                        ),
                        SizedBox(
                          width: itemWidth,
                          child: FanClubFeaturedMeta(
                            label: 'MEMBERS',
                            value:
                                '${(club['member_count'] as num?)?.toInt() ?? 0}',
                          ),
                        ),
                        SizedBox(
                          width: itemWidth,
                          child: FanClubFeaturedMeta(
                            label: 'EVENTS',
                            value:
                                '${(club['event_count'] as num?)?.toInt() ?? 0}',
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FanClubListItem extends StatelessWidget {
  const FanClubListItem({
    super.key,
    required this.club,
    required this.isJoined,
    required this.isOfficial,
    required this.onTap,
    required this.onJoinToggled,
  });

  final Map<String, dynamic> club;
  final bool isJoined;
  final bool isOfficial;
  final VoidCallback onTap;
  final VoidCallback onJoinToggled;

  @override
  Widget build(BuildContext context) {
    final members = (club['member_count'] as num?)?.toInt() ?? 0;
    final rating = (club['rating'] as num?)?.toDouble() ?? 0;

    return GlassCard(
      animate: false,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (club['name']?.toString() ?? 'Fan Club').toUpperCase(),
                      style: TypographyTokens.monolithFont(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: ColorTokens.onSurface,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: SpacingTokens.spacing2),
                    Text(
                      club['description']?.toString() ??
                          'Supporter chapter details unavailable.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TypographyTokens.bodyMedium(),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: SpacingTokens.spacing3),
              if (isOfficial)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: ColorTokens.clubAccent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'OFFICIAL',
                    style: TypographyTokens.editorialFont(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: ColorTokens.clubAccent,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: SpacingTokens.spacing4),
          Wrap(
            spacing: SpacingTokens.spacing2,
            runSpacing: SpacingTokens.spacing2,
            children: [
              FanClubMetaPill(
                icon: Icons.place_outlined,
                label: club['region']?.toString() ?? 'Unknown',
              ),
              FanClubMetaPill(
                icon: Icons.people_outline_rounded,
                label: '$members members',
              ),
              FanClubMetaPill(
                icon: Icons.star_rounded,
                label: rating == 0 ? 'New' : rating.toStringAsFixed(1),
              ),
            ],
          ),
          const SizedBox(height: SpacingTokens.spacing4),
          Column(
            children: [
              ClaymorphicButton(
                label: isJoined ? 'JOINED' : 'JOIN CLUB',
                width: double.infinity,
                onPressed: onJoinToggled,
              ),
              const SizedBox(height: SpacingTokens.spacing2),
              OutlinedButton(
                onPressed: onTap,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: const Text('VIEW DETAILS'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class FanClubFeaturedMeta extends StatelessWidget {
  const FanClubFeaturedMeta({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TypographyTokens.editorialFont(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: ColorTokens.onSurfaceVariant,
            letterSpacing: 0.9,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TypographyTokens.monolithFont(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: ColorTokens.onSurface,
          ),
        ),
      ],
    );
  }
}

class FanClubMetaPill extends StatelessWidget {
  const FanClubMetaPill({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: ColorTokens.surfaceContainerLow,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: ColorTokens.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: TypographyTokens.editorialFont(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: ColorTokens.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
