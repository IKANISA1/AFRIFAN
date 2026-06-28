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
      } catch (error, stackTrace) {
        AfriLogger.warn(
          'FetWalletScreen',
          'Operation failed (non-critical).',
          error,
          stackTrace,
        );
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

    // M-7: Client-side balance validation.
    final currentBalance =
        ref.read(fetWalletProvider).valueOrNull?.wallet?.balance ?? 0;
    if (amount > currentBalance) {
      _showMessage(
        'Insufficient FET balance. You have ${_formatFet(currentBalance)} FET.',
      );
      return;
    }

    // B-2: Confirmation gate for FET transfer.
    final confirmed = await _showWalletConfirmation(
      title: 'Confirm Transfer',
      message:
          'Send ${_formatFet(amount)} FET to ${selectedSupporter.displayName}?',
      detail: 'Remaining balance: ${_formatFet(currentBalance - amount)} FET',
      confirmLabel: 'SEND FET',
    );
    if (!confirmed || !mounted) return;

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

    // M-7: Client-side balance validation.
    final currentBalance =
        ref.read(fetWalletProvider).valueOrNull?.wallet?.balance ?? 0;
    if (amount > currentBalance) {
      _showMessage(
        'Insufficient FET balance. You have ${_formatFet(currentBalance)} FET.',
      );
      return;
    }

    // B-2: Confirmation gate for FET redemption.
    final confirmed = await _showWalletConfirmation(
      title: 'Confirm Redemption',
      message: 'Redeem ${_formatFet(amount)} FET?',
      detail: 'Remaining balance: ${_formatFet(currentBalance - amount)} FET',
      confirmLabel: 'REDEEM FET',
    );
    if (!confirmed || !mounted) return;

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

  /// B-2: Reusable confirmation bottom sheet for wallet operations.
  Future<bool> _showWalletConfirmation({
    required String title,
    required String message,
    required String detail,
    required String confirmLabel,
  }) async {
    final result = await showAfriBottomSheet<bool>(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.only(bottom: SpacingTokens.spacing4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.toUpperCase(),
              style: TypographyTokens.headlineSmall().copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing4),
            GlassCard(
              animate: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(message, style: TypographyTokens.titleMedium()),
                  const SizedBox(height: SpacingTokens.spacing2),
                  Text(
                    detail,
                    style: TypographyTokens.bodySmall(
                      ColorTokens.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing5),
            AfriButton(label: confirmLabel, onTap: () => context.pop(true)),
            const SizedBox(height: SpacingTokens.spacing3),
            AfriButton(
              label: 'CANCEL',
              variant: AfriButtonVariant.secondary,
              onTap: () => context.pop(false),
            ),
          ],
        ),
      ),
    );
    return result == true;
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
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              children: [
                Text(
                  'Current Balance',
                  style: TypographyTokens.labelSmall(
                    ColorTokens.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${_formatFet(wallet?.balance ?? 0)} FET',
                  style: TypographyTokens.metricValue(ColorTokens.clubAccent),
                ),
                const SizedBox(height: 12),
                AfriStatusChip(
                  label: wallet?.tier ?? 'fan',
                  tone: AfriStatusTone.live,
                ),
                const SizedBox(height: 32),
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
                      'Spent',
                      _formatFet(wallet?.lifetimeSpent ?? 0),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if ((wallet?.legacyBalanceGap ?? 0) > 0) ...[
            const SizedBox(height: SpacingTokens.spacing4),
            AfriSurfaceCard(
              child: Row(
                children: [
                  const Icon(AfriIcons.statusInfo, size: 20),
                  const SizedBox(width: SpacingTokens.spacing3),
                  Expanded(
                    child: Text(
                      '${_formatFet(wallet!.legacyBalanceGap)} FET comes from older rewards before wallet history was enabled.',
                      style: TypographyTokens.bodySmall(),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: SpacingTokens.spacing6),
          FetSplitModel(currentTier: wallet?.tier ?? 'supporter'),
          const SizedBox(height: SpacingTokens.spacing8),
          const AfriSectionHeader(title: 'Transfer'),
          const SizedBox(height: SpacingTokens.spacing4),
          AfriSurfaceCard(
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
                          child: AfriLoadingIndicator(size: 16),
                        )
                      : (_searchController.text.isEmpty
                            ? const Icon(AfriIcons.search)
                            : AfriIconButton(
                                icon: AfriIcons.close,
                                onTap: () {
                                  _searchController.clear();
                                  setState(() {
                                    _selectedSupporter = null;
                                    _supporterMatches =
                                        const <FetWalletSupporter>[];
                                  });
                                },
                                tooltip: 'Clear search',
                                filled: false,
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
                    (supporter) => AfriListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(
                        supporter.displayName,
                        style: TypographyTokens.titleSmall(),
                      ),
                      subtitle: Text(
                        '#${supporter.publicUserId ?? '000000'} · ${supporter.tier}',
                        style: TypographyTokens.bodySmall(
                          ColorTokens.onSurfaceVariant,
                        ),
                      ),
                      trailing: const Icon(AfriIcons.out, size: 18),
                      onTap: () {
                        _searchController.text = supporter.displayName;
                        setState(() {
                          _selectedSupporter = supporter;
                          _supporterMatches = const <FetWalletSupporter>[];
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
                const SizedBox(height: SpacingTokens.spacing5),
                AfriButton(
                  key: const ValueKey<String>('wallet-transfer-submit'),
                  label: _isSubmittingTransfer ? 'Sending…' : 'Send FET',
                  onTap: _submitTransfer,
                  isLoading: _isSubmittingTransfer,
                ),
              ],
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing8),
          const AfriSectionHeader(title: 'Redeem'),
          const SizedBox(height: SpacingTokens.spacing4),
          AfriSurfaceCard(
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
                const SizedBox(height: SpacingTokens.spacing5),
                AfriButton(
                  key: const ValueKey<String>('wallet-redeem-submit'),
                  label: _isSubmittingRedemption ? 'Submitting…' : 'Redeem FET',
                  onTap: _submitRedemption,
                  isLoading: _isSubmittingRedemption,
                  variant: AfriButtonVariant.secondary,
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
                'Wallet activity appears here once you start earning, sending, or redeeming FET.',
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
        const SizedBox(height: 4),
        Text(value, style: TypographyTokens.titleMedium()),
      ],
    );
  }

  Widget _buildBorrowedStat(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TypographyTokens.metricLabel(
            ColorTokens.borrowedInkFaint,
          ).copyWith(fontWeight: FontWeight.w900, letterSpacing: 1),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TypographyTokens.titleSmall(
            ColorTokens.borrowedInk,
          ).copyWith(fontWeight: FontWeight.w900, letterSpacing: 0),
        ),
      ],
    );
  }
}
