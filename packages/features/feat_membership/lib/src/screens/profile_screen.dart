import 'package:core_auth/core_auth.dart';
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
    final profile = ref.watch(currentUserProvider);
    final membershipSummary = ref.watch(_profileMembershipSummaryProvider);
    final alias = AliasGenerator.format(profile?.publicUserId ?? '000000');

    return Scaffold(
      backgroundColor: ColorTokens.background,
      appBar: AfriAppBar(
        backgroundColor: ColorTokens.transparent,
        elevation: 0,
        leading: AfriIconButton(
          icon: AfriIcons.back,
          onTap: () => context.pop(),
          tooltip: 'Back',
        ),
        title: Text(
          'PROFILE',
          style: TypographyTokens.titleLarge().copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
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
                              ColorTokens.clubAccent,
                            ).copyWith(
                              fontWeight: FontWeight.w900,
                              shadows: [
                                Shadow(
                                  color: ColorTokens.clubAccent.withValues(
                                    alpha: 0.3,
                                  ),
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
                              summary.activityLabel,
                              style: TypographyTokens.titleMedium(
                                ColorTokens.onSurfaceVariant,
                              ).copyWith(fontWeight: FontWeight.w700),
                            ),
                            loading: () => Text(
                              'Loading membership...',
                              style: TypographyTokens.titleMedium(
                                ColorTokens.onSurfaceVariant,
                              ).copyWith(fontWeight: FontWeight.w700),
                            ),
                            error: (_, __) => Text(
                              'Membership review pending',
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
                  'MY CLUB',
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
                      label: 'Membership',
                      onTap: () => context.go('/membership'),
                    ),
                    const SizedBox(height: SpacingTokens.spacing2),
                    _MenuItem(
                      icon: AfriIcons.bolt,
                      label: 'Matchday',
                      onTap: () => context.push('/fanzone/fixtures'),
                    ),
                    const SizedBox(height: SpacingTokens.spacing2),
                    _MenuItem(
                      icon: AfriIcons.myPicks,
                      label: 'My Picks',
                      onTap: () => context.push('/fanzone/my'),
                    ),
                    const SizedBox(height: SpacingTokens.spacing2),
                    _MenuItem(
                      icon: AfriIcons.premium,
                      label: 'Club Benefits',
                      onTap: () => context.push('/fanzone/rewards'),
                    ),
                    const SizedBox(height: SpacingTokens.spacing2),
                    _MenuItem(
                      icon: AfriIcons.contribute,
                      label: 'Contributions',
                      onTap: () => context.push('/contribute'),
                    ),
                    const SizedBox(height: SpacingTokens.spacing2),
                    _MenuItem(
                      icon: AfriIcons.shop,
                      label: 'Shop',
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
                  'APP',
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
                      label: 'Notifications',
                      onTap: () => context.push('/settings/notifications'),
                    ),
                    const SizedBox(height: SpacingTokens.spacing2),
                    _MenuItem(
                      icon: AfriIcons.history,
                      label: 'Activity History',
                      onTap: () => context.push('/my-tickets'),
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

  String get activityLabel {
    if (points <= 0) {
      return 'Membership review pending';
    }
    return '${_formatPoints(points)} activity points';
  }

  static String _formatPoints(int value) {
    final buffer = StringBuffer();
    final digits = value.toString();
    for (var index = 0; index < digits.length; index++) {
      if (index > 0 && (digits.length - index) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(digits[index]);
    }
    return buffer.toString();
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
        color: ColorTokens.clubAccent.withValues(alpha: 0.15),
        border: BorderTokens.all(
          color: ColorTokens.clubAccent,
          width: BorderTokens.strong,
          opacity: 0.3,
        ),
      ),
      child: Center(
        child: Icon(AfriIcons.profile, size: 36, color: ColorTokens.clubAccent),
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
          color: ColorTokens.clubAccent.withValues(alpha: 0.15),
          borderRadius: ShapeTokens.chipRadius,
        ),
        child: const AfriLoadingIndicator(size: 12),
      );
    }

    return AfriInfoChip(label: label, color: ColorTokens.clubAccent);
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
