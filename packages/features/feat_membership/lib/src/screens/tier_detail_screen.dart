import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../official_membership_tiers.dart';

final _tierDetailProvider = FutureProvider.autoDispose
    .family<_TierDetailData?, String>((ref, rawTierId) async {
      final normalizedTier = normalizeMembershipSlug(rawTierId);
      final client = ref.watch(supabaseClientProvider);

      try {
        final rows = List<Map<String, dynamic>>.from(
          await client
              .from('membership_tiers')
              .select()
              .eq('category_slug', normalizedTier)
              .eq('active', true)
              .order('sort_order', ascending: true)
              .limit(1),
        );
        if (rows.isNotEmpty) {
          return _TierDetailData.fromPackage(
            normalizeMembershipTierRow(rows.first),
          );
        }
      } catch (_) {
        return null;
      }
      return null;
    });

class TierDetailScreen extends ConsumerWidget {
  const TierDetailScreen({required this.tierId, super.key});

  final String tierId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(_tierDetailProvider(tierId.toLowerCase()));
    final detail = detailAsync.valueOrNull ?? _TierDetailData.fallback(tierId);

    return Scaffold(
      backgroundColor: ColorTokens.background,
      appBar: AfriAppBar(
        title: Text(
          detail.title,
          style: TypographyTokens.headlineSmall().copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: AfriIconButton(
          icon: AfriIcons.back,
          onTap: () => context.pop(),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
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
                    width: SizeTokens.iconXxl * 2,
                    height: SizeTokens.iconXxl * 2,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: ColorTokens.universalGradient(
                        colors: [
                          ColorTokens.clubAccent.withValues(alpha: 0.9),
                          ColorTokens.clubPrimary,
                        ],
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Icon(detail.icon, size: SizeTokens.iconXl),
                  ),
                  const SizedBox(height: SpacingTokens.spacing4),
                  Text(
                    detail.priceLabel,
                    style: TypographyTokens.headlineLarge().copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (detail.subtitle.isNotEmpty) ...[
                    const SizedBox(height: SpacingTokens.spacing2),
                    Text(
                      detail.subtitle,
                      textAlign: TextAlign.center,
                      style: TypographyTokens.bodyMedium(),
                    ),
                  ],
                ],
              ),
            ),
            if (detail.description.isNotEmpty) ...[
              const SizedBox(height: SpacingTokens.spacing4),
              GlassCard(
                animate: false,
                child: Text(
                  detail.description,
                  style: TypographyTokens.bodyLarge(),
                ),
              ),
            ],
            const SizedBox(height: SpacingTokens.spacing4),
            _PerkCard(title: 'Tier perks', items: detail.benefits),
            const SizedBox(height: SpacingTokens.spacing4),
            _PerkCard(title: 'Membership access', items: detail.accessItems),
          ],
        ),
      ),
    );
  }
}

class _TierDetailData {
  const _TierDetailData({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.benefits,
    required this.priceLabel,
    required this.accessItems,
    required this.icon,
  });

  factory _TierDetailData.fromPackage(Map<String, dynamic> json) {
    final fallback = _TierDetailData.fromOfficialSlug(
      json['tier']?.toString() ?? '',
    );
    final benefits = parseMembershipBenefits(json['benefits']);
    final amount =
        (json['annual_price'] as num?)?.toInt() ??
        (json['price'] as num?)?.toInt() ??
        0;
    final billingPeriod = json['billing_period']?.toString() ?? 'annual';
    final accessItems = <String>[
      json['seating_access']?.toString() ?? '',
      json['match_access']?.toString() ?? '',
      json['source_label']?.toString() ?? '',
    ].where((entry) => entry.trim().isNotEmpty).toList(growable: false);

    return _TierDetailData(
      title: (json['title']?.toString().trim().isNotEmpty ?? false)
          ? json['title'].toString().trim().toUpperCase()
          : fallback.title,
      subtitle: json['subtitle']?.toString().trim() ?? fallback.subtitle,
      description: json['description']?.toString().trim() ?? '',
      benefits: benefits.isEmpty ? fallback.benefits : benefits,
      priceLabel: amount <= 0
          ? fallback.priceLabel
          : '$amount RWF / $billingPeriod',
      accessItems: accessItems.isEmpty ? fallback.accessItems : accessItems,
      icon: fallback.icon,
    );
  }

  factory _TierDetailData.fallback(String rawTier) {
    return _TierDetailData.fromOfficialSlug(rawTier);
  }

  factory _TierDetailData.fromOfficialSlug(String rawTier) {
    final normalized = normalizeMembershipSlug(rawTier);
    final tier = officialMembershipTiers.firstWhere(
      (entry) => entry.slug == normalized,
      orElse: () =>
          officialMembershipTiers.firstWhere((entry) => entry.slug == 'imena'),
    );
    return _TierDetailData(
      title: tier.name.toUpperCase(),
      subtitle: tier.track,
      description: tier.summary,
      benefits: tier.benefits,
      priceLabel: '${tier.priceRwf} RWF / ${tier.billingPeriod}',
      accessItems: <String>[
        if (tier.seatingAccess != null) tier.seatingAccess!,
        if (tier.matchAccess != null) tier.matchAccess!,
        'User-provided official Rayon Sports membership category list, 2026-06-27',
      ],
      icon: switch (tier.slug) {
        'gold' => AfriIcons.rank,
        'silver' => AfriIcons.premium,
        'bronze' => AfriIcons.verified,
        _ => AfriIcons.membership,
      },
    );
  }

  final String title;
  final String subtitle;
  final String description;
  final List<String> benefits;
  final String priceLabel;
  final List<String> accessItems;
  final IconData icon;
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
            style: TypographyTokens.headlineSmall().copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing3),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: SpacingTokens.spacing2),
              child: Row(
                children: [
                  const Icon(
                    AfriIcons.checkGroup,
                    color: ColorTokens.success,
                    size: SizeTokens.iconSm,
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
