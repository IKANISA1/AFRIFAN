import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';

/// Initiative card — glassmorphic tile showing name, progress, and members.
class GroupCard extends StatelessWidget {
  final Map<String, dynamic> group;
  final VoidCallback? onTap;

  const GroupCard({super.key, required this.group, this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = group['name']?.toString() ?? 'Public group';
    final target = (group['target_amount'] as num?)?.toDouble() ?? 0;
    final current = (group['current_total'] as num?)?.toDouble() ?? 0;
    final progress = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
    final memberCount = (group['member_count'] as num?)?.toInt() ?? 0;

    return GlassCard(
      animate: false,
      onTap: onTap,
      padding: const EdgeInsets.all(SpacingTokens.spacing4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: ColorTokens.clubAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(
                    AfriIcons.groups,
                    color: ColorTokens.clubAccent,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: SpacingTokens.spacing3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.toUpperCase(),
                      style: TypographyTokens.titleMedium().copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '$memberCount contributors',
                      style: TypographyTokens.bodyLarge(
                        ColorTokens.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                AfriIcons.chevronRight,
                color: ColorTokens.onSurfaceVariant,
                size: 20,
              ),
            ],
          ),

          if (target > 0) ...[
            const SizedBox(height: SpacingTokens.spacing3),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: AfriLinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: ColorTokens.surfaceContainerHigh,
                color: ColorTokens.clubAccent,
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing1),
            Text(
              '${(progress * 100).toStringAsFixed(0)}% of goal',
              style: TypographyTokens.bodyLarge(ColorTokens.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}
