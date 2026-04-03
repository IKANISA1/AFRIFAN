import 'package:core_auth/core_auth.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:feat_club/feat_club.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../ticketing_providers.dart';
import '../widgets/ticketing_overlays.dart';

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
  final _currency = CurrencyFormatter(
    currencyCode: 'RWF',
    currencySymbol: 'FRw',
  );

  void _ensurePaymentRouteState(UserProfile? user) {
    final lookupKey =
        user == null ? 'guest' : '${user.id}:${user.clubId}:${user.hasMomo}';
    if (_paymentRouteLookupKey == lookupKey) {
      return;
    }

    _paymentRouteLookupKey = lookupKey;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshPaymentRouteState(user);
    });
  }

  Future<void> _refreshPaymentRouteState(UserProfile? user) async {
    final lookupKey = _paymentRouteLookupKey;
    if (user == null || !user.hasMomo) {
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
      _paymentRouteMessage =
          route == null ? 'No active payment route for this club.' : null;
    });
  }

  Future<void> _handlePurchase(ClubMatch match) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in first to buy tickets.')),
      );
      context.go('/onboarding');
      return;
    }

    if (!user.hasMomo) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Link your MOMO number before buying tickets.'),
        ),
      );
      context.push('/profile_setup');
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
          _paymentRouteMessage = 'No active payment route for this club.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This club does not have an active MOMO ticketing route yet.',
            ),
            backgroundColor: ColorTokens.error,
          ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not launch the MOMO dialer.'),
            backgroundColor: ColorTokens.error,
          ),
        );
        return;
      }

      final confirmed = await showTicketPurchaseConfirmSheet(
        context,
        matchTitle: '${match.homeTeam} vs ${match.awayTeam}',
        zone: _selectedSeatType.label,
        quantity: _quantity,
        seatCode: _selectedSeatCode,
        totalLabel: _currency.format(total),
      );

      if (!confirmed || !mounted) return;

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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment was confirmed, but ticket issuance failed.'),
            backgroundColor: ColorTokens.error,
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _quantity == 1
                ? 'Ticket issued successfully.'
                : '${tickets.length} tickets issued successfully.',
          ),
          backgroundColor: ColorTokens.success,
        ),
      );

      if (tickets.length == 1) {
        context.go('/e-ticket/${tickets.first.id}');
      } else {
        context.go('/my-tickets');
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ticket purchase failed: $error'),
          backgroundColor: ColorTokens.error,
        ),
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
    _ensurePaymentRouteState(user);
    final matchAsync = ref.watch(ticketMatchProvider(widget.matchId));

    return Scaffold(
      backgroundColor: ColorTokens.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: ColorTokens.onSurface),
          onPressed: () {
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
        error: (error, _) => _TicketDetailState(
          title: 'Unable to load this fixture',
          body: 'Refresh and try again.',
          actionLabel: 'Back to Tickets',
          onPressed: () => context.go('/tickets'),
        ),
        data: (match) {
          if (match == null) {
            return _TicketDetailState(
              title: 'Fixture not found',
              body: 'This fixture is no longer available.',
              actionLabel: 'Back to Tickets',
              onPressed: () => context.go('/tickets'),
            );
          }

          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) {
              final inAnimation =
                  Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero)
                      .animate(CurvedAnimation(
                          parent: animation, curve: Curves.easeOut));
              final outAnimation = Tween<Offset>(
                      begin: const Offset(-1.0, 0.0), end: Offset.zero)
                  .animate(CurvedAnimation(
                      parent: animation, curve: Curves.easeOut));
              if (child.key == ValueKey(_CheckoutWizardStep.checkout)) {
                return SlideTransition(position: inAnimation, child: child);
              } else {
                return SlideTransition(position: outAnimation, child: child);
              }
            },
            child: _step == _CheckoutWizardStep.configure
                ? _buildConfigureStep(match)
                : _buildCheckoutStep(match),
          );
        },
      ),
    );
  }

  Widget _buildConfigureStep(ClubMatch match) {
    final generalSelected = _selectedSeatType == SeatType.general;

    return SingleChildScrollView(
      key: const ValueKey(_CheckoutWizardStep.configure),
      padding: const EdgeInsets.all(SpacingTokens.spacing6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClayCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${match.homeTeam} vs ${match.awayTeam}',
                  style: TypographyTokens.headlineLarge(),
                ),
                const SizedBox(height: SpacingTokens.spacing2),
                Text(
                  '${match.competition}  •  ${match.venue}',
                  style: TypographyTokens.bodyMedium(),
                ),
                const SizedBox(height: SpacingTokens.spacing2),
                Text(
                  AfriDateFormatter.formatDate(match.matchDate),
                  style: TypographyTokens.bodyLarge().copyWith(
                    color: ColorTokens.clubAccent,
                  ),
                ),
                const SizedBox(height: SpacingTokens.spacing2),
                Text(
                  'Remaining capacity: ${match.remainingCapacity}',
                  style: TypographyTokens.bodySmall(),
                ),
              ],
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing6),
          Text('CHOOSE ACCESS', style: TypographyTokens.labelLarge()),
          const SizedBox(height: SpacingTokens.spacing3),
          _SeatTypeCard(
            title: 'GENERAL ADMISSION',
            subtitle: 'Fast entry and general stand access',
            amount: _currency.format(match.ticketGeneralPrice),
            selected: generalSelected,
            onTap: () => setState(() => _selectedSeatType = SeatType.general),
          ),
          const SizedBox(height: SpacingTokens.spacing3),
          _SeatTypeCard(
            title: 'VIP',
            subtitle: 'Premium zone access and best sight lines',
            amount: _currency.format(match.ticketVipPrice),
            selected: !generalSelected,
            onTap: () => setState(() => _selectedSeatType = SeatType.vip),
          ),
          const SizedBox(height: SpacingTokens.spacing6),
          ClayCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('QUANTITY', style: TypographyTokens.labelLarge()),
                Row(
                  children: [
                    AfriIconButton(
                      icon: Icons.remove_rounded,
                      onTap: _quantity > 1
                          ? () => setState(() => _quantity--)
                          : null,
                    ),
                    const SizedBox(width: SpacingTokens.spacing3),
                    Text(
                      '$_quantity',
                      style: TypographyTokens.headlineMedium(),
                    ),
                    const SizedBox(width: SpacingTokens.spacing3),
                    AfriIconButton(
                      icon: Icons.add_rounded,
                      onTap: _quantity < 8
                          ? () => setState(() => _quantity++)
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing6),
          OutlinedButton.icon(
            onPressed: () async {
              final seat = await context.push<String>(
                '/tickets/map/${match.id}',
              );
              if (!mounted || seat == null) return;
              setState(() => _selectedSeatCode = seat);
            },
            icon: const Icon(Icons.event_seat_rounded),
            label: Text(
              _selectedSeatCode == null
                  ? 'CHOOSE SPECIFIC SEAT'
                  : 'CHANGE SELECTED SEAT',
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing6),
          ClaymorphicButton(
            label: 'REVIEW RESERVATION',
            onPressed: match.isSoldOut || !match.isOnSale
                ? null
                : () => setState(() => _step = _CheckoutWizardStep.checkout),
            width: double.infinity,
          ),
        ],
      ),
    );
  }

  Widget _buildCheckoutStep(ClubMatch match) {
    final total = (_selectedSeatType == SeatType.vip
            ? match.ticketVipPrice
            : match.ticketGeneralPrice) *
        _quantity;

    return SingleChildScrollView(
      key: const ValueKey(_CheckoutWizardStep.checkout),
      padding: const EdgeInsets.all(SpacingTokens.spacing6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClayCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CHECKOUT SUMMARY', style: TypographyTokens.labelLarge()),
                const SizedBox(height: SpacingTokens.spacing3),
                _SummaryRow(
                  label: 'Match',
                  value: '${match.homeTeam} vs ${match.awayTeam}',
                ),
                _SummaryRow(
                  label: 'Seat type',
                  value: _selectedSeatType.label,
                ),
                _SummaryRow(
                  label: 'Quantity',
                  value: '$_quantity',
                ),
                if (_selectedSeatCode != null)
                  _SummaryRow(
                    label: 'Seat code',
                    value: _selectedSeatCode!,
                  ),
                _SummaryRow(
                  label: 'Total',
                  value: _currency.format(total),
                  highlighted: true,
                ),
              ],
            ),
          ),
          if (_paymentRouteMessage != null) ...[
            const SizedBox(height: SpacingTokens.spacing4),
            ClayCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PAYMENT ROUTE',
                    style: TypographyTokens.labelLarge(),
                  ),
                  const SizedBox(height: SpacingTokens.spacing2),
                  Text(
                    _paymentRouteMessage!,
                    style: TypographyTokens.bodyMedium(),
                  ),
                ],
              ),
            ),
          ] else if (_paymentRoute != null) ...[
            const SizedBox(height: SpacingTokens.spacing4),
            ClayCard(
              child: Row(
                children: [
                  const Icon(
                    Icons.verified_rounded,
                    color: ColorTokens.success,
                  ),
                  const SizedBox(width: SpacingTokens.spacing3),
                  Expanded(
                    child: Text(
                      'Pay to ${_paymentRoute!.payToLabel}\nDialer will open USSD prompt.',
                      style: TypographyTokens.bodyMedium(),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: SpacingTokens.spacing6),
          ClaymorphicButton(
            label: match.isSoldOut
                ? 'SOLD OUT'
                : _paymentRouteMessage != null
                    ? 'PAYMENT ROUTE NOT READY'
                    : _submitting
                        ? 'PROCESSING'
                        : 'PAY VIA MOMO',
            icon: Icons.phone_android_rounded,
            width: double.infinity,
            onPressed: match.isSoldOut ||
                    !match.isOnSale ||
                    _submitting ||
                    _paymentRouteMessage != null
                ? null
                : () => _handlePurchase(match),
          ),
          const SizedBox(height: SpacingTokens.spacing3),
          Text(
            'Confirm payment after completing the MOMO prompt.',
            style: TypographyTokens.bodySmall(),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _SeatTypeCard extends StatelessWidget {
  const _SeatTypeCard({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String amount;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AfriPressFeedback(
      onTap: onTap,
      builder: (context, state) => ClayCard(
        padding: const EdgeInsets.all(SpacingTokens.spacing4),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: selected
                ? ColorTokens.clubPrimary.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: ShapeTokens.cardRadius,
            border: Border.all(
              color: selected ? ColorTokens.clubPrimary : Colors.transparent,
            ),
          ),
          padding: const EdgeInsets.all(SpacingTokens.spacing2),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TypographyTokens.labelLarge()),
                    const SizedBox(height: SpacingTokens.spacing1),
                    Text(subtitle, style: TypographyTokens.bodyMedium()),
                  ],
                ),
              ),
              const SizedBox(width: SpacingTokens.spacing4),
              Text(
                amount,
                style: TypographyTokens.headlineMedium().copyWith(
                  color: selected
                      ? ColorTokens.clubPrimary
                      : ColorTokens.clubAccent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.highlighted = false,
  });

  final String label;
  final String value;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: SpacingTokens.spacing2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TypographyTokens.bodyMedium()),
          Text(
            value,
            style: highlighted
                ? TypographyTokens.headlineMedium().copyWith(
                    color: ColorTokens.clubAccent,
                  )
                : TypographyTokens.labelLarge(),
          ),
        ],
      ),
    );
  }
}

class _TicketDetailState extends StatelessWidget {
  const _TicketDetailState({
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onPressed,
  });

  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(SpacingTokens.spacing8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.confirmation_number_outlined,
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
            const SizedBox(height: SpacingTokens.spacing6),
            ClaymorphicButton(label: actionLabel, onPressed: onPressed),
          ],
        ),
      ),
    );
  }
}
