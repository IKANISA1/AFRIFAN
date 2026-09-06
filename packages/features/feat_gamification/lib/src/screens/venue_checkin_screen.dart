import 'dart:async';

import 'package:core_l10n/core_l10n.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../controllers/venue_checkin_controller.dart';
import '../venue_checkin_providers.dart';

class VenueCheckinScreen extends ConsumerStatefulWidget {
  const VenueCheckinScreen({super.key, this.checkinFocusNode});

  final FocusNode? checkinFocusNode;

  @override
  ConsumerState<VenueCheckinScreen> createState() => _VenueCheckinScreenState();
}

class _VenueCheckinScreenState extends ConsumerState<VenueCheckinScreen> {
  final TextEditingController _codeController = TextEditingController();
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
    _codeController.dispose();
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
        ref.read(venueCheckinControllerProvider.notifier).connectionRestored(),
      );
    }
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/predict');
    }
  }

  Future<void> _submit() async {
    final accepted = await ref
        .read(venueCheckinControllerProvider.notifier)
        .submit(_codeController.text);
    if (!mounted || !accepted) return;
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.afriL10n;
    final enabled = ref.watch(venueCheckinAccessEnabledProvider);
    final asyncState = ref.watch(venueCheckinControllerProvider);
    return AfriScreenScaffold(
      backgroundColor: ColorTokens.background,
      appBar: AfriAppBar(
        backgroundColor: ColorTokens.transparent,
        title: Text(
          l10n.venueCheckinTitle,
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
          icon: AfriIcons.back,
          onTap: _close,
          tooltip: l10n.gameBack,
        ),
      ),
      scrollable: false,
      constrainContent: true,
      child: !enabled
          ? _Consequence(
              title: l10n.venueCheckinUnavailable,
              body: l10n.venueFeatureDisabled,
              actionLabel: l10n.venueBackToFanZone,
              onAction: _close,
            )
          : asyncState.when(
              loading: () => const SafeArea(
                child: Padding(
                  padding: EdgeInsets.all(SpacingTokens.spacing6),
                  child: AfriSkeletonList(),
                ),
              ),
              error: (error, _) => _initialFailure(error),
              data: _content,
            ),
    );
  }

  Widget _initialFailure(Object error) {
    final l10n = context.afriL10n;
    final failure = VenueCheckinFailure.fromError(error);
    return _Consequence(
      title: failure.kind == VenueCheckinFailureKind.permissionDenied
          ? l10n.venueCheckinAccessDenied
          : l10n.venueCheckinUnavailable,
      body: failure.kind == VenueCheckinFailureKind.permissionDenied
          ? l10n.venueCheckinAccessDeniedBody
          : l10n.venueCheckinSafeStateBody,
      actionLabel: l10n.venueBackToFanZone,
      onAction: _close,
    );
  }

  Widget _content(VenueCheckinRouteState state) {
    final l10n = context.afriL10n;
    if (state.failure?.kind == VenueCheckinFailureKind.permissionDenied) {
      return _Consequence(
        title: l10n.venueCheckinAccessDenied,
        body: l10n.venueCheckinAccessDeniedBody,
        actionLabel: l10n.venueBackToFanZone,
        onAction: _close,
      );
    }
    final online = ConnectivityService.isOnline;
    final actionsEnabled = online && !state.actionBlocked;
    return ListView(
      key: const ValueKey<String>('venue-checkin-content'),
      padding: const EdgeInsets.all(SpacingTokens.screenPadding),
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      children: [
        AfriSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                AfriIcons.qrScan,
                color: context.afriSemanticColors.accent,
                size: SpacingTokens.spacing10,
              ),
              const SizedBox(height: SpacingTokens.spacing4),
              Text(
                l10n.venueCheckinHero,
                style: TypographyTokens.headlineLarge().copyWith(
                  fontWeight: FontWeight.w700,
                  height: TypographyTokens.lineHeightCompact,
                ),
              ),
              const SizedBox(height: SpacingTokens.spacing3),
              Text(
                l10n.venueCheckinHeroBody,
                style: TypographyTokens.bodyMedium(),
              ),
            ],
          ),
        ),
        const SizedBox(height: SpacingTokens.sectionGap),
        if (_statusFor(state, online: online) case final status?)
          Padding(
            padding: const EdgeInsets.only(bottom: SpacingTokens.sectionGap),
            child: status,
          ),
        AfriSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.venueCheckinCodeLabel,
                style: TypographyTokens.titleLarge(),
              ),
              const SizedBox(height: SpacingTokens.spacing3),
              AfriInputField(
                controller: _codeController,
                label: l10n.venueCheckinInputLabel,
                hint: l10n.venueCheckinInputHint,
                enabled: actionsEnabled,
                keyboardType: TextInputType.visiblePassword,
                textCapitalization: TextCapitalization.characters,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => unawaited(_submit()),
              ),
              const SizedBox(height: SpacingTokens.spacing3),
              AfriButton(
                key: const ValueKey<String>('venue-checkin-submit'),
                focusNode: widget.checkinFocusNode,
                label: state.phase == VenueCheckinPhase.syncing
                    ? l10n.venueCheckinCheckingCodeUpper
                    : l10n.venueCheckinActionUpper,
                icon: AfriIcons.qrCode,
                enabled: actionsEnabled,
                isLoading: state.phase == VenueCheckinPhase.syncing,
                onTap: () => unawaited(_submit()),
              ),
            ],
          ),
        ),
        const SizedBox(height: SpacingTokens.sectionGap),
        Semantics(
          selected: state.locationConsent,
          label: l10n.venueCheckinLocationConsentSemantics,
          value: state.locationConsent
              ? l10n.gameSelected
              : l10n.venueNotSelected,
          child: AfriSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.venueCheckinOptionalLocationReview,
                  style: TypographyTokens.titleLarge(),
                ),
                const SizedBox(height: SpacingTokens.spacing2),
                Text(
                  state.locationConsent
                      ? l10n.venueCheckinConsentMarkedBody
                      : l10n.venueCheckinNoLocationBody,
                  style: TypographyTokens.bodyMedium(),
                ),
                const SizedBox(height: SpacingTokens.spacing3),
                AfriButton(
                  key: const ValueKey<String>('venue-location-consent'),
                  label: state.locationConsent
                      ? l10n.venueCheckinRemoveConsentUpper
                      : l10n.venueCheckinMarkConsentUpper,
                  icon: AfriIcons.location,
                  variant: AfriButtonVariant.secondary,
                  enabled:
                      state.phase != VenueCheckinPhase.syncing &&
                      state.phase != VenueCheckinPhase.confirmed,
                  onTap: () => ref
                      .read(venueCheckinControllerProvider.notifier)
                      .setLocationConsent(!state.locationConsent),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: SpacingTokens.sectionGap),
        AfriStateBanner(
          icon: AfriIcons.privacy,
          title: l10n.venueCheckinPrivacyBoundary,
          subtitle: l10n.venueCheckinPrivacyBoundaryBody,
          tone: AfriStateBannerTone.neutral,
        ),
      ],
    );
  }

  Widget? _statusFor(VenueCheckinRouteState state, {required bool online}) {
    final l10n = context.afriL10n;
    if (!online || state.failure?.kind == VenueCheckinFailureKind.offline) {
      return AfriStateBanner(
        icon: AfriIcons.offline,
        title: l10n.venueCheckinPausedOffline,
        subtitle: l10n.venueCheckinPausedOfflineBody,
        tone: AfriStateBannerTone.warning,
        onTap: state.failure == null
            ? null
            : () => ref
                  .read(venueCheckinControllerProvider.notifier)
                  .acknowledgeFailure(),
      );
    }
    if (state.phase == VenueCheckinPhase.syncing) {
      return AfriStateBanner(
        icon: AfriIcons.refresh,
        title: l10n.venueCheckinCheckingCode,
        subtitle: l10n.venueCheckinCheckingCodeBody,
        tone: AfriStateBannerTone.info,
      );
    }
    if (state.phase == VenueCheckinPhase.confirmed && state.result != null) {
      final pending = state.result!.status == 'pending_review';
      return AfriStateBanner(
        icon: pending ? AfriIcons.statusInfo : AfriIcons.statusSuccess,
        title: pending
            ? l10n.venueCheckinPendingReview
            : l10n.venueCheckinConfirmed,
        subtitle: pending
            ? l10n.venueCheckinPendingReviewBody
            : state.result!.fetAwarded > 0
            ? l10n.venueCheckinFetRecorded(state.result!.fetAwarded)
            : l10n.venueCheckinConfirmedNoReward,
        tone: pending ? AfriStateBannerTone.info : AfriStateBannerTone.success,
      );
    }
    final failure = state.failure;
    if (failure == null) {
      return AfriStateBanner(
        icon: AfriIcons.qrCode,
        title: l10n.venueCheckinReady,
        subtitle: l10n.venueCheckinReadyBody,
        tone: AfriStateBannerTone.neutral,
      );
    }
    final content = switch (failure.kind) {
      VenueCheckinFailureKind.invalidCode => (
        l10n.venueCheckinInvalidCode,
        l10n.venueCheckinInvalidCodeBody,
      ),
      VenueCheckinFailureKind.expiredCode => (
        l10n.venueCheckinExpiredCode,
        l10n.venueCheckinExpiredCodeBody,
      ),
      VenueCheckinFailureKind.alreadyCheckedIn => (
        l10n.venueCheckinAlreadyCheckedIn,
        l10n.venueCheckinAlreadyCheckedInBody,
      ),
      VenueCheckinFailureKind.campaignUnavailable => (
        l10n.venueCheckinCampaignUnavailable,
        l10n.venueCheckinCampaignUnavailableBody,
      ),
      VenueCheckinFailureKind.conflict => (
        l10n.venueCheckinConflict,
        l10n.venueCheckinConflictBody,
      ),
      VenueCheckinFailureKind.securityTimeout => (
        l10n.venueCheckinConfirmationUncertain,
        l10n.venueCheckinConfirmationUncertainBody,
      ),
      _ => (
        l10n.venueCheckinUnavailableShort,
        l10n.venueCheckinUnavailableBody,
      ),
    };
    return AfriStateBanner(
      icon: AfriIcons.warning,
      title: content.$1,
      subtitle: content.$2,
      tone: failure.kind == VenueCheckinFailureKind.securityTimeout
          ? AfriStateBannerTone.danger
          : AfriStateBannerTone.warning,
      onTap: () => ref
          .read(venueCheckinControllerProvider.notifier)
          .acknowledgeFailure(),
    );
  }
}

class _Consequence extends StatelessWidget {
  const _Consequence({
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
