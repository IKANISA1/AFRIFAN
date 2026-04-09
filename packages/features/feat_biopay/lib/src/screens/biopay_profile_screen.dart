import 'package:core_auth/core_auth.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/biopay_recovery_args.dart';
import '../models/biopay_task_result.dart';
import '../providers/biopay_providers.dart';
import '../services/biopay_auth_gate_service.dart';
import '../widgets/biopay_branding.dart';

/// BioPay Profile — identity hub for Face ID and MoMo setup
class BiopayProfileScreen extends ConsumerStatefulWidget {
  const BiopayProfileScreen({super.key});

  @override
  ConsumerState<BiopayProfileScreen> createState() =>
      _BiopayProfileScreenState();
}

class _BiopayProfileScreenState extends ConsumerState<BiopayProfileScreen> {
  bool _isRevoking = false;

  Future<void> _revokeEnrollment() async {
    final confirmed = await showAfriBottomSheet<bool>(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Remove Face ID?', style: TypographyTokens.titleLarge()),
          const SizedBox(height: SpacingTokens.spacing4),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: SpacingTokens.spacing3),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: ColorTokens.error,
                  ),
                  child: const Text('Remove'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isRevoking = true);

    try {
      final gate = await ref
          .read(biopayAuthGateServiceProvider)
          .authorize(BiopayAuthAction.revocation);

      if (!mounted) return;
      if (!gate.isAuthorized) {
        if (gate.status == BiopayAuthGateStatus.unavailable ||
            gate.status == BiopayAuthGateStatus.lockedOut) {
          context.push(
            '/biopay/recovery',
            extra: const BiopayRecoveryArgs(
              issue: BiopayRecoveryIssue.deviceAuth,
              title: 'Device Auth Required',
              message: 'Set up device security first.',
              primaryLabel: 'Back',
              primaryRoute: '/biopay',
              secondaryLabel: 'Retry',
              secondaryRoute: '/biopay/profile',
            ),
          );
        }
        return;
      }

      await ref.read(biopayRepositoryProvider).revoke(reason: 'user_requested');
      ref.invalidate(biopayProfileProvider);

      if (!mounted) return;
      context.go(
        '/biopay/result',
        extra: const BiopayTaskResultArgs(
          tone: BiopayTaskResultTone.success,
          title: 'Face ID Removed',
          message: 'You can re-enroll any time.',
          primaryLabel: 'Back to BioPay',
          primaryRoute: '/biopay',
          secondaryLabel: 'Re-enroll',
          secondaryRoute: '/biopay/register',
        ),
      );
    } catch (error) {
      if (!mounted) return;
      context.go(
        '/biopay/result',
        extra: BiopayTaskResultArgs(
          tone: BiopayTaskResultTone.error,
          title: 'Failed',
          message: error.toString(),
          primaryLabel: 'Try Again',
          primaryRoute: '/biopay/profile',
          secondaryLabel: 'Back',
          secondaryRoute: '/biopay',
        ),
      );
    } finally {
      if (mounted) setState(() => _isRevoking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(biopayProfileProvider);
    final userProfile = ref.watch(currentUserProvider);
    final hasMomo = userProfile?.hasMomo == true;
    final colorScheme = Theme.of(context).colorScheme;
    final appName = biopayAppName(context);
    final primaryColor = biopayPrimary(context);
    final accentColor = biopayAccent(context);

    return Scaffold(
      backgroundColor: ColorTokens.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: ColorTokens.onSurface),
          onPressed: () => context.go('/biopay'),
        ),
        title: Text('Profile', style: TypographyTokens.titleLarge()),
      ),
      body: BiopayMoodBackground(
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: SpacingTokens.spacing6,
              vertical: SpacingTokens.spacing2,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: SpacingTokens.spacing4),
                BiopayHeroCard(
                  eyebrow: '$appName MEMBER ID',
                  title:
                      profileAsync.valueOrNull?.formattedAlias ??
                      userProfile?.fullName ??
                      'BioPay User',
                  subtitle:
                      profileAsync.valueOrNull?.maskedRecipientValue ??
                      userProfile?.momoNumber ??
                      'Link a payment route to receive supporter transfers.',
                  trailing: Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: primaryColor.withValues(alpha: 0.22),
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.person_rounded,
                        size: 42,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  bottom: Wrap(
                    spacing: SpacingTokens.spacing2,
                    runSpacing: SpacingTokens.spacing2,
                    children: [
                      BiopayBadge(
                        icon: Icons.badge_outlined,
                        label:
                            'BioPay ID ${profileAsync.valueOrNull?.publicAlias ?? userProfile?.publicUserId ?? '--'}',
                        tint: primaryColor.withValues(alpha: 0.14),
                      ),
                      BiopayBadge(
                        icon: hasMomo
                            ? Icons.bolt_rounded
                            : Icons.bolt_outlined,
                        label: hasMomo ? 'Wallet Linked' : 'Wallet Missing',
                        tint: hasMomo
                            ? ColorTokens.success.withValues(alpha: 0.14)
                            : accentColor.withValues(alpha: 0.14),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: SpacingTokens.spacing8),

                Text(
                  'Financial Configuration',
                  style: TypographyTokens.labelSmall().copyWith(
                    color: ColorTokens.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: SpacingTokens.spacing2),
                ClayCard(
                  backgroundColor: ColorTokens.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(32),
                  onTap: () => context.push('/profile_setup'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: SpacingTokens.spacing4,
                    vertical: SpacingTokens.spacing4,
                  ),
                  semanticsLabel: 'Open mobile money setup',
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: hasMomo
                              ? primaryColor.withValues(alpha: 0.12)
                              : colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          Icons.bolt_rounded,
                          color: hasMomo
                              ? primaryColor
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: SpacingTokens.spacing4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              hasMomo ? 'MoMo Configured' : 'No MoMo Linked',
                              style: TypographyTokens.titleMedium().copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: SpacingTokens.spacing1),
                            Text(
                              hasMomo
                                  ? (userProfile?.momoNumber ??
                                        'Linked payment route')
                                  : 'Add the number or merchant code supporters should pay.',
                              style: TypographyTokens.bodySmall().copyWith(
                                color: ColorTokens.onSurfaceVariant,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: SpacingTokens.spacing2),
                      if (hasMomo)
                        const Icon(
                          Icons.check_circle_rounded,
                          color: ColorTokens.success,
                        )
                      else
                        Icon(
                          Icons.chevron_right_rounded,
                          color: colorScheme.onSurfaceVariant,
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: SpacingTokens.spacing6),

                Text(
                  'Biometric Status',
                  style: TypographyTokens.labelSmall().copyWith(
                    color: ColorTokens.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: SpacingTokens.spacing2),
                profileAsync.when(
                  data: (profile) {
                    final isEnrolled = profile != null;
                    return ClayCard(
                      backgroundColor: ColorTokens.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(32),
                      onTap: () {
                        if (_isRevoking) return;
                        if (isEnrolled) {
                          _revokeEnrollment();
                        } else {
                          context.push('/biopay/register');
                        }
                      },
                      padding: const EdgeInsets.symmetric(
                        horizontal: SpacingTokens.spacing4,
                        vertical: SpacingTokens.spacing4,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: isEnrolled
                                  ? ColorTokens.success.withValues(alpha: 0.1)
                                  : ColorTokens.warning.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(
                              isEnrolled
                                  ? Icons.face_retouching_natural_rounded
                                  : Icons.face_outlined,
                              color: isEnrolled
                                  ? ColorTokens.success
                                  : ColorTokens.warning,
                            ),
                          ),
                          const SizedBox(width: SpacingTokens.spacing4),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isEnrolled
                                      ? 'Face Enrolled'
                                      : 'Pending Enrollment',
                                  style: TypographyTokens.titleMedium()
                                      .copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: SpacingTokens.spacing1),
                                Text(
                                  isEnrolled
                                      ? 'Your face can authorize BioPay handoffs for supporters.'
                                      : 'Capture your face once to unlock club-branded scan payments.',
                                  style: TypographyTokens.bodySmall().copyWith(
                                    color: ColorTokens.onSurfaceVariant,
                                    height: 1.35,
                                  ),
                                ),
                                if (isEnrolled) ...[
                                  const SizedBox(
                                    height: SpacingTokens.spacing2,
                                  ),
                                  Text(
                                    _isRevoking
                                        ? 'Removing enrollment...'
                                        : 'Tap to remove and re-enroll',
                                    style: TypographyTokens.labelSmall()
                                        .copyWith(
                                          color: ColorTokens.onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (_isRevoking)
                            const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            Container(
                              width: 10,
                              height: 10,
                              margin: const EdgeInsets.only(top: 8),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isEnrolled
                                    ? ColorTokens.success
                                    : ColorTokens.warning,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                  loading: () => const AfriSkeletonList(itemCount: 1),
                  error: (_, __) => ClayCard(
                    backgroundColor: ColorTokens.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(32),
                    child: Text(
                      'Failed to load biometric data.',
                      style: TypographyTokens.bodySmall().copyWith(
                        color: ColorTokens.error,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
