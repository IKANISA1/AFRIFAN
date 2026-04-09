import 'package:core_auth/core_auth.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/biopay_providers.dart';
import '../widgets/biopay_branding.dart';

/// BioPay Hub — 2×2 payment method grid.
class BioPayScreen extends ConsumerWidget {
  const BioPayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEnabled = ref
        .watch(biopayEnabledProvider)
        .maybeWhen(data: (value) => value, orElse: () => true);
    final profile = ref.watch(biopayProfileProvider).valueOrNull;
    final user = ref.watch(currentUserProvider);
    final appName = biopayAppName(context);
    final clubName = biopayClubName(context);
    final primaryColor = biopayPrimary(context);
    final accentColor = biopayAccent(context);

    return KillSwitchGate(
      enabled: isEnabled,
      featureName: 'BioPay',
      child: Scaffold(
        backgroundColor: ColorTokens.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text('BioPay', style: TypographyTokens.titleLarge()),
          actions: [
            IconButton(
              tooltip: 'Open BioPay profile',
              icon: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: ColorTokens.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(ShapeTokens.radiusXl),
                ),
                child: Icon(
                  Icons.person_outline_rounded,
                  color: ColorTokens.onSurface,
                  size: 20,
                ),
              ),
              onPressed: () => context.push('/biopay/profile'),
            ),
          ],
        ),
        body: BiopayMoodBackground(
          child: SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                SpacingTokens.spacing6,
                SpacingTokens.spacing6,
                SpacingTokens.spacing6,
                SpacingTokens.spacing8,
              ),
              children: [
                BiopayHeroCard(
                  eyebrow: '$appName • $clubName',
                  title: 'How you want\nto pay today',
                  subtitle:
                      'Face, NFC and QR stay aligned with your club payment identity.',
                  trailing: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          accentColor.withValues(alpha: 0.9),
                          primaryColor.withValues(alpha: 0.9),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  bottom: Wrap(
                    spacing: SpacingTokens.spacing2,
                    runSpacing: SpacingTokens.spacing2,
                    children: [
                      BiopayBadge(
                        icon: profile != null
                            ? Icons.face_retouching_natural_rounded
                            : Icons.face_outlined,
                        label: profile != null
                            ? 'Face Ready'
                            : 'Enroll Face ID',
                        tint: profile != null
                            ? ColorTokens.success.withValues(alpha: 0.16)
                            : accentColor.withValues(alpha: 0.16),
                      ),
                      if (user?.hasMomo == true)
                        BiopayBadge(
                          icon: Icons.bolt_rounded,
                          label: user?.momoProvider ?? 'Wallet Linked',
                          tint: primaryColor.withValues(alpha: 0.16),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: SpacingTokens.spacing8),

                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: SpacingTokens.spacing4,
                  crossAxisSpacing: SpacingTokens.spacing4,
                  childAspectRatio: 0.92,
                  children: [
                    _MethodTile(
                      icon: Icons.face_retouching_natural_rounded,
                      iconColor: primaryColor,
                      label: 'Face Scan',
                      subtitle: 'Verify a member and launch payment.',
                      onTap: () {
                        HapticFeedback.lightImpact();
                        context.push('/biopay/scan?mode=pay');
                      },
                    ),
                    _MethodTile(
                      icon: Icons.nfc_rounded,
                      iconColor: accentColor,
                      label: 'NFC Tap',
                      subtitle: 'Request or scan a contactless handoff.',
                      onTap: () {
                        HapticFeedback.lightImpact();
                        context.push('/biopay/nfc');
                      },
                    ),
                    _MethodTile(
                      icon: Icons.qr_code_rounded,
                      iconColor: accentColor,
                      label: 'Get QR',
                      subtitle: 'Create a live payment code for supporters.',
                      onTap: () {
                        HapticFeedback.lightImpact();
                        context.push('/biopay/qr');
                      },
                    ),
                    _MethodTile(
                      icon: Icons.qr_code_scanner_rounded,
                      iconColor: primaryColor,
                      label: 'Scan QR',
                      subtitle: 'Resolve a BioPay request instantly.',
                      onTap: () {
                        HapticFeedback.lightImpact();
                        context.push('/biopay/qr/scan');
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── 2×2 Grid Tile ──

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClayCard(
      backgroundColor: ColorTokens.surfaceContainerLow,
      borderRadius: BorderRadius.circular(32),
      onTap: onTap,
      semanticsLabel: label,
      padding: const EdgeInsets.all(SpacingTokens.spacing5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  iconColor.withValues(alpha: 0.28),
                  ColorTokens.surfaceContainerLowest,
                ],
              ),
              borderRadius: BorderRadius.circular(26),
            ),
            child: Icon(icon, size: 30, color: iconColor),
          ),
          const SizedBox(height: SpacingTokens.spacing5),
          Text(
            label,
            style: TypographyTokens.titleMedium().copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing2),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TypographyTokens.bodySmall().copyWith(
              color: ColorTokens.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
