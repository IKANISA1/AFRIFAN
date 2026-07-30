import 'package:core_l10n/core_l10n.dart';
import 'package:core_network/core_network.dart';
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
          AfriSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.afriL10n.ticketCheckoutSummary,
                  style: TypographyTokens.labelLarge(),
                ),
                const SizedBox(height: SpacingTokens.spacing3),
                TicketSummaryRow(
                  label: context.afriL10n.ticketMatchLabel,
                  value: context.afriL10n.ticketMatchVersus(
                    match.homeTeam,
                    match.awayTeam,
                  ),
                ),
                TicketSummaryRow(
                  label: context.afriL10n.ticketSeatTypeLabel,
                  value: selectedSeatType.label,
                ),
                TicketSummaryRow(
                  label: context.afriL10n.ticketQuantityLabel,
                  value: '$quantity',
                ),
                if (selectedSeatCode != null)
                  TicketSummaryRow(
                    label: context.afriL10n.ticketSeatCodeLabel,
                    value: selectedSeatCode!,
                  ),
                TicketSummaryRow(
                  label: context.afriL10n.ticketTotalLabel,
                  value: currency.format(total),
                  highlighted: true,
                ),
              ],
            ),
          ),
          if (paymentRouteMessage != null) ...[
            const SizedBox(height: SpacingTokens.spacing4),
            AfriStateBanner(
              icon: AfriIcons.statusWarning,
              title: context.afriL10n.ticketPaymentRouteLabel,
              subtitle: paymentRouteMessage!,
              tone: AfriStateBannerTone.warning,
              compact: true,
            ),
          ] else if (paymentRoute != null) ...[
            const SizedBox(height: SpacingTokens.spacing4),
            AfriSurfaceCard(
              child: Row(
                children: [
                  Icon(
                    AfriIcons.verified,
                    color: ColorTokens.success,
                  ),
                  const SizedBox(width: SpacingTokens.spacing3),
                  Expanded(
                    child: Text(
                      context.afriL10n.ticketPayToDialer(
                        paymentRoute!.payToLabel,
                      ),
                      style: TypographyTokens.bodyMedium(),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: SpacingTokens.spacing6),
          ConnectivityBuilder(
            builder: (context, isOnline) => AfriButton(
              label: !isOnline
                  ? context.afriL10n.shopConnectionRequired
                  : match.isSoldOut
                      ? context.afriL10n.ticketSoldOut
                      : paymentRouteMessage != null
                          ? context.afriL10n.shopPaymentRouteNotReady
                          : submitting
                              ? context.afriL10n.shopProcessing
                              : context.afriL10n.ticketPayViaMomo,
              icon: AfriIcons.phone,
              fullWidth: true,
              isLoading: submitting,
              onTap: onPurchaseRequest,
              enabled: isOnline &&
                  !match.isSoldOut &&
                  match.isOnSale &&
                  !submitting &&
                  paymentRouteMessage == null,
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing3),
          Text(
            context.afriL10n.ticketConfirmAfterMomo,
            style: TypographyTokens.bodySmall(),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
