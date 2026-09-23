import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/material.dart';

/// One image-led project card for discovery and contribution details.
/// Optional publisher imagery is never replaced by unrelated or invented art.
class GroupCard extends StatelessWidget {
  const GroupCard({super.key, required this.group, this.onTap, this.action});
  final Map<String, dynamic> group;
  final VoidCallback? onTap;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final l10n = context.afriL10n;
    final name =
        group['name']?.toString() ?? l10n.contributionsPublicGroupFallback;
    final target = (group['target_amount'] as num?)?.toInt() ?? 0;
    final current = (group['current_total'] as num?)?.toInt() ?? 0;
    final progress = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
    final members = (group['member_count'] as num?)?.toInt() ?? 0;
    final currency = CurrencyFormatter(
      currencyCode: context.afriCurrencyCode,
      currencySymbol: context.afriCurrencySymbol,
    );
    final imageUri = Uri.tryParse(group['image_url']?.toString() ?? '');
    final hasImage =
        imageUri?.scheme == 'https' &&
        imageUri!.host.isNotEmpty &&
        imageUri.userInfo.isEmpty;
    return GlassCard(
      animate: false,
      padding: EdgeInsets.zero,
      onTap: onTap,
      semanticsLabel: onTap == null ? null : name,
      child: ClipRRect(
        borderRadius: ShapeTokens.cardRadius,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hasImage)
              LayoutBuilder(
                builder: (context, constraints) => Image.network(
                  imageUri.toString(),
                  width: constraints.maxWidth,
                  height: constraints.maxWidth * 0.65,
                  semanticLabel: name,
                  fit: BoxFit.cover,
                  cacheWidth: 1080,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(SpacingTokens.spacing5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TypographyTokens.titleLarge().copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: SpacingTokens.spacing4),
                  Wrap(
                    spacing: SpacingTokens.spacing5,
                    runSpacing: SpacingTokens.spacing3,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.contributionsConfirmedTotal,
                            style: TypographyTokens.bodySmall(
                              ColorTokens.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: SpacingTokens.spacing1),
                          Text(
                            currency.format(current),
                            style: TypographyTokens.headlineMedium(),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.contributionsContributorsUpper,
                            style: TypographyTokens.bodySmall(
                              ColorTokens.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: SpacingTokens.spacing1),
                          Text(
                            '$members',
                            style: TypographyTokens.headlineMedium(),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (target > 0) ...[
                    const SizedBox(height: SpacingTokens.spacing4),
                    Semantics(
                      label: l10n.contributionsProgressSemantic(
                        (progress * 100).round(),
                      ),
                      child: AfriLinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        borderRadius: ShapeTokens.buttonRadius,
                        color: ColorTokens.accessibleChartColor(
                          ColorTokens.primaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(height: SpacingTokens.spacing2),
                    Text(
                      l10n.contributionsTargetProgress(
                        currency.format(target),
                        (progress * 100).round(),
                      ),
                      style: TypographyTokens.bodySmall(
                        ColorTokens.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (action != null) ...[
                    const SizedBox(height: SpacingTokens.spacing5),
                    action!,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
