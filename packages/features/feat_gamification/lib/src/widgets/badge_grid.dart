import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Grid of achievement badges — earned and locked.
///
/// Uses Material Icons instead of emoji. Each badge maps to a
/// semantic icon that represents the achievement type.
class BadgeGrid extends StatelessWidget {
  final List<Map<String, dynamic>> achievements;

  const BadgeGrid({super.key, required this.achievements});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

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
            _defaultIcons.keys.elementAt(index % _defaultIcons.length);
        final icon = _defaultIcons[iconKey] ?? Icons.shield_rounded;
        final name =
            badge['title']?.toString() ?? badge['name']?.toString() ?? 'Badge';

        return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: isEarned
                        ? primary.withValues(alpha: 0.15)
                        : ColorTokens.surfaceContainerHigh.withValues(
                            alpha: 0.5,
                          ),
                    borderRadius: BorderRadius.circular(16),
                    border: BorderTokens.all(
                      color: isEarned
                          ? primary.withValues(alpha: 0.3)
                          : ColorTokens.glassFill,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      icon,
                      size: isEarned ? 26 : 22,
                      color: isEarned
                          ? primary
                          : ColorTokens.onSurface.withValues(alpha: 0.2),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  name.toUpperCase(),
                  style: TypographyTokens.editorialFont(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isEarned
                        ? ColorTokens.onSurfaceVariant
                        : ColorTokens.onSurfaceVariant.withValues(alpha: 0.4),
                    letterSpacing: 0.3,
                  ),
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

/// Icon map: semantic keys → Material Icons.
/// These replace all emoji badge icons.
const _defaultIcons = <String, IconData>{
  'match': Icons.sports_soccer_rounded,
  'contributor': Icons.volunteer_activism_rounded,
  'early_bird': Icons.alarm_on_rounded,
  'fan_club': Icons.stadium_rounded,
  'streak': Icons.local_fire_department_rounded,
  'spender': Icons.shopping_bag_rounded,
  'legend': Icons.emoji_events_rounded,
  'mvp': Icons.star_rounded,
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
