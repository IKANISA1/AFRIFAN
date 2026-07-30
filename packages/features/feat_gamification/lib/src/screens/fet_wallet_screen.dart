import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/fet_wallet_provider.dart';
import '../widgets/fet_split_model.dart';
import '../widgets/fet_wallet_widgets.dart';

enum _WalletSection {
  earn('earn', 'Earn', AfriIcons.rewards),
  rewards('rewards', 'Rewards', AfriIcons.rewards),
  activity('history', 'Activity', AfriIcons.history);

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
  late bool _wasOnline;

  @override
  void initState() {
    super.initState();
    _wasOnline = ConnectivityService.isOnline;
    ConnectivityService.onlineNotifier.addListener(_handleConnectivityChange);
  }

  @override
  void dispose() {
    ConnectivityService.onlineNotifier.removeListener(
      _handleConnectivityChange,
    );
    super.dispose();
  }

  void _handleConnectivityChange() {
    final isOnline = ConnectivityService.isOnline;
    final restored = !_wasOnline && isOnline;
    _wasOnline = isOnline;
    if (!mounted) return;
    setState(() {});
    if (restored) {
      unawaited(ref.read(fetWalletRouteProvider.notifier).connectionRestored());
    }
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/fanzone');
    }
  }

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
        title: 'Rewards',
        actions: [
          AfriSheetAction(
            icon: AfriIcons.history,
            label: 'Activity',
            onTap: () => context.go('/fanzone/wallet?section=history'),
          ),
          AfriSheetAction(
            icon: AfriIcons.rewards,
            label: 'Rewards',
            onTap: () => context.go('/fanzone/wallet?section=rewards'),
          ),
          AfriSheetAction(
            icon: AfriIcons.refresh,
            label: 'Refresh',
            onTap: () =>
                unawaited(ref.read(fetWalletRouteProvider.notifier).refresh()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final asyncWallet = ref.watch(fetWalletRouteProvider);
    final enabled = ref.watch(fetWalletEnabledProvider);

    return AfriScreenScaffold(
      backgroundColor: ColorTokens.background,
      appBar: AfriAppBar(
        backgroundColor: ColorTokens.transparent,
        title: Text('Rewards', style: TypographyTokens.headlineSmall()),
        leading: AfriIconButton(
          key: const ValueKey<String>('fet-wallet-back'),
          icon: AfriIcons.back,
          onTap: _close,
          tooltip: 'Back',
        ),
        actions: [
          AfriIconButton(
            key: const ValueKey<String>('fet-wallet-more'),
            icon: AfriIcons.more,
            onTap: enabled ? _showOverflow : null,
            tooltip: 'More options',
          ),
        ],
      ),
      scrollable: false,
      constrainContent: true,
      child: !enabled
          ? _WalletConsequence(
              title: 'Rewards unavailable',
              body: 'Points and reward activity are disabled for this build.',
              actionLabel: 'BACK TO FAN ZONE',
              onAction: _close,
            )
          : asyncWallet.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(SpacingTokens.spacing6),
                child: AfriSkeletonList(),
              ),
              error: (error, __) => _buildInitialFailure(error),
              data: (snapshot) => snapshot.isEmpty
                  ? _WalletConsequence(
                      key: const ValueKey<String>('fet-wallet-empty'),
                      title: 'No points activity yet',
                      body:
                          'Your confirmed points balance and reward activity will appear here.',
                      actionLabel: 'BACK TO FAN ZONE',
                      onAction: _close,
                    )
                  : _buildContent(snapshot),
            ),
    );
  }

  Widget _buildInitialFailure(Object error) {
    final failure = FetWalletFailure.fromError(error);
    return switch (failure.kind) {
      FetWalletFailureKind.offline => _WalletConsequence(
        title: 'Rewards offline',
        body:
            'Reconnect to load your confirmed points balance. Nothing is queued offline.',
        actionLabel: 'BACK TO FAN ZONE',
        onAction: _close,
      ),
      FetWalletFailureKind.permissionDenied => _WalletConsequence(
        title: 'Rewards access denied',
        body: 'This account cannot open the private points ledger.',
        actionLabel: 'BACK TO FAN ZONE',
        onAction: _close,
      ),
      FetWalletFailureKind.securityTimeout => _WalletConsequence(
        title: 'Points check timed out',
        body:
            'The app could not confirm your private points ledger in time. Try one bounded refresh.',
        actionLabel: 'TRY AGAIN',
        onAction: () => ref.read(fetWalletRouteProvider.notifier).refresh(),
      ),
      _ => _WalletConsequence(
        title: 'Rewards unavailable',
        body:
            'Your points ledger could not be loaded. No private activity details were shown.',
        actionLabel: 'TRY AGAIN',
        onAction: () => ref.read(fetWalletRouteProvider.notifier).refresh(),
      ),
    };
  }

  Widget _buildContent(FetWalletSnapshot snapshot) {
    final wallet = snapshot.wallet;
    final transactions = snapshot.transactions;
    final selectedSection = _WalletSection.fromUri(
      GoRouterState.of(context).uri,
    );

    return AfriRefreshIndicator(
      onRefresh: () => ref.read(fetWalletRouteProvider.notifier).refresh(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          SpacingTokens.spacing6,
          SpacingTokens.spacing4,
          SpacingTokens.spacing6,
          SpacingTokens.spacing12,
        ),
        children: [
          if (_statusFor(snapshot) case final status?) ...[
            status,
            const SizedBox(height: SpacingTokens.spacing4),
          ],
          GlassCard(
            padding: const EdgeInsets.symmetric(
              horizontal: SpacingTokens.spacing6,
              vertical: SpacingTokens.spacing8,
            ),
            child: Column(
              children: [
                Text(
                  'Points balance',
                  style: TypographyTokens.labelSmall(
                    ColorTokens.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: SpacingTokens.spacing3),
                Text(
                  '${_formatPoints(wallet?.balance ?? 0)} pts',
                  style: TypographyTokens.metricValue(
                    ColorTokens.accessibleMetricColor(ColorTokens.clubAccent),
                  ),
                ),
                const SizedBox(height: SpacingTokens.spacing3),
                AfriStatusChip(
                  label: wallet?.tier ?? 'imena',
                  tone: AfriStatusTone.live,
                ),
                const SizedBox(height: SpacingTokens.spacing8),
                Wrap(
                  alignment: WrapAlignment.spaceAround,
                  runAlignment: WrapAlignment.center,
                  spacing: SpacingTokens.spacing4,
                  runSpacing: SpacingTokens.spacing4,
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
          if (selectedSection == _WalletSection.rewards) ...[
            const AfriSectionHeader(title: 'Rewards'),
            const SizedBox(height: SpacingTokens.spacing4),
            AfriSurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Use points for matchday perks and partner rewards.',
                    style: TypographyTokens.bodyMedium(),
                  ),
                  const SizedBox(height: SpacingTokens.spacing2),
                  Text(
                    'Available rewards appear here when the club or partners publish them.',
                    style: TypographyTokens.bodySmall(
                      ColorTokens.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (selectedSection == _WalletSection.activity) ...[
            AfriSectionHeader(
              title: 'Activity',
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
                  'Points activity appears after partner rewards or matchday actions.',
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

  Widget? _statusFor(FetWalletSnapshot snapshot) {
    if (!ConnectivityService.isOnline ||
        snapshot.failure?.kind == FetWalletFailureKind.offline) {
      return const AfriStateBanner(
        icon: AfriIcons.offline,
        title: 'Showing saved points',
        subtitle:
            'Reconnect for the latest balance and activity. No action is queued offline.',
        tone: AfriStateBannerTone.warning,
      );
    }
    if (snapshot.phase == FetWalletPhase.syncing) {
      return const AfriStateBanner(
        icon: AfriIcons.refresh,
        title: 'Refreshing points',
        subtitle:
            'The confirmed balance stays visible while the latest ledger loads.',
        tone: AfriStateBannerTone.info,
      );
    }
    return switch (snapshot.failure?.kind) {
      FetWalletFailureKind.conflict => AfriStateBanner(
        icon: AfriIcons.warning,
        title: 'Points changed elsewhere',
        subtitle:
            'The saved balance stays visible. Refresh to confirm the latest ledger.',
        tone: AfriStateBannerTone.warning,
        onTap: () => ref.read(fetWalletRouteProvider.notifier).refresh(),
      ),
      FetWalletFailureKind.securityTimeout => AfriStateBanner(
        icon: AfriIcons.warning,
        title: 'Points refresh timed out',
        subtitle: 'The saved balance is still shown. Try one bounded refresh.',
        tone: AfriStateBannerTone.danger,
        onTap: () => ref.read(fetWalletRouteProvider.notifier).refresh(),
      ),
      FetWalletFailureKind.unknown => AfriStateBanner(
        icon: AfriIcons.warning,
        title: 'Points may be out of date',
        subtitle:
            'The last confirmed balance stays visible while service is unavailable.',
        tone: AfriStateBannerTone.warning,
        onTap: () => ref.read(fetWalletRouteProvider.notifier).refresh(),
      ),
      _ when snapshot.phase == FetWalletPhase.degraded => AfriStateBanner(
        icon: AfriIcons.warning,
        title: 'Showing saved points',
        subtitle:
            'The last confirmed balance stays visible until refresh succeeds.',
        tone: AfriStateBannerTone.warning,
        onTap: () => ref.read(fetWalletRouteProvider.notifier).refresh(),
      ),
      _ => null,
    };
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

class _WalletConsequence extends StatelessWidget {
  const _WalletConsequence({
    super.key,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(SpacingTokens.spacing6),
        child: AfriStateView.empty(
          title: title,
          message: body,
          actionLabel: actionLabel,
          onAction: onAction,
        ),
      ),
    );
  }
}
