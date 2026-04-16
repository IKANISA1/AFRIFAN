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
    return EliteCard(
      backgroundColor: Colors.white,
      borderColor: Colors.transparent,
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
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: ColorTokens.clubAccent,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            (club['name']?.toString() ?? 'FAN CLUB').toUpperCase(),
            style: const TextStyle(
              fontFamily: 'Display',
              fontSize: 32,
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
              color: Colors.black,
              height: 0.9,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            club['description']?.toString() ?? 'Official supporter chapter.',
            maxLines: 2,
            style: const TextStyle(fontSize: 13, color: Colors.black54, height: 1.4),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildEliteMeta('REGION', club['region']?.toString() ?? 'Unknown'),
              _buildEliteMeta('MEMBERS', '${(club['member_count'] as num?)?.toInt() ?? 0}'),
              _buildEliteMeta('RATING', '${(club['rating'] as num?)?.toDouble() ?? 0.0}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEliteMeta(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.black26, letterSpacing: 1),
        ),
        const SizedBox(height: 2),
        Text(
          value.toUpperCase(),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.black, letterSpacing: -0.5),
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

    return EliteCard(
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
                  style: const TextStyle(
                    fontFamily: 'Display',
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                    color: Colors.white,
                  ),
                ),
              ),
              if (isOfficial)
                Icon(AfriIcons.verified, color: ColorTokens.clubAccent, size: 20),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${club['region']} • $members Members'.toUpperCase(),
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              color: Colors.white38,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: EliteButton(
                  label: isJoined ? 'Joined' : 'Join',
                  onTap: onJoinToggled,
                  isLoading: isPending,
                  variant: isJoined ? EliteButtonVariant.outline : EliteButtonVariant.primary,
                ),
              ),
              const SizedBox(width: 12),
              EliteButton(
                label: 'Details',
                onTap: onTap,
                fullWidth: false,
                variant: EliteButtonVariant.secondary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
