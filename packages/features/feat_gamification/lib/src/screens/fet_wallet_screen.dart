import 'dart:async';
import 'dart:math';

import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../fet_providers.dart';
import '../models/fet_models.dart';
import '../providers/fet_wallet_provider.dart';
import '../widgets/fet_split_model.dart';
import '../widgets/fet_wallet_widgets.dart';

/// FET Wallet screen — balance, transfers, redemptions, and transaction history.
///
/// Uses [FetWalletNotifier] via Riverpod for wallet data state.
/// Keeps `ConsumerStatefulWidget` for interactive form controllers and
/// search debounce timer.
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

  List<FetWalletSupporter> _supporterMatches = const <FetWalletSupporter>[];
  FetWalletSupporter? _selectedSupporter;
  bool _isSubmittingTransfer = false;
  bool _isSubmittingRedemption = false;
  bool _isSearching = false;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
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
      // Refresh wallet data after successful transfer.
      await ref.read(fetWalletProvider.notifier).refresh();
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
      // Refresh wallet data after successful redemption.
      await ref.read(fetWalletProvider.notifier).refresh();
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
          onTap: () => ref.read(fetWalletProvider.notifier).refresh(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final asyncWallet = ref.watch(fetWalletProvider);

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

    return RefreshIndicator(
      onRefresh: () => ref.read(fetWalletProvider.notifier).refresh(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          SpacingTokens.spacing6,
          SpacingTokens.spacing4,
          SpacingTokens.spacing6,
          SpacingTokens.spacing12,
        ),
        children: [
          EliteCard(
            backgroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              children: [
                const Text(
                  'CURRENT BALANCE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: Colors.black38,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${_formatFet(wallet?.balance ?? 0)} FET',
                  style: const TextStyle(
                    fontFamily: 'Display',
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                    color: Colors.black,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: ColorTokens.clubAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    (wallet?.tier ?? 'fan').toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: ColorTokens.clubAccent,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildEliteStat('WEEKLY', '+${_formatFet(wallet?.weeklyEarned ?? 0)}'),
                    _buildEliteStat('MONTHLY', '+${_formatFet(wallet?.monthlyEarned ?? 0)}'),
                    _buildEliteStat('SPENT', _formatFet(wallet?.lifetimeSpent ?? 0)),
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
                  const Icon(AfriIcons.statusInfo),
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
                  WalletSelectedSupporterTile(
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
                      trailing: const Icon(AfriIcons.out),
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
                EliteButton(
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
                EliteButton(
                  key: const ValueKey<String>('wallet-redeem-submit'),
                  label: _isSubmittingRedemption
                      ? 'Submitting…'
                      : 'Redeem FET',
                  onTap: _submitRedemption,
                  isLoading: _isSubmittingRedemption,
                  enabled: !_isSubmittingRedemption,
                  variant: EliteButtonVariant.secondary,
                ),
              ],
            ),
          ),
          const SizedBox(height: SpacingTokens.sectionGap),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                const Text(
                  'ACTIVITY',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: Colors.white38,
                    letterSpacing: 2,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${transactions.length}',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (transactions.isEmpty)
            EliteCard(
              child: Text(
                'Wallet activity appears here once you start earning, sending, or redeeming FET.',
                style: TypographyTokens.bodyMedium(),
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
                  formatFet: _formatFet,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEliteStat(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w900,
            color: Colors.black26,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: Colors.black,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}
