import 'package:core_l10n/core_l10n.dart';
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
    final stackControls = MediaQuery.textScalerOf(context).scale(16) >= 28;
    final quantityControls = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AfriIconButton(
          icon: AfriIcons.remove,
          onTap: quantity > 1 ? () => onQuantityChanged(quantity - 1) : null,
        ),
        const SizedBox(width: SpacingTokens.spacing3),
        Text('$quantity', style: TypographyTokens.headlineMedium()),
        const SizedBox(width: SpacingTokens.spacing3),
        AfriIconButton(
          icon: AfriIcons.add,
          onTap: quantity < 8 ? () => onQuantityChanged(quantity + 1) : null,
        ),
      ],
    );

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
                  context.afriL10n.ticketMatchVersus(
                    match.homeTeam,
                    match.awayTeam,
                  ),
                  style: TypographyTokens.headlineLarge(),
                ),
                const SizedBox(height: SpacingTokens.spacing2),
                Text(
                  context.afriL10n.ticketCompetitionVenue(
                    match.competition,
                    match.venue,
                  ),
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
                  context.afriL10n.ticketRemainingCapacity(
                    match.remainingCapacity,
                  ),
                  style: TypographyTokens.bodySmall(),
                ),
              ],
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing6),
          Text(
            context.afriL10n.ticketChooseAccess,
            style: TypographyTokens.labelLarge(),
          ),
          const SizedBox(height: SpacingTokens.spacing3),
          SeatTypeCard(
            title: context.afriL10n.ticketGeneral,
            subtitle: context.afriL10n.ticketGeneralSubtitle,
            amount: currency.format(match.ticketGeneralPrice),
            selected: generalSelected,
            onTap: () => onSeatTypeChanged(SeatType.general),
          ),
          const SizedBox(height: SpacingTokens.spacing3),
          SeatTypeCard(
            title: context.afriL10n.ticketVip,
            subtitle: context.afriL10n.ticketVipSubtitle,
            amount: currency.format(match.ticketVipPrice),
            selected: !generalSelected,
            onTap: () => onSeatTypeChanged(SeatType.vip),
          ),
          const SizedBox(height: SpacingTokens.spacing4),
          _OfficialTicketCategoryReference(currency: currency),
          const SizedBox(height: SpacingTokens.spacing6),
          AfriSurfaceCard(
            child: stackControls
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.afriL10n.ticketQuantityUpper,
                        style: TypographyTokens.labelLarge(),
                      ),
                      const SizedBox(height: SpacingTokens.spacing3),
                      Align(
                        alignment: Alignment.centerRight,
                        child: quantityControls,
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        context.afriL10n.ticketQuantityUpper,
                        style: TypographyTokens.labelLarge(),
                      ),
                      quantityControls,
                    ],
                  ),
          ),
          const SizedBox(height: SpacingTokens.spacing6),
          AfriOutlinedIconButton(
            onPressed: onSeatCodeRequested,
            icon: const Icon(AfriIcons.seat),
            label: Text(
              selectedSeatCode == null
                  ? context.afriL10n.ticketChooseSeat
                  : context.afriL10n.ticketChangeSeat,
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
            label: stackControls
                ? context.afriL10n.ticketReview
                : context.afriL10n.ticketReviewReservation,
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
    final stackContent = MediaQuery.textScalerOf(context).scale(16) >= 28;
    return AfriSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.afriL10n.ticketOfficialCategories,
            style: TypographyTokens.labelLarge(),
          ),
          const SizedBox(height: SpacingTokens.spacing2),
          Text(
            context.afriL10n.ticketOfficialCategoriesMessage,
            style: TypographyTokens.bodySmall(ColorTokens.onSurfaceVariant),
          ),
          const SizedBox(height: SpacingTokens.spacing4),
          ...officialTicketCategories.map(
            (category) => Padding(
              padding: const EdgeInsets.only(bottom: SpacingTokens.spacing2),
              child: stackContent
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category.name,
                          style: TypographyTokens.bodyMedium().copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: SpacingTokens.spacing1),
                        Text(
                          currency.format(category.priceRwf),
                          style: TypographyTokens.labelMedium(
                            ColorTokens.clubAccent,
                          ),
                        ),
                      ],
                    )
                  : Row(
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
