import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final _tierDetailProvider = FutureProvider.autoDispose
    .family<_TierDetailData?, String>((ref, rawTierId) async {
      final tier = FanTierX.fromValue(rawTierId);
      final client = ref.watch(supabaseClientProvider);
      final resolver = ClubScopeResolver(client: client);
      final scope = await resolver.requireResolved();

      var query = client
          .from('membership_packages')
          .select('club_id, tier, title, subtitle, description, benefits')
          .eq('tier', tier.value)
          .eq('is_active', true);

      if (scope.clubId != null) {
        query = query.or('club_id.is.null,club_id.eq.${scope.clubId}');
      } else {
        query = query.isFilter('club_id', null);
      }

      final rows = List<Map<String, dynamic>>.from(
        await query
            .order('club_id', ascending: false)
            .order('sort_order', ascending: true)
            .limit(5),
      );
      if (rows.isEmpty) {
        return null;
      }

      final preferred = scope.clubId == null
          ? rows.first
          : rows.cast<Map<String, dynamic>?>().firstWhere(
              (row) => (row?['club_id'] as num?)?.toInt() == scope.clubId,
              orElse: () => rows.first,
            )!;

      return _TierDetailData.fromJson(preferred, tier: tier);
    });

class TierDetailScreen extends ConsumerWidget {
  const TierDetailScreen({required this.tierId, super.key});

  final String tierId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tier = FanTierX.fromValue(tierId);
    final detailAsync = ref.watch(_tierDetailProvider(tierId.toLowerCase()));
    final detail = detailAsync.valueOrNull ?? _TierDetailData.fallback(tier);

    return Scaffold(
      backgroundColor: ColorTokens.background,
      appBar: AppBar(
        title: Text(
          detail.title,
          style: TypographyTokens.monolithFont(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(AfriIcons.back),
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
                    child: Icon(tier.icon, size: 48),
                  ),
                  const SizedBox(height: SpacingTokens.spacing4),
                  Text(
                    detail.xpBand,
                    style: TypographyTokens.monolithFont(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: ColorTokens.onSurface,
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

class _TierDetailData {
  const _TierDetailData({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.benefits,
    required this.xpBand,
  });

  factory _TierDetailData.fromJson(
    Map<String, dynamic> json, {
    required FanTier tier,
  }) {
    final fallback = _TierDetailData.fallback(tier);
    final benefits = _parseBenefits(json['benefits']);
    return _TierDetailData(
      title: (json['title']?.toString().trim().isNotEmpty ?? false)
          ? json['title'].toString().trim().toUpperCase()
          : fallback.title,
      subtitle: json['subtitle']?.toString().trim() ?? fallback.subtitle,
      description: json['description']?.toString().trim() ?? '',
      benefits: benefits.isEmpty ? fallback.benefits : benefits,
      xpBand: fallback.xpBand,
    );
  }

  factory _TierDetailData.fallback(FanTier tier) {
    return switch (tier) {
      FanTier.platinum => const _TierDetailData(
        title: 'PLATINUM Group',
        subtitle: 'VIP supporter access and top-tier benefits.',
        description: '',
        benefits: <String>[
          '15% shop discount',
          'Priority support',
          'Early ticket access',
          'VIP event invites',
        ],
        xpBand: '5,000+ FET',
      ),
      FanTier.gold => const _TierDetailData(
        title: 'GOLD FAITHFUL',
        subtitle: 'Expanded member rewards and priority access.',
        description: '',
        benefits: <String>[
          '10% shop discount',
          '48-hour ticket priority',
          'Priority club updates',
          'Season rewards eligibility',
        ],
        xpBand: '2,000 - 4,999 FET',
      ),
      FanTier.bronze => const _TierDetailData(
        title: 'BRONZE SUPPORTER',
        subtitle: 'Core member benefits for active supporters.',
        description: '',
        benefits: <String>[
          '5% shop discount',
          '24-hour ticket priority',
          'Member badge on profile',
          'Access to supporter campaigns',
        ],
        xpBand: '1,000 - 1,999 FET',
      ),
      FanTier.fan => const _TierDetailData(
        title: 'FAN MEMBERSHIP',
        subtitle: 'Official supporter identity and starter benefits.',
        description: '',
        benefits: <String>[
          'Official fan identity',
          'Access to supporter campaigns',
          'Progress tracking toward Bronze',
          'Club news and matchday access',
        ],
        xpBand: '0 - 999 FET',
      ),
    };
  }

  final String title;
  final String subtitle;
  final String description;
  final List<String> benefits;
  final String xpBand;

  static List<String> _parseBenefits(dynamic raw) {
    if (raw is! List) {
      return const <String>[];
    }

    return raw
        .map((entry) {
          if (entry is String) {
            return entry.trim();
          }
          if (entry is Map) {
            final map = Map<String, dynamic>.from(entry);
            return (map['label'] ?? map['title'] ?? map['value'] ?? '')
                .toString()
                .trim();
          }
          return '';
        })
        .where((entry) => entry.isNotEmpty)
        .toList(growable: false);
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
                    AfriIcons.checkGroup,
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
