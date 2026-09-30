import 'dart:async';

import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../native_supporter_journey.dart';

/// A single scoped route contains sign-in, review, confirmation and recovery.
/// Route/query input never supplies a user, credential, price or counterparty.
class NativeMembershipJourneyScreen extends ConsumerStatefulWidget {
  const NativeMembershipJourneyScreen({
    required this.configuredClubId,
    this.journey,
    super.key,
  });
  final String configuredClubId;
  final NativeSupporterJourney? journey;
  @override
  ConsumerState<NativeMembershipJourneyScreen> createState() =>
      _NativeMembershipJourneyScreenState();
}

class _NativeMembershipJourneyScreenState
    extends ConsumerState<NativeMembershipJourneyScreen>
    with WidgetsBindingObserver {
  final _phone = TextEditingController(), _code = TextEditingController();
  NativeSupporterJourney? _journey;
  String? _acknowledgedReview;
  bool _releaseAcknowledged = false;
  bool _restartAcknowledged = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  void _clearDrafts() {
    _phone.clear();
    _code.clear();
    _acknowledgedReview = null;
    _releaseAcknowledged = false;
    _restartAcknowledged = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _clearDrafts();
  }

  @override
  void didUpdateWidget(NativeMembershipJourneyScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.configuredClubId != widget.configuredClubId ||
        oldWidget.journey != widget.journey) {
      _journey?.invalidate();
      _clearDrafts();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _journey?.invalidate();
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<NativeSupporterJourney?>(nativeSupporterJourneyProvider, (
      old,
      next,
    ) {
      if (old != next) {
        old?.invalidate();
        _clearDrafts();
      }
    });
    final journey = widget.journey ?? ref.watch(nativeSupporterJourneyProvider);
    _journey = journey;
    final l10n = context.afriL10n;
    if (journey == null || !journey.matchesClub(widget.configuredClubId)) {
      return AfriScreenScaffold(
        title: l10n.nativeMembershipTitle,
        child: _notice(
          l10n.nativeMembershipUnavailable,
          l10n.nativeMembershipUnavailableBody,
        ),
      );
    }
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) journey.invalidate();
      },
      child: AnimatedBuilder(
        animation: journey,
        builder: (context, _) => AfriScreenScaffold(
          title: l10n.nativeMembershipTitle,
          child: FocusTraversalGroup(
            policy: OrderedTraversalPolicy(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (journey.problem != null)
                  Semantics(
                    liveRegion: true,
                    child: _notice(_problem(journey.problem!), null),
                  ),
                if (journey.busy)
                  Semantics(
                    liveRegion: true,
                    label: l10n.nativeMembershipWorking,
                    child: const AfriLinearProgressIndicator(),
                  ),
                ..._content(journey),
                if (journey.canRestartSignIn) ...[
                  const SizedBox(height: SpacingTokens.spacing4),
                  _notice(
                    l10n.nativeMembershipRestart,
                    l10n.nativeMembershipRestartBody,
                  ),
                  AfriCheckbox(
                    label: l10n.nativeMembershipRestartAcknowledgement,
                    value: _restartAcknowledged,
                    onChanged: journey.busy
                        ? null
                        : (v) =>
                              setState(() => _restartAcknowledged = v == true),
                  ),
                  AfriButton(
                    label: l10n.nativeMembershipRestart,
                    labelMaxLines: 4,
                    enabled: !journey.busy && _restartAcknowledged,
                    onTap: () {
                      _clearDrafts();
                      unawaited(journey.restartSignIn(acknowledgement: true));
                    },
                  ),
                ],
                if (journey.identity != null && !journey.busy) ...[
                  const SizedBox(height: SpacingTokens.spacing6),
                  _button(
                    l10n.nativeMembershipSignOut,
                    journey.signOut,
                    secondary: true,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _problem(NativeJourneyProblem problem) {
    final l = context.afriL10n;
    return switch (problem) {
      NativeJourneyProblem.unavailable => l.nativeMembershipUnavailable,
      NativeJourneyProblem.invalidInput => l.nativeMembershipInvalidInput,
      NativeJourneyProblem.signInRequired => l.nativeMembershipSignIn,
      NativeJourneyProblem.changed => l.nativeMembershipChanged,
      NativeJourneyProblem.denied => l.nativeMembershipDenied,
      NativeJourneyProblem.unresolved => l.nativeMembershipUnresolvedBody,
      NativeJourneyProblem.storage => l.nativeMembershipStorage,
      NativeJourneyProblem.retry => l.nativeMembershipRetry,
    };
  }

  Widget _notice(String title, String? body) => Padding(
    padding: const EdgeInsets.symmetric(vertical: SpacingTokens.spacing4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TypographyTokens.titleMedium(
            context.afriSemanticColors.primaryText,
          ),
        ),
        if (body != null) ...[
          const SizedBox(height: SpacingTokens.spacing2),
          Text(
            body,
            style: TypographyTokens.bodyLarge(
              context.afriSemanticColors.secondaryText,
            ),
          ),
        ],
      ],
    ),
  );

  Widget _button(
    String label,
    Future<void> Function() action, {
    bool secondary = false,
  }) => Padding(
    padding: const EdgeInsets.only(top: SpacingTokens.spacing2),
    child: AfriButton(
      label: label,
      labelMaxLines: 4,
      enabled: _journey?.busy != true,
      variant: secondary
          ? AfriButtonVariant.secondary
          : AfriButtonVariant.primary,
      onTap: () => unawaited(action()),
    ),
  );

  Widget _field(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: SpacingTokens.spacing2),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TypographyTokens.bodySmall(
            context.afriSemanticColors.secondaryText,
          ),
        ),
        const SizedBox(height: SpacingTokens.spacing1),
        Text(
          value,
          style: TypographyTokens.bodyLarge(
            context.afriSemanticColors.primaryText,
          ),
        ),
      ],
    ),
  );

  List<Widget> _content(NativeSupporterJourney j) {
    final l = context.afriL10n;
    switch (j.stage) {
      case NativeMembershipStage.unavailable:
        return [
          _notice(
            l.nativeMembershipUnavailable,
            l.nativeMembershipUnavailableBody,
          ),
        ];
      case NativeMembershipStage.signedOut:
        return [
          _notice(l.nativeMembershipSignIn, null),
          AfriInputField(
            controller: _phone,
            label: l.nativeMembershipPhone,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            maxLength: 16,
            enabled: !j.busy,
            autofillHints: const [AutofillHints.telephoneNumber],
            autocorrect: false,
            enableSuggestions: false,
          ),
          _button(l.nativeMembershipRequestCode, () async {
            await j.requestCode(_phone.text.trim());
            if (mounted && j.stage == NativeMembershipStage.codeRequested) {
              _phone.clear();
            }
          }),
          _button(
            l.nativeMembershipCheckSession,
            j.checkSession,
            secondary: true,
          ),
          _button(
            l.nativeMembershipRecoverSignIn,
            j.recoverIdentity,
            secondary: true,
          ),
        ];
      case NativeMembershipStage.codeRequested:
        return [
          AfriInputField(
            controller: _code,
            label: l.nativeMembershipCode,
            keyboardType: TextInputType.number,
            maxLength: 6,
            obscureText: true,
            autofillHints: const [AutofillHints.oneTimeCode],
            enabled: !j.busy,
            autocorrect: false,
            enableSuggestions: false,
          ),
          _button(l.nativeMembershipVerify, () async {
            final code = _code.text;
            _code.clear();
            await j.verifyCode(code);
          }),
          _button(
            l.nativeMembershipRecoverSignIn,
            j.recoverIdentity,
            secondary: true,
          ),
        ];
      case NativeMembershipStage.ready:
        return [
          _notice(
            l.nativeMembershipChoose,
            j.plans.isEmpty ? l.nativeMembershipNoPlans : null,
          ),
          for (final plan in j.plans)
            _button(
              '${l.nativeMembershipPrepare}: ${plan.label}',
              () => j.prepare(plan.tier),
            ),
          _button(
            l.nativeMembershipCheckStatus,
            j.inspectRecovery,
            secondary: true,
          ),
          _button(
            l.nativeMembershipRefreshSignIn,
            j.rotateCredentials,
            secondary: true,
          ),
        ];
      case NativeMembershipStage.prepared:
        return [
          _notice(l.nativeMembershipPrepared, l.nativeMembershipDialerNotice),
          _button(l.nativeMembershipReview, j.reviewPayment),
          _button(
            l.nativeMembershipCheckStatus,
            j.inspectRecovery,
            secondary: true,
          ),
        ];
      case NativeMembershipStage.review:
      case NativeMembershipStage.confirmation:
        final review = j.paymentReview;
        if (review == null) {
          return [
            _notice(l.nativeMembershipChanged, null),
            _button(l.nativeMembershipCheckStatus, j.inspectRecovery),
          ];
        }
        final instruction = review.instruction;
        return [
          _notice(
            j.stage == NativeMembershipStage.review
                ? l.nativeMembershipReview
                : l.nativeMembershipConfirm,
            l.nativeMembershipDialerNotice,
          ),
          _field(
            l.nativeMembershipPlan,
            j.plans
                    .where((p) => p.tier == review.checkout.tier)
                    .map((p) => p.label)
                    .firstOrNull ??
                review.checkout.tier,
          ),
          _field(l.nativeMembershipAmount, instruction.amount.toString()),
          _field(l.nativeMembershipCurrency, instruction.currency),
          _field(l.nativeMembershipProvider, instruction.provider),
          _field(l.nativeMembershipRecipient, instruction.recipient),
          if (j.stage == NativeMembershipStage.review)
            _button(
              l.nativeMembershipContinue,
              () async => j.showConfirmation(),
            )
          else ...[
            AfriCheckbox(
              label: l.nativeMembershipAcknowledgement,
              value: _acknowledgedReview == review.reviewId,
              onChanged: j.busy
                  ? null
                  : (checked) => setState(() {
                      _acknowledgedReview = checked == true
                          ? review.reviewId
                          : null;
                    }),
            ),
            AfriButton(
              label: l.nativeMembershipOpenDialer,
              labelMaxLines: 4,
              enabled: !j.busy && _acknowledgedReview == review.reviewId,
              onTap: () {
                _acknowledgedReview = null;
                unawaited(j.confirmPayment(acknowledgement: true));
              },
            ),
          ],
          _button(l.nativeMembershipCancel, () async {
            _acknowledgedReview = null;
            j.cancelReview();
          }, secondary: true),
        ];
      case NativeMembershipStage.unresolved:
        final handoff = j.recovery?.server.handoff;
        final releasable =
            handoff != null &&
            handoff.claimedAt == null &&
            handoff.phase == 'reserved' &&
            !handoff.paymentEvidenceAllocated &&
            (j.recovery?.attempt == null ||
                [
                  'reserved',
                  'not_opened',
                ].contains(j.recovery!.attempt!.phase));
        return [
          _notice(
            l.nativeMembershipUnresolved,
            l.nativeMembershipUnresolvedBody,
          ),
          _button(l.nativeMembershipCheckStatus, j.inspectRecovery),
          if (j.pending?.pending == true)
            _button(
              l.nativeMembershipRetryOriginal,
              j.retryOriginalCheckout,
              secondary: true,
            ),
          if (j.pending?.orderId != null &&
              (handoff == null || handoff.phase == 'released'))
            _button(l.nativeMembershipReview, j.reviewPayment, secondary: true),
          if (releasable) ...[
            AfriCheckbox(
              label: l.nativeMembershipReleaseAcknowledgement,
              value: _releaseAcknowledged,
              onChanged: j.busy
                  ? null
                  : (v) => setState(() => _releaseAcknowledged = v == true),
            ),
            AfriButton(
              label: l.nativeMembershipRelease,
              labelMaxLines: 4,
              enabled: !j.busy && _releaseAcknowledged,
              onTap: () {
                _releaseAcknowledged = false;
                unawaited(j.releaseUnclaimed(acknowledgement: true));
              },
            ),
          ],
          if (j.identity == null)
            _button(
              l.nativeMembershipRecoverSignIn,
              j.recoverIdentity,
              secondary: true,
            ),
        ];
      case NativeMembershipStage.allocationRecorded:
        return [
          _notice(
            l.nativeMembershipAllocationRecorded,
            l.nativeMembershipAllocationBody,
          ),
          _button(l.nativeMembershipReceipt, j.readReceipt),
          if (j.receipt != null) ...[
            _notice(l.nativeMembershipReceiptNotice, null),
            _field(l.nativeMembershipReference, j.receipt!.allocationId),
            _field(l.nativeMembershipAmount, j.receipt!.amount.toString()),
            _field(l.nativeMembershipCurrency, j.receipt!.currency),
            _field(
              l.nativeMembershipRecordedAt,
              DateTime.fromMillisecondsSinceEpoch(
                j.receipt!.recordedAt,
                isUtc: true,
              ).toIso8601String(),
            ),
          ],
          _button(
            l.nativeMembershipCheckStatus,
            j.inspectRecovery,
            secondary: true,
          ),
        ];
    }
  }
}
