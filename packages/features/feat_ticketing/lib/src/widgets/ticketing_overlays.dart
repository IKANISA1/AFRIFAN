import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

Future<bool> showTicketPurchaseConfirmSheet(
  BuildContext context, {
  required String matchTitle,
  required String zone,
  required int quantity,
  required String totalLabel,
  String? seatCode,
  String momoLabel = '07XX ***XXX',
}) async {
  final confirmed = await showAfriBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _TicketPurchaseConfirmSheet(
      matchTitle: matchTitle,
      zone: zone,
      quantity: quantity,
      seatCode: seatCode,
      totalLabel: totalLabel,
      momoLabel: momoLabel,
    ),
  );

  return confirmed ?? false;
}

class _TicketPurchaseConfirmSheet extends StatelessWidget {
  const _TicketPurchaseConfirmSheet({
    required this.matchTitle,
    required this.zone,
    required this.quantity,
    required this.totalLabel,
    this.seatCode,
    this.momoLabel = '07XX ***XXX',
  });

  final String matchTitle;
  final String zone;
  final int quantity;
  final String totalLabel;
  final String? seatCode;
  final String momoLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: ColorTokens.onSurfaceVariant.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
        const SizedBox(height: SpacingTokens.spacing4),
        Text(
          'CONFIRM PURCHASE',
          style: TypographyTokens.headlineMedium().copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: SpacingTokens.spacing4),
        GlassCard(
          animate: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SheetRow(label: 'MATCH', value: matchTitle),
              _SheetRow(label: 'ZONE', value: zone),
              if (seatCode != null) _SheetRow(label: 'SEAT', value: seatCode!),
              _SheetRow(label: 'QUANTITY', value: '$quantity'),
              const _SheetRow(label: 'SERVICE FEE', value: 'Included'),
              _SheetRow(label: 'TOTAL', value: totalLabel, highlighted: true),
              const SizedBox(height: SpacingTokens.spacing2),
              Text(
                'MOMO: $momoLabel',
                style: TypographyTokens.bodySmall(),
              ),
            ],
          ),
        ),
        const SizedBox(height: SpacingTokens.spacing4),
        Text(
          'Only confirm below if you completed the MoMo payment on your phone.',
          style: TypographyTokens.bodySmall(),
        ),
        const SizedBox(height: SpacingTokens.spacing5),
        AfriButton(
          label: 'I completed payment',
          fullWidth: true,
          onTap: () => context.pop(true),
        ),
        const SizedBox(height: SpacingTokens.spacing3),
        AfriButton(
          label: 'I did not pay',
          variant: AfriButtonVariant.outline,
          fullWidth: true,
          onTap: () => context.pop(false),
        ),
      ],
    );
  }
}

class _SheetRow extends StatelessWidget {
  const _SheetRow({
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
        children: [
          Expanded(
            child: Text(label, style: TypographyTokens.bodyMedium()),
          ),
          Text(
            value,
            style: highlighted
                ? TypographyTokens.headlineLarge(
                    ColorTokens.clubAccent,
                  ).copyWith(
                    fontWeight: FontWeight.w800,
                  )
                : TypographyTokens.labelLarge(),
          ),
        ],
      ),
    );
  }
}
