import 'dart:async';

import 'package:club_data/club_data.dart';
import 'package:core_auth/core_auth.dart';
import 'package:core_l10n/core_l10n.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ContributionPaymentLaunchResult {
  launched,
  cancelledAfterLaunchFailure,
  cancellationFailed,
}

/// Launches the external payment channel and compensates a failed launch by
/// cancelling the exact pending contribution created for that attempt.
Future<ContributionPaymentLaunchResult> launchContributionPaymentWithRecovery({
  required Future<bool> Function() launchPayment,
  required Future<void> Function() cancelPendingContribution,
  void Function(Object error, StackTrace stackTrace)? onCancellationError,
}) async {
  if (await launchPayment()) {
    return ContributionPaymentLaunchResult.launched;
  }

  try {
    await cancelPendingContribution();
    return ContributionPaymentLaunchResult.cancelledAfterLaunchFailure;
  } catch (error, stackTrace) {
    onCancellationError?.call(error, stackTrace);
    return ContributionPaymentLaunchResult.cancellationFailed;
  }
}

/// Full contribution flow: Amount → USSD Confirmation → Record → Success.
///
/// Uses [MomoDialerService] for dynamic USSD building and
/// [ClubRepository.contribute] to persist the contribution.
Future<void> showMomoAmountEntrySheet(
  BuildContext context, {
  required String title,
  String? groupId,
  String? recipientMomo,
}) async {
  if (!ConnectivityService.isOnline) {
    AfriToast.error(
      context,
      context.afriL10n.contributionsConnectBeforeContributing,
    );
    return;
  }

  var amountDraft = 5000;
  while (context.mounted) {
    final amount = await showAfriBottomSheet<int>(
      context: context,
      builder: (context) =>
          _AmountEntrySheet(title: title, initialAmount: amountDraft),
    );

    if (amount == null || !context.mounted) return;
    amountDraft = amount;

    final confirmed = await showAfriBottomSheet<bool>(
      context: context,
      builder: (context) {
        final country =
            AfriCountryCatalog.byIsoCode(context.afriCountryCode) ??
            AfriCountryCatalog.defaultCountry;
        return _UssdConfirmationSheet(
          amount: amountDraft,
          title: title,
          country: country,
          // §2.4 LOCKED — no hardcoded MOMO. Caller must supply recipientMomo.
          recipientMomo: recipientMomo ?? '',
        );
      },
    );

    if (!context.mounted || confirmed == null) return;
    if (!confirmed) continue;
    break;
  }

  // Persist the immutable reconciliation target before opening an external
  // payment channel. A payment must never launch without a recoverable record.
  final normalizedGroupId = groupId?.trim() ?? '';
  final recipient = recipientMomo?.trim() ?? '';
  if (normalizedGroupId.isEmpty || recipient.isEmpty || !context.mounted) {
    if (context.mounted) {
      AfriToast.error(
        context,
        context.afriL10n.contributionsPaymentRouteUnavailableMessage,
      );
    }
    return;
  }

  final container = ProviderScope.containerOf(context);
  final repo = container.read(clubRepositoryProvider);
  final userId = container.read(currentUserProvider)?.id;
  if (userId == null) {
    AfriToast.error(context, context.afriL10n.contributionsRecordFailedMessage);
    return;
  }

  final country =
      AfriCountryCatalog.byIsoCode(context.afriCountryCode) ??
      AfriCountryCatalog.defaultCountry;

  while (context.mounted) {
    late final String contributionId;
    try {
      final requestReference = 'MOMO-${DateTime.now().microsecondsSinceEpoch}';
      contributionId = await repo.contribute(
        groupId: normalizedGroupId,
        userId: userId,
        amount: amountDraft,
        clientRequestReference: requestReference,
      );
    } catch (error, stackTrace) {
      AfriLogger.warn(
        'ContributionOverlay',
        'Failed to create the pending contribution before payment launch.',
        error,
        stackTrace,
      );
      if (context.mounted) {
        AfriToast.error(
          context,
          context.afriL10n.contributionsRecordFailedMessage,
        );
      }
      return;
    }

    final launchResult = await launchContributionPaymentWithRecovery(
      // §2.4 LOCKED — no hardcoded MOMO fallback.
      launchPayment: () => MomoDialerService.launchMomoUssd(
        recipient: recipient,
        amount: amountDraft,
        country: country,
      ),
      cancelPendingContribution: () =>
          repo.cancelPendingContributionPaymentLaunch(contributionId),
      onCancellationError: (error, stackTrace) {
        AfriLogger.warn(
          'ContributionOverlay',
          'Failed to cancel the pending contribution after dialer launch failure.',
          error,
          stackTrace,
        );
      },
    );

    if (!context.mounted) return;

    if (launchResult == ContributionPaymentLaunchResult.launched) {
      await showDialog<void>(
        context: context,
        barrierColor: ColorTokens.scrim,
        builder: (context) => _ContributionSuccessDialog(
          amount: amountDraft,
          title: title,
          recordedPending: true,
          contributionId: contributionId,
        ),
      );
      return;
    }

    var cancellationFailed =
        launchResult == ContributionPaymentLaunchResult.cancellationFailed;
    var retryPaymentAfterCleanup = false;
    while (cancellationFailed) {
      if (!context.mounted) return;
      final retryCancellation = await showDialog<bool>(
        context: context,
        barrierColor: ColorTokens.scrim,
        builder: (context) =>
            const _ContributionDialerRecoveryDialog(cancellationFailed: true),
      );
      if (retryCancellation != true || !context.mounted) return;

      try {
        await repo.cancelPendingContributionPaymentLaunch(contributionId);
        cancellationFailed = false;
        retryPaymentAfterCleanup = true;
      } catch (error, stackTrace) {
        AfriLogger.warn(
          'ContributionOverlay',
          'Pending contribution cancellation retry failed.',
          error,
          stackTrace,
        );
      }
    }

    if (!context.mounted) return;
    if (!retryPaymentAfterCleanup) {
      final retryPayment = await showDialog<bool>(
        context: context,
        barrierColor: ColorTokens.scrim,
        builder: (context) =>
            const _ContributionDialerRecoveryDialog(cancellationFailed: false),
      );
      if (retryPayment != true || !context.mounted) return;
    }
    // The failed attempt is cancelled. A retry starts with a new immutable
    // pending record before making another external dialer request.
  }
}

class _ContributionDialerRecoveryDialog extends StatelessWidget {
  const _ContributionDialerRecoveryDialog({required this.cancellationFailed});

  final bool cancellationFailed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.afriL10n;
    final heading = cancellationFailed
        ? l10n.contributionsRecordFailedTitle
        : l10n.contributionsPaymentFailedTitle;
    final message = cancellationFailed
        ? '${l10n.contributionsDialerFailed}\n\n'
              '${l10n.contributionsRecordFailedMessage}'
        : l10n.contributionsDialerFailed;

    return AfriDialog(
      child: SingleChildScrollView(
        child: Semantics(
          container: true,
          liveRegion: true,
          label: l10n.contributionsStatusAnnouncement(heading, message),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(AfriIcons.statusWarning, color: ColorTokens.error, size: 64),
              const SizedBox(height: SpacingTokens.spacing4),
              Text(
                heading,
                style: TypographyTokens.headlineLarge().copyWith(
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: SpacingTokens.spacing2),
              Text(
                message,
                style: TypographyTokens.bodyMedium(),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: SpacingTokens.spacing4),
              AfriButton(
                label: l10n.tryAgain,
                fullWidth: true,
                onTap: () => Navigator.of(context).pop(true),
              ),
              const SizedBox(height: SpacingTokens.spacing2),
              AfriTextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.contributionsBackToGroup),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Announces contribution payment state changes without hiding the visible
/// status content or the dialog's recovery controls from assistive technology.
class ContributionPaymentStatusAnnouncement extends StatelessWidget {
  const ContributionPaymentStatusAnnouncement({
    super.key,
    required this.heading,
    required this.message,
    required this.child,
  });

  final String heading;
  final String message;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      explicitChildNodes: true,
      liveRegion: true,
      label: context.afriL10n.contributionsStatusAnnouncement(heading, message),
      child: child,
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Private Widgets — Amount entry
// ═══════════════════════════════════════════════════════════════

class _AmountEntrySheet extends StatefulWidget {
  const _AmountEntrySheet({required this.title, required this.initialAmount});

  final String title;
  final int initialAmount;

  @override
  State<_AmountEntrySheet> createState() => _AmountEntrySheetState();
}

class _AmountEntrySheetState extends State<_AmountEntrySheet> {
  late int _amount;

  @override
  void initState() {
    super.initState();
    _amount = widget.initialAmount;
  }

  @override
  Widget build(BuildContext context) {
    final currency = CurrencyFormatter(
      currencyCode: context.afriCurrencyCode,
      currencySymbol: context.afriCurrencySymbol,
    );

    return Padding(
      padding: const EdgeInsets.all(SpacingTokens.spacing4),
      child: SingleChildScrollView(
        child: GlassCard(
          animate: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: ColorTokens.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: ShapeTokens.buttonRadius,
                ),
              ),
              const SizedBox(height: SpacingTokens.spacing4),
              Text(
                context.afriL10n.contributionsAmountPrompt,
                style: TypographyTokens.headlineMedium().copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: SpacingTokens.spacing2),
              Text(widget.title, style: TypographyTokens.bodySmall()),
              const SizedBox(height: SpacingTokens.spacing4),
              Text(
                currency.format(_amount),
                style: TypographyTokens.displayLarge(
                  ColorTokens.accessibleMetricColor(ColorTokens.clubAccent),
                ).copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: SpacingTokens.spacing4),
              Wrap(
                spacing: SpacingTokens.spacing2,
                runSpacing: SpacingTokens.spacing2,
                alignment: WrapAlignment.center,
                children: [1000, 2000, 5000, 10000]
                    .map(
                      (value) => AfriChoiceChip(
                        selected: _amount == value,
                        label: Text(
                          context.afriL10n.contributionsQuickAmount(
                            value ~/ 1000,
                          ),
                          semanticsLabel: currency.format(value),
                        ),
                        onSelected: (_) => setState(() => _amount = value),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: SpacingTokens.spacing5),
              AfriButton(
                label: context.afriL10n.contributionsLaunchMomoDialer,
                fullWidth: true,
                onTap: () => Navigator.of(context).pop(_amount),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Private Widgets — USSD Confirmation
// ═══════════════════════════════════════════════════════════════

class _UssdConfirmationSheet extends StatelessWidget {
  const _UssdConfirmationSheet({
    required this.amount,
    required this.title,
    required this.country,
    required this.recipientMomo,
  });

  final int amount;
  final String title;
  final AfriCountry country;
  final String recipientMomo;

  @override
  Widget build(BuildContext context) {
    final l10n = context.afriL10n;
    final ussdCode = country.buildUssdCode(
      recipientMomo: recipientMomo,
      amount: amount,
    );

    return Padding(
      padding: const EdgeInsets.all(SpacingTokens.spacing4),
      child: SingleChildScrollView(
        child: GlassCard(
          animate: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.contributionsLaunchingMomo,
                style: TypographyTokens.headlineMedium().copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: SpacingTokens.spacing4),
              Text(
                ussdCode,
                style: TypographyTokens.titleMedium(),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: SpacingTokens.spacing2),
              Text(title, style: TypographyTokens.bodySmall()),
              const SizedBox(height: SpacingTokens.spacing5),
              Row(
                children: [
                  Expanded(
                    child: AfriButton(
                      label: l10n.contributionsChangeAmount,
                      variant: AfriButtonVariant.outline,
                      onTap: () => Navigator.of(context).pop(false),
                    ),
                  ),
                  const SizedBox(width: SpacingTokens.spacing3),
                  Expanded(
                    child: AfriButton(
                      label: l10n.contributionsDialNow,
                      onTap: () => Navigator.of(context).pop(true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: SpacingTokens.spacing3),
              AfriTextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.contributionsCancel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Private Widgets — Payment Verification Dialog
// ═══════════════════════════════════════════════════════════════

class _ContributionSuccessDialog extends StatefulWidget {
  const _ContributionSuccessDialog({
    required this.amount,
    required this.title,
    required this.recordedPending,
    this.contributionId,
  });

  final int amount;
  final String title;
  final bool recordedPending;
  final String? contributionId;

  @override
  State<_ContributionSuccessDialog> createState() =>
      _ContributionSuccessDialogState();
}

class _ContributionSuccessDialogState
    extends State<_ContributionSuccessDialog> {
  /// `pending` → `verified` → `failed` → `timeout`
  String _status = 'pending';
  Timer? _pollTimer;
  int _pollCount = 0;
  bool _completionLogged = false;

  // Poll every 5 seconds for up to 2 minutes (24 attempts).
  static const int _maxPolls = 24;
  static const Duration _pollInterval = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    if (widget.recordedPending && widget.contributionId != null) {
      _startPolling();
    } else if (!widget.recordedPending) {
      _status = 'error';
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(_pollInterval, (_) => _checkStatus());
  }

  Future<void> _checkStatus() async {
    final id = widget.contributionId;
    if (id == null || !mounted) {
      _pollTimer?.cancel();
      return;
    }

    _pollCount++;

    try {
      final container = ProviderScope.containerOf(context);
      final repo = container.read(clubRepositoryProvider);
      final result = await repo.getContributionPaymentStatus(id);

      if (!mounted) return;

      if (result == 'verified') {
        _pollTimer?.cancel();
        setState(() => _status = 'verified');
        if (!_completionLogged) {
          _completionLogged = true;
          unawaited(
            FirebaseAnalyticsService.logContributionCompletion(
              paymentChannel: 'momo',
              amount: widget.amount,
            ),
          );
        }
        return;
      }
      if (result == 'failed') {
        _pollTimer?.cancel();
        setState(() => _status = 'failed');
        return;
      }
    } catch (error, stackTrace) {
      AfriLogger.warn(
        'MomoContributionSheet',
        'Operation failed (non-critical).',
        error,
        stackTrace,
      );
      // Network error during poll — continue polling
    }

    if (_pollCount >= _maxPolls) {
      _pollTimer?.cancel();
      if (mounted) {
        setState(() => _status = 'timeout');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.afriL10n;
    final currency = CurrencyFormatter(
      currencyCode: context.afriCurrencyCode,
      currencySymbol: context.afriCurrencySymbol,
    );

    final IconData icon;
    final Color iconColor;
    final String heading;
    final String body;

    switch (_status) {
      case 'verified':
        icon = AfriIcons.statusSuccess;
        iconColor = ColorTokens.success;
        heading = l10n.contributionsPaymentConfirmedTitle;
        body = l10n.contributionsPaymentConfirmedMessage(
          currency.format(widget.amount),
        );
        break;
      case 'failed':
        icon = AfriIcons.statusWarning;
        iconColor = ColorTokens.error;
        heading = l10n.contributionsPaymentFailedTitle;
        body = l10n.contributionsPaymentFailedMessage;
        break;
      case 'timeout':
        icon = AfriIcons.statusPending;
        iconColor = ColorTokens.warning;
        heading = l10n.contributionsPaymentProcessingTitle;
        body = l10n.contributionsPaymentProcessingMessage;
        break;
      case 'error':
        icon = AfriIcons.statusWarning;
        iconColor = ColorTokens.error;
        heading = l10n.contributionsRecordFailedTitle;
        body = l10n.contributionsRecordFailedMessage;
        break;
      default: // 'pending'
        icon = AfriIcons.statusPending;
        iconColor = ColorTokens.warning;
        heading = l10n.contributionsAwaitingPaymentTitle;
        body = l10n.contributionsAwaitingPaymentMessage;
    }

    return AfriDialog(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ContributionPaymentStatusAnnouncement(
              heading: heading,
              message: body,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: iconColor, size: 64),
                  const SizedBox(height: SpacingTokens.spacing4),
                  Text(
                    heading,
                    style: TypographyTokens.headlineLarge().copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: SpacingTokens.spacing2),
                  Text(
                    currency.format(widget.amount),
                    style: TypographyTokens.displaySmall(
                      ColorTokens.clubAccent,
                    ).copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: SpacingTokens.spacing2),
                  Text(widget.title, style: TypographyTokens.bodySmall()),
                  const SizedBox(height: SpacingTokens.spacing3),
                  Text(
                    body,
                    textAlign: TextAlign.center,
                    style: TypographyTokens.bodyMedium(),
                  ),
                  if (_status == 'pending') ...[
                    const SizedBox(height: SpacingTokens.spacing3),
                    const AfriLoadingIndicator(size: 20),
                    const SizedBox(height: SpacingTokens.spacing2),
                    Text(
                      l10n.contributionsCheckingPaymentStatus,
                      style: TypographyTokens.bodySmall(
                        ColorTokens.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (_status == 'verified') ...[
                    const SizedBox(height: SpacingTokens.spacing3),
                    AfriInfoChip(
                      label: l10n.contributionsVerifiedUpper,
                      color: ColorTokens.success,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing4),
            AfriButton(
              label: _status == 'verified'
                  ? l10n.contributionsDone
                  : l10n.contributionsBackToGroup,
              fullWidth: true,
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
