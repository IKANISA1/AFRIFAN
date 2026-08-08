import 'dart:async';

import 'package:core_l10n/core_l10n.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../prediction_providers.dart';

/// Privacy settings screen — core guarantees + visibility toggles.
///
/// Implements the universal privacy pattern: phone-hidden guarantee,
/// anonymous contributions guarantee, and tokenized visibility controls.
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

class _PrivacySettingsScreenState extends ConsumerState<PrivacySettingsScreen> {
  static const _showRealNameKey = 'privacy:show_real_name';
  static const _findableByPhoneKey = 'privacy:findable_by_phone';

  late bool _showRealName;
  late bool _findableByPhone;

  @override
  void initState() {
    super.initState();
    // Start with cached values for instant UI, then load from server.
    _showRealName = HiveCacheService.getJson<bool>(_showRealNameKey) ?? false;
    _findableByPhone =
        HiveCacheService.getJson<bool>(_findableByPhoneKey) ?? false;
    unawaited(_loadFromServer());
  }

  /// Loads current toggle values from the profiles table.
  Future<void> _loadFromServer() async {
    try {
      final repo = ref.read(predictionRepositoryProvider);
      final userId = repo.currentUserId;
      if (userId == null || userId.isEmpty) {
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
        final serverShowReal = row['privacy_show_real_name'] as bool? ?? false;
        final serverFindable =
            row['privacy_findable_by_phone'] as bool? ?? false;

        setState(() {
          _showRealName = serverShowReal;
          _findableByPhone = serverFindable;
        });

        unawaited(
          HiveCacheService.putJson(
            _showRealNameKey,
            serverShowReal,
            ttl: const Duration(days: 365),
          ),
        );
        unawaited(
          HiveCacheService.putJson(
            _findableByPhoneKey,
            serverFindable,
            ttl: const Duration(days: 365),
          ),
        );
      } else {
        return;
      }
    } catch (error, stackTrace) {
      AfriLogger.warn(
        'PrivacySettingsScreen',
        'Operation failed (non-critical).',
        error,
        stackTrace,
      );
      // Keep cached values if server is unavailable.
    }
  }

  void _setShowRealName(bool value) {
    setState(() => _showRealName = value);
    unawaited(
      HiveCacheService.putJson(
        _showRealNameKey,
        value,
        ttl: const Duration(days: 365),
      ),
    );
    unawaited(
      ref.read(predictionRepositoryProvider).updateProfile(<String, dynamic>{
        'privacy_show_real_name': value,
      }),
    );
  }

  void _setFindableByPhone(bool value) {
    setState(() => _findableByPhone = value);
    unawaited(
      HiveCacheService.putJson(
        _findableByPhoneKey,
        value,
        ttl: const Duration(days: 365),
      ),
    );
    unawaited(
      ref.read(predictionRepositoryProvider).updateProfile(<String, dynamic>{
        'privacy_findable_by_phone': value,
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AfriScreenScaffold(
      backgroundColor: ColorTokens.background,
      showAppBar: false,
      showBackButton: false,
      scrollable: false,
      constrainContent: false,
      bodyWrapper: (child) => GradientBackground(child: child),
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
                    AfriIconButton(
                      icon: AfriIcons.back,
                      onTap: () => context.pop(),
                      tooltip: context.afriL10n.gameBack,
                    ),
                    const SizedBox(width: SpacingTokens.spacing2),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.afriL10n.gameSettingsUpper,
                          style:
                              TypographyTokens.metricLabel(
                                ColorTokens.onSurfaceVariant,
                              ).copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.6,
                              ),
                        ),
                        Text(
                          context.afriL10n.gamePrivacyUpper,
                          style: TypographyTokens.headlineSmall().copyWith(
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
                    context.afriL10n.gameCoreGuarantees,
                    style: TypographyTokens.metricLabel(
                      ColorTokens.onSurfaceVariant,
                    ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.6),
                  ),
                  const SizedBox(height: SpacingTokens.spacing3),
                  AfriSurfaceCard(
                        child: Column(
                          children: [
                            _GuaranteeRow(
                              icon: AfriIcons.phone,
                              iconColor: ExternalBrandColors.whatsAppGreen,
                              title: context.afriL10n.gamePhoneNumberHidden,
                              description: context
                                  .afriL10n
                                  .gamePhoneNumberHiddenDescription,
                            ),
                            const AfriDivider(),
                            _GuaranteeRow(
                              icon: AfriIcons.privacy,
                              iconColor: ColorTokens.clubAccent,
                              title:
                                  context.afriL10n.gameAnonymousContributions,
                              description: context
                                  .afriL10n
                                  .gameAnonymousContributionsDescription,
                            ),
                          ],
                        ),
                      )
                      .afriAnimate(context)
                      .fadeIn(duration: 300.ms)
                      .slideY(begin: 0.03, end: 0, duration: 300.ms),

                  const SizedBox(height: SpacingTokens.spacing6),

                  // ══════════ Visibility Controls ══════════
                  Text(
                    context.afriL10n.gameVisibilityControls,
                    style: TypographyTokens.metricLabel(
                      ColorTokens.onSurfaceVariant,
                    ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.6),
                  ),
                  const SizedBox(height: SpacingTokens.spacing3),
                  AfriSurfaceCard(
                        child: Column(
                          children: [
                            _VisibilityToggle(
                              icon: _showRealName
                                  ? AfriIcons.visibility
                                  : AfriIcons.visibilityOff,
                              title: context.afriL10n.gameShowRealName,
                              description:
                                  context.afriL10n.gameShowRealNameDescription,
                              value: _showRealName,
                              onChanged: _setShowRealName,
                            ),
                            const AfriDivider(),
                            _VisibilityToggle(
                              icon: AfriIcons.search,
                              title: context.afriL10n.gameFindableByPhone,
                              description: context
                                  .afriL10n
                                  .gameFindableByPhoneDescription,
                              value: _findableByPhone,
                              onChanged: _setFindableByPhone,
                            ),
                          ],
                        ),
                      )
                      .afriAnimate(context, delay: 100.ms)
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
                              width: SpacingTokens.spacing12,
                              height: SpacingTokens.spacing12,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: ColorTokens.success.withValues(
                                  alpha: 0.12,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                AfriIcons.lock,
                                color: ColorTokens.success,
                                size: SpacingTokens.spacing6,
                              ),
                            ),
                            const SizedBox(width: SpacingTokens.spacing3),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    context.afriL10n.gamePrivacyFirst,
                                    style: TypographyTokens.titleSmall(),
                                  ),
                                  const SizedBox(
                                    height: SpacingTokens.spacing1 / 2,
                                  ),
                                  Text(
                                    context.afriL10n
                                        .gamePrivacyFirstDescription(
                                          RuntimeBranding.displayAppName,
                                        ),
                                    style: TypographyTokens.bodySmall(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                      .afriAnimate(context, delay: 200.ms)
                      .fadeIn(duration: 300.ms),

                  const SizedBox(height: SpacingTokens.spacing20),
                ]),
              ),
            ),
          ],
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
            width: SpacingTokens.spacing10,
            height: SpacingTokens.spacing10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: iconColor.withValues(alpha: 0.12),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: SpacingTokens.spacing5, color: iconColor),
          ),
          const SizedBox(width: SpacingTokens.spacing3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TypographyTokens.titleSmall()),
                const SizedBox(height: SpacingTokens.spacing1 / 2),
                Text(description, style: TypographyTokens.bodySmall()),
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
            width: SpacingTokens.spacing10,
            height: SpacingTokens.spacing10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ColorTokens.onSurfaceVariant.withValues(alpha: 0.1),
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: SpacingTokens.spacing5,
              color: ColorTokens.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: SpacingTokens.spacing3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TypographyTokens.titleSmall()),
                const SizedBox(height: SpacingTokens.spacing1 / 2),
                Text(description, style: TypographyTokens.bodySmall()),
              ],
            ),
          ),
          const SizedBox(width: SpacingTokens.spacing2),
          AfriSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
