import 'dart:async';

import 'package:core_auth/core_auth.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:feat_club/feat_club.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
  CurrencyFormatter get _currencyFormatter => CurrencyFormatter(
        currencyCode: context.afriCurrencyCode,
        currencySymbol: context.afriCurrencySymbol,
      );

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

    final route = await ref
        .read(clubRepositoryProvider)
        .findActivePaymentRoute(user.clubId);

    if (!mounted || lookupKey != _paymentRouteLookupKey) return;
    setState(() {
      _paymentRoute = route;
      _paymentRouteMessage = route == null
          ? 'Ticket payment setup is pending club activation.'
          : null;
    });
  }

  Future<void> _handlePurchase(ClubMatch match) async {
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
      final route =
          _paymentRoute ?? await repo.findActivePaymentRoute(user.clubId);
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
      final tickets = await repo.purchaseTickets(
        matchId: match.id,
        userId: user.id,
        seatType: _selectedSeatType.value,
        quantity: _quantity,
        paymentReference: reference,
      );

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

      if (tickets.length == 1 &&
          tickets.first.status == TicketStatus.active &&
          mounted) {
        context.go('/e-ticket/${tickets.first.id}');
      } else {
        context.go('/tickets?tab=mine');
      }
    } catch (error) {
      if (!mounted) return;
      AfriToast.error(context, 'Ticket request failed: $error');
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    _ensurePaymentRouteState(user);
    final matchAsync = ref.watch(ticketMatchProvider(widget.matchId));

    return Scaffold(
      backgroundColor: ColorTokens.background,
      appBar: AfriAppBar(
        backgroundColor: ColorTokens.transparent,
        elevation: 0,
        centerTitle: true,
        leading: AfriIconButton(
          icon: AfriIcons.back,
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onTap: () {
            if (_step == _CheckoutWizardStep.checkout) {
              setState(() => _step = _CheckoutWizardStep.configure);
            } else {
              context.pop();
            }
          },
        ),
        title: Text('MATCH DAY', style: TypographyTokens.headlineLarge()),
      ),
      body: matchAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(SpacingTokens.spacing4),
          child: AfriSkeletonList(),
        ),
        error: (error, _) => MatchDetailEmptyState(
          title: 'Unable to load this fixture',
          body: 'Refresh and try again.',
          actionLabel: 'Back to Tickets',
          onPressed: () => context.go('/tickets'),
        ),
        data: (match) {
          if (match == null) {
            return MatchDetailEmptyState(
              title: 'Fixture not found',
              body: 'This fixture is unavailable.',
              actionLabel: 'Back to Tickets',
              onPressed: () => context.go('/tickets'),
            );
          }

          return AnimatedSwitcher(
            duration: AfriMotion.emphasized,
            transitionBuilder: (child, animation) {
              final inAnimation =
                  Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero)
                      .animate(CurvedAnimation(
                          parent: animation, curve: Curves.easeOut));
              final outAnimation = Tween<Offset>(
                      begin: const Offset(-1.0, 0.0), end: Offset.zero)
                  .animate(CurvedAnimation(
                      parent: animation, curve: Curves.easeOut));
              if (child.key == const ValueKey(_CheckoutWizardStep.checkout)) {
                return SlideTransition(position: inAnimation, child: child);
              } else {
                return SlideTransition(position: outAnimation, child: child);
              }
            },
            child: _step == _CheckoutWizardStep.configure
                ? TicketConfigureStep(
                    key: const ValueKey(_CheckoutWizardStep.configure),
                    match: match,
                    currency: _currencyFormatter,
                    selectedSeatType: _selectedSeatType,
                    selectedSeatCode: _selectedSeatCode,
                    quantity: _quantity,
                    onSeatTypeChanged: (type) =>
                        setState(() => _selectedSeatType = type),
                    onQuantityChanged: (q) => setState(() => _quantity = q),
                    onSeatCodeRequested: () async {
                      final seat = await context.push<String>(
                        '/tickets/map/${match.id}',
                      );
                      if (!mounted || seat == null) return;
                      setState(() => _selectedSeatCode = seat);
                    },
                    onReviewRequested: () =>
                        setState(() => _step = _CheckoutWizardStep.checkout),
                  )
                : TicketCheckoutStep(
                    key: const ValueKey(_CheckoutWizardStep.checkout),
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
          );
        },
      ),
    );
  }
}
