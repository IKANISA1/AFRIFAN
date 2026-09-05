import 'dart:async';

import 'package:core_auth/core_auth.dart';
import 'package:core_feature_config/core_feature_config.dart';
import 'package:core_l10n/core_l10n.dart';
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

/// Shows the user's runtime-branded Fan ID with profile-backed privacy state.
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
    final storePolicy = ref.read(storeReleasePolicyProvider);
    final profile = ref.read(currentUserProvider);
    if (profile == null || profile.id.isEmpty) {
      if (!mounted) return;
      setState(() {
        _fanId = '';
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
        storePolicy.allowsCrossUserText &&
        (profileRow?['privacy_show_real_name'] as bool? ?? _showRealName);
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

  List<_PrivacyBadgeData> _privacyBadges(
    BuildContext context, {
    required bool showRealName,
  }) {
    return <_PrivacyBadgeData>[
      _PrivacyBadgeData(
        icon: showRealName && (_displayName?.isNotEmpty ?? false)
            ? AfriIcons.badge
            : AfriIcons.visibilityOff,
        label: showRealName && (_displayName?.isNotEmpty ?? false)
            ? context.afriL10n.gameDisplayNameOn
            : context.afriL10n.gameAliasOnly,
        description: showRealName && (_displayName?.isNotEmpty ?? false)
            ? context.afriL10n.gameDisplayNameOnDescription(_displayName!)
            : context.afriL10n.gameAliasOnlyDescription,
      ),
      _PrivacyBadgeData(
        icon: AfriIcons.phone,
        label: context.afriL10n.gamePhoneHidden,
        description: context.afriL10n.gamePhoneHiddenDescription,
      ),
      _PrivacyBadgeData(
        icon: _findableByPhone ? AfriIcons.friend : AfriIcons.profile,
        label: _findableByPhone
            ? context.afriL10n.gamePhoneDiscoveryOn
            : context.afriL10n.gamePhoneDiscoveryOff,
        description: _findableByPhone
            ? context.afriL10n.gamePhoneDiscoveryOnDescription
            : context.afriL10n.gamePhoneDiscoveryOffDescription,
      ),
      _PrivacyBadgeData(
        icon: _isVerified ? AfriIcons.verified : AfriIcons.statusPending,
        label: _isVerified
            ? context.afriL10n.gameVerified
            : context.afriL10n.gameVerificationPending,
        description: _isVerified
            ? context.afriL10n.gameVerifiedDescription(
                RuntimeBranding.displayAppName,
              )
            : context.afriL10n.gameVerificationPendingDescription(
                RuntimeBranding.displayAppName,
              ),
      ),
    ];
  }

  List<String> _identityRules(
    BuildContext context, {
    required bool showRealName,
  }) {
    return <String>[
      context.afriL10n.gameFanIdPersistentRule,
      if (showRealName && (_displayName?.isNotEmpty ?? false))
        context.afriL10n.gameDisplayNameVisibleRule(_displayName!)
      else
        context.afriL10n.gameRealNameHiddenRule,
      context.afriL10n.gamePhoneEncryptedRule,
      if (_findableByPhone)
        context.afriL10n.gamePhoneDiscoveryEnabledRule
      else
        context.afriL10n.gamePhoneDiscoveryDisabledRule,
      if (_isVerified)
        context.afriL10n.gamePhoneVerifiedRule(RuntimeBranding.displayAppName)
      else
        context.afriL10n.gamePhonePendingRule(RuntimeBranding.displayAppName),
      if (_favoriteTeamSlug != null)
        context.afriL10n.gameTeamLinkedRule(_humanizeSlug(_favoriteTeamSlug!))
      else
        context.afriL10n.gameLinkTeamRule,
      context.afriL10n.gameDeleteAccountRule,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final allowsCrossUserText = ref.watch(
      storeReleasePolicyProvider.select((policy) => policy.allowsCrossUserText),
    );
    final showRealName = allowsCrossUserText && _showRealName;
    return AfriScreenScaffold(
      backgroundColor: ColorTokens.background,
      appBar: AfriAppBar(
        backgroundColor: ColorTokens.transparent,
        title: Text(
          context.afriL10n.gameFanIdTitle,
          style: TypographyTokens.headlineMedium().copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: TypographyTokens.trackingNone,
          ),
        ),
        leading: AfriIconButton(
          icon: AfriIcons.back,
          onTap: () => context.pop(),
          tooltip: context.afriL10n.gameBack,
        ),
      ),
      scrollable: false,
      constrainContent: true,
      bodyWrapper: (child) => GradientBackground(child: child),
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
                                  gradient: ColorTokens.universalGradient(
                                    colors: [
                                      ColorTokens.primaryContainer,
                                      ColorTokens.primaryContainer.withValues(
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
                              .afriAnimate(context)
                              .scale(
                                begin: const Offset(0.8, 0.8),
                                end: const Offset(1, 1),
                                duration: 600.ms,
                                curve: Curves.easeOutBack,
                              )
                              .fadeIn(duration: 400.ms),
                          const SizedBox(height: SpacingTokens.spacing4),
                          Text(
                            context.afriL10n.gameYourFanId,
                            style:
                                TypographyTokens.metricLabel(
                                  ColorTokens.onSurfaceVariant,
                                ).copyWith(
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: TypographyTokens.trackingNone,
                                ),
                          ),
                          const SizedBox(height: SpacingTokens.spacing2),
                          Text(
                            _fanId.isEmpty
                                ? context.afriL10n.gameNotSignedIn
                                : _fanId,
                            style: TypographyTokens.displaySmall().copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: TypographyTokens.trackingNone,
                            ),
                          ),
                          const SizedBox(height: SpacingTokens.spacing2),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: SpacingTokens.spacing3,
                              vertical: SpacingTokens.spacing1,
                            ),
                            decoration: BoxDecoration(
                              color: ColorTokens.primaryContainer.withValues(
                                alpha: 0.14,
                              ),
                              borderRadius: BorderRadius.circular(
                                ShapeTokens.radiusFull,
                              ),
                            ),
                            child: Text(
                              _tier.toUpperCase() == 'FAN'
                                  ? context.afriL10n.gameTierFan
                                  : _tier.toUpperCase(),
                              style: TypographyTokens.labelSmall(
                                ColorTokens.primaryContainer,
                              ),
                            ),
                          ),
                          if (_displayName?.isNotEmpty ?? false) ...[
                            const SizedBox(height: SpacingTokens.spacing3),
                            Text(
                              showRealName
                                  ? _displayName!
                                  : context.afriL10n.gameAliasOnlyProfile,
                              style: TypographyTokens.bodyMedium(),
                            ),
                          ],
                          const SizedBox(height: SpacingTokens.spacing4),
                          AfriPressFeedback(
                            onTap: () {
                              unawaited(
                                Clipboard.setData(ClipboardData(text: _fanId)),
                              );
                              unawaited(HapticFeedback.mediumImpact());
                              AfriToast.success(
                                context,
                                context.afriL10n.gameFanIdCopied,
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
                                    color: ColorTokens.primaryContainer,
                                  ),
                                  const SizedBox(width: SpacingTokens.spacing2),
                                  Text(
                                    context.afriL10n.gameCopyToClipboard,
                                    style: TypographyTokens.labelSmall(
                                      ColorTokens.primaryContainer,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                    .afriAnimate(context)
                    .fadeIn(duration: 400.ms)
                    .slideY(begin: 0.04, end: 0, duration: 400.ms),
                const SizedBox(height: SpacingTokens.spacing6),
                AfriSurfaceCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.afriL10n.gamePrivacyBadges,
                            style: TypographyTokens.titleMedium().copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: TypographyTokens.trackingNone,
                            ),
                          ),
                          const SizedBox(height: SpacingTokens.spacing4),
                          Wrap(
                            spacing: SpacingTokens.spacing2,
                            runSpacing: SpacingTokens.spacing2,
                            children:
                                _privacyBadges(
                                      context,
                                      showRealName: showRealName,
                                    )
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
                    .afriAnimate(context, delay: 100.ms)
                    .fadeIn(duration: 400.ms)
                    .slideY(begin: 0.04, end: 0, duration: 400.ms),
                const SizedBox(height: SpacingTokens.spacing6),
                AfriSurfaceCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.afriL10n.gameIdentityRules,
                            style: TypographyTokens.titleMedium().copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: TypographyTokens.trackingNone,
                            ),
                          ),
                          const SizedBox(height: SpacingTokens.spacing2),
                          Text(
                            context.afriL10n.gameIdentityRulesDescription,
                            style: TypographyTokens.bodySmall(),
                          ),
                          const SizedBox(height: SpacingTokens.spacing4),
                          ..._identityRules(
                            context,
                            showRealName: showRealName,
                          ).asMap().entries.map(
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
                    .afriAnimate(context, delay: 200.ms)
                    .fadeIn(duration: 400.ms)
                    .slideY(begin: 0.04, end: 0, duration: 400.ms),
                const SizedBox(height: SpacingTokens.spacing12),
              ],
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
              color: ColorTokens.primaryContainer.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(ShapeTokens.radiusMd),
            ),
            child: Icon(
              icon,
              size: SpacingTokens.spacing5,
              color: ColorTokens.primaryContainer,
            ),
          ),
          const SizedBox(width: SpacingTokens.spacing3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TypographyTokens.labelSmall(ColorTokens.onSurface)
                      .copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: TypographyTokens.trackingNone,
                      ),
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
            color: ColorTokens.primaryContainer.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(ShapeTokens.radiusFull),
          ),
          alignment: Alignment.center,
          child: Text(
            index.toString(),
            style: TypographyTokens.labelMedium(
              ColorTokens.primaryContainer,
            ).copyWith(fontWeight: FontWeight.w600),
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
