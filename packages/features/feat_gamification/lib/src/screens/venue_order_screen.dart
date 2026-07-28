import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class VenueOrderScreen extends StatefulWidget {
  const VenueOrderScreen({super.key});

  @override
  State<VenueOrderScreen> createState() => _VenueOrderScreenState();
}

class _VenueOrderScreenState extends State<VenueOrderScreen> {
  int _waterCount = 1;
  int _juiceCount = 0;
  String _statusCode = 'draft';

  int get _totalItems => _waterCount + _juiceCount;
  int get _totalAmount => (_waterCount * 1500) + (_juiceCount * 2500);

  void _submitOrder() {
    setState(() {
      _statusCode = _totalItems == 0 ? 'empty' : 'created';
    });
  }

  void _advanceStatus() {
    setState(() {
      _statusCode = switch (_statusCode) {
        'created' => 'accepted',
        'accepted' => 'preparing',
        'preparing' => 'ready',
        'ready' => 'served',
        _ => 'created',
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final status = _orderStatusFor(_statusCode);

    return AfriScreenScaffold(
      backgroundColor: ColorTokens.background,
      appBar: AfriAppBar(
        backgroundColor: ColorTokens.transparent,
        title: Text('Venue order', style: TypographyTokens.headlineSmall()),
        leading: AfriIconButton(
          icon: AfriIcons.back,
          onTap: () => context.pop(),
          tooltip: 'Back',
        ),
      ),
      scrollable: false,
      constrainContent: true,
      bodyWrapper: (child) => GradientBackground(child: child),
      child: ListView(
        padding: const EdgeInsets.all(SpacingTokens.screenPadding),
        children: [
          AfriSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  AfriIcons.cart,
                  color: ColorTokens.clubAccent,
                  size: SpacingTokens.spacing10,
                ),
                const SizedBox(height: SpacingTokens.spacing4),
                Text(
                  'Order from the approved drinks menu',
                  style: TypographyTokens.headlineLarge().copyWith(
                    fontWeight: FontWeight.w900,
                    height: TypographyTokens.lineHeightCompact,
                  ),
                ),
                const SizedBox(height: SpacingTokens.spacing3),
                Text(
                  'Supporters can create and track drinks-only orders. Staff queue controls and admin approvals stay outside the mobile app.',
                  style: TypographyTokens.bodyMedium(),
                ),
              ],
            ),
          ),
          const SizedBox(height: SpacingTokens.sectionGap),
          AfriSectionCard(
            title: 'Approved drinks',
            child: Column(
              children: [
                _DrinkStepper(
                  label: 'Water',
                  detail: 'RWF 1,500',
                  count: _waterCount,
                  onAdd: () => setState(() => _waterCount++),
                  onRemove: _waterCount == 0
                      ? null
                      : () => setState(() => _waterCount--),
                ),
                const SizedBox(height: SpacingTokens.spacing3),
                _DrinkStepper(
                  label: 'Passion juice',
                  detail: 'RWF 2,500',
                  count: _juiceCount,
                  onAdd: () => setState(() => _juiceCount++),
                  onRemove: _juiceCount == 0
                      ? null
                      : () => setState(() => _juiceCount--),
                ),
              ],
            ),
          ),
          const SizedBox(height: SpacingTokens.sectionGap),
          AfriSurfaceCard(
            child: Row(
              children: [
                Icon(
                  AfriIcons.myPicks,
                  color: ColorTokens.clubAccent,
                  size: AfriIcons.sizeNav,
                ),
                const SizedBox(width: SpacingTokens.spacing3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Receipt preview',
                        style: TypographyTokens.titleLarge(),
                      ),
                      const SizedBox(height: SpacingTokens.spacing1),
                      Text(
                        '$_totalItems item${_totalItems == 1 ? '' : 's'} · RWF $_totalAmount',
                        style: TypographyTokens.bodyMedium(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: SpacingTokens.sectionGap),
          AfriStateBanner(
            icon: status.icon,
            title: status.title,
            subtitle: status.subtitle,
            tone: status.tone,
          ),
          const SizedBox(height: SpacingTokens.spacing4),
          AfriButton(
            label: 'Create order',
            icon: AfriIcons.cart,
            onTap: _submitOrder,
          ),
          const SizedBox(height: SpacingTokens.spacing3),
          AfriButton(
            label: 'Preview next status',
            icon: AfriIcons.statusPending,
            variant: AfriButtonVariant.secondary,
            onTap: _advanceStatus,
          ),
          const SizedBox(height: SpacingTokens.sectionGap),
          const AfriSectionCard(
            title: 'Order protections',
            child: Column(
              children: [
                _ProtectionRow(
                  label: 'Alcohol items',
                  detail: 'Age gate required',
                ),
                _ProtectionRow(
                  label: 'Duplicate submit',
                  detail: 'Idempotency key',
                ),
                _ProtectionRow(
                  label: 'Staff actions',
                  detail: 'Venue portal only',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DrinkStepper extends StatelessWidget {
  const _DrinkStepper({
    required this.label,
    required this.detail,
    required this.count,
    required this.onAdd,
    required this.onRemove,
  });

  final String label;
  final String detail;
  final int count;
  final VoidCallback onAdd;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TypographyTokens.titleSmall()),
              Text(detail, style: TypographyTokens.bodySmall()),
            ],
          ),
        ),
        AfriIconButton(
          icon: AfriIcons.remove,
          onTap: onRemove,
          tooltip: 'Remove $label',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SpacingTokens.spacing2,
          ),
          child: Text('$count', style: TypographyTokens.titleMedium()),
        ),
        AfriIconButton(
          icon: AfriIcons.add,
          onTap: onAdd,
          tooltip: 'Add $label',
        ),
      ],
    );
  }
}

class _ProtectionRow extends StatelessWidget {
  const _ProtectionRow({required this.label, required this.detail});

  final String label;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: SpacingTokens.spacing3),
      child: Row(
        children: [
          Icon(
            AfriIcons.shield,
            color: ColorTokens.success,
            size: AfriIcons.sizeInline,
          ),
          const SizedBox(width: SpacingTokens.spacing3),
          Expanded(child: Text(label, style: TypographyTokens.titleSmall())),
          Text(detail, style: TypographyTokens.bodySmall()),
        ],
      ),
    );
  }
}

class _OrderStatus {
  const _OrderStatus({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tone,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final AfriStateBannerTone tone;
}

_OrderStatus _orderStatusFor(String code) {
  switch (code) {
    case 'empty':
      return const _OrderStatus(
        title: 'Choose at least one drink',
        subtitle: 'The order cannot be created with an empty basket.',
        icon: AfriIcons.statusWarning,
        tone: AfriStateBannerTone.warning,
      );
    case 'created':
      return const _OrderStatus(
        title: 'Order created',
        subtitle:
            'The venue queue can accept or cancel it from the staff portal.',
        icon: AfriIcons.statusInfo,
        tone: AfriStateBannerTone.info,
      );
    case 'accepted':
      return const _OrderStatus(
        title: 'Accepted by venue',
        subtitle: 'Staff confirmed the order and started the queue trail.',
        icon: AfriIcons.statusSuccess,
        tone: AfriStateBannerTone.success,
      );
    case 'preparing':
      return const _OrderStatus(
        title: 'Preparing',
        subtitle: 'The supporter can track progress without staff controls.',
        icon: AfriIcons.statusPending,
        tone: AfriStateBannerTone.info,
      );
    case 'ready':
      return const _OrderStatus(
        title: 'Ready for pickup',
        subtitle: 'Show the receipt at the venue counter.',
        icon: AfriIcons.verified,
        tone: AfriStateBannerTone.success,
      );
    case 'served':
      return const _OrderStatus(
        title: 'Served',
        subtitle: 'The audit trail remains in the venue order events.',
        icon: AfriIcons.statusSuccess,
        tone: AfriStateBannerTone.success,
      );
    default:
      return const _OrderStatus(
        title: 'Draft order',
        subtitle: 'Choose drinks from the approved venue menu.',
        icon: AfriIcons.cart,
        tone: AfriStateBannerTone.neutral,
      );
  }
}
