import 'package:core_auth/core_auth.dart';
import 'package:core_feature_config/core_feature_config.dart';
import 'package:core_l10n/core_l10n.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../official_membership_tiers.dart';

/// Settings screen — fan identity, feature links, and app settings.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.afriL10n;
    final profile = ref.watch(currentUserProvider);
    final membershipSummary = ref.watch(_profileMembershipSummaryProvider);
    final storePolicy = ref.watch(storeReleasePolicyProvider);
    final alias = AliasGenerator.format(profile?.publicUserId ?? '000000');

    return AfriScreenScaffold(
      backgroundColor: ColorTokens.background,
      appBar: AfriAppBar(
        backgroundColor: ColorTokens.transparent,
        elevation: 0,
        leading: AfriIconButton(
          icon: AfriIcons.back,
          onTap: () => context.pop(),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        ),
        title: Text(
          l10n.profileTitle,
          style: TypographyTokens.titleLarge().copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      scrollable: false,
      child: SafeArea(
        top: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            const SliverToBoxAdapter(
              child: SizedBox(height: SpacingTokens.spacing4),
            ),

            // Identity card
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: SpacingTokens.spacing6,
                ),
                child: GlassCard(
                  child: Column(
                    children: [
                      // Avatar Group
                      const _ProfileAvatar(),
                      const SizedBox(height: SpacingTokens.spacing4),

                      // Alias
                      Text(
                        alias,
                        style:
                            TypographyTokens.displayMedium(
                              ColorTokens.primaryContainer,
                            ).copyWith(
                              fontWeight: FontWeight.w700,
                              shadows: [
                                Shadow(
                                  color: ColorTokens.primaryContainer
                                      .withValues(alpha: 0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                      ),
                      const SizedBox(height: SpacingTokens.spacing2),
                      if ((profile?.displayName ?? '').trim().isNotEmpty) ...[
                        Text(
                          profile!.displayName!.trim(),
                          style: TypographyTokens.bodyMedium().copyWith(
                            color: ColorTokens.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: SpacingTokens.spacing2),
                      ],

                      // Membership category + activity status
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          membershipSummary.when(
                            data: (summary) => _TierBadge(summary.tier),
                            loading: () => const _TierBadge.loading(),
                            error: (_, __) => const _TierBadge('IMENA'),
                          ),
                          const SizedBox(width: SpacingTokens.spacing3),
                          membershipSummary.when(
                            data: (summary) => Text(
                              summary.activityLabel(l10n),
                              style: TypographyTokens.titleMedium(
                                ColorTokens.onSurfaceVariant,
                              ).copyWith(fontWeight: FontWeight.w700),
                            ),
                            loading: () => Text(
                              l10n.profileLoadingMembership,
                              style: TypographyTokens.titleMedium(
                                ColorTokens.onSurfaceVariant,
                              ).copyWith(fontWeight: FontWeight.w700),
                            ),
                            error: (_, __) => Text(
                              l10n.profileMembershipReviewPending,
                              style: TypographyTokens.titleMedium(
                                ColorTokens.onSurfaceVariant,
                              ).copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(
              child: SizedBox(height: SpacingTokens.spacing6),
            ),

            // Features section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: SpacingTokens.spacing6,
                ),
                child: Text(
                  l10n.profileMyClub,
                  style: TypographyTokens.labelMedium(
                    ColorTokens.onSurfaceVariant,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),

            const SliverToBoxAdapter(
              child: SizedBox(height: SpacingTokens.spacing3),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: SpacingTokens.spacing6,
                ),
                child: Column(
                  children: [
                    _MenuItem(
                      icon: AfriIcons.membership,
                      label: l10n.membershipTitle,
                      onTap: () => context.go('/membership'),
                    ),
                    const SizedBox(height: SpacingTokens.spacing2),
                    _MenuItem(
                      icon: AfriIcons.bolt,
                      label: l10n.profileMatchday,
                      onTap: () => context.go('/fanzone?section=league'),
                    ),
                    const SizedBox(height: SpacingTokens.spacing2),
                    _MenuItem(
                      icon: AfriIcons.myPicks,
                      label: l10n.profileMyPicks,
                      onTap: () => context.push('/fanzone/my'),
                    ),
                    const SizedBox(height: SpacingTokens.spacing2),
                    if (storePolicy.allowsRewardRedemption) ...[
                      _MenuItem(
                        icon: AfriIcons.premium,
                        label: l10n.profileClubBenefits,
                        onTap: () => context.go('/fanzone?section=rewards'),
                      ),
                      const SizedBox(height: SpacingTokens.spacing2),
                    ],
                    _MenuItem(
                      icon: AfriIcons.contribute,
                      label: l10n.profileContributions,
                      onTap: () => context.go('/fanzone?section=supporters'),
                    ),
                    const SizedBox(height: SpacingTokens.spacing2),
                    _MenuItem(
                      icon: AfriIcons.shop,
                      label: l10n.profileShop,
                      onTap: () => context.push('/shop'),
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(
              child: SizedBox(height: SpacingTokens.spacing6),
            ),

            // App settings section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: SpacingTokens.spacing6,
                ),
                child: Text(
                  l10n.profileApp,
                  style: TypographyTokens.labelMedium(
                    ColorTokens.onSurfaceVariant,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),

            const SliverToBoxAdapter(
              child: SizedBox(height: SpacingTokens.spacing3),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: SpacingTokens.spacing6,
                ),
                child: Column(
                  children: [
                    _MenuItem(
                      icon: AfriIcons.notifications,
                      label: l10n.profileNotifications,
                      onTap: () => context.push('/settings/notifications'),
                    ),
                    const SizedBox(height: SpacingTokens.spacing2),
                    _MenuItem(
                      icon: AfriIcons.history,
                      label: l10n.profileActivityHistory,
                      onTap: () => context.push('/tickets?tab=mine'),
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(
              child: SizedBox(height: SpacingTokens.spacing20),
            ),
          ],
        ),
      ),
    );
  }
}

final _profileMembershipSummaryProvider =
    FutureProvider.autoDispose<_ProfileMembershipSummary>((ref) async {
      final profile = ref.watch(currentUserProvider);
      if (profile == null) {
        return const _ProfileMembershipSummary();
      }

      final client = ref.watch(supabaseClientProvider);
      final resolver = ClubScopeResolver(client: client);
      final scope = await resolver.requireResolved();

      var query = client
          .from('fan_memberships')
          .select('tier, points')
          .eq('user_id', profile.id)
          .limit(1);
      query = resolver.apply(query, scope);

      final row = await query.maybeSingle();
      if (row == null) {
        return const _ProfileMembershipSummary();
      }

      return _ProfileMembershipSummary(
        tier: officialMembershipLabel(row['tier']?.toString()).toUpperCase(),
        points: (row['points'] as num?)?.toInt() ?? 0,
      );
    });

class _ProfileMembershipSummary {
  const _ProfileMembershipSummary({this.tier = 'IMENA', this.points = 0});

  final String tier;
  final int points;

  String activityLabel(AfriLocalizations l10n) {
    if (points <= 0) {
      return l10n.profileMembershipReviewPending;
    }
    return l10n.profileActivityPoints(points);
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: ColorTokens.primaryContainer.withValues(alpha: 0.15),
        border: BorderTokens.all(
          color: ColorTokens.primaryContainer,
          width: BorderTokens.strong,
          opacity: 0.3,
        ),
      ),
      child: Center(
        child: Icon(
          AfriIcons.profile,
          size: 36,
          color: ColorTokens.primaryContainer,
        ),
      ),
    );
  }
}

class _TierBadge extends StatelessWidget {
  const _TierBadge(this.label) : isLoading = false;

  const _TierBadge.loading() : label = '', isLoading = true;

  final String label;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Container(
        width: 44,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: ColorTokens.primaryContainer.withValues(alpha: 0.15),
          borderRadius: ShapeTokens.chipRadius,
        ),
        child: const AfriLoadingIndicator(size: 12),
      );
    }

    return AfriInfoChip(label: label, color: ColorTokens.primaryContainer);
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AfriListRow(icon: icon, title: label, onTap: onTap);
  }
}
