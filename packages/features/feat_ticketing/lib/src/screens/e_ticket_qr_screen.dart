import 'dart:async';

import 'package:core_l10n/core_l10n.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../providers/e_ticket_provider.dart';

class ETicketQrScreen extends ConsumerStatefulWidget {
  const ETicketQrScreen({
    super.key,
    required this.ticketId,
    this.scannerAnimationEnabled = true,
  });

  final String ticketId;
  final bool scannerAnimationEnabled;

  @override
  ConsumerState<ETicketQrScreen> createState() => _ETicketQrScreenState();
}

class _ETicketQrScreenState extends ConsumerState<ETicketQrScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scannerController;
  bool? _lastOnline;

  @override
  void initState() {
    super.initState();
    _scannerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncScannerAnimation();
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  bool _shouldReduceMotion(BuildContext context) {
    final mediaQuery = MediaQuery.maybeOf(context);
    return mediaQuery?.disableAnimations == true ||
        mediaQuery?.accessibleNavigation == true;
  }

  void _syncScannerAnimation() {
    if (!widget.scannerAnimationEnabled || _shouldReduceMotion(context)) {
      if (_scannerController.isAnimating) {
        _scannerController.stop();
      }
      _scannerController.value = 0;
      return;
    }

    if (!_scannerController.isAnimating) {
      unawaited(_scannerController.repeat(reverse: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ticketAsync = ref.watch(eTicketProvider(widget.ticketId));
    final accessEnabled = ref.watch(eTicketAccessEnabledProvider);
    return ConnectivityBuilder(
      builder: (context, isOnline) {
        final previousOnline = _lastOnline;
        _lastOnline = isOnline;
        if (previousOnline == false && isOnline) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            unawaited(
              ref.read(eTicketProvider(widget.ticketId).notifier).refresh(),
            );
          });
        }
        return _buildScaffold(
          ticketAsync,
          isOnline: isOnline,
          accessEnabled: accessEnabled,
        );
      },
    );
  }

  Widget _buildScaffold(
    AsyncValue<ETicketState> ticketAsync, {
    required bool isOnline,
    required bool accessEnabled,
  }) {
    final l10n = context.afriL10n;
    return AfriScreenScaffold(
      backgroundColor: ColorTokens.background,
      appBar: AfriAppBar(
        backgroundColor: ColorTokens.transparent,
        elevation: 0,
        leading: AfriIconButton(
          key: const ValueKey<String>('e-ticket-close'),
          icon: AfriIcons.close,
          onTap: () => context.canPop()
              ? context.pop()
              : context.go('/tickets?tab=mine'),
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
        ),
      ),
      scrollable: false,
      child: !accessEnabled
          ? _QrState(
              title: l10n.ticketQrAccessUnavailableTitle,
              body: l10n.ticketQrAccessUnavailableMessage,
            )
          : ticketAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(SpacingTokens.spacing6),
                child: AfriSkeletonList(),
              ),
              error: (error, _) => _failureState(error, isOnline),
              data: (routeState) {
                final ticket = routeState.ticket;
                if (ticket == null) {
                  return _QrState(
                    title: l10n.ticketNotFoundTitle,
                    body: l10n.ticketUnavailableShort,
                  );
                }

                if (ticket.status == TicketStatus.pending) {
                  return _QrState(
                    title: l10n.ticketPaymentPendingTitle,
                    body: l10n.ticketPaymentPendingMessage,
                  );
                }

                final code =
                    ticket.qrCode.isNotEmpty ? ticket.qrCode : ticket.id;
                final reduceMotion = !widget.scannerAnimationEnabled ||
                    _shouldReduceMotion(context);
                final stackWalletActions =
                    MediaQuery.textScalerOf(context).scale(1) >= 1.5 ||
                        MediaQuery.sizeOf(context).width < 360;
                final qrSize = stackWalletActions ? 160.0 : 220.0;
                final passCard = AfriPanelCard(
                  backgroundColor: ColorTokens.paperSurface,
                  borderColor: ColorTokens.transparent,
                  padding: EdgeInsets.zero,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Upper Pass: QR Code
                      Padding(
                        padding: const EdgeInsets.all(SpacingTokens.spacing8),
                        child: AfriQrBarcodeSurface(
                          semanticLabel: l10n.ticketEntryCode,
                          helperText: l10n.ticketScannerHelper,
                          code: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  border: BorderTokens.all(
                                    color: ColorTokens.inkBase,
                                    opacity: 0.05,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    ShapeTokens.radiusSm,
                                  ),
                                ),
                                child: QrImageView(
                                  data: code,
                                  size: qrSize,
                                  backgroundColor: ColorTokens.paperSurface,
                                  eyeStyle: const QrEyeStyle(
                                    eyeShape: QrEyeShape.square,
                                    color: ColorTokens.inkBase,
                                  ),
                                  dataModuleStyle: const QrDataModuleStyle(
                                    dataModuleShape: QrDataModuleShape.square,
                                    color: ColorTokens.inkBase,
                                  ),
                                ),
                              ),
                              if (!reduceMotion)
                                AnimatedBuilder(
                                  animation: _scannerController,
                                  builder: (context, child) {
                                    return Positioned(
                                      top: _scannerController.value * qrSize,
                                      child: Container(
                                        key: const Key('qr_scanner_overlay'),
                                        width: qrSize,
                                        height: 2,
                                        color: ColorTokens.clubPrimary,
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),

                      // Perforated Divider
                      Row(
                        children: List.generate(
                          20,
                          (i) => Expanded(
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: SpacingTokens.spacing1 / 2,
                              ),
                              height: BorderTokens.hairline,
                              color: ColorTokens.inkHairline,
                            ),
                          ),
                        ),
                      ),

                      // Lower Pass: Details
                      Padding(
                        padding: const EdgeInsets.all(SpacingTokens.spacing8),
                        child: Column(
                          children: [
                            Text(
                              ticket.matchTitle.toUpperCase(),
                              style: TypographyTokens.headlineMedium(
                                ColorTokens.inkBase,
                              ).copyWith(
                                fontWeight: FontWeight.w900,
                                fontStyle: FontStyle.italic,
                                height: 1,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: SpacingTokens.spacing3),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: SpacingTokens.spacing3,
                                vertical: SpacingTokens.spacing1,
                              ),
                              decoration: BoxDecoration(
                                color: ColorTokens.clubAccent
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(
                                  ShapeTokens.radiusSm,
                                ),
                              ),
                              child: Text(
                                ticket.seatType.label.toUpperCase(),
                                style: TypographyTokens.titleMedium(
                                  ColorTokens.clubAccent,
                                ).copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(height: SpacingTokens.spacing6),
                            if (stackWalletActions) ...[
                              _buildPassMeta(
                                l10n.ticketDateLabel,
                                AfriDateFormatter.formatDate(
                                  ticket.match.matchDate,
                                ),
                              ),
                              const SizedBox(height: SpacingTokens.spacing3),
                              _buildPassMeta(
                                l10n.ticketTimeLabel,
                                ticket.match.kickoffTime,
                              ),
                            ] else
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  _buildPassMeta(
                                    l10n.ticketDateLabel,
                                    AfriDateFormatter.formatDate(
                                      ticket.match.matchDate,
                                    ),
                                  ),
                                  _buildPassMeta(
                                    l10n.ticketTimeLabel,
                                    ticket.match.kickoffTime,
                                  ),
                                ],
                              ),
                            const SizedBox(height: SpacingTokens.spacing4),
                            _buildPassMeta(
                              l10n.ticketVenueLabel,
                              ticket.match.venue.toUpperCase(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );

                final pass = SafeArea(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: SpacingTokens.spacing8,
                          vertical: SpacingTokens.spacing6,
                        ),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: (constraints.maxHeight -
                                    SpacingTokens.spacing12)
                                .clamp(0, double.infinity),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                reduceMotion
                                    ? passCard
                                    : passCard.afriAnimate(context).scale(
                                          duration: 400.ms,
                                          curve: Curves.easeOutBack,
                                        ),
                                const SizedBox(height: SpacingTokens.spacing8),
                                if (stackWalletActions) ...[
                                  SizedBox(
                                    width: double.infinity,
                                    child: AfriButton(
                                      label: l10n.ticketAppleWallet,
                                      onTap: () {},
                                      variant: AfriButtonVariant.outline,
                                      icon: AfriIcons.addCard,
                                      enabled: false,
                                    ),
                                  ),
                                  const SizedBox(
                                    height: SpacingTokens.spacing3,
                                  ),
                                  SizedBox(
                                    width: double.infinity,
                                    child: AfriButton(
                                      label: l10n.ticketGoogleWallet,
                                      onTap: () {},
                                      variant: AfriButtonVariant.outline,
                                      icon: AfriIcons.wallet,
                                      enabled: false,
                                    ),
                                  ),
                                ] else
                                  Row(
                                    children: [
                                      Expanded(
                                        child: AfriButton(
                                          label: l10n.ticketAppleWallet,
                                          onTap: () {},
                                          variant: AfriButtonVariant.outline,
                                          icon: AfriIcons.addCard,
                                          enabled: false,
                                        ),
                                      ),
                                      const SizedBox(
                                        width: SpacingTokens.spacing3,
                                      ),
                                      Expanded(
                                        child: AfriButton(
                                          label: l10n.ticketGoogleWallet,
                                          onTap: () {},
                                          variant: AfriButtonVariant.outline,
                                          icon: AfriIcons.wallet,
                                          enabled: false,
                                        ),
                                      ),
                                    ],
                                  ),
                                const SizedBox(height: SpacingTokens.spacing3),
                                Text(
                                  l10n.ticketWalletExportUnavailable,
                                  style: TypographyTokens.bodySmall(
                                    ColorTokens.onSurfaceVariant,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
                final isRefreshing = ticketAsync.isRefreshing;
                if (!isOnline ||
                    isRefreshing ||
                    routeState.phase == ETicketPhase.syncing ||
                    routeState.failure != null) {
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          SpacingTokens.spacing6,
                          SpacingTokens.spacing3,
                          SpacingTokens.spacing6,
                          0,
                        ),
                        child: _RetainedTicketBanner(
                          online: isOnline,
                          refreshing: isRefreshing ||
                              routeState.phase == ETicketPhase.syncing,
                          failure: routeState.failure,
                          onRefresh: routeState.failure?.kind ==
                                  ETicketFailureKind.permissionDenied
                              ? null
                              : () => unawaited(
                                    ref
                                        .read(
                                          eTicketProvider(widget.ticketId)
                                              .notifier,
                                        )
                                        .refresh(),
                                  ),
                        ),
                      ),
                      Expanded(child: pass),
                    ],
                  );
                }
                return Semantics(
                  selected: true,
                  label: l10n.ticketSelectedSemantic(ticket.matchTitle),
                  child: pass,
                );
              },
            ),
    );
  }

  Widget _failureState(Object error, bool isOnline) {
    final failure = ETicketFailure.fromError(error);
    return switch (failure.kind) {
      ETicketFailureKind.offline => _QrState(
          title: context.afriL10n.ticketOfflineTitle,
          body: context.afriL10n.ticketOfflineMessage,
        ),
      ETicketFailureKind.permissionDenied => _QrState(
          title: context.afriL10n.ticketAccessDeniedTitle,
          body: context.afriL10n.ticketAccessDeniedMessage,
        ),
      ETicketFailureKind.conflict => _QrState(
          title: context.afriL10n.ticketChangedTitle,
          body: context.afriL10n.ticketChangedMessage,
          actionLabel: isOnline ? context.afriL10n.ticketRefreshAction : null,
          onAction: isOnline
              ? () => unawaited(
                    ref
                        .read(eTicketProvider(widget.ticketId).notifier)
                        .refresh(),
                  )
              : null,
        ),
      ETicketFailureKind.securityTimeout => _QrState(
          title: context.afriL10n.ticketSecurityTimeoutTitle,
          body: context.afriL10n.ticketSecurityTimeoutMessage,
          actionLabel: isOnline ? context.afriL10n.ticketRefreshAction : null,
          onAction: isOnline
              ? () => unawaited(
                    ref
                        .read(eTicketProvider(widget.ticketId).notifier)
                        .refresh(),
                  )
              : null,
        ),
      ETicketFailureKind.unknown => _QrState(
          title: context.afriL10n.ticketUnavailableTitle,
          body: context.afriL10n.ticketUnavailableMessage,
          actionLabel: isOnline ? context.afriL10n.ticketRefreshAction : null,
          onAction: isOnline
              ? () => unawaited(
                    ref
                        .read(eTicketProvider(widget.ticketId).notifier)
                        .refresh(),
                  )
              : null,
        ),
    };
  }

  Widget _buildPassMeta(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TypographyTokens.labelSmall(
            ColorTokens.inkFaint,
          ).copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: SpacingTokens.spacing1 / 2),
        Text(
          value,
          style: TypographyTokens.labelMedium(
            ColorTokens.inkBase,
          ).copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _RetainedTicketBanner extends StatelessWidget {
  const _RetainedTicketBanner({
    required this.online,
    required this.refreshing,
    required this.failure,
    required this.onRefresh,
  });

  final bool online;
  final bool refreshing;
  final ETicketFailure? failure;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = context.afriL10n;
    final title = !online
        ? l10n.ticketSavedCodeTitle
        : refreshing
            ? l10n.ticketRefreshingTitle
            : failure?.kind == ETicketFailureKind.permissionDenied
                ? l10n.ticketAccessChangedTitle
                : failure?.kind == ETicketFailureKind.conflict
                    ? l10n.ticketChangedTitle
                    : failure?.kind == ETicketFailureKind.securityTimeout
                        ? l10n.ticketCheckTimedOutTitle
                        : l10n.ticketRefreshUnavailableTitle;
    final subtitle = !online
        ? l10n.ticketSavedCodeMessage
        : refreshing
            ? l10n.ticketRefreshingMessage
            : l10n.ticketRefreshBeforeUse;
    return Column(
      children: [
        AfriStateBanner(
          icon: !online ? AfriIcons.offline : AfriIcons.statusWarning,
          title: title,
          subtitle: subtitle,
          tone: refreshing
              ? AfriStateBannerTone.info
              : AfriStateBannerTone.warning,
          compact: true,
        ),
        if (onRefresh != null && !refreshing) ...[
          const SizedBox(height: SpacingTokens.spacing2),
          AfriButton(
            label: l10n.ticketRefreshUpper,
            icon: AfriIcons.refresh,
            variant: AfriButtonVariant.outline,
            onTap: onRefresh!,
          ),
        ],
      ],
    );
  }
}

class _QrState extends StatelessWidget {
  const _QrState({
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(SpacingTokens.spacing8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              AfriIcons.qrCode,
              size: 56,
              color: ColorTokens.onSurfaceVariant,
            ),
            const SizedBox(height: SpacingTokens.spacing4),
            Text(title, style: TypographyTokens.headlineSmall()),
            const SizedBox(height: SpacingTokens.spacing2),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TypographyTokens.bodyMedium(),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: SpacingTokens.spacing5),
              AfriButton(
                label: actionLabel!.toUpperCase(),
                icon: AfriIcons.refresh,
                onTap: onAction!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
