import 'dart:async';

import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/fet_wallet_provider.dart';
import '../widgets/fet_split_model.dart';
import '../widgets/fet_wallet_widgets.dart';

/// FET Wallet screen — balance and audited partner reward activity.
///
/// Uses [FetWalletNotifier] via Riverpod for wallet data state.
class FetWalletScreen extends ConsumerStatefulWidget {
  const FetWalletScreen({super.key});

  @override
  ConsumerState<FetWalletScreen> createState() => _FetWalletScreenState();
}

class _FetWalletScreenState extends ConsumerState<FetWalletScreen> {
  String _formatFet(int value) {
    return CurrencyFormatter(
      currencyCode: 'FET',
      currencySymbol: 'FET',
    ).formatPlain(value);
  }

  void _showOverflow() {
    unawaited(
      showAfriActionSheet(
        context: context,
        title: 'Wallet',
        actions: [
          AfriSheetAction(
            icon: AfriIcons.history,
            label: 'Token history',
            onTap: () => unawaited(context.push('/fanzone/history')),
          ),
          AfriSheetAction(
            icon: AfriIcons.rewards,
            label: 'Rewards store',
            onTap: () => unawaited(context.push('/fanzone/rewards')),
          ),
          AfriSheetAction(
            icon: AfriIcons.refresh,
            label: 'Refresh',
            onTap: () =>
                unawaited(ref.read(fetWalletProvider.notifier).refresh()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final asyncWallet = ref.watch(fetWalletProvider);

    return Scaffold(
      backgroundColor: ColorTokens.background,
      appBar: AfriAppBar(
        backgroundColor: ColorTokens.transparent,
        title: Text('Wallet', style: TypographyTokens.headlineSmall()),
        leading: AfriIconButton(
          icon: AfriIcons.back,
          onTap: () => context.pop(),
          tooltip: 'Back',
        ),
        actions: [
          AfriIconButton(
            icon: AfriIcons.more,
            onTap: _showOverflow,
            tooltip: 'More options',
          ),
        ],
      ),
      body: asyncWallet.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(SpacingTokens.spacing6),
          child: AfriSkeletonList(),
        ),
        error: (_, __) => Center(
          child: Padding(
            padding: const EdgeInsets.all(SpacingTokens.spacing6),
            child: AfriStateView.offline(
              title: 'Wallet unavailable',
              message: 'Wallet data is temporarily unavailable.',
              actionLabel: 'Retry',
              onAction: () => ref.read(fetWalletProvider.notifier).refresh(),
            ),
          ),
        ),
        data: (snapshot) => _buildContent(snapshot),
      ),
    );
  }

  Widget _buildContent(FetWalletSnapshot snapshot) {
    final wallet = snapshot.wallet;
    final transactions = snapshot.transactions;

    return AfriRefreshIndicator(
      onRefresh: () => ref.read(fetWalletProvider.notifier).refresh(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          SpacingTokens.spacing6,
          SpacingTokens.spacing4,
          SpacingTokens.spacing6,
          SpacingTokens.spacing12,
        ),
        children: [
          GlassCard(
            padding: const EdgeInsets.symmetric(
              horizontal: SpacingTokens.spacing6,
              vertical: SpacingTokens.spacing8,
            ),
            child: Column(
              children: [
                Text(
                  'Current Balance',
                  style: TypographyTokens.labelSmall(
                    ColorTokens.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: SpacingTokens.spacing3),
                Text(
                  '${_formatFet(wallet?.balance ?? 0)} FET',
                  style: TypographyTokens.metricValue(ColorTokens.clubAccent),
                ),
                const SizedBox(height: SpacingTokens.spacing3),
                AfriStatusChip(
                  label: wallet?.tier ?? 'imena',
                  tone: AfriStatusTone.live,
                ),
                const SizedBox(height: SpacingTokens.spacing8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildCompactStat(
                      'Weekly',
                      '+${_formatFet(wallet?.weeklyEarned ?? 0)}',
                    ),
                    _buildCompactStat(
                      'Monthly',
                      '+${_formatFet(wallet?.monthlyEarned ?? 0)}',
                    ),
                    _buildCompactStat(
                      'Used',
                      _formatFet(wallet?.lifetimeSpent ?? 0),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if ((wallet?.historicalBalanceGap ?? 0) > 0) ...[
            const SizedBox(height: SpacingTokens.spacing4),
            AfriSurfaceCard(
              child: Row(
                children: [
                  const Icon(
                    AfriIcons.statusInfo,
                    size: SpacingTokens.spacing5,
                  ),
                  const SizedBox(width: SpacingTokens.spacing3),
                  Expanded(
                    child: Text(
                      '${_formatFet(wallet!.historicalBalanceGap)} FET comes from earlier rewards before wallet history was enabled.',
                      style: TypographyTokens.bodySmall(),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: SpacingTokens.spacing6),
          FetSplitModel(currentTier: wallet?.tier ?? 'supporter'),
          const SizedBox(height: SpacingTokens.sectionGap),
          const AfriSectionHeader(title: 'Partner rewards'),
          const SizedBox(height: SpacingTokens.spacing4),
          AfriSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Earn FET from partner initiatives and promotions.',
                  style: TypographyTokens.bodyMedium(),
                ),
                const SizedBox(height: SpacingTokens.spacing2),
                Text(
                  'Use FET in partner match pools, rewards, and fan-zone activity.',
                  style: TypographyTokens.bodySmall(
                    ColorTokens.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: SpacingTokens.sectionGap),
          AfriSectionHeader(
            title: 'Activity',
            trailing: Text(
              '${transactions.length}',
              style: TypographyTokens.labelSmall(ColorTokens.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing4),
          if (transactions.isEmpty)
            AfriSurfaceCard(
              child: Text(
                'Wallet activity appears here once you earn FET from partner initiatives or join partner pools.',
                style: TypographyTokens.bodyMedium(
                  ColorTokens.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            )
          else
            ...transactions.map(
              (transaction) => Padding(
                padding: const EdgeInsets.only(bottom: SpacingTokens.spacing3),
                child: WalletTransactionRow(
                  transaction: transaction,
                  formatFet: _formatFet,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCompactStat(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TypographyTokens.labelSmall(ColorTokens.onSurfaceVariant),
        ),
        const SizedBox(height: SpacingTokens.spacing1),
        Text(value, style: TypographyTokens.titleMedium()),
      ],
    );
  }
}
