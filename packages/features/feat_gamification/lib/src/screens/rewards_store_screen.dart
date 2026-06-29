import 'dart:async';

import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../fet_providers.dart';
import '../models/fet_models.dart';
import '../models/reward_store_content.dart';
import 'package:core_utils/core_utils.dart';

class RewardsStoreScreen extends ConsumerStatefulWidget {
  const RewardsStoreScreen({super.key});

  @override
  ConsumerState<RewardsStoreScreen> createState() => _RewardsStoreScreenState();
}

class _RewardsStoreScreenState extends ConsumerState<RewardsStoreScreen> {
  FetWalletSummary? _wallet;
  List<FetRewardOption> _rewardOptions = const <FetRewardOption>[];
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait<Object?>([
        ref.read(fetRepositoryProvider).loadWallet(),
        ref.read(fetRepositoryProvider).loadRewardStoreItems(),
      ]);
      final wallet = results[0] as FetWalletSummary?;
      final rewardOptions = results[1]! as List<FetRewardOption>;
      if (!mounted) {
        return;
      }
      setState(() {
        _wallet = wallet;
        _rewardOptions = rewardOptions;
        _isLoading = false;
        _error = null;
      });
    } catch (error, stackTrace) {
      AfriLogger.warn(
        'RewardsStoreScreen',
        'Operation failed (non-critical).',
        error,
        stackTrace,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _error = 'Rewards are temporarily unavailable.';
      });
    }
  }

  Future<void> _redeem(FetRewardOption option) async {
    final cost = option.costFet;
    if (cost <= 0 || _isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final fetRepository = ref.read(fetRepositoryProvider);
      final String snackbarMessage;
      if (option.id.isNotEmpty) {
        final result = await fetRepository.redeemReward(
          rewardItemId: option.id,
          note: 'FANZONE reward: ${option.reward}',
          idempotencyKey: 'reward-${option.id}',
        );
        snackbarMessage = result.message.isNotEmpty
            ? result.message
            : result.alreadyProcessed
            ? 'That reward redemption already completed.'
            : 'Redeemed ${option.reward} for ${option.cost}.';
      } else {
        final result = await fetRepository.redeemFet(
          amount: cost,
          note: 'FANZONE reward: ${option.reward}',
          idempotencyKey: 'reward-fallback-${option.slug}-${option.costFet}',
        );
        snackbarMessage = result.alreadyProcessed
            ? 'That reward redemption already completed.'
            : 'Redeemed ${option.reward} for ${option.cost}.';
      }
      if (!mounted) {
        return;
      }
      await _load();
      if (!mounted) {
        return;
      }
      AfriToast.success(context, snackbarMessage);
    } catch (error) {
      if (!mounted) {
        return;
      }
      AfriToast.error(
        context,
        error is Exception
            ? error.toString().replaceFirst('Exception: ', '')
            : 'Could not redeem this reward.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallet = _wallet;
    final rewardOptions = _rewardOptions;

    return Scaffold(
      backgroundColor: ColorTokens.background,
      appBar: AfriAppBar(
        backgroundColor: ColorTokens.transparent,
        title: Text(
          'REWARDS STORE',
          style: TypographyTokens.headlineSmall().copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        leading: AfriIconButton(
          icon: AfriIcons.back,
          onTap: () => context.pop(),
          tooltip: 'Back',
        ),
      ),
      body: _isLoading
          ? const Padding(
              padding: EdgeInsets.all(SpacingTokens.spacing6),
              child: AfriSkeletonList(),
            )
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(SpacingTokens.spacing6),
                child: AfriStateView.offline(
                  title: 'Rewards unavailable',
                  message: _error!,
                  actionLabel: 'Retry',
                  onAction: _load,
                ),
              ),
            )
          : AfriRefreshIndicator(
              onRefresh: _load,
              color: ColorTokens.clubAccent,
              child: ListView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: const EdgeInsets.all(SpacingTokens.spacing6),
                children: [
                  AfriSurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AVAILABLE BALANCE',
                          style: TypographyTokens.labelSmall(
                            ColorTokens.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: SpacingTokens.spacing2),
                        Text(
                          '${wallet?.balance ?? 0} FET',
                          style: TypographyTokens.displaySmall(
                            ColorTokens.clubAccent,
                          ).copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: SpacingTokens.spacing2),
                        Text(
                          'Redeem FANZONE rewards without leaving the consolidated wallet flow.',
                          style: TypographyTokens.bodyMedium(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: SpacingTokens.spacing4),
                  ...rewardOptions.map((option) {
                    final cost = option.costFet;
                    final affordable = (wallet?.balance ?? 0) >= cost;
                    return Padding(
                      padding: const EdgeInsets.only(
                        bottom: SpacingTokens.spacing3,
                      ),
                      child: GlassCard(
                        animate: false,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    option.reward,
                                    style: TypographyTokens.titleMedium(),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: SpacingTokens.spacing2,
                                    vertical: SpacingTokens.spacing1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: affordable
                                        ? ColorTokens.clubAccent.withValues(
                                            alpha: 0.14,
                                          )
                                        : ColorTokens.surfaceContainerHigh,
                                    borderRadius: BorderRadius.circular(
                                      ShapeTokens.radiusFull,
                                    ),
                                  ),
                                  child: Text(
                                    option.cost,
                                    style: TypographyTokens.labelSmall(
                                      affordable
                                          ? ColorTokens.clubAccent
                                          : ColorTokens.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: SpacingTokens.spacing2),
                            Text(
                              '${option.category} · ${option.notes}',
                              style: TypographyTokens.bodySmall(),
                            ),
                            const SizedBox(height: SpacingTokens.spacing4),
                            AfriButton(
                              onTap: affordable && !_isSubmitting
                                  ? () => _redeem(option)
                                  : () {},
                              label: affordable
                                  ? 'Redeem ${option.cost}'
                                  : 'Need ${option.cost}',
                              enabled: affordable && !_isSubmitting,
                              isLoading: _isSubmitting,
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }
}
