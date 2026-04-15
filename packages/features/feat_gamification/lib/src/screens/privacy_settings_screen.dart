import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../prediction_providers.dart';

/// Privacy settings screen — core guarantees + visibility toggles.
///
/// Mirrors the fanafrika `PrivacySettings.tsx` — phone-hidden guarantee,
/// anonymous contributions guarantee, and visibility controls.
///
/// Persists toggle values to the Supabase `profiles` table (columns
/// `privacy_show_real_name` and `privacy_findable_by_phone`) and
/// uses local HiveCacheService as a fast read cache.
class PrivacySettingsScreen extends ConsumerStatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  ConsumerState<PrivacySettingsScreen> createState() =>
      _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState
    extends ConsumerState<PrivacySettingsScreen> {
  static const _showRealNameKey = 'privacy:show_real_name';
  static const _findableByPhoneKey = 'privacy:findable_by_phone';

  late bool _showRealName;
  late bool _findableByPhone;
  bool _isLoadingFromServer = true;

  @override
  void initState() {
    super.initState();
    // Start with cached values for instant UI, then load from server.
    _showRealName =
        HiveCacheService.getJson<bool>(_showRealNameKey) ?? false;
    _findableByPhone =
        HiveCacheService.getJson<bool>(_findableByPhoneKey) ?? false;
    _loadFromServer();
  }

  /// Loads current toggle values from the profiles table.
  Future<void> _loadFromServer() async {
    try {
      final repo = ref.read(predictionRepositoryProvider);
      final userId = repo.currentUserId;
      if (userId == null || userId.isEmpty) {
        if (mounted) setState(() => _isLoadingFromServer = false);
        return;
      }

      final client = ref.read(supabaseClientProvider);
      final row = await client
          .from('profiles')
          .select('privacy_show_real_name, privacy_findable_by_phone')
          .eq('id', userId)
          .maybeSingle();

      if (!mounted) return;
      if (row != null) {
        final serverShowReal =
            row['privacy_show_real_name'] as bool? ?? false;
        final serverFindable =
            row['privacy_findable_by_phone'] as bool? ?? false;

        setState(() {
          _showRealName = serverShowReal;
          _findableByPhone = serverFindable;
          _isLoadingFromServer = false;
        });

        // Update local cache to match server.
        HiveCacheService.putJson(
          _showRealNameKey, serverShowReal,
          ttl: const Duration(days: 365),
        );
        HiveCacheService.putJson(
          _findableByPhoneKey, serverFindable,
          ttl: const Duration(days: 365),
        );
      } else {
        setState(() => _isLoadingFromServer = false);
      }
    } catch (_) {
      // Keep cached values if server is unavailable.
      if (mounted) setState(() => _isLoadingFromServer = false);
    }
  }

  void _setShowRealName(bool value) {
    setState(() => _showRealName = value);
    HiveCacheService.putJson(
      _showRealNameKey,
      value,
      ttl: const Duration(days: 365),
    );
    // Fire-and-forget sync to server.
    ref.read(predictionRepositoryProvider).updateProfile(<String, dynamic>{
      'privacy_show_real_name': value,
    });
  }

  void _setFindableByPhone(bool value) {
    setState(() => _findableByPhone = value);
    HiveCacheService.putJson(
      _findableByPhoneKey,
      value,
      ttl: const Duration(days: 365),
    );
    // Fire-and-forget sync to server.
    ref.read(predictionRepositoryProvider).updateProfile(<String, dynamic>{
      'privacy_findable_by_phone': value,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorTokens.background,
      body: GradientBackground(
        child: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── Header ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    SpacingTokens.spacing4,
                    SpacingTokens.spacing4,
                    SpacingTokens.spacing6,
                    SpacingTokens.spacing4,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => context.pop(),
                        icon: const Icon(AfriIcons.back),
                      ),
                      const SizedBox(width: SpacingTokens.spacing2),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SETTINGS',
                            style: TypographyTokens.editorialFont(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: ColorTokens.onSurfaceVariant,
                              letterSpacing: 1.6,
                            ),
                          ),
                          Text(
                            'PRIVACY',
                            style: TypographyTokens.monolithFont(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.6,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: SpacingTokens.spacing6,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // ══════════ Core Guarantees ══════════
                    Text(
                      'CORE GUARANTEES',
                      style: TypographyTokens.editorialFont(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: ColorTokens.onSurfaceVariant,
                        letterSpacing: 1.6,
                      ),
                    ),
                    const SizedBox(height: SpacingTokens.spacing3),
                    ClayCard(
                      child: Column(
                        children: [
                          _GuaranteeRow(
                            icon: Icons.phone_android_rounded,
                            iconColor: ExternalBrandColors.whatsAppGreen,
                            title: 'Phone Number Hidden',
                            description:
                                'Your WhatsApp/Phone number is encrypted and stored '
                                'server-side only. It is never exposed to other users, '
                                'club admins, or in public leaderboards.',
                          ),
                          Divider(
                            height: 1,
                            color: ColorTokens.ghostBorder,
                          ),
                          _GuaranteeRow(
                            icon: Icons.shield_rounded,
                            iconColor: ColorTokens.clubAccent,
                            title: 'Anonymous Contributions',
                            description:
                                'MoMo contributions to fan clubs are logged using your '
                                'Fan ID and amount bracket only. Exact amounts and '
                                'phone numbers are not recorded.',
                          ),
                        ],
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 300.ms)
                        .slideY(begin: 0.03, end: 0, duration: 300.ms),

                    const SizedBox(height: SpacingTokens.spacing6),

                    // ══════════ Visibility Controls ══════════
                    Text(
                      'VISIBILITY CONTROLS',
                      style: TypographyTokens.editorialFont(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: ColorTokens.onSurfaceVariant,
                        letterSpacing: 1.6,
                      ),
                    ),
                    const SizedBox(height: SpacingTokens.spacing3),
                    ClayCard(
                      child: Column(
                        children: [
                          _VisibilityToggle(
                            icon: _showRealName
                                ? Icons.visibility
                                : Icons.visibility_off,
                            title: 'Show Real Name',
                            description:
                                'If OFF, your Fan ID is displayed on leaderboards '
                                'instead of your real name.',
                            value: _showRealName,
                            onChanged: _setShowRealName,
                          ),
                          Divider(
                            height: 1,
                            color: ColorTokens.ghostBorder,
                          ),
                          _VisibilityToggle(
                            icon: AfriIcons.search,
                            title: 'Findable by Phone',
                            description:
                                'Allows friends to find you by phone number. '
                                'Your number stays private.',
                            value: _findableByPhone,
                            onChanged: _setFindableByPhone,
                          ),
                        ],
                      ),
                    )
                        .animate(delay: 100.ms)
                        .fadeIn(duration: 300.ms)
                        .slideY(begin: 0.03, end: 0, duration: 300.ms),

                    const SizedBox(height: SpacingTokens.spacing6),

                    // ══════════ Privacy Badge ══════════
                    Container(
                      padding: const EdgeInsets.all(SpacingTokens.spacing5),
                      decoration: BoxDecoration(
                        color: ColorTokens.surfaceContainerLow,
                        borderRadius: ShapeTokens.cardRadius,
                        border: BorderTokens.ghost(),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: ColorTokens.success
                                  .withValues(alpha: 0.12),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.lock_rounded,
                              color: ColorTokens.success,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: SpacingTokens.spacing3),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Privacy First',
                                  style: TypographyTokens.titleSmall(),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'FANZONE does not sell, share, or expose '
                                  'your personal data. All identifiers '
                                  'on the platform are anonymised.',
                                  style: TypographyTokens.bodySmall(),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                        .animate(delay: 200.ms)
                        .fadeIn(duration: 300.ms),

                    const SizedBox(height: 80),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuaranteeRow extends StatelessWidget {
  const _GuaranteeRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SpacingTokens.spacing3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: iconColor.withValues(alpha: 0.12),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: SpacingTokens.spacing3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TypographyTokens.titleSmall()),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TypographyTokens.bodySmall(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VisibilityToggle extends StatelessWidget {
  const _VisibilityToggle({
    required this.icon,
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SpacingTokens.spacing3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ColorTokens.onSurfaceVariant.withValues(alpha: 0.1),
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 20,
              color: ColorTokens.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: SpacingTokens.spacing3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TypographyTokens.titleSmall()),
                const SizedBox(height: 2),
                Text(description, style: TypographyTokens.bodySmall()),
              ],
            ),
          ),
          const SizedBox(width: SpacingTokens.spacing2),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: ColorTokens.clubAccent,
          ),
        ],
      ),
    );
  }
}
