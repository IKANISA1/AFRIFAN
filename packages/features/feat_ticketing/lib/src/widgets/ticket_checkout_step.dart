import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:feat_club/feat_club.dart';
import 'package:flutter/material.dart';

import 'ticket_checkout_shared.dart';

class TicketCheckoutStep extends StatelessWidget {
  const TicketCheckoutStep({
    super.key,
    required this.match,
    required this.currency,
    required this.selectedSeatType,
    required this.selectedSeatCode,
    required this.quantity,
    required this.paymentRoute,
    required this.paymentRouteMessage,
    required this.submitting,
    required this.onPurchaseRequest,
  });

  final ClubMatch match;
  final CurrencyFormatter currency;
  final SeatType selectedSeatType;
  final String? selectedSeatCode;
  final int quantity;
  final PartnerPaymentRoute? paymentRoute;
  final String? paymentRouteMessage;
  final bool submitting;
  final VoidCallback onPurchaseRequest;

  @override
  Widget build(BuildContext context) {
    final total = (selectedSeatType == SeatType.vip
            ? match.ticketVipPrice
            : match.ticketGeneralPrice) *
        quantity;

    return SingleChildScrollView(
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
                TicketSummaryRow(
                  label: 'Match',
                  value: '${match.homeTeam} vs ${match.awayTeam}',
                ),
                TicketSummaryRow(
                  label: 'Seat type',
                  value: selectedSeatType.label,
                ),
                TicketSummaryRow(
                  label: 'Quantity',
                  value: '$quantity',
                ),
                if (selectedSeatCode != null)
                  TicketSummaryRow(
                    label: 'Seat code',
                    value: selectedSeatCode!,
                  ),
                TicketSummaryRow(
                  label: 'Total',
                  value: currency.format(total),
                  highlighted: true,
                ),
              ],
            ),
          ),
          if (paymentRouteMessage != null) ...[
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
                    paymentRouteMessage!,
                    style: TypographyTokens.bodyMedium(),
                  ),
                ],
              ),
            ),
          ] else if (paymentRoute != null) ...[
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
                      'Pay to ${paymentRoute!.payToLabel}\nDialer will open USSD prompt.',
                      style: TypographyTokens.bodyMedium(),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: SpacingTokens.spacing6),
          AfriButton(
            label: match.isSoldOut
                ? 'Sold out'
                : paymentRouteMessage != null
                    ? 'Payment route not ready'
                    : submitting
                        ? 'Processing'
                        : 'Pay via MOMO',
            icon: Icons.phone_android_rounded,
            fullWidth: true,
            isLoading: submitting,
            onTap: onPurchaseRequest,
            enabled: !match.isSoldOut &&
                    match.isOnSale &&
                    !submitting &&
                    paymentRouteMessage == null,
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
