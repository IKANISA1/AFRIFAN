import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../fanzone_content.dart';
import '../fet_providers.dart';
import '../models/fet_models.dart';

class RewardsStoreScreen extends ConsumerStatefulWidget {
  const RewardsStoreScreen({super.key});

  @override
  ConsumerState<RewardsStoreScreen> createState() => _RewardsStoreScreenState();
}

class _RewardsStoreScreenState extends ConsumerState<RewardsStoreScreen> {
  FetWalletSummary? _wallet;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final wallet = await ref.read(fetRepositoryProvider).loadWallet();
      if (!mounted) {
        return;
      }
      setState(() {
        _wallet = wallet;
        _isLoading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _error = 'Rewards are temporarily unavailable.';
      });
    }
  }

  int _costFor(String costLabel) {
    return int.tryParse(costLabel.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  }

  Future<void> _redeem(FetRewardOption option) async {
    final cost = _costFor(option.cost);
    if (cost <= 0 || _isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final result = await ref
          .read(fetRepositoryProvider)
          .redeemFet(amount: cost, note: 'FANZONE reward: ${option.reward}');
      if (!mounted) {
        return;
      }
      await _load();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.alreadyProcessed
                ? 'That reward redemption already completed.'
                : 'Redeemed ${option.reward} for ${option.cost}.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is Exception
                ? error.toString().replaceFirst('Exception: ', '')
                : 'Could not redeem this reward.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
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

    return Scaffold(
      backgroundColor: ColorTokens.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'REWARDS STORE',
          style: TypographyTokens.monolithFont(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_rounded),
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
          : RefreshIndicator(
              onRefresh: _load,
              color: ColorTokens.clubAccent,
              child: ListView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: const EdgeInsets.all(SpacingTokens.spacing6),
                children: [
                  ClayCard(
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
                          style: TypographyTokens.monolithFont(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: ColorTokens.clubAccent,
                          ),
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
                  ...fetRewardOptions.map((option) {
                    final cost = _costFor(option.cost);
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
                                    borderRadius: BorderRadius.circular(999),
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
