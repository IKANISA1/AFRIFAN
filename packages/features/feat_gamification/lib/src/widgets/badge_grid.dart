import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Grid of achievement badges — earned and locked.
///
/// Uses shared semantic icons instead of emoji. Each badge maps to a
/// shared UI icon that represents the achievement type.
class BadgeGrid extends StatelessWidget {
  final List<Map<String, dynamic>> achievements;

  const BadgeGrid({super.key, required this.achievements});

  @override
  Widget build(BuildContext context) {
    // Default badges if API returns empty
    final badges = achievements.isNotEmpty ? achievements : _defaultBadges;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: SpacingTokens.spacing2,
        mainAxisSpacing: SpacingTokens.spacing2,
        childAspectRatio: 0.85,
      ),
      itemCount: badges.length.clamp(0, 8),
      itemBuilder: (context, index) {
        final badge = badges[index];
        final isEarned = badge['is_earned'] == true || index < 4;
        final iconKey =
            badge['icon_key']?.toString() ??
            _defaultIconTokens.keys.elementAt(
              index % _defaultIconTokens.length,
            );
        final icon = _defaultIconTokens[iconKey] ?? AfriIcons.shield;
        final name =
            badge['title']?.toString() ?? badge['name']?.toString() ?? 'Badge';

        return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: SpacingTokens.spacing12 + SpacingTokens.spacing2,
                  height: SpacingTokens.spacing12 + SpacingTokens.spacing2,
                  decoration: BoxDecoration(
                    color: isEarned
                        ? ColorTokens.clubAccent.withValues(alpha: 0.15)
                        : ColorTokens.surfaceContainerHigh.withValues(
                            alpha: 0.5,
                          ),
                    borderRadius: BorderRadius.circular(ShapeTokens.radiusLg),
                    border: BorderTokens.all(
                      color: isEarned
                          ? ColorTokens.clubAccent.withValues(alpha: 0.3)
                          : ColorTokens.glassFill,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      icon,
                      size: isEarned
                          ? SpacingTokens.spacing6 + SpacingTokens.spacing1 / 2
                          : SpacingTokens.spacing5 + SpacingTokens.spacing1 / 2,
                      color: isEarned
                          ? ColorTokens.clubAccent
                          : ColorTokens.onSurface.withValues(alpha: 0.2),
                    ),
                  ),
                ),
                const SizedBox(height: SpacingTokens.spacing1),
                Text(
                  name.toUpperCase(),
                  style: TypographyTokens.labelLarge(
                    isEarned
                        ? ColorTokens.onSurfaceVariant
                        : ColorTokens.onSurfaceVariant.withValues(alpha: 0.4),
                  ).copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.3),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            )
            .animate(delay: (index * 60).ms)
            .fadeIn(duration: 300.ms)
            .scale(begin: const Offset(0.8, 0.8), duration: 300.ms);
      },
    );
  }
}

/// Icon map: semantic keys -> shared AfriIcons.
/// These replace all emoji badge icons.
const _defaultIconTokens = <String, IconData>{
  'match': AfriIcons.fanzone,
  'contributor': AfriIcons.contribute,
  'early_bird': AfriIcons.statusWait,
  'fan_club': AfriIcons.stadium,
  'streak': AfriIcons.streak,
  'spender': AfriIcons.shop,
  'legend': AfriIcons.rank,
  'mvp': AfriIcons.star,
};

final _defaultBadges = [
  {'name': 'First Match', 'icon_key': 'match', 'is_earned': true},
  {'name': 'Contributor', 'icon_key': 'contributor', 'is_earned': true},
  {'name': 'Early Bird', 'icon_key': 'early_bird', 'is_earned': true},
  {'name': 'Fan Club', 'icon_key': 'fan_club', 'is_earned': true},
  {'name': 'Streak 7', 'icon_key': 'streak', 'is_earned': false},
  {'name': 'Big Spender', 'icon_key': 'spender', 'is_earned': false},
  {'name': 'Legend', 'icon_key': 'legend', 'is_earned': false},
  {'name': 'MVP', 'icon_key': 'mvp', 'is_earned': false},
];
