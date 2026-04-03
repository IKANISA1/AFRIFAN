import 'package:core_auth/core_auth.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/biopay_recovery_args.dart';
import '../models/biopay_task_result.dart';
import '../providers/biopay_providers.dart';
import '../services/biopay_auth_gate_service.dart';

/// BioPay Profile — identity hub for Face ID and MoMo setup
class BiopayProfileScreen extends ConsumerStatefulWidget {
  const BiopayProfileScreen({super.key});

  @override
  ConsumerState<BiopayProfileScreen> createState() => _BiopayProfileScreenState();
}

class _BiopayProfileScreenState extends ConsumerState<BiopayProfileScreen> {
  bool _isRevoking = false;

  Future<void> _revokeEnrollment() async {
    final confirmed = await showAfriBottomSheet<bool>(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Remove Face ID?',
            style: TypographyTokens.titleLarge(),
          ),
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
              title: 'DEVICE AUTH REQUIRED',
              message: 'Set up device security first.',
              primaryLabel: 'BACK',
              primaryRoute: '/biopay',
              secondaryLabel: 'RETRY',
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
          title: 'FACE ID REMOVED',
          message: 'You can re-enroll any time.',
          primaryLabel: 'BACK TO BIOPAY',
          primaryRoute: '/biopay',
          secondaryLabel: 'RE-ENROLL',
          secondaryRoute: '/biopay/register',
        ),
      );
    } catch (error) {
      if (!mounted) return;
      context.go(
        '/biopay/result',
        extra: BiopayTaskResultArgs(
          tone: BiopayTaskResultTone.error,
          title: 'FAILED',
          message: error.toString(),
          primaryLabel: 'TRY AGAIN',
          primaryRoute: '/biopay/profile',
          secondaryLabel: 'BACK',
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

    return Scaffold(
      backgroundColor: ColorTokens.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: ColorTokens.onSurface),
          onPressed: () => context.go('/biopay'),
        ),
        title: Text(
          'PROFILE',
          style: TypographyTokens.headlineLarge(),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SpacingTokens.spacing6,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Standard User Profile Header
              Center(
                child: Column(
                  children: [
                    const SizedBox(height: SpacingTokens.spacing4),
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(
                          Icons.person_rounded,
                          size: 48,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(height: SpacingTokens.spacing4),
                    // If biometric profile is not active, fallback to showing full name or blank
                    Text(
                      profileAsync.valueOrNull?.formattedAlias ?? 
                          userProfile?.fullName ?? 'BIOPAY USER',
                      style: TypographyTokens.displaySmall(),
                    ),
                    const SizedBox(height: SpacingTokens.spacing1),
                    Text(
                      'BIOPAY ID',
                      style: TypographyTokens.labelSmall().copyWith(
                        color: ColorTokens.onSurfaceVariant,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: SpacingTokens.spacing8),
                  ],
                ),
              ),

              // MoMo Configuration Block
              Text(
                'FINANCIAL CONFIGURATION',
                style: TypographyTokens.labelSmall().copyWith(
                  letterSpacing: 1.0,
                  color: ColorTokens.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: SpacingTokens.spacing2),
              GlassCard(
                onTap: () => context.push('/profile_setup'),
                padding: const EdgeInsets.symmetric(
                  horizontal: SpacingTokens.spacing4,
                  vertical: SpacingTokens.spacing3,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(SpacingTokens.spacing2),
                      decoration: BoxDecoration(
                        color: hasMomo
                            ? colorScheme.primary.withValues(alpha: 0.1)
                            : colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.bolt_rounded,
                        color: hasMomo
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: SpacingTokens.spacing4),
                    Expanded(
                      child: Text(
                        hasMomo ? 'MoMo Configured' : 'No MoMo Linked',
                        style: TypographyTokens.bodyLarge().copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (hasMomo)
                      const Icon(Icons.check_circle_rounded, color: ColorTokens.success)
                    else
                      Icon(Icons.chevron_right_rounded, color: colorScheme.onSurfaceVariant),
                  ],
                ),
              ),

              const SizedBox(height: SpacingTokens.spacing6),

              // Biometric Enrollment Block
              Text(
                'BIOMETRIC STATUS',
                style: TypographyTokens.labelSmall().copyWith(
                  letterSpacing: 1.0,
                  color: ColorTokens.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: SpacingTokens.spacing2),
              profileAsync.when(
                data: (profile) {
                  final isEnrolled = profile != null;
                  return GlassCard(
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
                      vertical: SpacingTokens.spacing3,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(SpacingTokens.spacing2),
                          decoration: BoxDecoration(
                            color: isEnrolled
                                ? ColorTokens.success.withValues(alpha: 0.1)
                                : ColorTokens.warning.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
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
                          child: Text(
                            isEnrolled ? 'Face Enrolled' : 'Pending Enrollment',
                            style: TypographyTokens.bodyLarge().copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Container(
                          width: 8,
                          height: 8,
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
                error: (_, __) => GlassCard(
                   child: Text(
                      'Failed to load biometric data.',
                      style: TypographyTokens.bodySmall().copyWith(color: ColorTokens.error),
                   ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
