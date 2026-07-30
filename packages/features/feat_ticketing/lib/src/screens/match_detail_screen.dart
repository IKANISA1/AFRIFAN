import 'dart:async';

import 'package:core_auth/core_auth.dart';
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
            'Connect to verify current ticket payment availability.';
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
            'Connect to verify current ticket payment availability.';
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
            ? 'Ticket payment setup is pending club activation.'
            : null;
      });
    } catch (_) {
      if (!mounted || lookupKey != _paymentRouteLookupKey) return;
      setState(() {
        _paymentRoute = null;
        _paymentRouteMessage =
            'Payment route verification is unavailable. Try again.';
      });
    }
  }

  Future<void> _handlePurchase(ClubMatch match) async {
    if (_submitting) return;
    if (!ConnectivityService.isOnline) {
      AfriToast.error(
        context,
        'Connect before purchasing. Your seat and quantity are still selected.',
      );
      return;
    }

    final user = ref.read(currentUserProvider);
    if (user == null) {
      AfriToast.info(context, 'Sign in first to buy tickets.');
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
      final route = _paymentRoute ??
          await repo.findActivePaymentRoute(user.clubId).timeout(
                ref.read(ticketDetailMutationTimeoutProvider),
              );
      if (route == null) {
        if (!mounted) return;
        setState(() {
          _paymentRouteMessage =
              'Ticket payment setup is pending club activation.';
        });
        AfriToast.error(
          context,
          'MOMO ticketing setup is pending club activation.',
        );
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
        AfriToast.error(
          context,
          'Ticket reservation failed. Please try again from the match screen.',
        );
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
        AfriToast.error(
          context,
          'Ticket request was saved, but the MOMO dialer could not open.',
        );
        context.go('/tickets?tab=mine');
        return;
      }

      AfriToast.success(
        context,
        _quantity == 1
            ? 'Ticket request submitted — pending payment verification.'
            : '${tickets.length} ticket requests submitted — pending verification.',
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
      AfriToast.error(
        context,
        'Ticket confirmation timed out. Check My Tickets before trying again.',
      );
      context.go('/tickets?tab=mine');
    } catch (_) {
      if (!mounted) return;
      AfriToast.error(
        context,
        'Ticket request failed. Your selection is still available.',
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final accessEnabled = ref.watch(ticketDetailAccessEnabledProvider);
    if (accessEnabled) {
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
        title: Text('MATCH DAY', style: TypographyTokens.headlineLarge()),
      ),
      scrollable: false,
      child: !accessEnabled
          ? MatchDetailEmptyState(
              title: 'Ticket sales unavailable',
              body: 'Ticket selection is not enabled for this build or club.',
              actionLabel: 'Back to Tickets',
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
                    title: 'Fixture not found',
                    body: 'This fixture is unavailable.',
                    actionLabel: 'Back to Tickets',
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
                          final inAnimation = Tween<Offset>(
                            begin: const Offset(1.0, 0.0),
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOut,
                            ),
                          );
                          final outAnimation = Tween<Offset>(
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
    final failure = error is TicketDetailFailure
        ? error
        : TicketDetailFailure.fromError(error);
    switch (failure.kind) {
      case TicketDetailFailureKind.offline:
        return MatchDetailEmptyState(
          title: 'Ticket details unavailable offline',
          body: 'Connect to load this fixture and current ticket availability.',
          actionLabel: 'Back to Tickets',
          onPressed: () => context.go('/tickets'),
        );
      case TicketDetailFailureKind.permissionDenied:
        return MatchDetailEmptyState(
          title: 'Ticket access denied',
          body: 'This fixture is not available for the current club account.',
          actionLabel: 'Back to Tickets',
          onPressed: () => context.go('/tickets'),
        );
      case TicketDetailFailureKind.securityTimeout:
        return MatchDetailEmptyState(
          title: 'Ticket security check timed out',
          body: 'The fixture could not be confirmed safely. Try again.',
          actionLabel: 'TRY AGAIN',
          onPressed: () =>
              ref.read(ticketDetailProvider(widget.matchId).notifier).load(),
        );
      case TicketDetailFailureKind.conflict:
        return MatchDetailEmptyState(
          title: 'Fixture details changed',
          body: 'Refresh the fixture before selecting ticket access.',
          actionLabel: 'REFRESH FIXTURE',
          onPressed: () =>
              ref.read(ticketDetailProvider(widget.matchId).notifier).load(),
        );
      case TicketDetailFailureKind.unknown:
        return MatchDetailEmptyState(
          title: 'Unable to load this fixture',
          body: 'The fixture could not be confirmed. Try again.',
          actionLabel: 'TRY AGAIN',
          onPressed: () =>
              ref.read(ticketDetailProvider(widget.matchId).notifier).load(),
        );
    }
  }

  Widget? _retainedBanner(TicketDetailState detail) {
    if (!ConnectivityService.isOnline) {
      return const _TicketDetailStatus(
        title: 'Showing saved fixture',
        body:
            'Ticket prices may have changed. Reconnect before reviewing or purchasing.',
        tone: AfriStateBannerTone.warning,
      );
    }
    if (detail.phase == TicketDetailPhase.syncing) {
      return const _TicketDetailStatus(
        title: 'Refreshing fixture',
        body: 'The last confirmed ticket options remain visible.',
        tone: AfriStateBannerTone.info,
      );
    }
    final failure = detail.failure;
    if (failure == null) return null;
    return switch (failure.kind) {
      TicketDetailFailureKind.conflict => _TicketDetailStatus(
          title: 'Fixture changed',
          body:
              'These are the last confirmed options. Refresh before continuing.',
          tone: AfriStateBannerTone.warning,
          actionLabel: 'REFRESH FIXTURE',
          onAction: () =>
              ref.read(ticketDetailProvider(widget.matchId).notifier).refresh(),
        ),
      TicketDetailFailureKind.securityTimeout => _TicketDetailStatus(
          title: 'Fixture check timed out',
          body:
              'These are the last confirmed options. Refresh before continuing.',
          tone: AfriStateBannerTone.warning,
          actionLabel: 'REFRESH FIXTURE',
          onAction: () =>
              ref.read(ticketDetailProvider(widget.matchId).notifier).refresh(),
        ),
      TicketDetailFailureKind.permissionDenied => const _TicketDetailStatus(
          title: 'Ticket access changed',
          body:
              'The saved fixture is read-only. Return to Tickets to continue safely.',
          tone: AfriStateBannerTone.danger,
        ),
      TicketDetailFailureKind.offline => const _TicketDetailStatus(
          title: 'Showing saved fixture',
          body:
              'Ticket prices may have changed. Reconnect before reviewing or purchasing.',
          tone: AfriStateBannerTone.warning,
        ),
      TicketDetailFailureKind.unknown => _TicketDetailStatus(
          title: 'Fixture refresh failed',
          body:
              'These are the last confirmed options. Refresh before continuing.',
          tone: AfriStateBannerTone.warning,
          actionLabel: 'REFRESH FIXTURE',
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
