import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class TierDetailScreen extends StatelessWidget {
  const TierDetailScreen({required this.tierId, super.key});

  final String tierId;

  @override
  Widget build(BuildContext context) {
    final normalizedTier = tierId.toLowerCase();
    final title = switch (normalizedTier) {
      'platinum' => 'PLATINUM CIRCLE',
      'gold' => 'GOLD FAITHFUL',
      'bronze' || 'silver' => 'BRONZE SUPPORTER',
      _ => 'FAN MEMBERSHIP',
    };
    final xpBand = switch (normalizedTier) {
      'platinum' => '5,000+ FET',
      'gold' => '2,000 - 4,999 FET',
      'bronze' || 'silver' => '1,000 - 1,999 FET',
      _ => '0 - 999 FET',
    };
    final tierPerks = switch (normalizedTier) {
      'platinum' => const <String>[
        '15% shop discount',
        'Priority support',
        'Early ticket access',
        'VIP event invites',
      ],
      'gold' => const <String>[
        '10% shop discount',
        '48-hour ticket priority',
        'Priority club updates',
        'Season rewards eligibility',
      ],
      'bronze' || 'silver' => const <String>[
        '5% shop discount',
        '24-hour ticket priority',
        'Member badge on profile',
        'Access to supporter campaigns',
      ],
      _ => const <String>[
        'Official fan identity',
        'Access to supporter campaigns',
        'Progress tracking toward Bronze',
        'Club news and matchday access',
      ],
    };

    return Scaffold(
      backgroundColor: ColorTokens.background,
      appBar: AppBar(
        title: Text(
          title,
          style: TypographyTokens.monolithFont(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(SpacingTokens.spacing6),
        child: Column(
          children: [
            GlassCard(
              animate: false,
              child: Column(
                children: [
                  Container(
                    width: 104,
                    height: 104,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          ColorTokens.clubAccent.withValues(alpha: 0.9),
                          Theme.of(context).colorScheme.primary,
                        ],
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.military_tech_rounded, size: 48),
                  ),
                  const SizedBox(height: SpacingTokens.spacing4),
                  Text(
                    xpBand,
                    style: TypographyTokens.monolithFont(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: ColorTokens.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing4),
            _PerkCard(title: 'Tier perks', items: tierPerks),
            const SizedBox(height: SpacingTokens.spacing4),
            const _PerkCard(
              title: 'How to earn FET faster',
              items: [
                'Attend matchdays and scan tickets',
                'Contribute to club projects',
                'Complete weekly challenges',
                'Join verified fan-club events',
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PerkCard extends StatelessWidget {
  const _PerkCard({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      animate: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TypographyTokens.monolithFont(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: ColorTokens.onSurface,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing3),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: SpacingTokens.spacing2),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: ColorTokens.success,
                    size: 18,
                  ),
                  const SizedBox(width: SpacingTokens.spacing2),
                  Expanded(
                    child: Text(item, style: TypographyTokens.bodyLarge()),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
