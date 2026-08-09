import 'dart:async';

import 'package:core_feature_config/core_feature_config.dart';
import 'package:core_l10n/core_l10n.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/fet_wallet_provider.dart';
import '../widgets/fet_split_model.dart';
import '../widgets/fet_wallet_widgets.dart';

enum _WalletSection {
  earn('earn', AfriIcons.rewards),
  rewards('rewards', AfriIcons.rewards),
  activity('history', AfriIcons.history);

  const _WalletSection(this.value, this.icon);

  final String value;
  final IconData icon;

  static _WalletSection fromUri(Uri uri, {required bool allowsRewards}) {
    final raw = uri.queryParameters['section']?.trim().toLowerCase();
    final selected = _WalletSection.values.firstWhere(
      (section) => section.value == raw,
      orElse: () => _WalletSection.earn,
    );
    if (selected == _WalletSection.rewards && !allowsRewards) {
      return _WalletSection.earn;
    }
    return selected;
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
    final storePolicy = ref.read(storeReleasePolicyProvider);
    unawaited(
      showAfriActionSheet(
        context: context,
        title: storePolicy.allowsRewardRedemption
            ? context.afriL10n.gameRewardsLabel
            : context.afriL10n.gamePointsLabel,
        actions: [
          AfriSheetAction(
            icon: AfriIcons.history,
            label: context.afriL10n.gameActivity,
            onTap: () => context.go('/fanzone/wallet?section=history'),
          ),
          if (storePolicy.allowsRewardRedemption)
            AfriSheetAction(
              icon: AfriIcons.rewards,
              label: context.afriL10n.gameRewardsLabel,
              onTap: () => context.go('/fanzone/wallet?section=rewards'),
            ),
          AfriSheetAction(
            icon: AfriIcons.refresh,
            label: context.afriL10n.gameRefresh,
            onTap: () =>
                unawaited(ref.read(fetWalletRouteProvider.notifier).refresh()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.afriL10n;
    final asyncWallet = ref.watch(fetWalletRouteProvider);
    final enabled = ref.watch(fetWalletEnabledProvider);
    final storePolicy = ref.watch(storeReleasePolicyProvider);

    return AfriScreenScaffold(
      backgroundColor: ColorTokens.background,
      appBar: AfriAppBar(
        backgroundColor: ColorTokens.transparent,
        title: Text(
          storePolicy.allowsRewardRedemption
              ? l10n.gameRewardsLabel
              : l10n.gamePointsLabel,
          style: TypographyTokens.headlineSmall(),
        ),
        leading: AfriIconButton(
          key: const ValueKey<String>('fet-wallet-back'),
          icon: AfriIcons.back,
          onTap: _close,
          tooltip: l10n.gameBack,
        ),
        actions: [
          AfriIconButton(
            key: const ValueKey<String>('fet-wallet-more'),
            icon: AfriIcons.more,
            onTap: enabled ? _showOverflow : null,
            tooltip: l10n.gameMoreOptions,
          ),
        ],
      ),
      scrollable: false,
      constrainContent: true,
      child: !enabled
          ? _WalletConsequence(
              title: l10n.walletRewardsUnavailable,
              body: l10n.walletDisabledBody,
              actionLabel: l10n.venueBackToFanZone,
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
                      title: l10n.walletNoActivity,
                      body: l10n.walletNoActivityBody,
                      actionLabel: l10n.venueBackToFanZone,
                      onAction: _close,
                    )
                  : _buildContent(snapshot, storePolicy),
            ),
    );
  }

  Widget _buildInitialFailure(Object error) {
    final l10n = context.afriL10n;
    final failure = FetWalletFailure.fromError(error);
    return switch (failure.kind) {
      FetWalletFailureKind.offline => _WalletConsequence(
        title: l10n.walletOffline,
        body: l10n.walletOfflineBody,
        actionLabel: l10n.venueBackToFanZone,
        onAction: _close,
      ),
      FetWalletFailureKind.permissionDenied => _WalletConsequence(
        title: l10n.walletAccessDenied,
        body: l10n.walletAccessDeniedBody,
        actionLabel: l10n.venueBackToFanZone,
        onAction: _close,
      ),
      FetWalletFailureKind.securityTimeout => _WalletConsequence(
        title: l10n.walletCheckTimedOut,
        body: l10n.walletCheckTimedOutBody,
        actionLabel: l10n.venueTryAgain,
        onAction: () => ref.read(fetWalletRouteProvider.notifier).refresh(),
      ),
      _ => _WalletConsequence(
        title: l10n.walletRewardsUnavailable,
        body: l10n.walletUnavailableBody,
        actionLabel: l10n.venueTryAgain,
        onAction: () => ref.read(fetWalletRouteProvider.notifier).refresh(),
      ),
    };
  }

  Widget _buildContent(
    FetWalletSnapshot snapshot,
    StoreReleasePolicy storePolicy,
  ) {
    final l10n = context.afriL10n;
    final wallet = snapshot.wallet;
    final transactions = snapshot.transactions;
    final selectedSection = _WalletSection.fromUri(
      GoRouterState.of(context).uri,
      allowsRewards: storePolicy.allowsRewardRedemption,
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
                  l10n.gamePointsBalanceTitle,
                  style: TypographyTokens.labelSmall(
                    ColorTokens.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: SpacingTokens.spacing3),
                Text(
                  l10n.walletBalanceValue(_formatPoints(wallet?.balance ?? 0)),
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
                      l10n.gameWeekly,
                      '+${_formatPoints(wallet?.weeklyEarned ?? 0)}',
                    ),
                    _buildCompactStat(
                      l10n.gameMonthly,
                      '+${_formatPoints(wallet?.monthlyEarned ?? 0)}',
                    ),
                    _buildCompactStat(
                      l10n.walletUsed,
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
                      l10n.walletHistoricalPoints(
                        _formatPoints(wallet!.historicalBalanceGap),
                      ),
                      style: TypographyTokens.bodySmall(),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: SpacingTokens.spacing6),
          _buildSectionSelector(selectedSection, storePolicy),
          const SizedBox(height: SpacingTokens.sectionGap),
          if (selectedSection == _WalletSection.earn) ...[
            if (storePolicy.allowsPaidDigitalMembership) ...[
              FetSplitModel(currentTier: wallet?.tier ?? 'supporter'),
              const SizedBox(height: SpacingTokens.sectionGap),
            ],
            AfriSectionHeader(title: l10n.walletEarn),
            const SizedBox(height: SpacingTokens.spacing4),
            AfriSurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.walletEarnBody,
                    style: TypographyTokens.bodyMedium(),
                  ),
                  if (storePolicy.allowsRewardRedemption) ...[
                    const SizedBox(height: SpacingTokens.spacing2),
                    Text(
                      l10n.walletUseBody,
                      style: TypographyTokens.bodySmall(
                        ColorTokens.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (storePolicy.allowsRewardRedemption &&
              selectedSection == _WalletSection.rewards) ...[
            AfriSectionHeader(title: l10n.gameRewardsLabel),
            const SizedBox(height: SpacingTokens.spacing4),
            AfriSurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.walletRewardsBody,
                    style: TypographyTokens.bodyMedium(),
                  ),
                  const SizedBox(height: SpacingTokens.spacing2),
                  Text(
                    l10n.walletRewardsEmptyBody,
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
              title: l10n.gameActivity,
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
                  l10n.walletActivityEmptyBody,
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
    final l10n = context.afriL10n;
    if (!ConnectivityService.isOnline ||
        snapshot.failure?.kind == FetWalletFailureKind.offline) {
      return AfriStateBanner(
        icon: AfriIcons.offline,
        title: l10n.walletShowingSaved,
        subtitle: l10n.walletShowingSavedBody,
        tone: AfriStateBannerTone.warning,
      );
    }
    if (snapshot.phase == FetWalletPhase.syncing) {
      return AfriStateBanner(
        icon: AfriIcons.refresh,
        title: l10n.walletRefreshing,
        subtitle: l10n.walletRefreshingBody,
        tone: AfriStateBannerTone.info,
      );
    }
    return switch (snapshot.failure?.kind) {
      FetWalletFailureKind.conflict => AfriStateBanner(
        icon: AfriIcons.warning,
        title: l10n.walletChangedElsewhere,
        subtitle: l10n.walletChangedElsewhereBody,
        tone: AfriStateBannerTone.warning,
        onTap: () => ref.read(fetWalletRouteProvider.notifier).refresh(),
      ),
      FetWalletFailureKind.securityTimeout => AfriStateBanner(
        icon: AfriIcons.warning,
        title: l10n.walletRefreshTimedOut,
        subtitle: l10n.walletRefreshTimedOutBody,
        tone: AfriStateBannerTone.danger,
        onTap: () => ref.read(fetWalletRouteProvider.notifier).refresh(),
      ),
      FetWalletFailureKind.unknown => AfriStateBanner(
        icon: AfriIcons.warning,
        title: l10n.walletMayBeOutdated,
        subtitle: l10n.walletMayBeOutdatedBody,
        tone: AfriStateBannerTone.warning,
        onTap: () => ref.read(fetWalletRouteProvider.notifier).refresh(),
      ),
      _ when snapshot.phase == FetWalletPhase.degraded => AfriStateBanner(
        icon: AfriIcons.warning,
        title: l10n.walletShowingSaved,
        subtitle: l10n.walletSavedUntilRefresh,
        tone: AfriStateBannerTone.warning,
        onTap: () => ref.read(fetWalletRouteProvider.notifier).refresh(),
      ),
      _ => null,
    };
  }

  Widget _buildSectionSelector(
    _WalletSection selectedSection,
    StoreReleasePolicy storePolicy,
  ) {
    final sections = _WalletSection.values
        .where(
          (section) =>
              section != _WalletSection.rewards ||
              storePolicy.allowsRewardRedemption,
        )
        .toList(growable: false);
    return AfriSegmentedControl(
      items: sections
          .map(
            (section) => AfriSegment(
              label: switch (section) {
                _WalletSection.earn => context.afriL10n.walletEarn,
                _WalletSection.rewards => context.afriL10n.gameRewardsLabel,
                _WalletSection.activity => context.afriL10n.gameActivity,
              },
              icon: section.icon,
            ),
          )
          .toList(growable: false),
      selectedIndex: sections.indexOf(selectedSection),
      onChanged: (index) {
        final section = sections[index];
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
