import 'dart:async';
import 'dart:math';

import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../fet_providers.dart';
import '../models/fet_models.dart';
import '../widgets/fet_split_model.dart';

class FetWalletScreen extends ConsumerStatefulWidget {
  const FetWalletScreen({super.key});

  @override
  ConsumerState<FetWalletScreen> createState() => _FetWalletScreenState();
}

class _FetWalletScreenState extends ConsumerState<FetWalletScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _transferAmountController =
      TextEditingController();
  final TextEditingController _transferNoteController = TextEditingController();
  final TextEditingController _redeemAmountController = TextEditingController();
  final TextEditingController _redeemNoteController = TextEditingController();
  final Random _random = Random();

  FetWalletSummary? _wallet;
  List<FetWalletTransaction> _transactions = const <FetWalletTransaction>[];
  List<FetWalletSupporter> _supporterMatches = const <FetWalletSupporter>[];
  FetWalletSupporter? _selectedSupporter;
  bool _isLoading = true;
  bool _isSubmittingTransfer = false;
  bool _isSubmittingRedemption = false;
  bool _isSearching = false;
  String? _error;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _loadWallet();
    _searchController.addListener(_handleSearchChanged);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();
    _transferAmountController.dispose();
    _transferNoteController.dispose();
    _redeemAmountController.dispose();
    _redeemNoteController.dispose();
    super.dispose();
  }

  Future<void> _loadWallet() async {
    try {
      final repository = ref.read(fetRepositoryProvider);
      final results = await Future.wait<Object?>([
        repository.loadWallet(),
        repository.loadWalletTransactions(limit: 40),
      ]);

      if (!mounted) {
        return;
      }

      setState(() {
        _wallet = results[0] as FetWalletSummary?;
        _transactions = results[1] as List<FetWalletTransaction>;
        _isLoading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _error = 'Wallet data is temporarily unavailable.';
      });
    }
  }

  void _handleSearchChanged() {
    final query = _searchController.text.trim();
    _searchDebounce?.cancel();
    if (query.length < 2) {
      setState(() {
        _supporterMatches = const <FetWalletSupporter>[];
        _isSearching = false;
      });
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 250), () async {
      setState(() {
        _isSearching = true;
      });
      try {
        final matches = await ref
            .read(fetRepositoryProvider)
            .findSupporters(query, limit: 6);
        if (!mounted) {
          return;
        }
        setState(() {
          _supporterMatches = matches;
          _isSearching = false;
        });
      } catch (_) {
        if (!mounted) {
          return;
        }
        setState(() {
          _supporterMatches = const <FetWalletSupporter>[];
          _isSearching = false;
        });
      }
    });
  }

  Future<void> _submitTransfer() async {
    final selectedSupporter = _selectedSupporter;
    final amount = int.tryParse(
      _transferAmountController.text.replaceAll(RegExp(r'[^0-9]'), ''),
    );

    if (selectedSupporter == null) {
      _showMessage('Choose a supporter to receive the transfer.');
      return;
    }
    if (amount == null || amount <= 0) {
      _showMessage('Enter a valid FET amount to transfer.');
      return;
    }

    setState(() {
      _isSubmittingTransfer = true;
    });

    try {
      final result = await ref
          .read(fetRepositoryProvider)
          .transferFet(
            recipientUserId: selectedSupporter.userId,
            amount: amount,
            note: _transferNoteController.text.trim().isEmpty
                ? null
                : _transferNoteController.text.trim(),
            idempotencyKey: _operationKey('transfer'),
          );

      if (!mounted) {
        return;
      }

      _transferAmountController.clear();
      _transferNoteController.clear();
      _searchController.clear();
      setState(() {
        _selectedSupporter = null;
        _supporterMatches = const <FetWalletSupporter>[];
      });
      await _loadWallet();
      _showMessage(
        result.alreadyProcessed
            ? 'That transfer was already processed.'
            : 'Transferred ${_formatFet(amount)} FET.',
      );
    } catch (error) {
      _showMessage(
        error is Exception
            ? error.toString().replaceFirst('Exception: ', '')
            : 'Transfer failed.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingTransfer = false;
        });
      }
    }
  }

  Future<void> _submitRedemption() async {
    final amount = int.tryParse(
      _redeemAmountController.text.replaceAll(RegExp(r'[^0-9]'), ''),
    );
    if (amount == null || amount <= 0) {
      _showMessage('Enter a valid FET amount to redeem.');
      return;
    }

    setState(() {
      _isSubmittingRedemption = true;
    });

    try {
      final result = await ref
          .read(fetRepositoryProvider)
          .redeemFet(
            amount: amount,
            note: _redeemNoteController.text.trim().isEmpty
                ? null
                : _redeemNoteController.text.trim(),
            idempotencyKey: _operationKey('redeem'),
          );

      if (!mounted) {
        return;
      }

      _redeemAmountController.clear();
      _redeemNoteController.clear();
      await _loadWallet();
      _showMessage(
        result.alreadyProcessed
            ? 'That redemption was already processed.'
            : 'Redeemed ${_formatFet(amount)} FET.',
      );
    } catch (error) {
      _showMessage(
        error is Exception
            ? error.toString().replaceFirst('Exception: ', '')
            : 'Redemption failed.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingRedemption = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _operationKey(String operation) {
    final micros = DateTime.now().toUtc().microsecondsSinceEpoch;
    return '$operation-$micros-${_random.nextInt(1 << 32)}';
  }

  String _formatFet(int value) {
    return CurrencyFormatter(
      currencyCode: 'FET',
      currencySymbol: 'FET',
    ).formatPlain(value);
  }

  String _formatCounterparty(FetWalletTransaction transaction) {
    final displayName = transaction.counterpartyDisplayName;
    final alias = transaction.counterpartyPublicUserId;
    if (displayName != null && displayName.trim().isNotEmpty) {
      return alias != null && alias.trim().isNotEmpty
          ? '$displayName · #$alias'
          : displayName;
    }
    if (alias != null && alias.trim().isNotEmpty) {
      return '#$alias';
    }
    return 'Supporter';
  }

  Color _transactionColor(FetWalletTransaction transaction) {
    return transaction.direction == FetWalletEntryDirection.credit
        ? ColorTokens.success
        : ColorTokens.warning;
  }

  IconData _transactionIcon(FetWalletTransaction transaction) {
    switch (transaction.entryType) {
      case 'transfer_in':
        return Icons.call_received_rounded;
      case 'transfer_out':
        return Icons.call_made_rounded;
      case 'redeem':
        return Icons.redeem_rounded;
      case 'admin_adjustment':
        return Icons.tune_rounded;
      case 'opening_balance':
        return Icons.account_balance_wallet_rounded;
      case 'earn':
      default:
        return Icons.stars_rounded;
    }
  }

  void _showOverflow() {
    showAfriActionSheet(
      context: context,
      title: 'Wallet',
      actions: [
        AfriSheetAction(
          icon: AfriIcons.history,
          label: 'Token history',
          onTap: () => context.push('/fanzone/history'),
        ),
        AfriSheetAction(
          icon: AfriIcons.rewards,
          label: 'Rewards store',
          onTap: () => context.push('/fanzone/rewards'),
        ),
        AfriSheetAction(
          icon: AfriIcons.refresh,
          label: 'Refresh',
          onTap: _loadWallet,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final wallet = _wallet;

    return Scaffold(
      backgroundColor: ColorTokens.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'FET WALLET',
          style: TypographyTokens.monolithFont(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
          ),
        ),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(AfriIcons.back),
        ),
        actions: [
          IconButton(
            onPressed: _showOverflow,
            icon: const Icon(AfriIcons.more),
            tooltip: 'More options',
          ),
        ],
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
                  title: 'Wallet unavailable',
                  message: _error!,
                  actionLabel: 'Retry',
                  onAction: _loadWallet,
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadWallet,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  SpacingTokens.spacing6,
                  SpacingTokens.spacing4,
                  SpacingTokens.spacing6,
                  SpacingTokens.spacing12,
                ),
                children: [
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${_formatFet(wallet?.balance ?? 0)} FET',
                                style: TypographyTokens.metricValue(
                                  ColorTokens.clubAccent,
                                ),
                              ),
                            ),
                            AfriInfoChip(
                              label: (wallet?.tier ?? 'fan').toUpperCase(),
                            ),
                          ],
                        ),
                        const SizedBox(height: SpacingTokens.spacing4),
                        AfriStatRow(
                          compact: true,
                          stats: [
                            AfriStat(
                              label: 'Weekly',
                              value: '+${_formatFet(wallet?.weeklyEarned ?? 0)}',
                              accentColor: ColorTokens.success,
                            ),
                            AfriStat(
                              label: 'Monthly',
                              value: '+${_formatFet(wallet?.monthlyEarned ?? 0)}',
                              accentColor: ColorTokens.primaryContainer,
                            ),
                            AfriStat(
                              label: 'Spent',
                              value: _formatFet(wallet?.lifetimeSpent ?? 0),
                              accentColor: ColorTokens.warning,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if ((wallet?.legacyBalanceGap ?? 0) > 0) ...[
                    const SizedBox(height: SpacingTokens.spacing4),
                    GlassCard(
                      animate: false,
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded),
                          const SizedBox(width: SpacingTokens.spacing3),
                          Expanded(
                            child: Text(
                              '${_formatFet(wallet!.legacyBalanceGap)} FET comes from older rewards before wallet history was enabled.',
                              style: TypographyTokens.bodyMedium(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: SpacingTokens.spacing4),
                  FetSplitModel(
                    currentTier: wallet?.tier ?? 'supporter',
                  ),
                  const SizedBox(height: SpacingTokens.spacing5),
                  AfriSectionCard(
                    title: 'Transfer',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AfriInputField(
                          key: const ValueKey<String>('wallet-transfer-search'),
                          controller: _searchController,
                          label: 'Search supporter',
                          suffixIcon: _isSearching
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : (_searchController.text.isEmpty
                                    ? const Icon(AfriIcons.search)
                                    : IconButton(
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() {
                                            _selectedSupporter = null;
                                            _supporterMatches =
                                                const <FetWalletSupporter>[];
                                          });
                                        },
                                        icon: const Icon(AfriIcons.close),
                                      )),
                        ),
                        if (_selectedSupporter != null) ...[
                          const SizedBox(height: SpacingTokens.listItemGap),
                          _SelectedSupporterTile(
                            supporter: _selectedSupporter!,
                            onClear: () {
                              setState(() {
                                _selectedSupporter = null;
                              });
                            },
                          ),
                        ] else if (_supporterMatches.isNotEmpty) ...[
                          const SizedBox(height: SpacingTokens.listItemGap),
                          ..._supporterMatches.map(
                            (supporter) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              title: Text(supporter.displayName),
                              subtitle: Text(
                                '#${supporter.publicUserId ?? '000000'} · ${supporter.tier.toUpperCase()}',
                              ),
                              trailing: const Icon(Icons.north_east_rounded),
                              onTap: () {
                                _searchController.text = supporter.displayName;
                                setState(() {
                                  _selectedSupporter = supporter;
                                  _supporterMatches =
                                      const <FetWalletSupporter>[];
                                });
                              },
                            ),
                          ),
                        ],
                        const SizedBox(height: SpacingTokens.listItemGap),
                        AfriInputField(
                          key: const ValueKey<String>('wallet-transfer-amount'),
                          controller: _transferAmountController,
                          keyboardType: TextInputType.number,
                          label: 'Amount',
                          prefixText: 'FET ',
                        ),
                        const SizedBox(height: SpacingTokens.listItemGap),
                        AfriInputField(
                          controller: _transferNoteController,
                          label: 'Note (optional)',
                          maxLines: 2,
                        ),
                        const SizedBox(height: SpacingTokens.spacing4),
                        AfriButton(
                          key: const ValueKey<String>(
                            'wallet-transfer-submit',
                          ),
                          label: _isSubmittingTransfer ? 'Sending…' : 'Send FET',
                          onTap: _submitTransfer,
                          isLoading: _isSubmittingTransfer,
                          enabled: !_isSubmittingTransfer,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: SpacingTokens.spacing4),
                  AfriSectionCard(
                    title: 'Redeem',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AfriInputField(
                          key: const ValueKey<String>('wallet-redeem-amount'),
                          controller: _redeemAmountController,
                          keyboardType: TextInputType.number,
                          label: 'Amount',
                          prefixText: 'FET ',
                        ),
                        const SizedBox(height: SpacingTokens.listItemGap),
                        AfriInputField(
                          controller: _redeemNoteController,
                          label: 'Note',
                          maxLines: 2,
                        ),
                        const SizedBox(height: SpacingTokens.spacing4),
                        AfriButton(
                          key: const ValueKey<String>('wallet-redeem-submit'),
                          label: _isSubmittingRedemption
                              ? 'Submitting…'
                              : 'Redeem FET',
                          onTap: _submitRedemption,
                          isLoading: _isSubmittingRedemption,
                          enabled: !_isSubmittingRedemption,
                          variant: AfriButtonVariant.secondary,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: SpacingTokens.sectionGap),
                  AfriSectionHeader(
                    title: 'Activity',
                    trailing: Text(
                      '${_transactions.length}',
                      style: TypographyTokens.labelSmall(
                        ColorTokens.onSurfaceVariant,
                      ),
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: SpacingTokens.spacing3),
                  if (_transactions.isEmpty)
                    GlassCard(
                      animate: false,
                      child: Text(
                        'Wallet activity appears here once you start earning, sending, or redeeming FET.',
                        style: TypographyTokens.bodyMedium(),
                      ),
                    )
                  else
                    ..._transactions.map(
                      (transaction) => Padding(
                        padding: const EdgeInsets.only(
                          bottom: SpacingTokens.spacing3,
                        ),
                        child: GlassCard(
                          animate: false,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                height: 44,
                                width: 44,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _transactionColor(
                                    transaction,
                                  ).withValues(alpha: 0.18),
                                ),
                                child: Icon(
                                  _transactionIcon(transaction),
                                  color: _transactionColor(transaction),
                                ),
                              ),
                              const SizedBox(width: SpacingTokens.spacing3),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      transaction.headline,
                                      style: TypographyTokens.bodyLarge()
                                          .copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    if (transaction.counterpartyUserId != null)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          top: SpacingTokens.spacing1,
                                        ),
                                        child: Text(
                                          _formatCounterparty(transaction),
                                          style: TypographyTokens.bodySmall(
                                            ColorTokens.onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                    if (transaction.note != null)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          top: SpacingTokens.spacing1,
                                        ),
                                        child: Text(
                                          transaction.note!,
                                          style: TypographyTokens.bodySmall(
                                            ColorTokens.onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                    const SizedBox(
                                      height: SpacingTokens.spacing1,
                                    ),
                                    Text(
                                      transaction.createdAt == null
                                          ? 'Just now'
                                          : AfriDateFormatter.timeAgo(
                                              transaction.createdAt!,
                                            ),
                                      style: TypographyTokens.bodySmall(
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
                                    '${transaction.direction == FetWalletEntryDirection.debit ? '-' : '+'}${_formatFet(transaction.amount)}',
                                    style: TypographyTokens.monolithFont(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: _transactionColor(transaction),
                                    ),
                                  ),
                                  const SizedBox(
                                    height: SpacingTokens.spacing1,
                                  ),
                                  Text(
                                    'Bal. ${_formatFet(transaction.balanceAfter)}',
                                    style: TypographyTokens.bodySmall(
                                      ColorTokens.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

// _MetricPill removed — replaced by AfriStatRow(compact: true)

class _SelectedSupporterTile extends StatelessWidget {
  const _SelectedSupporterTile({
    required this.supporter,
    required this.onClear,
  });

  final FetWalletSupporter supporter;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(SpacingTokens.spacing3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ShapeTokens.radiusLg),
        color: ColorTokens.surfaceContainerHigh,
      ),
      child: Row(
        children: [
          const Icon(Icons.person_pin_circle_rounded),
          const SizedBox(width: SpacingTokens.spacing3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  supporter.displayName,
                  style: TypographyTokens.bodyLarge().copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '#${supporter.publicUserId ?? '000000'} • ${supporter.tier.toUpperCase()}',
                  style: TypographyTokens.bodySmall(
                    ColorTokens.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onClear,
            icon: const Icon(AfriIcons.close),
            tooltip: 'Clear supporter',
          ),
        ],
      ),
    );
  }
}
