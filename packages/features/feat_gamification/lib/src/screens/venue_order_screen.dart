import 'dart:async';

import 'package:core_l10n/core_l10n.dart';
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
    AfriToast.success(context, context.afriL10n.venueOrderConfirmedToast);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.afriL10n;
    final enabled = ref.watch(venueOrderAccessEnabledProvider);
    final asyncState = ref.watch(venueOrderControllerProvider);
    return AfriScreenScaffold(
      backgroundColor: ColorTokens.background,
      appBar: AfriAppBar(
        backgroundColor: ColorTokens.transparent,
        title: Text(
          l10n.gameVenueOrder,
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
          tooltip: l10n.gameBack,
        ),
      ),
      scrollable: false,
      constrainContent: true,
      child: !enabled
          ? _VenueOrderConsequence(
              title: l10n.venueOrderingUnavailable,
              body: l10n.venueFeatureDisabled,
              actionLabel: l10n.venueBackToFanZone,
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
                    title: l10n.venueOrderAccessDenied,
                    body: l10n.venueOrderAccessDeniedBody,
                    actionLabel: l10n.venueBackToFanZone,
                    onAction: _close,
                  );
                }
                if (!state.context.hasCheckin) {
                  return _VenueOrderConsequence(
                    key: const ValueKey<String>('venue-order-empty'),
                    title: l10n.venueCheckInBeforeOrdering,
                    body: l10n.venueCheckInRequiredBody,
                    actionLabel: l10n.venueCheckInFirst,
                    onAction: () => context.go('/fanzone/venue'),
                  );
                }
                if (state.context.menu.isEmpty) {
                  return _VenueOrderConsequence(
                    key: const ValueKey<String>('venue-order-empty'),
                    title: l10n.venueNoDrinksAvailable,
                    body: l10n.venueNoDrinksBody,
                    actionLabel: l10n.venueRefreshMenu,
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
    final l10n = context.afriL10n;
    final failure = VenueOrderFailure.fromError(error);
    return switch (failure.kind) {
      VenueOrderFailureKind.permissionDenied => _VenueOrderConsequence(
        title: l10n.venueOrderAccessDenied,
        body: l10n.venueOrderAccessDeniedLoadBody,
        actionLabel: l10n.venueBackToFanZone,
        onAction: _close,
      ),
      VenueOrderFailureKind.offline => _VenueOrderConsequence(
        title: l10n.venueMenuUnavailableOffline,
        body: l10n.venueMenuOfflineBody,
        actionLabel: l10n.venueTryAgain,
        onAction: () =>
            ref.read(venueOrderControllerProvider.notifier).refresh(),
      ),
      VenueOrderFailureKind.securityTimeout => _VenueOrderConsequence(
        title: l10n.venueMenuCheckTimedOut,
        body: l10n.venueMenuCheckTimedOutBody,
        actionLabel: l10n.venueTryAgain,
        onAction: () =>
            ref.read(venueOrderControllerProvider.notifier).refresh(),
      ),
      _ => _VenueOrderConsequence(
        title: l10n.venueOrderingUnavailable,
        body: l10n.venueMenuUnavailableBody,
        actionLabel: l10n.venueTryAgain,
        onAction: () =>
            ref.read(venueOrderControllerProvider.notifier).refresh(),
      ),
    };
  }

  Widget _content(VenueOrderRouteState state) {
    final l10n = context.afriL10n;
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
                  l10n.venueOrderHero,
                  style: TypographyTokens.headlineLarge().copyWith(
                    fontWeight: FontWeight.w700,
                    height: TypographyTokens.lineHeightCompact,
                  ),
                ),
                const SizedBox(height: SpacingTokens.spacing3),
                Text(
                  l10n.venueOrderHeroBody,
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
            title: l10n.venueApprovedDrinks,
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
            label: l10n.venueOrderReview,
            value: l10n.venueOrderReviewValue(
              state.totalItems,
              _money(state.currencyCode, state.totalAmount),
            ),
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
              label: l10n.venueLegalAgeConfirmation,
              value: state.ageGateConfirmed
                  ? l10n.gameSelected
                  : l10n.venueNotSelected,
              child: AfriSurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.venueAgeConfirmationRequired,
                      style: TypographyTokens.titleLarge(),
                    ),
                    const SizedBox(height: SpacingTokens.spacing2),
                    Text(
                      l10n.venueAgeConfirmationBody,
                      style: TypographyTokens.bodyMedium(),
                    ),
                    const SizedBox(height: SpacingTokens.spacing3),
                    AfriButton(
                      key: const ValueKey<String>('venue-order-age-gate'),
                      label: state.ageGateConfirmed
                          ? l10n.venueRemoveConfirmation
                          : l10n.venueConfirmLegalAge,
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
          AfriStateBanner(
            icon: AfriIcons.statusInfo,
            title: l10n.venuePayAtVenue,
            subtitle: l10n.venuePaymentDisclaimer,
            tone: AfriStateBannerTone.neutral,
          ),
          const SizedBox(height: SpacingTokens.spacing4),
          AfriButton(
            key: const ValueKey<String>('venue-order-submit'),
            focusNode: widget.submitFocusNode,
            label: state.phase == VenueOrderPhase.syncing
                ? l10n.venueCreatingOrderUpper
                : state.phase == VenueOrderPhase.confirmed
                ? l10n.venueOrderConfirmedUpper
                : l10n.venueReviewCreateOrder,
            icon: AfriIcons.cart,
            enabled: actionsEnabled && state.totalItems > 0,
            isLoading: state.phase == VenueOrderPhase.syncing,
            onTap: () => unawaited(_submit()),
          ),
          const SizedBox(height: SpacingTokens.sectionGap),
          AfriSectionCard(
            title: l10n.venueOrderProtections,
            child: Column(
              children: [
                _ProtectionRow(
                  label: l10n.venueDuplicateSubmission,
                  detail: l10n.venueDuplicateSubmissionBody,
                ),
                _ProtectionRow(
                  label: l10n.venueOfflineBehavior,
                  detail: l10n.venueOfflineBehaviorBody,
                ),
                _ProtectionRow(
                  label: l10n.venueStaffControls,
                  detail: l10n.venueStaffControlsBody,
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
    final l10n = context.afriL10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.venueOrderReview, style: TypographyTokens.titleLarge()),
        const SizedBox(height: SpacingTokens.spacing1),
        Text(
          l10n.venueItemsSelected(state.totalItems),
          style: TypographyTokens.bodyMedium(),
        ),
      ],
    );
  }

  Widget _receiptTotal(VenueOrderRouteState state) {
    return Text(
      _money(state.currencyCode, state.totalAmount),
      style: TypographyTokens.headlineSmall().copyWith(
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget? _statusFor(VenueOrderRouteState state, {required bool online}) {
    final l10n = context.afriL10n;
    if (!online || state.failure?.kind == VenueOrderFailureKind.offline) {
      return AfriStateBanner(
        icon: AfriIcons.offline,
        title: l10n.venueShowingSavedMenu,
        subtitle: l10n.venueShowingSavedMenuBody,
        tone: AfriStateBannerTone.warning,
      );
    }
    if (state.phase == VenueOrderPhase.syncing) {
      return AfriStateBanner(
        icon: AfriIcons.refresh,
        title: l10n.venueCreatingOrder,
        subtitle: l10n.venueCreatingOrderBody,
        tone: AfriStateBannerTone.info,
      );
    }
    if (state.phase == VenueOrderPhase.confirmed && state.result != null) {
      return AfriStateBanner(
        icon: AfriIcons.statusSuccess,
        title: l10n.venueOrderCreated,
        subtitle: l10n.venueOrderCreatedSummary(
          _orderStatusLabel(l10n, state.result!.status),
          _money(state.result!.currencyCode, state.result!.totalAmount),
        ),
        tone: AfriStateBannerTone.success,
      );
    }
    final failure = state.failure;
    if (failure != null) {
      final content = switch (failure.kind) {
        VenueOrderFailureKind.invalidSelection => (
          l10n.venueChooseDrink,
          l10n.venueChooseDrinkBody,
        ),
        VenueOrderFailureKind.checkinRequired => (
          l10n.venueCheckInRequired,
          l10n.venueCheckInRejectedBody,
        ),
        VenueOrderFailureKind.ageGateRequired => (
          l10n.venueAgeConfirmationRequired,
          l10n.venueAgeSubmitBody,
        ),
        VenueOrderFailureKind.itemUnavailable => (
          l10n.venueDrinkChanged,
          l10n.venueDrinkChangedBody,
        ),
        VenueOrderFailureKind.conflict => (
          l10n.venueOrderAttemptPaused,
          l10n.venueOrderAttemptPausedBody,
        ),
        VenueOrderFailureKind.securityTimeout => (
          l10n.venueOrderConfirmationUncertain,
          l10n.venueOrderConfirmationUncertainBody,
        ),
        _ => (l10n.venueOrderNotConfirmed, l10n.venueOrderNotConfirmedBody),
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
        title: l10n.venueLatestOrder(_orderStatusLabel(l10n, latest.status)),
        subtitle: l10n.venueLatestOrderSummary(
          _money(latest.currencyCode, latest.totalAmount),
          _paymentStatusLabel(l10n, latest.paymentStatus),
        ),
        tone: _orderStatusTone(latest.status),
      );
    }
    return AfriStateBanner(
      icon: AfriIcons.cart,
      title: l10n.venueReadyToOrder,
      subtitle: l10n.venueReadyToOrderBody,
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
          tooltip: context.afriL10n.venueRemoveItem(item.name),
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
          tooltip: context.afriL10n.venueAddItem(item.name),
        ),
      ],
    );
    return Semantics(
      container: true,
      selected: selected,
      label: item.name,
      value: context.afriL10n.venueDrinkSemantics(
        count,
        _money(item.currencyCode, item.priceAmount),
      ),
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
                semanticLabel: context.afriL10n.venueAgeRestricted,
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

String _orderStatusLabel(AfriLocalizations l10n, String status) {
  return switch (status) {
    'created' => l10n.venueWaitingForVenue,
    'accepted' => l10n.venueAccepted,
    'preparing' => l10n.venuePreparing,
    'ready' => l10n.venueReadyForPickup,
    'served' => l10n.venueServed,
    'cancelled' => l10n.gameCancelled,
    _ => l10n.venueStatusPending,
  };
}

String _paymentStatusLabel(AfriLocalizations l10n, String status) {
  return switch (status) {
    'externally_paid' => l10n.venuePaidAtVenue,
    'waived' => l10n.venuePaymentWaived,
    'refunded' => l10n.venueRefundedExternally,
    _ => l10n.venuePaymentPending,
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
