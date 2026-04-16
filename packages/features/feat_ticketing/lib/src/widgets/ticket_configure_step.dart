import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:feat_club/feat_club.dart';
import 'package:flutter/material.dart';

import 'ticket_checkout_shared.dart';

class TicketConfigureStep extends StatelessWidget {
  const TicketConfigureStep({
    super.key,
    required this.match,
    required this.currency,
    required this.selectedSeatType,
    required this.selectedSeatCode,
    required this.quantity,
    required this.onSeatTypeChanged,
    required this.onQuantityChanged,
    required this.onSeatCodeRequested,
    required this.onReviewRequested,
  });

  final ClubMatch match;
  final CurrencyFormatter currency;
  final SeatType selectedSeatType;
  final String? selectedSeatCode;
  final int quantity;
  final ValueChanged<SeatType> onSeatTypeChanged;
  final ValueChanged<int> onQuantityChanged;
  final VoidCallback onSeatCodeRequested;
  final VoidCallback onReviewRequested;

  @override
  Widget build(BuildContext context) {
    final generalSelected = selectedSeatType == SeatType.general;

    return SingleChildScrollView(
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
          SeatTypeCard(
            title: 'GENERAL ADMISSION',
            subtitle: 'Fast entry and general stand access',
            amount: currency.format(match.ticketGeneralPrice),
            selected: generalSelected,
            onTap: () => onSeatTypeChanged(SeatType.general),
          ),
          const SizedBox(height: SpacingTokens.spacing3),
          SeatTypeCard(
            title: 'VIP',
            subtitle: 'Premium zone access and best sight lines',
            amount: currency.format(match.ticketVipPrice),
            selected: !generalSelected,
            onTap: () => onSeatTypeChanged(SeatType.vip),
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
                      onTap: quantity > 1
                          ? () => onQuantityChanged(quantity - 1)
                          : null,
                    ),
                    const SizedBox(width: SpacingTokens.spacing3),
                    Text(
                      '$quantity',
                      style: TypographyTokens.headlineMedium(),
                    ),
                    const SizedBox(width: SpacingTokens.spacing3),
                    AfriIconButton(
                      icon: Icons.add_rounded,
                      onTap: quantity < 8
                          ? () => onQuantityChanged(quantity + 1)
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing6),
          OutlinedButton.icon(
            onPressed: onSeatCodeRequested,
            icon: const Icon(Icons.event_seat_rounded),
            label: Text(
              selectedSeatCode == null
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
          AfriButton(
            label: 'Review reservation',
            onTap: onReviewRequested,
            enabled: !match.isSoldOut && match.isOnSale,
            fullWidth: true,
          ),
        ],
      ),
    );
  }
}
