import 'dart:async';

import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../fet_providers.dart';
import '../game_result_copy.dart';
import '../models/fet_models.dart';
import '../models/reward_store_content.dart';

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
        _error = context.afriL10n.gameRewardsTemporarilyUnavailable;
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
      if (option.id.isEmpty) {
        throw StateError('reward_configuration_missing');
      }
      final result = await fetRepository.redeemReward(
        rewardItemId: option.id,
        note: '${RuntimeBranding.displayAppName} reward: ${option.reward}',
        idempotencyKey: 'reward-${option.id}',
      );
      if (!mounted) {
        return;
      }
      snackbarMessage = result.message.isNotEmpty
          ? context.localizeGameResultMessage(result.message)
          : result.alreadyProcessed
          ? context.afriL10n.gameRewardAlreadyRedeemed
          : context.afriL10n.gameRewardRedeemed(option.reward, option.cost);
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
        error is StateError && error.message == 'reward_configuration_missing'
            ? context.afriL10n.gameRewardConfigurationMissing
            : context.afriL10n.gameRewardCouldNotRedeem,
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

    return AfriScreenScaffold(
      backgroundColor: ColorTokens.background,
      appBar: AfriAppBar(
        backgroundColor: ColorTokens.transparent,
        title: Text(
          context.afriL10n.gameRewardsStoreTitle,
          style: TypographyTokens.headlineSmall().copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
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
      child: _isLoading
          ? const Padding(
              padding: EdgeInsets.all(SpacingTokens.spacing6),
              child: AfriSkeletonList(),
            )
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(SpacingTokens.spacing6),
                child: AfriStateView.offline(
                  title: context.afriL10n.gameRewardsUnavailable,
                  message: _error!,
                  actionLabel: context.afriL10n.gameRetry,
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
                          context.afriL10n.gameAvailableBalance,
                          style: TypographyTokens.labelSmall(
                            ColorTokens.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: SpacingTokens.spacing2),
                        Text(
                          context.afriL10n.gamePointBalance(
                            wallet?.balance ?? 0,
                          ),
                          style: TypographyTokens.displaySmall(
                            ColorTokens.clubAccent,
                          ).copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: SpacingTokens.spacing2),
                        Text(
                          context.afriL10n.gameRewardsStoreDescription(
                            RuntimeBranding.displayAppName,
                          ),
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
                              context.afriL10n.gameRewardMeta(
                                option.category,
                                option.notes,
                              ),
                              style: TypographyTokens.bodySmall(),
                            ),
                            const SizedBox(height: SpacingTokens.spacing4),
                            AfriButton(
                              onTap: affordable && !_isSubmitting
                                  ? () => _redeem(option)
                                  : () {},
                              label: affordable
                                  ? context.afriL10n.gameRedeemCost(option.cost)
                                  : context.afriL10n.gameNeedCost(option.cost),
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
