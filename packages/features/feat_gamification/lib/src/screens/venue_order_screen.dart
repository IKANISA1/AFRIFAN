import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../controllers/venue_order_controller.dart';
import '../venue_order_providers.dart';

class VenueOrderScreen extends ConsumerStatefulWidget {
  const VenueOrderScreen({super.key, this.submitFocusNode});

  final FocusNode? submitFocusNode;

  @override
  ConsumerState<VenueOrderScreen> createState() => _VenueOrderScreenState();
}

class _VenueOrderScreenState extends ConsumerState<VenueOrderScreen> {
  late bool _wasOnline;

  @override
  void initState() {
    super.initState();
    _wasOnline = ConnectivityService.isOnline;
    ConnectivityService.onlineNotifier.addListener(_connectivityChanged);
  }

  @override
  void dispose() {
    ConnectivityService.onlineNotifier.removeListener(_connectivityChanged);
    super.dispose();
  }

  void _connectivityChanged() {
    final online = ConnectivityService.isOnline;
    final restored = !_wasOnline && online;
    _wasOnline = online;
    if (!mounted) return;
    setState(() {});
    if (restored) {
      unawaited(
        ref.read(venueOrderControllerProvider.notifier).connectionRestored(),
      );
    }
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/fanzone');
    }
  }

  Future<void> _submit() async {
    final accepted = await ref
        .read(venueOrderControllerProvider.notifier)
        .submit();
    if (!mounted || !accepted) return;
    FocusScope.of(context).unfocus();
    AfriToast.success(
      context,
      'Order confirmed by the venue service. Pay only at the venue.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(venueOrderAccessEnabledProvider);
    final asyncState = ref.watch(venueOrderControllerProvider);
    return AfriScreenScaffold(
      backgroundColor: ColorTokens.background,
      appBar: AfriAppBar(
        backgroundColor: ColorTokens.transparent,
        title: Text(
          'Venue order',
          style: TypographyTokens.headlineSmall().copyWith(
            fontWeight: FontWeight.w700,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textScaler: TextScaler.linear(
            MediaQuery.textScalerOf(context).scale(1).clamp(1, 1.3),
          ),
        ),
        leading: AfriIconButton(
          key: const ValueKey<String>('venue-order-back'),
          icon: AfriIcons.back,
          onTap: _close,
          tooltip: 'Back',
        ),
      ),
      scrollable: false,
      constrainContent: true,
      child: !enabled
          ? _VenueOrderConsequence(
              title: 'Venue ordering unavailable',
              body:
                  'This governed feature is disabled for the current club or build.',
              actionLabel: 'BACK TO FAN ZONE',
              onAction: _close,
            )
          : asyncState.when(
              loading: () {
                final previous = asyncState.valueOrNull;
                if (previous?.context.hasCheckin == true) {
                  return _content(previous!);
                }
                return const SafeArea(
                  child: Padding(
                    padding: EdgeInsets.all(SpacingTokens.spacing6),
                    child: AfriSkeletonList(),
                  ),
                );
              },
              error: (error, _) => _initialFailure(error),
              data: (state) {
                if (state.failure?.kind ==
                    VenueOrderFailureKind.permissionDenied) {
                  return _VenueOrderConsequence(
                    title: 'Venue order access denied',
                    body:
                        'This account cannot use the supporter venue-order route.',
                    actionLabel: 'BACK TO FAN ZONE',
                    onAction: _close,
                  );
                }
                if (!state.context.hasCheckin) {
                  return _VenueOrderConsequence(
                    key: const ValueKey<String>('venue-order-empty'),
                    title: 'Check in before ordering',
                    body:
                        'A confirmed venue check-in is required before the approved drinks menu can be loaded.',
                    actionLabel: 'CHECK IN FIRST',
                    onAction: () => context.go('/fanzone/venue'),
                  );
                }
                if (state.context.menu.isEmpty) {
                  return _VenueOrderConsequence(
                    key: const ValueKey<String>('venue-order-empty'),
                    title: 'No drinks available',
                    body:
                        'The checked-in venue has no approved active drinks right now.',
                    actionLabel: 'REFRESH MENU',
                    onAction: () => ref
                        .read(venueOrderControllerProvider.notifier)
                        .refresh(),
                  );
                }
                return _content(state);
              },
            ),
    );
  }

  Widget _initialFailure(Object error) {
    final failure = VenueOrderFailure.fromError(error);
    return switch (failure.kind) {
      VenueOrderFailureKind.permissionDenied => _VenueOrderConsequence(
        title: 'Venue order access denied',
        body: 'This account cannot load the supporter venue-order route.',
        actionLabel: 'BACK TO FAN ZONE',
        onAction: _close,
      ),
      VenueOrderFailureKind.offline => _VenueOrderConsequence(
        title: 'Venue menu unavailable offline',
        body:
            'Reconnect before loading the venue menu. No order is queued offline.',
        actionLabel: 'TRY AGAIN',
        onAction: () =>
            ref.read(venueOrderControllerProvider.notifier).refresh(),
      ),
      VenueOrderFailureKind.securityTimeout => _VenueOrderConsequence(
        title: 'Venue menu check timed out',
        body:
            'The app could not establish a safe order context in time. Try one bounded refresh.',
        actionLabel: 'TRY AGAIN',
        onAction: () =>
            ref.read(venueOrderControllerProvider.notifier).refresh(),
      ),
      _ => _VenueOrderConsequence(
        title: 'Venue ordering unavailable',
        body:
            'The checked-in venue and approved menu could not be loaded safely.',
        actionLabel: 'TRY AGAIN',
        onAction: () =>
            ref.read(venueOrderControllerProvider.notifier).refresh(),
      ),
    };
  }

  Widget _content(VenueOrderRouteState state) {
    final online = ConnectivityService.isOnline;
    final actionsEnabled = online && !state.actionsBlocked;
    final controller = ref.read(venueOrderControllerProvider.notifier);
    final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.5;

    return AfriRefreshIndicator(
      onRefresh: controller.refresh,
      color: context.afriSemanticColors.accent,
      child: ListView(
        key: const ValueKey<String>('venue-order-content'),
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.all(SpacingTokens.screenPadding),
        children: [
          AfriSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  AfriIcons.cart,
                  color: context.afriSemanticColors.accent,
                  size: SpacingTokens.spacing10,
                ),
                const SizedBox(height: SpacingTokens.spacing4),
                Text(
                  'Order drinks at this venue',
                  style: TypographyTokens.headlineLarge().copyWith(
                    fontWeight: FontWeight.w900,
                    height: TypographyTokens.lineHeightCompact,
                  ),
                ),
                const SizedBox(height: SpacingTokens.spacing3),
                Text(
                  'Choose from the approved drinks-only menu. Staff queue actions remain in the venue portal.',
                  style: TypographyTokens.bodyMedium(),
                ),
              ],
            ),
          ),
          const SizedBox(height: SpacingTokens.sectionGap),
          if (_statusFor(state, online: online) case final status?) ...[
            status,
            const SizedBox(height: SpacingTokens.sectionGap),
          ],
          AfriSectionCard(
            title: 'Approved drinks',
            child: Column(
              children: [
                for (
                  var index = 0;
                  index < state.context.menu.length;
                  index++
                ) ...[
                  _VenueDrinkStepper(
                    item: state.context.menu[index],
                    count: state.quantityFor(state.context.menu[index].id),
                    enabled: actionsEnabled,
                    onAdd: () => controller.setQuantity(
                      state.context.menu[index].id,
                      state.quantityFor(state.context.menu[index].id) + 1,
                    ),
                    onRemove:
                        state.quantityFor(state.context.menu[index].id) == 0
                        ? null
                        : () => controller.setQuantity(
                            state.context.menu[index].id,
                            state.quantityFor(state.context.menu[index].id) - 1,
                          ),
                  ),
                  if (index < state.context.menu.length - 1)
                    const SizedBox(height: SpacingTokens.spacing3),
                ],
              ],
            ),
          ),
          const SizedBox(height: SpacingTokens.sectionGap),
          Semantics(
            container: true,
            label: 'Order review',
            value:
                '${state.totalItems} items, ${_money(state.currencyCode, state.totalAmount)}',
            child: AfriSurfaceCard(
              child: largeText
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _receiptTitle(state),
                        const SizedBox(height: SpacingTokens.spacing3),
                        _receiptTotal(state),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(child: _receiptTitle(state)),
                        const SizedBox(width: SpacingTokens.spacing3),
                        _receiptTotal(state),
                      ],
                    ),
            ),
          ),
          if (state.hasAlcoholSelection) ...[
            const SizedBox(height: SpacingTokens.sectionGap),
            Semantics(
              selected: state.ageGateConfirmed,
              label: 'Legal age confirmation',
              value: state.ageGateConfirmed ? 'Selected' : 'Not selected',
              child: AfriSurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Age confirmation required',
                      style: TypographyTokens.titleLarge(),
                    ),
                    const SizedBox(height: SpacingTokens.spacing2),
                    Text(
                      'Confirm only if you meet the venueʼs legal age requirement. Venue staff may still verify eligibility.',
                      style: TypographyTokens.bodyMedium(),
                    ),
                    const SizedBox(height: SpacingTokens.spacing3),
                    AfriButton(
                      key: const ValueKey<String>('venue-order-age-gate'),
                      label: state.ageGateConfirmed
                          ? 'REMOVE CONFIRMATION'
                          : 'CONFIRM LEGAL AGE',
                      icon: AfriIcons.shield,
                      variant: AfriButtonVariant.secondary,
                      enabled: actionsEnabled,
                      onTap: () => controller.setAgeGateConfirmed(
                        !state.ageGateConfirmed,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: SpacingTokens.sectionGap),
          const AfriStateBanner(
            icon: AfriIcons.statusInfo,
            title: 'Pay at the venue',
            subtitle:
                'This app creates the drinks order only. It does not take payment or claim that payment succeeded.',
            tone: AfriStateBannerTone.neutral,
          ),
          const SizedBox(height: SpacingTokens.spacing4),
          AfriButton(
            key: const ValueKey<String>('venue-order-submit'),
            focusNode: widget.submitFocusNode,
            label: state.phase == VenueOrderPhase.syncing
                ? 'CREATING ORDER'
                : state.phase == VenueOrderPhase.confirmed
                ? 'ORDER CONFIRMED'
                : 'REVIEW AND CREATE ORDER',
            icon: AfriIcons.cart,
            enabled: actionsEnabled && state.totalItems > 0,
            isLoading: state.phase == VenueOrderPhase.syncing,
            onTap: () => unawaited(_submit()),
          ),
          const SizedBox(height: SpacingTokens.sectionGap),
          const AfriSectionCard(
            title: 'Order protections',
            child: Column(
              children: [
                _ProtectionRow(
                  label: 'Duplicate submission',
                  detail: 'One idempotency key per attempt',
                ),
                _ProtectionRow(
                  label: 'Offline behavior',
                  detail: 'No queued or automatic replay',
                ),
                _ProtectionRow(
                  label: 'Staff controls',
                  detail: 'Venue portal only',
                  last: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _receiptTitle(VenueOrderRouteState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Order review', style: TypographyTokens.titleLarge()),
        const SizedBox(height: SpacingTokens.spacing1),
        Text(
          '${state.totalItems} item${state.totalItems == 1 ? '' : 's'} selected',
          style: TypographyTokens.bodyMedium(),
        ),
      ],
    );
  }

  Widget _receiptTotal(VenueOrderRouteState state) {
    return Text(
      _money(state.currencyCode, state.totalAmount),
      style: TypographyTokens.headlineSmall().copyWith(
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Widget? _statusFor(VenueOrderRouteState state, {required bool online}) {
    if (!online || state.failure?.kind == VenueOrderFailureKind.offline) {
      return const AfriStateBanner(
        icon: AfriIcons.offline,
        title: 'Showing saved venue menu',
        subtitle:
            'Reconnect before creating the order. Nothing is queued or replayed offline.',
        tone: AfriStateBannerTone.warning,
      );
    }
    if (state.phase == VenueOrderPhase.syncing) {
      return const AfriStateBanner(
        icon: AfriIcons.refresh,
        title: 'Creating venue order',
        subtitle:
            'Wait for server confirmation. Do not repeat this order attempt.',
        tone: AfriStateBannerTone.info,
      );
    }
    if (state.phase == VenueOrderPhase.confirmed && state.result != null) {
      return AfriStateBanner(
        icon: AfriIcons.statusSuccess,
        title: 'Order created',
        subtitle:
            '${_orderStatusLabel(state.result!.status)} · '
            '${_money(state.result!.currencyCode, state.result!.totalAmount)}. '
            'Payment remains external at the venue.',
        tone: AfriStateBannerTone.success,
      );
    }
    final failure = state.failure;
    if (failure != null) {
      final content = switch (failure.kind) {
        VenueOrderFailureKind.invalidSelection => (
          'Choose at least one drink',
          'The order cannot be created with an empty selection.',
        ),
        VenueOrderFailureKind.checkinRequired => (
          'Check-in required',
          'The venue did not accept this check-in for ordering. Check in again before retrying.',
        ),
        VenueOrderFailureKind.ageGateRequired => (
          'Age confirmation required',
          'Confirm legal age before submitting an alcohol item.',
        ),
        VenueOrderFailureKind.itemUnavailable => (
          'A selected drink changed',
          'Refresh the approved menu before retrying.',
        ),
        VenueOrderFailureKind.conflict => (
          'Order attempt paused',
          'Another request may be active. Check the latest order before retrying.',
        ),
        VenueOrderFailureKind.securityTimeout => (
          'Order confirmation uncertain',
          'Do not resubmit. Check the latest venue order before dismissing.',
        ),
        _ => (
          'Order not confirmed',
          'The server did not confirm this order. Dismiss the warning before retrying.',
        ),
      };
      return AfriStateBanner(
        icon: AfriIcons.warning,
        title: content.$1,
        subtitle: content.$2,
        tone: failure.kind == VenueOrderFailureKind.securityTimeout
            ? AfriStateBannerTone.danger
            : AfriStateBannerTone.warning,
        onTap: () => ref
            .read(venueOrderControllerProvider.notifier)
            .acknowledgeFailure(),
      );
    }
    final latest = state.context.latestOrder;
    if (latest != null) {
      return AfriStateBanner(
        icon: _orderStatusIcon(latest.status),
        title: 'Latest order: ${_orderStatusLabel(latest.status)}',
        subtitle:
            '${_money(latest.currencyCode, latest.totalAmount)} · '
            '${_paymentStatusLabel(latest.paymentStatus)}.',
        tone: _orderStatusTone(latest.status),
      );
    }
    return const AfriStateBanner(
      icon: AfriIcons.cart,
      title: 'Ready to order',
      subtitle: 'Choose approved drinks, review the total, then create once.',
      tone: AfriStateBannerTone.neutral,
    );
  }
}

class _VenueDrinkStepper extends StatelessWidget {
  const _VenueDrinkStepper({
    required this.item,
    required this.count,
    required this.enabled,
    required this.onAdd,
    required this.onRemove,
  });

  final VenueDrinkItem item;
  final int count;
  final bool enabled;
  final VoidCallback onAdd;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final selected = count > 0;
    final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.5;
    final controls = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AfriIconButton(
          key: ValueKey<String>('venue-order-remove-${item.id}'),
          icon: AfriIcons.remove,
          onTap: enabled ? onRemove : null,
          tooltip: 'Remove ${item.name}',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SpacingTokens.spacing2,
          ),
          child: Text('$count', style: TypographyTokens.titleMedium()),
        ),
        AfriIconButton(
          key: ValueKey<String>('venue-order-add-${item.id}'),
          icon: AfriIcons.add,
          onTap: enabled && count < 20 ? onAdd : null,
          tooltip: 'Add ${item.name}',
        ),
      ],
    );
    return Semantics(
      container: true,
      selected: selected,
      label: item.name,
      value:
          '$count selected, ${_money(item.currencyCode, item.priceAmount)} each',
      child: GlassCard(
        animate: false,
        borderColor: selected ? context.afriSemanticColors.accent : null,
        child: largeText
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _drinkDetails(context),
                  const SizedBox(height: SpacingTokens.spacing3),
                  Align(alignment: Alignment.centerRight, child: controls),
                ],
              )
            : Row(
                children: [
                  Expanded(child: _drinkDetails(context)),
                  const SizedBox(width: SpacingTokens.spacing3),
                  controls,
                ],
              ),
      ),
    );
  }

  Widget _drinkDetails(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                item.name,
                style: TypographyTokens.titleSmall(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (item.isAlcohol) ...[
              const SizedBox(width: SpacingTokens.spacing2),
              Icon(
                AfriIcons.shield,
                size: AfriIcons.sizeInline,
                color: context.afriSemanticColors.warning,
                semanticLabel: 'Age restricted',
              ),
            ],
          ],
        ),
        if (item.description.isNotEmpty) ...[
          const SizedBox(height: SpacingTokens.spacing1),
          Text(
            item.description,
            style: TypographyTokens.bodySmall(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const SizedBox(height: SpacingTokens.spacing1),
        Text(
          _money(item.currencyCode, item.priceAmount),
          style: TypographyTokens.bodyMedium().copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ProtectionRow extends StatelessWidget {
  const _ProtectionRow({
    required this.label,
    required this.detail,
    this.last = false,
  });

  final String label;
  final String detail;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : SpacingTokens.spacing3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            AfriIcons.shield,
            color: context.afriSemanticColors.success,
            size: AfriIcons.sizeInline,
          ),
          const SizedBox(width: SpacingTokens.spacing3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TypographyTokens.titleSmall()),
                const SizedBox(height: SpacingTokens.spacing1),
                Text(detail, style: TypographyTokens.bodySmall()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VenueOrderConsequence extends StatelessWidget {
  const _VenueOrderConsequence({
    super.key,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(SpacingTokens.spacing6),
        child: AfriStateView.error(
          title: title,
          message: body,
          actionLabel: actionLabel,
          onAction: onAction,
        ),
      ),
    );
  }
}

String _money(String currencyCode, int amount) {
  final digits = amount.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]},',
  );
  return '$currencyCode $digits';
}

String _orderStatusLabel(String status) {
  return switch (status) {
    'created' => 'Waiting for venue',
    'accepted' => 'Accepted',
    'preparing' => 'Preparing',
    'ready' => 'Ready for pickup',
    'served' => 'Served',
    'cancelled' => 'Cancelled',
    _ => 'Status pending',
  };
}

String _paymentStatusLabel(String status) {
  return switch (status) {
    'externally_paid' => 'Paid at venue',
    'waived' => 'Payment waived',
    'refunded' => 'Refunded externally',
    _ => 'Payment pending at venue',
  };
}

IconData _orderStatusIcon(String status) {
  return switch (status) {
    'ready' || 'served' => AfriIcons.statusSuccess,
    'cancelled' => AfriIcons.warning,
    'preparing' => AfriIcons.statusPending,
    _ => AfriIcons.statusInfo,
  };
}

AfriStateBannerTone _orderStatusTone(String status) {
  return switch (status) {
    'ready' || 'served' => AfriStateBannerTone.success,
    'cancelled' => AfriStateBannerTone.warning,
    _ => AfriStateBannerTone.info,
  };
}
