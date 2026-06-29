import 'dart:async';

import 'package:core_auth/core_auth.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../fet_providers.dart';
import '../models/fet_models.dart';

/// Shows the user's AFRICLUB Fan ID with profile-backed privacy state.
///
/// The displayed Fan ID comes from `profiles.public_user_id`, while the
/// visibility badges reflect the real privacy toggles persisted on the profile.
class FanIdScreen extends ConsumerStatefulWidget {
  const FanIdScreen({super.key});

  @override
  ConsumerState<FanIdScreen> createState() => _FanIdScreenState();
}

class _FanIdScreenState extends ConsumerState<FanIdScreen> {
  static const _showRealNameCacheKey = 'privacy:show_real_name';
  static const _findableByPhoneCacheKey = 'privacy:findable_by_phone';

  String _fanId = '------';
  String _tier = 'FAN';
  String? _displayName;
  String? _favoriteTeamSlug;
  bool _showRealName = false;
  bool _findableByPhone = false;
  bool _isVerified = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _showRealName =
        HiveCacheService.getJson<bool>(_showRealNameCacheKey) ?? false;
    _findableByPhone =
        HiveCacheService.getJson<bool>(_findableByPhoneCacheKey) ?? false;
    unawaited(_loadProfile());
  }

  Future<void> _loadProfile() async {
    final profile = ref.read(currentUserProvider);
    if (profile == null || profile.id.isEmpty) {
      if (!mounted) return;
      setState(() {
        _fanId = 'NOT SIGNED IN';
        _isLoading = false;
      });
      return;
    }

    FetWalletSummary? wallet;
    Map<String, dynamic>? profileRow;

    try {
      wallet = await ref.read(fetRepositoryProvider).loadWallet();
    } catch (error, stackTrace) {
      AfriLogger.warn(
        'FanIdScreen',
        'Operation failed (non-critical).',
        error,
        stackTrace,
      );
      wallet = null;
    }

    try {
      profileRow = await ref
          .read(supabaseClientProvider)
          .from('profiles')
          .select(
            'public_user_id, display_name, favorite_team_slug, '
            'privacy_show_real_name, privacy_findable_by_phone',
          )
          .eq('id', profile.id)
          .maybeSingle();
    } catch (error, stackTrace) {
      AfriLogger.warn(
        'FanIdScreen',
        'Operation failed (non-critical).',
        error,
        stackTrace,
      );
      profileRow = null;
    }

    final alias =
        _trimmedOrNull(profileRow?['public_user_id']) ??
        _trimmedOrNull(profile.publicUserId);
    final displayName =
        _trimmedOrNull(profileRow?['display_name']) ??
        _trimmedOrNull(profile.displayName);
    final favoriteTeamSlug =
        _trimmedOrNull(profileRow?['favorite_team_slug']) ??
        _trimmedOrNull(profile.favoriteTeamSlug);
    final showRealName =
        profileRow?['privacy_show_real_name'] as bool? ?? _showRealName;
    final findableByPhone =
        profileRow?['privacy_findable_by_phone'] as bool? ?? _findableByPhone;

    unawaited(
      HiveCacheService.putJson(
        _showRealNameCacheKey,
        showRealName,
        ttl: const Duration(days: 365),
      ),
    );
    unawaited(
      HiveCacheService.putJson(
        _findableByPhoneCacheKey,
        findableByPhone,
        ttl: const Duration(days: 365),
      ),
    );

    if (!mounted) return;
    setState(() {
      _fanId = _formatFanId(alias, profile.id);
      _tier = wallet?.tier ?? 'FAN';
      _displayName = displayName;
      _favoriteTeamSlug = favoriteTeamSlug;
      _showRealName = showRealName;
      _findableByPhone = findableByPhone;
      _isVerified = ref.read(isPhoneVerifiedProvider);
      _isLoading = false;
    });
  }

  List<_PrivacyBadgeData> get _privacyBadges {
    return <_PrivacyBadgeData>[
      _PrivacyBadgeData(
        icon: _showRealName && (_displayName?.isNotEmpty ?? false)
            ? AfriIcons.badge
            : AfriIcons.visibilityOff,
        label: _showRealName && (_displayName?.isNotEmpty ?? false)
            ? 'Display Name On'
            : 'Alias Only',
        description: _showRealName && (_displayName?.isNotEmpty ?? false)
            ? 'Leaderboards can show ${_displayName!} instead of only your Fan ID.'
            : 'Leaderboards show your Fan ID or alias instead of your real name.',
      ),
      const _PrivacyBadgeData(
        icon: AfriIcons.phone,
        label: 'Phone Hidden',
        description:
            'Your phone number stays server-side and is never shown to other supporters or club admins.',
      ),
      _PrivacyBadgeData(
        icon: _findableByPhone ? AfriIcons.friend : AfriIcons.profile,
        label: _findableByPhone ? 'Phone Discovery On' : 'Phone Discovery Off',
        description: _findableByPhone
            ? 'Friends who already know your phone number can find your profile.'
            : 'Phone-based discovery is currently disabled on your profile.',
      ),
      _PrivacyBadgeData(
        icon: _isVerified ? AfriIcons.verified : AfriIcons.statusPending,
        label: _isVerified ? 'Verified' : 'Verification Pending',
        description: _isVerified
            ? 'Your phone identity is verified for AFRICLUB earning and social flows.'
            : 'Verify your phone to unlock the full AFRICLUB social experience.',
      ),
    ];
  }

  List<String> get _identityRules {
    return <String>[
      'Your Fan ID is assigned from your profile and stays stable across the app.',
      if (_showRealName && (_displayName?.isNotEmpty ?? false))
        'Your display name "$_displayName" can appear on leaderboards until you turn that off.'
      else
        'Your real name stays hidden on leaderboards until you explicitly enable display-name visibility.',
      'Your phone number is encrypted and stored server-side only.',
      if (_findableByPhone)
        'Phone-based friend discovery is enabled on your account right now.'
      else
        'Phone-based friend discovery is disabled on your account right now.',
      if (_isVerified)
        'Your phone identity is verified for AFRICLUB features and rewards.'
      else
        'Phone verification is still pending for your AFRICLUB profile.',
      if (_favoriteTeamSlug != null)
        'Your profile is linked to ${_humanizeSlug(_favoriteTeamSlug!)} for personalization.'
      else
        'You can link a favorite team from onboarding or profile setup for personalization.',
      'Deleting your account removes your personal data and Fan ID mapping from the active profile.',
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorTokens.background,
      appBar: AfriAppBar(
        backgroundColor: ColorTokens.transparent,
        title: Text(
          'FAN ID',
          style: TypographyTokens.headlineMedium().copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.6,
          ),
        ),
        leading: AfriIconButton(
          icon: AfriIcons.back,
          onTap: () => context.pop(),
          tooltip: 'Back',
        ),
      ),
      body: GradientBackground(
        child: _isLoading
            ? const Padding(
                padding: EdgeInsets.all(SpacingTokens.spacing6),
                child: AfriSkeletonList(),
              )
            : ListView(
                padding: const EdgeInsets.all(SpacingTokens.spacing6),
                physics: const BouncingScrollPhysics(),
                children: [
                  AfriSurfaceCard(
                        padding: const EdgeInsets.all(SpacingTokens.spacing6),
                        child: Column(
                          children: [
                            Container(
                                  width:
                                      SpacingTokens.spacing20 +
                                      SpacingTokens.spacing2,
                                  height:
                                      SpacingTokens.spacing20 +
                                      SpacingTokens.spacing2,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: ColorTokens.borrowedGradient(
                                      colors: [
                                        ColorTokens.clubAccent,
                                        ColorTokens.clubAccent.withValues(
                                          alpha: 0.5,
                                        ),
                                      ],
                                    ),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      AfriIcons.fanzone,
                                      size: SpacingTokens.spacing10,
                                      color: ColorTokens.background,
                                    ),
                                  ),
                                )
                                .animate()
                                .scale(
                                  begin: const Offset(0.8, 0.8),
                                  end: const Offset(1, 1),
                                  duration: 600.ms,
                                  curve: Curves.easeOutBack,
                                )
                                .fadeIn(duration: 400.ms),
                            const SizedBox(height: SpacingTokens.spacing4),
                            Text(
                              'YOUR FAN ID',
                              style:
                                  TypographyTokens.metricLabel(
                                    ColorTokens.onSurfaceVariant,
                                  ).copyWith(
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 2,
                                  ),
                            ),
                            const SizedBox(height: SpacingTokens.spacing2),
                            Text(
                              _fanId,
                              style: TypographyTokens.displaySmall().copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: 4,
                              ),
                            ),
                            const SizedBox(height: SpacingTokens.spacing2),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: SpacingTokens.spacing3,
                                vertical: SpacingTokens.spacing1,
                              ),
                              decoration: BoxDecoration(
                                color: ColorTokens.clubAccent.withValues(
                                  alpha: 0.14,
                                ),
                                borderRadius: BorderRadius.circular(
                                  ShapeTokens.radiusFull,
                                ),
                              ),
                              child: Text(
                                _tier.toUpperCase(),
                                style: TypographyTokens.labelSmall(
                                  ColorTokens.clubAccent,
                                ),
                              ),
                            ),
                            if (_displayName?.isNotEmpty ?? false) ...[
                              const SizedBox(height: SpacingTokens.spacing3),
                              Text(
                                _showRealName
                                    ? _displayName!
                                    : 'Alias-only profile',
                                style: TypographyTokens.bodyMedium(),
                              ),
                            ],
                            const SizedBox(height: SpacingTokens.spacing4),
                            AfriPressFeedback(
                              onTap: () {
                                unawaited(
                                  Clipboard.setData(
                                    ClipboardData(text: _fanId),
                                  ),
                                );
                                unawaited(HapticFeedback.mediumImpact());
                                AfriToast.success(
                                  context,
                                  'Fan ID copied to clipboard.',
                                );
                              },
                              builder: (context, state) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: SpacingTokens.spacing4,
                                  vertical: SpacingTokens.spacing3,
                                ),
                                decoration: BoxDecoration(
                                  color: ColorTokens.surfaceContainerHigh,
                                  borderRadius: BorderRadius.circular(
                                    ShapeTokens.radiusMd,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      AfriIcons.copy,
                                      size: SpacingTokens.spacing4,
                                      color: ColorTokens.clubAccent,
                                    ),
                                    const SizedBox(
                                      width: SpacingTokens.spacing2,
                                    ),
                                    Text(
                                      'Copy to clipboard',
                                      style: TypographyTokens.labelSmall(
                                        ColorTokens.clubAccent,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                      .animate()
                      .fadeIn(duration: 400.ms)
                      .slideY(begin: 0.04, end: 0, duration: 400.ms),
                  const SizedBox(height: SpacingTokens.spacing6),
                  AfriSurfaceCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PRIVACY BADGES',
                              style: TypographyTokens.titleMedium().copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: SpacingTokens.spacing4),
                            Wrap(
                              spacing: SpacingTokens.spacing2,
                              runSpacing: SpacingTokens.spacing2,
                              children: _privacyBadges
                                  .map(
                                    (badge) => _PrivacyBadge(
                                      icon: badge.icon,
                                      label: badge.label,
                                      description: badge.description,
                                    ),
                                  )
                                  .toList(growable: false),
                            ),
                          ],
                        ),
                      )
                      .animate(delay: 100.ms)
                      .fadeIn(duration: 400.ms)
                      .slideY(begin: 0.04, end: 0, duration: 400.ms),
                  const SizedBox(height: SpacingTokens.spacing6),
                  AfriSurfaceCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'IDENTITY RULES',
                              style: TypographyTokens.titleMedium().copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: SpacingTokens.spacing2),
                            Text(
                              'How your Fan ID works based on your current profile settings.',
                              style: TypographyTokens.bodySmall(),
                            ),
                            const SizedBox(height: SpacingTokens.spacing4),
                            ..._identityRules.asMap().entries.map(
                              (entry) => Padding(
                                padding: const EdgeInsets.only(
                                  bottom: SpacingTokens.spacing3,
                                ),
                                child: _IdentityRuleRow(
                                  index: entry.key + 1,
                                  rule: entry.value,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                      .animate(delay: 200.ms)
                      .fadeIn(duration: 400.ms)
                      .slideY(begin: 0.04, end: 0, duration: 400.ms),
                  const SizedBox(height: SpacingTokens.spacing12),
                ],
              ),
      ),
    );
  }
}

class _PrivacyBadgeData {
  const _PrivacyBadgeData({
    required this.icon,
    required this.label,
    required this.description,
  });

  final IconData icon;
  final String label;
  final String description;
}

class _PrivacyBadge extends StatelessWidget {
  const _PrivacyBadge({
    required this.icon,
    required this.label,
    required this.description,
  });

  final IconData icon;
  final String label;
  final String description;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      animate: false,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: SpacingTokens.spacing10,
            height: SpacingTokens.spacing10,
            decoration: BoxDecoration(
              color: ColorTokens.clubAccent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(ShapeTokens.radiusMd),
            ),
            child: Icon(
              icon,
              size: SpacingTokens.spacing5,
              color: ColorTokens.clubAccent,
            ),
          ),
          const SizedBox(width: SpacingTokens.spacing3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TypographyTokens.labelSmall(
                    ColorTokens.onSurface,
                  ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.2),
                ),
                const SizedBox(height: SpacingTokens.spacing1),
                Text(description, style: TypographyTokens.bodySmall()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IdentityRuleRow extends StatelessWidget {
  const _IdentityRuleRow({required this.index, required this.rule});

  final int index;
  final String rule;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: SpacingTokens.spacing7,
          height: SpacingTokens.spacing7,
          decoration: BoxDecoration(
            color: ColorTokens.clubAccent.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(ShapeTokens.radiusFull),
          ),
          alignment: Alignment.center,
          child: Text(
            '$index',
            style: TypographyTokens.labelMedium(
              ColorTokens.clubAccent,
            ).copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(width: SpacingTokens.spacing3),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: SpacingTokens.spacing1),
            child: Text(rule, style: TypographyTokens.bodyMedium()),
          ),
        ),
      ],
    );
  }
}

String _formatFanId(String? publicUserId, String userId) {
  final alias = _trimmedOrNull(publicUserId);
  if (alias != null) {
    return 'FAN-${alias.toUpperCase()}';
  }

  final compactUserId = userId.replaceAll('-', '');
  final suffixLength = compactUserId.length < 6 ? compactUserId.length : 6;
  final suffix = compactUserId.substring(0, suffixLength);
  return 'FAN-${suffix.toUpperCase()}';
}

String? _trimmedOrNull(Object? value) {
  final trimmed = value?.toString().trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}

String _humanizeSlug(String value) {
  return value
      .split('-')
      .where((part) => part.trim().isNotEmpty)
      .map(
        (part) => '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
      )
      .join(' ');
}
