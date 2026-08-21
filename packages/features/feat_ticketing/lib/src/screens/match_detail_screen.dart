import 'dart:async';

import 'package:core_auth/core_auth.dart';
import 'package:core_feature_config/core_feature_config.dart';
import 'package:core_l10n/core_l10n.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:feat_club/feat_club.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/ticket_detail_provider.dart';
import '../ticketing_providers.dart';
import '../widgets/ticket_checkout_shared.dart';
import '../widgets/ticket_checkout_step.dart';
import '../widgets/ticket_configure_step.dart';

enum _CheckoutWizardStep { configure, checkout }

class MatchDetailScreen extends ConsumerStatefulWidget {
  const MatchDetailScreen({super.key, required this.matchId});

  final String matchId;

  @override
  ConsumerState<MatchDetailScreen> createState() => _MatchDetailScreenState();
}

class _MatchDetailScreenState extends ConsumerState<MatchDetailScreen> {
  _CheckoutWizardStep _step = _CheckoutWizardStep.configure;
  SeatType _selectedSeatType = SeatType.general;
  String? _selectedSeatCode;
  int _quantity = 1;
  bool _submitting = false;
  PartnerPaymentRoute? _paymentRoute;
  String? _paymentRouteMessage;
  String? _paymentRouteLookupKey;
  late bool _wasOnline;
  CurrencyFormatter get _currencyFormatter => CurrencyFormatter(
    currencyCode: context.afriCurrencyCode,
    currencySymbol: context.afriCurrencySymbol,
  );

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

    if (!isOnline) {
      setState(() {
        _paymentRouteMessage =
            context.afriL10n.ticketPaymentAvailabilityOffline;
      });
    } else if (restored) {
      unawaited(
        ref.read(ticketDetailProvider(widget.matchId).notifier).refresh(),
      );
      unawaited(_refreshPaymentRouteState(ref.read(currentUserProvider)));
    }
  }

  void _ensurePaymentRouteState(UserProfile? user) {
    final lookupKey = user == null ? 'guest' : '${user.id}:${user.clubId}';
    if (_paymentRouteLookupKey == lookupKey) {
      return;
    }

    _paymentRouteLookupKey = lookupKey;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_refreshPaymentRouteState(user));
    });
  }

  Future<void> _refreshPaymentRouteState(UserProfile? user) async {
    final lookupKey = _paymentRouteLookupKey;
    if (user == null) {
      if (!mounted || lookupKey != _paymentRouteLookupKey) return;
      setState(() {
        _paymentRoute = null;
        _paymentRouteMessage = null;
      });
      return;
    }
    if (!ConnectivityService.isOnline) {
      if (!mounted || lookupKey != _paymentRouteLookupKey) return;
      setState(() {
        _paymentRouteMessage =
            context.afriL10n.ticketPaymentAvailabilityOffline;
      });
      return;
    }

    try {
      final route = await ref
          .read(clubRepositoryProvider)
          .findActivePaymentRoute(user.clubId)
          .timeout(ref.read(ticketDetailLoadTimeoutProvider));

      if (!mounted || lookupKey != _paymentRouteLookupKey) return;
      setState(() {
        _paymentRoute = route;
        _paymentRouteMessage = route == null
            ? context.afriL10n.ticketPaymentSetupPending
            : null;
      });
    } catch (_) {
      if (!mounted || lookupKey != _paymentRouteLookupKey) return;
      setState(() {
        _paymentRoute = null;
        _paymentRouteMessage =
            context.afriL10n.ticketPaymentVerificationUnavailable;
      });
    }
  }

  Future<void> _handlePurchase(ClubMatch match) async {
    if (_submitting) return;
    if (!ref
        .read(storeReleasePolicyProvider)
        .allowsUnreconciledExternalPaymentLaunch) {
      AfriToast.error(
        context,
        context.afriL10n.ticketPaymentVerificationUnavailable,
      );
      return;
    }
    if (!ConnectivityService.isOnline) {
      AfriToast.error(context, context.afriL10n.ticketConnectBeforePurchase);
      return;
    }

    final user = ref.read(currentUserProvider);
    if (user == null) {
      AfriToast.info(context, context.afriL10n.ticketSignInBeforePurchase);
      context.go('/onboarding');
      return;
    }

    setState(() => _submitting = true);
    final repo = ref.read(clubRepositoryProvider);
    final amount = _selectedSeatType == SeatType.vip
        ? match.ticketVipPrice
        : match.ticketGeneralPrice;
    final total = amount * _quantity;

    try {
      final route =
          _paymentRoute ??
          await repo
              .findActivePaymentRoute(user.clubId)
              .timeout(ref.read(ticketDetailMutationTimeoutProvider));
      if (route == null) {
        if (!mounted) return;
        setState(() {
          _paymentRouteMessage = context.afriL10n.ticketPaymentSetupPending;
        });
        AfriToast.error(context, context.afriL10n.ticketMomoSetupPending);
        return;
      }

      final reference = 'ticket-${DateTime.now().millisecondsSinceEpoch}';
      final tickets = await repo
          .purchaseTickets(
            matchId: match.id,
            userId: user.id,
            seatType: _selectedSeatType.value,
            quantity: _quantity,
            paymentReference: reference,
          )
          .timeout(ref.read(ticketDetailMutationTimeoutProvider));

      ref.invalidate(ticketMatchesProvider);
      ref.invalidate(myTicketsProvider);

      if (!mounted) return;

      if (tickets.isEmpty) {
        AfriToast.error(context, context.afriL10n.ticketReservationFailed);
        return;
      }

      final launched = await MomoDialerService.launchMomoUssd(
        recipient: route.recipientCode,
        amount: total,
        country: route.country,
        recipientType: PaymentRecipientType.code,
      );

      if (!mounted) return;

      if (!launched) {
        AfriToast.error(context, context.afriL10n.ticketDialerOpenFailed);
        context.go('/tickets?tab=mine');
        return;
      }

      AfriToast.success(
        context,
        context.afriL10n.ticketRequestsSubmitted(tickets.length),
      );
      unawaited(
        FirebaseAnalyticsService.logTicketCompletion(
          ticketType: _selectedSeatType.value,
          paymentChannel: 'momo',
        ),
      );

      if (tickets.length == 1 &&
          tickets.first.status == TicketStatus.active &&
          mounted) {
        context.go('/e-ticket/${tickets.first.id}');
      } else {
        context.go('/tickets?tab=mine');
      }
    } on TimeoutException {
      if (!mounted) return;
      AfriToast.error(context, context.afriL10n.ticketConfirmationTimedOut);
      context.go('/tickets?tab=mine');
    } catch (_) {
      if (!mounted) return;
      AfriToast.error(context, context.afriL10n.ticketRequestFailed);
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.afriL10n;
    final user = ref.watch(currentUserProvider);
    final accessEnabled = ref.watch(ticketDetailAccessEnabledProvider);
    final checkoutAllowed = ref.watch(
      storeReleasePolicyProvider.select(
        (policy) => policy.allowsUnreconciledExternalPaymentLaunch,
      ),
    );
    if (accessEnabled && checkoutAllowed) {
      _ensurePaymentRouteState(user);
    }
    final detailAsync = ref.watch(ticketDetailProvider(widget.matchId));

    return AfriScreenScaffold(
      backgroundColor: ColorTokens.background,
      appBar: AfriAppBar(
        backgroundColor: ColorTokens.transparent,
        elevation: 0,
        centerTitle: true,
        leading: AfriIconButton(
          key: const ValueKey<String>('ticket-detail-back'),
          icon: AfriIcons.back,
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onTap: () {
            if (_step == _CheckoutWizardStep.checkout) {
              unawaited(
                FirebaseAnalyticsService.logTaskAbandonment(
                  task: 'ticket_checkout',
                  stage: 'checkout_review',
                ),
              );
              setState(() => _step = _CheckoutWizardStep.configure);
            } else {
              context.pop();
            }
          },
        ),
        title: Text(
          l10n.ticketMatchDay,
          style: TypographyTokens.headlineLarge(),
        ),
      ),
      scrollable: false,
      child: !accessEnabled || !checkoutAllowed
          ? MatchDetailEmptyState(
              title: l10n.ticketSalesUnavailableTitle,
              body: l10n.ticketSalesUnavailableMessage,
              actionLabel: l10n.ticketBackToTickets,
              onPressed: () => context.go('/tickets'),
            )
          : detailAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(SpacingTokens.spacing4),
                child: AfriSkeletonList(),
              ),
              error: (error, _) => _failureConsequence(error),
              data: (detail) {
                final match = detail.match;
                if (match == null) {
                  return MatchDetailEmptyState(
                    title: l10n.ticketFixtureNotFoundTitle,
                    body: l10n.ticketFixtureNotFoundMessage,
                    actionLabel: l10n.ticketBackToTickets,
                    onPressed: () => context.go('/tickets'),
                  );
                }

                return Column(
                  children: [
                    if (_retainedBanner(detail) case final banner?) banner,
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: AfriMotion.emphasized,
                        transitionBuilder: (child, animation) {
                          final inAnimation =
                              Tween<Offset>(
                                begin: const Offset(1.0, 0.0),
                                end: Offset.zero,
                              ).animate(
                                CurvedAnimation(
                                  parent: animation,
                                  curve: Curves.easeOut,
                                ),
                              );
                          final outAnimation =
                              Tween<Offset>(
                                begin: const Offset(-1.0, 0.0),
                                end: Offset.zero,
                              ).animate(
                                CurvedAnimation(
                                  parent: animation,
                                  curve: Curves.easeOut,
                                ),
                              );
                          if (child.key ==
                              const ValueKey(_CheckoutWizardStep.checkout)) {
                            return SlideTransition(
                              position: inAnimation,
                              child: child,
                            );
                          }
                          return SlideTransition(
                            position: outAnimation,
                            child: child,
                          );
                        },
                        child: _step == _CheckoutWizardStep.configure
                            ? TicketConfigureStep(
                                key: const ValueKey(
                                  _CheckoutWizardStep.configure,
                                ),
                                match: match,
                                currency: _currencyFormatter,
                                selectedSeatType: _selectedSeatType,
                                selectedSeatCode: _selectedSeatCode,
                                quantity: _quantity,
                                onSeatTypeChanged: (type) =>
                                    setState(() => _selectedSeatType = type),
                                onQuantityChanged: (q) =>
                                    setState(() => _quantity = q),
                                onSeatCodeRequested: () async {
                                  final seat = await context.push<String>(
                                    '/tickets/map/${match.id}',
                                  );
                                  if (!mounted || seat == null) return;
                                  setState(() => _selectedSeatCode = seat);
                                },
                                onReviewRequested: () => setState(
                                  () => _step = _CheckoutWizardStep.checkout,
                                ),
                              )
                            : TicketCheckoutStep(
                                key: const ValueKey(
                                  _CheckoutWizardStep.checkout,
                                ),
                                match: match,
                                currency: _currencyFormatter,
                                selectedSeatType: _selectedSeatType,
                                selectedSeatCode: _selectedSeatCode,
                                quantity: _quantity,
                                paymentRoute: _paymentRoute,
                                paymentRouteMessage: _paymentRouteMessage,
                                submitting: _submitting,
                                onPurchaseRequest: () => _handlePurchase(match),
                              ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _failureConsequence(Object error) {
    final l10n = context.afriL10n;
    final failure = error is TicketDetailFailure
        ? error
        : TicketDetailFailure.fromError(error);
    switch (failure.kind) {
      case TicketDetailFailureKind.offline:
        return MatchDetailEmptyState(
          title: l10n.ticketDetailOfflineTitle,
          body: l10n.ticketDetailOfflineMessage,
          actionLabel: l10n.ticketBackToTickets,
          onPressed: () => context.go('/tickets'),
        );
      case TicketDetailFailureKind.permissionDenied:
        return MatchDetailEmptyState(
          title: l10n.ticketDetailAccessTitle,
          body: l10n.ticketDetailAccessMessage,
          actionLabel: l10n.ticketBackToTickets,
          onPressed: () => context.go('/tickets'),
        );
      case TicketDetailFailureKind.securityTimeout:
        return MatchDetailEmptyState(
          title: l10n.ticketDetailSecurityTitle,
          body: l10n.ticketDetailSecurityMessage,
          actionLabel: l10n.ticketTryAgainUpper,
          onPressed: () =>
              ref.read(ticketDetailProvider(widget.matchId).notifier).load(),
        );
      case TicketDetailFailureKind.conflict:
        return MatchDetailEmptyState(
          title: l10n.ticketDetailChangedTitle,
          body: l10n.ticketDetailChangedMessage,
          actionLabel: l10n.ticketRefreshFixtureUpper,
          onPressed: () =>
              ref.read(ticketDetailProvider(widget.matchId).notifier).load(),
        );
      case TicketDetailFailureKind.unknown:
        return MatchDetailEmptyState(
          title: l10n.ticketDetailUnavailableTitle,
          body: l10n.ticketDetailUnavailableMessage,
          actionLabel: l10n.ticketTryAgainUpper,
          onPressed: () =>
              ref.read(ticketDetailProvider(widget.matchId).notifier).load(),
        );
    }
  }

  Widget? _retainedBanner(TicketDetailState detail) {
    final l10n = context.afriL10n;
    if (!ConnectivityService.isOnline) {
      return _TicketDetailStatus(
        title: l10n.ticketSavedFixtureTitle,
        body: l10n.ticketSavedFixtureMessage,
        tone: AfriStateBannerTone.warning,
      );
    }
    if (detail.phase == TicketDetailPhase.syncing) {
      return _TicketDetailStatus(
        title: l10n.ticketRefreshingFixtureTitle,
        body: l10n.ticketRefreshingFixtureMessage,
        tone: AfriStateBannerTone.info,
      );
    }
    final failure = detail.failure;
    if (failure == null) return null;
    return switch (failure.kind) {
      TicketDetailFailureKind.conflict => _TicketDetailStatus(
        title: l10n.ticketFixtureChangedTitle,
        body: l10n.ticketLastConfirmedOptionsMessage,
        tone: AfriStateBannerTone.warning,
        actionLabel: l10n.ticketRefreshFixtureUpper,
        onAction: () =>
            ref.read(ticketDetailProvider(widget.matchId).notifier).refresh(),
      ),
      TicketDetailFailureKind.securityTimeout => _TicketDetailStatus(
        title: l10n.ticketFixtureCheckTimedOutTitle,
        body: l10n.ticketLastConfirmedOptionsMessage,
        tone: AfriStateBannerTone.warning,
        actionLabel: l10n.ticketRefreshFixtureUpper,
        onAction: () =>
            ref.read(ticketDetailProvider(widget.matchId).notifier).refresh(),
      ),
      TicketDetailFailureKind.permissionDenied => _TicketDetailStatus(
        title: l10n.ticketAccessChangedTitle,
        body: l10n.ticketSavedFixtureReadOnlyMessage,
        tone: AfriStateBannerTone.danger,
      ),
      TicketDetailFailureKind.offline => _TicketDetailStatus(
        title: l10n.ticketSavedFixtureTitle,
        body: l10n.ticketSavedFixtureMessage,
        tone: AfriStateBannerTone.warning,
      ),
      TicketDetailFailureKind.unknown => _TicketDetailStatus(
        title: l10n.ticketFixtureRefreshFailedTitle,
        body: l10n.ticketLastConfirmedOptionsMessage,
        tone: AfriStateBannerTone.warning,
        actionLabel: l10n.ticketRefreshFixtureUpper,
        onAction: () =>
            ref.read(ticketDetailProvider(widget.matchId).notifier).refresh(),
      ),
    };
  }
}

class _TicketDetailStatus extends StatelessWidget {
  const _TicketDetailStatus({
    required this.title,
    required this.body,
    required this.tone,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String body;
  final AfriStateBannerTone tone;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SpacingTokens.spacing4,
        SpacingTokens.spacing2,
        SpacingTokens.spacing4,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AfriStateBanner(
            icon: tone == AfriStateBannerTone.danger
                ? AfriIcons.statusError
                : AfriIcons.statusWarning,
            title: title,
            subtitle: body,
            tone: tone,
            compact: true,
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: SpacingTokens.spacing2),
            AfriButton(label: actionLabel!, onTap: onAction!),
          ],
        ],
      ),
    );
  }
}
