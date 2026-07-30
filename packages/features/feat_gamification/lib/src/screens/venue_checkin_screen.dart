import 'dart:async';

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
      context.go('/fanzone');
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
    final enabled = ref.watch(venueCheckinAccessEnabledProvider);
    final asyncState = ref.watch(venueCheckinControllerProvider);
    return AfriScreenScaffold(
      backgroundColor: ColorTokens.background,
      appBar: AfriAppBar(
        backgroundColor: ColorTokens.transparent,
        title: Text(
          'Venue check-in',
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
          tooltip: 'Back',
        ),
      ),
      scrollable: false,
      constrainContent: true,
      child: !enabled
          ? _Consequence(
              title: 'Venue check-in unavailable',
              body:
                  'This governed feature is disabled for the current club or build.',
              actionLabel: 'BACK TO FAN ZONE',
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
    final failure = VenueCheckinFailure.fromError(error);
    return _Consequence(
      title: failure.kind == VenueCheckinFailureKind.permissionDenied
          ? 'Check-in access denied'
          : 'Venue check-in unavailable',
      body: failure.kind == VenueCheckinFailureKind.permissionDenied
          ? 'This account cannot use the supporter check-in route.'
          : 'The route could not establish a safe check-in state.',
      actionLabel: 'BACK TO FAN ZONE',
      onAction: _close,
    );
  }

  Widget _content(VenueCheckinRouteState state) {
    if (state.failure?.kind == VenueCheckinFailureKind.permissionDenied) {
      return _Consequence(
        title: 'Check-in access denied',
        body: 'This account cannot use the supporter check-in route.',
        actionLabel: 'BACK TO FAN ZONE',
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
                'Check in at an approved venue',
                style: TypographyTokens.headlineLarge().copyWith(
                  fontWeight: FontWeight.w900,
                  height: TypographyTokens.lineHeightCompact,
                ),
              ),
              const SizedBox(height: SpacingTokens.spacing3),
              Text(
                'Enter the rotating TV or QR code after you arrive. Supporter check-in never exposes staff or admin controls.',
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
              Text('Venue code', style: TypographyTokens.titleLarge()),
              const SizedBox(height: SpacingTokens.spacing3),
              AfriInputField(
                controller: _codeController,
                label: 'TV or QR code',
                hint: 'Enter at least 4 characters',
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
                    ? 'CHECKING CODE'
                    : 'CHECK IN',
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
          label: 'Location review consent',
          value: state.locationConsent ? 'Selected' : 'Not selected',
          child: AfriSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Optional location review',
                  style: TypographyTokens.titleLarge(),
                ),
                const SizedBox(height: SpacingTokens.spacing2),
                Text(
                  state.locationConsent
                      ? 'Consent is marked for this attempt. This build still sends no coordinates; location-required campaigns remain pending review.'
                      : 'Precise location is not collected in this build. You may mark consent, but location-required campaigns remain pending review.',
                  style: TypographyTokens.bodyMedium(),
                ),
                const SizedBox(height: SpacingTokens.spacing3),
                AfriButton(
                  key: const ValueKey<String>('venue-location-consent'),
                  label: state.locationConsent
                      ? 'REMOVE CONSENT'
                      : 'MARK CONSENT',
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
        const AfriStateBanner(
          icon: AfriIcons.privacy,
          title: 'Privacy boundary',
          subtitle:
              'Raw rotating codes are hashed before submission and are not persisted by the app. No precise location is collected.',
          tone: AfriStateBannerTone.neutral,
        ),
      ],
    );
  }

  Widget? _statusFor(VenueCheckinRouteState state, {required bool online}) {
    if (!online || state.failure?.kind == VenueCheckinFailureKind.offline) {
      return AfriStateBanner(
        icon: AfriIcons.offline,
        title: 'Check-in paused offline',
        subtitle:
            'Reconnect before submitting. No check-in is queued or replayed.',
        tone: AfriStateBannerTone.warning,
        onTap: state.failure == null
            ? null
            : () => ref
                  .read(venueCheckinControllerProvider.notifier)
                  .acknowledgeFailure(),
      );
    }
    if (state.phase == VenueCheckinPhase.syncing) {
      return const AfriStateBanner(
        icon: AfriIcons.refresh,
        title: 'Checking venue code',
        subtitle: 'Wait for the server result. Do not repeat this check-in.',
        tone: AfriStateBannerTone.info,
      );
    }
    if (state.phase == VenueCheckinPhase.confirmed && state.result != null) {
      final pending = state.result!.status == 'pending_review';
      return AfriStateBanner(
        icon: pending ? AfriIcons.statusInfo : AfriIcons.statusSuccess,
        title: pending ? 'Check-in pending review' : 'Check-in confirmed',
        subtitle: pending
            ? 'The venue code was accepted, but a governed location or campaign check still needs review.'
            : state.result!.fetAwarded > 0
            ? '+${state.result!.fetAwarded} FET recorded for this check-in.'
            : 'The venue accepted this check-in. No reward was promised.',
        tone: pending ? AfriStateBannerTone.info : AfriStateBannerTone.success,
      );
    }
    final failure = state.failure;
    if (failure == null) {
      return const AfriStateBanner(
        icon: AfriIcons.qrCode,
        title: 'Ready for venue check-in',
        subtitle: 'Use the current code only after you arrive on site.',
        tone: AfriStateBannerTone.neutral,
      );
    }
    final content = switch (failure.kind) {
      VenueCheckinFailureKind.invalidCode => (
        'Code not accepted',
        'Enter the current TV or QR code shown at the venue.',
      ),
      VenueCheckinFailureKind.expiredCode => (
        'Venue code expired',
        'Ask the venue display for the current rotating code.',
      ),
      VenueCheckinFailureKind.alreadyCheckedIn => (
        'Already checked in',
        'The server found an existing check-in. No duplicate reward was created.',
      ),
      VenueCheckinFailureKind.campaignUnavailable => (
        'Check-in campaign unavailable',
        'The campaign is paused, inactive, or has reached its governed budget.',
      ),
      VenueCheckinFailureKind.conflict => (
        'Check-in conflict',
        'Another attempt may already be active. Confirm the venue state before retrying.',
      ),
      VenueCheckinFailureKind.securityTimeout => (
        'Check-in confirmation uncertain',
        'Do not repeat the code yet. Check your venue activity, then dismiss this warning.',
      ),
      _ => (
        'Check-in unavailable',
        'The server did not confirm the attempt. Dismiss this warning before retrying.',
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
