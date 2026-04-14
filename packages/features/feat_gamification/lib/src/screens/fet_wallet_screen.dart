import 'dart:async';
import 'dart:math';

import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../fet_providers.dart';
import '../models/fet_models.dart';

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
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        actions: [
          IconButton(
            onPressed: () => context.push('/fanzone/history'),
            icon: const Icon(Icons.history_rounded),
          ),
          IconButton(
            onPressed: () => context.push('/fanzone/rewards'),
            icon: const Icon(Icons.redeem_rounded),
          ),
          IconButton(
            onPressed: _isLoading ? null : _loadWallet,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh wallet',
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
                        Text(
                          'AVAILABLE BALANCE',
                          style: TypographyTokens.monolithFont(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.4,
                            color: ColorTokens.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: SpacingTokens.spacing3),
                        Text(
                          '${_formatFet(wallet?.balance ?? 0)} FET',
                          style: TypographyTokens.monolithFont(
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            color: ColorTokens.clubAccent,
                          ),
                        ),
                        const SizedBox(height: SpacingTokens.spacing2),
                        Text(
                          'Tier ${(wallet?.tier ?? 'fan').toUpperCase()} • ${wallet?.transactionCount ?? 0} wallet events',
                          style: TypographyTokens.bodyMedium(
                            ColorTokens.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: SpacingTokens.spacing4),
                        Wrap(
                          spacing: SpacingTokens.spacing2,
                          runSpacing: SpacingTokens.spacing2,
                          children: [
                            _MetricPill(
                              label: 'Weekly earned',
                              value:
                                  '+${_formatFet(wallet?.weeklyEarned ?? 0)}',
                              color: ColorTokens.success,
                            ),
                            _MetricPill(
                              label: 'Monthly earned',
                              value:
                                  '+${_formatFet(wallet?.monthlyEarned ?? 0)}',
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            _MetricPill(
                              label: 'Lifetime spent',
                              value: _formatFet(wallet?.lifetimeSpent ?? 0),
                              color: ColorTokens.warning,
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
                  const SizedBox(height: SpacingTokens.spacing5),
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TRANSFER FET',
                          style: TypographyTokens.monolithFont(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: SpacingTokens.spacing3),
                        TextField(
                          key: const ValueKey<String>('wallet-transfer-search'),
                          controller: _searchController,
                          decoration: InputDecoration(
                            labelText: 'Search supporter by name or alias',
                            helperText:
                                'Search by public ID, phone, or supporter name.',
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
                                      ? const Icon(Icons.search_rounded)
                                      : IconButton(
                                          onPressed: () {
                                            _searchController.clear();
                                            setState(() {
                                              _selectedSupporter = null;
                                              _supporterMatches =
                                                  const <FetWalletSupporter>[];
                                            });
                                          },
                                          icon: const Icon(Icons.close_rounded),
                                        )),
                          ),
                        ),
                        if (_selectedSupporter != null) ...[
                          const SizedBox(height: SpacingTokens.spacing3),
                          _SelectedSupporterTile(
                            supporter: _selectedSupporter!,
                            onClear: () {
                              setState(() {
                                _selectedSupporter = null;
                              });
                            },
                          ),
                        ] else if (_supporterMatches.isNotEmpty) ...[
                          const SizedBox(height: SpacingTokens.spacing3),
                          ..._supporterMatches.map(
                            (supporter) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              title: Text(supporter.displayName),
                              subtitle: Text(
                                '#${supporter.publicUserId ?? '000000'} • ${supporter.tier.toUpperCase()} • ${_formatFet(supporter.balance)} FET',
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
                        const SizedBox(height: SpacingTokens.spacing3),
                        TextField(
                          key: const ValueKey<String>('wallet-transfer-amount'),
                          controller: _transferAmountController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Amount',
                            prefixText: 'FET ',
                          ),
                        ),
                        const SizedBox(height: SpacingTokens.spacing3),
                        TextField(
                          controller: _transferNoteController,
                          decoration: const InputDecoration(
                            labelText: 'Note (optional)',
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: SpacingTokens.spacing4),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            key: const ValueKey<String>(
                              'wallet-transfer-submit',
                            ),
                            onPressed: _isSubmittingTransfer
                                ? null
                                : _submitTransfer,
                            child: Text(
                              _isSubmittingTransfer ? 'Sending…' : 'Send FET',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: SpacingTokens.spacing4),
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'REDEEM FET',
                          style: TypographyTokens.monolithFont(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: SpacingTokens.spacing2),
                        Text(
                          'Use this to request a wallet redemption once you are ready to spend or cash out earned FET.',
                          style: TypographyTokens.bodyMedium(
                            ColorTokens.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: SpacingTokens.spacing3),
                        TextField(
                          key: const ValueKey<String>('wallet-redeem-amount'),
                          controller: _redeemAmountController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Amount',
                            prefixText: 'FET ',
                          ),
                        ),
                        const SizedBox(height: SpacingTokens.spacing3),
                        TextField(
                          controller: _redeemNoteController,
                          decoration: const InputDecoration(
                            labelText: 'Redemption note',
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: SpacingTokens.spacing4),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            key: const ValueKey<String>('wallet-redeem-submit'),
                            onPressed: _isSubmittingRedemption
                                ? null
                                : _submitRedemption,
                            child: Text(
                              _isSubmittingRedemption
                                  ? 'Submitting…'
                                  : 'Request redemption',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: SpacingTokens.spacing5),
                  Row(
                    children: [
                      Text(
                        'RECENT ACTIVITY',
                        style: TypographyTokens.monolithFont(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_transactions.length} items',
                        style: TypographyTokens.bodySmall(
                          ColorTokens.onSurfaceVariant,
                        ),
                      ),
                    ],
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

class _MetricPill extends StatelessWidget {
  const _MetricPill({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.spacing3,
        vertical: SpacingTokens.spacing2,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.12),
        border: BorderTokens.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TypographyTokens.monolithFont(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: ColorTokens.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing1),
          Text(
            value,
            style: TypographyTokens.bodyMedium(
              color,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

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
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Clear supporter',
          ),
        ],
      ),
    );
  }
}
