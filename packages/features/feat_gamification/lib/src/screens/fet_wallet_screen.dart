import 'dart:async';

import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/fet_wallet_provider.dart';
import '../widgets/fet_split_model.dart';
import '../widgets/fet_wallet_widgets.dart';

enum _WalletSection {
  earn('earn', 'Earn', AfriIcons.wallet),
  redeem('rewards', 'Redeem', AfriIcons.rewards),
  history('history', 'History', AfriIcons.history);

  const _WalletSection(this.value, this.label, this.icon);

  final String value;
  final String label;
  final IconData icon;

  static _WalletSection fromUri(Uri uri) {
    final raw = uri.queryParameters['section']?.trim().toLowerCase();
    return _WalletSection.values.firstWhere(
      (section) => section.value == raw,
      orElse: () => _WalletSection.earn,
    );
  }
}

/// Wallet screen for points balance and audited partner reward activity.
class FetWalletScreen extends ConsumerStatefulWidget {
  const FetWalletScreen({super.key});

  @override
  ConsumerState<FetWalletScreen> createState() => _FetWalletScreenState();
}

class _FetWalletScreenState extends ConsumerState<FetWalletScreen> {
  String _formatPoints(int value) {
    final digits = value.abs().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i += 1) {
      final remaining = digits.length - i;
      buffer.write(digits[i]);
      if (remaining > 1 && remaining % 3 == 1) {
        buffer.write(',');
      }
    }
    return value < 0 ? '-$buffer' : buffer.toString();
  }

  void _showOverflow() {
    unawaited(
      showAfriActionSheet(
        context: context,
        title: 'Wallet',
        actions: [
          AfriSheetAction(
            icon: AfriIcons.history,
            label: 'History',
            onTap: () => context.go('/fanzone/wallet?section=history'),
          ),
          AfriSheetAction(
            icon: AfriIcons.rewards,
            label: 'Redeem',
            onTap: () => context.go('/fanzone/wallet?section=rewards'),
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
              title: 'Points unavailable',
              message: 'Points data is temporarily unavailable.',
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
    final selectedSection = _WalletSection.fromUri(
      GoRouterState.of(context).uri,
    );

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
                  '${_formatPoints(wallet?.balance ?? 0)} pts',
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
                      '+${_formatPoints(wallet?.weeklyEarned ?? 0)}',
                    ),
                    _buildCompactStat(
                      'Monthly',
                      '+${_formatPoints(wallet?.monthlyEarned ?? 0)}',
                    ),
                    _buildCompactStat(
                      'Used',
                      _formatPoints(wallet?.lifetimeSpent ?? 0),
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
                      '${_formatPoints(wallet!.historicalBalanceGap)} points come from earlier rewards before activity history was enabled.',
                      style: TypographyTokens.bodySmall(),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: SpacingTokens.spacing6),
          _buildSectionSelector(selectedSection),
          const SizedBox(height: SpacingTokens.sectionGap),
          if (selectedSection == _WalletSection.earn) ...[
            FetSplitModel(currentTier: wallet?.tier ?? 'supporter'),
            const SizedBox(height: SpacingTokens.sectionGap),
            const AfriSectionHeader(title: 'Earn'),
            const SizedBox(height: SpacingTokens.spacing4),
            AfriSurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Earn points from partner initiatives and promotions.',
                    style: TypographyTokens.bodyMedium(),
                  ),
                  const SizedBox(height: SpacingTokens.spacing2),
                  Text(
                    'Use points in rewards, matchday activities, and fan-zone challenges.',
                    style: TypographyTokens.bodySmall(
                      ColorTokens.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (selectedSection == _WalletSection.redeem) ...[
            const AfriSectionHeader(title: 'Redeem'),
            const SizedBox(height: SpacingTokens.spacing4),
            AfriSurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rewards and partner offers now live inside Points.',
                    style: TypographyTokens.bodyMedium(),
                  ),
                  const SizedBox(height: SpacingTokens.spacing2),
                  Text(
                    'Use your points balance for matchday rewards, supporter perks, and partner offers without leaving this flow.',
                    style: TypographyTokens.bodySmall(
                      ColorTokens.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (selectedSection == _WalletSection.history) ...[
            AfriSectionHeader(
              title: 'History',
              trailing: Text(
                '${transactions.length}',
                style: TypographyTokens.labelSmall(
                  ColorTokens.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing4),
            if (transactions.isEmpty)
              AfriSurfaceCard(
                child: Text(
                  'Points activity appears here once you earn from partner initiatives or join partner activities.',
                  style: TypographyTokens.bodyMedium(
                    ColorTokens.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              )
            else
              ...transactions.map(
                (transaction) => Padding(
                  padding: const EdgeInsets.only(
                    bottom: SpacingTokens.spacing3,
                  ),
                  child: WalletTransactionRow(
                    transaction: transaction,
                    formatFet: _formatPoints,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionSelector(_WalletSection selectedSection) {
    return AfriSegmentedControl(
      items: _WalletSection.values
          .map(
            (section) => AfriSegment(label: section.label, icon: section.icon),
          )
          .toList(growable: false),
      selectedIndex: _WalletSection.values.indexOf(selectedSection),
      onChanged: (index) {
        final section = _WalletSection.values[index];
        context.go('/fanzone/wallet?section=${section.value}');
      },
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
