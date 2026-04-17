import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';

/// Initiative card — glassmorphic tile showing name, progress, and members.
class GroupCard extends StatelessWidget {
  final Map<String, dynamic> group;
  final VoidCallback? onTap;

  const GroupCard({super.key, required this.group, this.onTap});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
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
                  color: primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(Icons.group_work, color: primary, size: 20),
                ),
              ),
              const SizedBox(width: SpacingTokens.spacing3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.toUpperCase(),
                      style: TypographyTokens.monolithFont(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: ColorTokens.onSurface,
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '$memberCount contributors',
                      style: TypographyTokens.editorialFont(
                        fontSize: 15,
                        color: ColorTokens.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: ColorTokens.onSurfaceVariant,
                size: 20,
              ),
            ],
          ),

          if (target > 0) ...[
            const SizedBox(height: SpacingTokens.spacing3),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: ColorTokens.surfaceContainerHigh,
                valueColor: AlwaysStoppedAnimation<Color>(primary),
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing1),
            Text(
              '${(progress * 100).toStringAsFixed(0)}% of goal',
              style: TypographyTokens.editorialFont(
                fontSize: 15,
                color: ColorTokens.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
