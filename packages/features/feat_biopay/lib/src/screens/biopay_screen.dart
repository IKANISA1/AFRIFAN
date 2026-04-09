import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/biopay_providers.dart';

/// BioPay Hub — 2×2 payment method grid.
class BioPayScreen extends ConsumerWidget {
  const BioPayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEnabled = ref
        .watch(biopayEnabledProvider)
        .maybeWhen(data: (value) => value, orElse: () => true);

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
        body: GradientBackground(
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
                Text(
                  'How you want\nto pay today',
                  style: TypographyTokens.displaySmall(),
                ),

                const SizedBox(height: SpacingTokens.spacing8),

                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: SpacingTokens.spacing4,
                  crossAxisSpacing: SpacingTokens.spacing4,
                  childAspectRatio: 1.05,
                  children: [
                    _MethodTile(
                      icon: Icons.face_retouching_natural_rounded,
                      iconColor: const Color(0xFF1565C0),
                      label: 'Face Scan',
                      onTap: () {
                        HapticFeedback.lightImpact();
                        context.push('/biopay/scan?mode=pay');
                      },
                    ),
                    _MethodTile(
                      icon: Icons.nfc_rounded,
                      iconColor: const Color(0xFF7C4DFF),
                      label: 'NFC Tap',
                      onTap: () {
                        HapticFeedback.lightImpact();
                        context.push('/biopay/nfc');
                      },
                    ),
                    _MethodTile(
                      icon: Icons.qr_code_rounded,
                      iconColor: const Color(0xFFEF6C00),
                      label: 'Get QR',
                      onTap: () {
                        HapticFeedback.lightImpact();
                        context.push('/biopay/qr');
                      },
                    ),
                    _MethodTile(
                      icon: Icons.qr_code_scanner_rounded,
                      iconColor: const Color(0xFF00897B),
                      label: 'Scan QR',
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
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClayCard(
      backgroundColor: ColorTokens.surfaceContainerLow,
      borderRadius: BorderRadius.circular(32),
      onTap: onTap,
      padding: const EdgeInsets.all(SpacingTokens.spacing6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: ColorTokens.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(icon, size: 34, color: iconColor),
          ),
          const SizedBox(height: SpacingTokens.spacing4),
          Text(
            label,
            style: TypographyTokens.titleMedium().copyWith(
              fontSize: 20,
              letterSpacing: 0,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
