import 'package:core_auth/core_auth.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

/// Settings screen — fan identity, feature links, and app settings.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final profile = ref.watch(currentUserProvider);
    final alias = AliasGenerator.format(profile?.publicUserId ?? '000000');

    return Scaffold(
      backgroundColor: ColorTokens.background,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  SpacingTokens.spacing6,
                  SpacingTokens.spacing4,
                  SpacingTokens.spacing6,
                  0,
                ),
                child: Text(
                  'SETTINGS',
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: ColorTokens.onSurface,
                    letterSpacing: 2.0,
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(
              child: SizedBox(height: SpacingTokens.spacing6),
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
                      // Avatar circle
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: primary.withValues(alpha: 0.15),
                          border: Border.all(
                            color: primary.withValues(alpha: 0.3),
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Icon(Icons.person, size: 36, color: primary),
                        ),
                      ),
                      const SizedBox(height: SpacingTokens.spacing4),

                      // Alias
                      Text(
                        alias,
                        style: GoogleFonts.barlowCondensed(
                          fontSize: 40,
                          fontWeight: FontWeight.w900,
                          color: ColorTokens.clubAccent,
                          letterSpacing: 8.0,
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

                      // Tier + XP
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: primary.withValues(alpha: 0.15),
                              borderRadius: ShapeTokens.chipRadius,
                            ),
                            child: Text(
                              'BRONZE',
                              style: GoogleFonts.barlowCondensed(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: primary,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: SpacingTokens.spacing3),
                          Text(
                            '2,450 XP',
                            style: GoogleFonts.barlowCondensed(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: ColorTokens.onSurfaceVariant,
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
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: ColorTokens.onSurfaceVariant,
                    letterSpacing: 1.5,
                  ),
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
                      icon: Icons.card_membership,
                      label: 'Membership',
                      onTap: () => context.go('/membership'),
                    ),
                    const SizedBox(height: SpacingTokens.spacing2),
                    _MenuItem(
                      icon: Icons.bolt_rounded,
                      label: 'XP & Achievements',
                      onTap: () => context.push('/xp'),
                    ),
                    const SizedBox(height: SpacingTokens.spacing2),
                    _MenuItem(
                      icon: Icons.group_work_rounded,
                      label: 'Contributions',
                      onTap: () => context.push('/contribute'),
                    ),
                    const SizedBox(height: SpacingTokens.spacing2),
                    _MenuItem(
                      icon: Icons.shopping_bag_rounded,
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
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: ColorTokens.onSurfaceVariant,
                    letterSpacing: 1.5,
                  ),
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
                      icon: Icons.language,
                      label: 'Language',
                      trailing: 'Kinyarwanda',
                      onTap: () => context.push('/settings/language'),
                    ),
                    const SizedBox(height: SpacingTokens.spacing2),
                    _MenuItem(
                      icon: Icons.notifications_outlined,
                      label: 'Notifications',
                      onTap: () => context.push('/settings/notifications'),
                    ),
                    const SizedBox(height: SpacingTokens.spacing2),
                    _MenuItem(
                      icon: Icons.history,
                      label: 'Activity History',
                      onTap: () => context.push('/my-tickets'),
                    ),
                    const SizedBox(height: SpacingTokens.spacing2),
                    _MenuItem(
                      icon: Icons.info_outline,
                      label: 'About ${RuntimeBranding.displayAppName}',
                      onTap: () => context.push('/settings/about'),
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

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? trailing;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      animate: false,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.spacing4,
        vertical: SpacingTokens.spacing3,
      ),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary, size: 22),
          const SizedBox(width: SpacingTokens.spacing3),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: ColorTokens.onSurface,
              ),
            ),
          ),
          if (trailing != null)
            Text(
              trailing!,
              style: GoogleFonts.inter(
                fontSize: 15,
                color: ColorTokens.onSurfaceVariant,
              ),
            ),
          const SizedBox(width: SpacingTokens.spacing2),
          Icon(
            Icons.chevron_right,
            color: ColorTokens.onSurfaceVariant,
            size: 20,
          ),
        ],
      ),
    );
  }
}
