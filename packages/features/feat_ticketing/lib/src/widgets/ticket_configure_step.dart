import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:feat_club/feat_club.dart';
import 'package:flutter/material.dart';

import '../official_ticket_categories.dart';
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
          AfriSurfaceCard(
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
            title: 'GENERAL',
            subtitle: 'Open stands / Bleachers area',
            amount: currency.format(match.ticketGeneralPrice),
            selected: generalSelected,
            onTap: () => onSeatTypeChanged(SeatType.general),
          ),
          const SizedBox(height: SpacingTokens.spacing3),
          SeatTypeCard(
            title: 'VIP',
            subtitle: 'Premium lounge seating',
            amount: currency.format(match.ticketVipPrice),
            selected: !generalSelected,
            onTap: () => onSeatTypeChanged(SeatType.vip),
          ),
          const SizedBox(height: SpacingTokens.spacing4),
          _OfficialTicketCategoryReference(currency: currency),
          const SizedBox(height: SpacingTokens.spacing6),
          AfriSurfaceCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('QUANTITY', style: TypographyTokens.labelLarge()),
                Row(
                  children: [
                    AfriIconButton(
                      icon: AfriIcons.remove,
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
                      icon: AfriIcons.add,
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
          AfriOutlinedIconButton(
            onPressed: onSeatCodeRequested,
            icon: const Icon(AfriIcons.seat),
            label: Text(
              selectedSeatCode == null
                  ? 'CHOOSE SPECIFIC SEAT'
                  : 'CHANGE SELECTED SEAT',
            ),
            style: AfriOutlinedButton.styleFrom(
              minimumSize: const Size(
                double.infinity,
                SizeTokens.buttonMinHeight,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: ShapeTokens.buttonRadius,
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

class _OfficialTicketCategoryReference extends StatelessWidget {
  const _OfficialTicketCategoryReference({required this.currency});

  final CurrencyFormatter currency;

  @override
  Widget build(BuildContext context) {
    return AfriSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('OFFICIAL CATEGORIES', style: TypographyTokens.labelLarge()),
          const SizedBox(height: SpacingTokens.spacing2),
          Text(
            'Approved public ticket tiers. Sale-specific availability appears when the club activates an official sale.',
            style: TypographyTokens.bodySmall(ColorTokens.onSurfaceVariant),
          ),
          const SizedBox(height: SpacingTokens.spacing4),
          ...officialTicketCategories.map(
            (category) => Padding(
              padding: const EdgeInsets.only(bottom: SpacingTokens.spacing2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      category.name,
                      style: TypographyTokens.bodyMedium().copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    currency.format(category.priceRwf),
                    style: TypographyTokens.labelMedium(
                      ColorTokens.clubAccent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
