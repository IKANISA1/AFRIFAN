import 'dart:async';

import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../fet_providers.dart';
import '../models/fet_models.dart';

class TokenHistoryScreen extends ConsumerStatefulWidget {
  const TokenHistoryScreen({super.key});

  @override
  ConsumerState<TokenHistoryScreen> createState() => _TokenHistoryScreenState();
}

class _TokenHistoryScreenState extends ConsumerState<TokenHistoryScreen> {
  FetWalletSummary? _wallet;
  List<FetWalletTransaction> _transactions = const <FetWalletTransaction>[];
  bool _isLoading = true;
  String _filter = 'all';
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final repo = ref.read(fetRepositoryProvider);
      final results = await Future.wait<Object?>([
        repo.loadWallet(),
        repo.loadWalletTransactions(limit: 100),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _wallet = results[0] as FetWalletSummary?;
        _transactions = results[1]! as List<FetWalletTransaction>;
        _isLoading = false;
        _error = null;
      });
    } catch (error, stackTrace) {
      AfriLogger.warn(
        'TokenHistoryScreen',
        'Operation failed (non-critical).',
        error,
        stackTrace,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _error = context.afriL10n.gameTokenHistoryTemporarilyUnavailable;
      });
    }
  }

  List<FetWalletTransaction> get _filteredTransactions {
    return _transactions
        .where((transaction) {
          if (_filter == 'credit') {
            return transaction.direction == FetWalletEntryDirection.credit;
          }
          if (_filter == 'debit') {
            return transaction.direction == FetWalletEntryDirection.debit;
          }
          return true;
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return AfriScreenScaffold(
      backgroundColor: ColorTokens.background,
      appBar: AfriAppBar(
        backgroundColor: ColorTokens.transparent,
        title: Text(
          context.afriL10n.gameTokenHistoryTitle,
          style: TypographyTokens.headlineSmall().copyWith(
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
                  title: context.afriL10n.gameHistoryUnavailable,
                  message: _error!,
                  actionLabel: context.afriL10n.gameRetry,
                  onAction: _load,
                ),
              ),
            )
          : AfriRefreshIndicator(
              onRefresh: _load,
              color: ColorTokens.primaryContainer,
              child: ListView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: const EdgeInsets.all(SpacingTokens.spacing6),
                children: [
                  AfriSurfaceCard(
                    child: Row(
                      children: [
                        Expanded(
                          child: _HistoryMetric(
                            label: context.afriL10n.gameBalance,
                            value: (_wallet?.balance ?? 0).toString(),
                          ),
                        ),
                        const SizedBox(width: SpacingTokens.spacing3),
                        Expanded(
                          child: _HistoryMetric(
                            label: context.afriL10n.gameEarned,
                            value: (_wallet?.lifetimeEarned ?? 0).toString(),
                          ),
                        ),
                        const SizedBox(width: SpacingTokens.spacing3),
                        Expanded(
                          child: _HistoryMetric(
                            label: context.afriL10n.gameSpent,
                            value: (_wallet?.lifetimeSpent ?? 0).toString(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: SpacingTokens.spacing4),
                  Wrap(
                    spacing: SpacingTokens.spacing2,
                    runSpacing: SpacingTokens.spacing2,
                    children: [
                      _HistoryFilterChip(
                        label: context.afriL10n.gameAllUpper,
                        selected: _filter == 'all',
                        onTap: () => setState(() => _filter = 'all'),
                      ),
                      _HistoryFilterChip(
                        label: context.afriL10n.gameEarnedUpperFilter,
                        selected: _filter == 'credit',
                        onTap: () => setState(() => _filter = 'credit'),
                      ),
                      _HistoryFilterChip(
                        label: context.afriL10n.gameSpentUpper,
                        selected: _filter == 'debit',
                        onTap: () => setState(() => _filter = 'debit'),
                      ),
                    ],
                  ),
                  const SizedBox(height: SpacingTokens.spacing4),
                  TokenHistoryTransactionList(
                    transactions: _filteredTransactions,
                  ),
                ],
              ),
            ),
    );
  }
}

class TokenHistoryTransactionList extends StatelessWidget {
  const TokenHistoryTransactionList({super.key, required this.transactions});

  final List<FetWalletTransaction> transactions;

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return const SizedBox.shrink(
        key: ValueKey<String>('token-history-empty'),
      );
    }

    return Column(
      children: transactions
          .map((transaction) {
            return Padding(
              padding: const EdgeInsets.only(bottom: SpacingTokens.spacing3),
              child: _TokenHistoryTransactionCard(transaction: transaction),
            );
          })
          .toList(growable: false),
    );
  }
}

class _TokenHistoryTransactionCard extends StatelessWidget {
  const _TokenHistoryTransactionCard({required this.transaction});

  final FetWalletTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final isCredit = transaction.direction == FetWalletEntryDirection.credit;
    final color = isCredit ? ColorTokens.success : ColorTokens.warning;
    final directionLabel = isCredit
        ? context.afriL10n.gameCredit
        : context.afriL10n.gameDebit;
    final dateLabel = _formatTokenHistoryDate(context, transaction.createdAt);
    final detail =
        transaction.note ??
        transaction.counterpartyDisplayName ??
        transaction.referenceType ??
        context.afriL10n.gameLedgerUpdate;

    return Semantics(
      container: true,
      label: context.afriL10n.gameTransactionSemantics(
        directionLabel,
        transaction.headline,
        detail,
        transaction.amount,
        transaction.balanceAfter,
        dateLabel,
      ),
      child: ExcludeSemantics(
        child: GlassCard(
          animate: false,
          child: Row(
            children: [
              Container(
                width: SpacingTokens.spacing10,
                height: SpacingTokens.spacing10,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(ShapeTokens.radiusMd),
                ),
                alignment: Alignment.center,
                child: Icon(
                  isCredit ? AfriIcons.incoming : AfriIcons.out,
                  color: color,
                  size: SpacingTokens.spacing5,
                ),
              ),
              const SizedBox(width: SpacingTokens.spacing3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.headline,
                      style: TypographyTokens.titleSmall(),
                    ),
                    const SizedBox(height: SpacingTokens.spacing1 / 2),
                    Text(detail, style: TypographyTokens.bodySmall()),
                    const SizedBox(height: SpacingTokens.spacing1 / 2),
                    Text(
                      dateLabel,
                      style: TypographyTokens.labelSmall(
                        ColorTokens.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: SpacingTokens.spacing3),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    context.afriL10n.gameWalletSignedPoints(
                      isCredit ? '+' : '-',
                      transaction.amount.toString(),
                    ),
                    style: TypographyTokens.titleMedium(
                      color,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    context.afriL10n.gameWalletBalance(
                      transaction.balanceAfter.toString(),
                    ),
                    style: TypographyTokens.bodySmall(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatTokenHistoryDate(BuildContext context, DateTime? value) {
  if (value == null) {
    return context.afriL10n.gameUnknownTime;
  }
  final local = value.toLocal();
  final materialL10n = MaterialLocalizations.of(context);
  return '${materialL10n.formatShortDate(local)} · '
      '${materialL10n.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
}

class _HistoryMetric extends StatelessWidget {
  const _HistoryMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      animate: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TypographyTokens.labelSmall(ColorTokens.onSurfaceVariant),
          ),
          const SizedBox(height: SpacingTokens.spacing1),
          Text(
            value,
            style: TypographyTokens.titleLarge().copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryFilterChip extends StatelessWidget {
  const _HistoryFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AfriPressFeedback(
      onTap: onTap,
      builder: (context, _) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: SpacingTokens.spacing3,
          vertical: SpacingTokens.spacing2,
        ),
        decoration: BoxDecoration(
          color: selected
              ? ColorTokens.primaryContainer.withValues(alpha: 0.16)
              : ColorTokens.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(ShapeTokens.radiusFull),
        ),
        child: Text(
          label,
          style: TypographyTokens.labelSmall(
            selected
                ? ColorTokens.primaryContainer
                : ColorTokens.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
