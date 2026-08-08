import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../controllers/game_operations_controllers.dart';
import '../game_operations_providers.dart';
import '../widgets/game_operations_ui.dart';

class SessionPlannerScreen extends ConsumerStatefulWidget {
  const SessionPlannerScreen({
    super.key,
    this.now,
    this.autofocusCreateAction = false,
  });

  @visibleForTesting
  final DateTime Function()? now;

  @visibleForTesting
  final bool autofocusCreateAction;

  @override
  ConsumerState<SessionPlannerScreen> createState() =>
      _SessionPlannerScreenState();
}

class _SessionPlannerScreenState extends ConsumerState<SessionPlannerScreen> {
  String? _packId;
  String _eligibility = 'club_membership';
  late DateTime _scheduledStart;
  final Set<String> _displayIds = <String>{};
  final Set<String> _inviteeUserIds = <String>{};
  bool _invalid = false;

  DateTime _now() => widget.now?.call() ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _scheduledStart = _now().add(const Duration(hours: 1));
  }

  Future<void> _chooseStart() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledStart,
      firstDate: _now(),
      lastDate: _now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledStart),
    );
    if (time == null) return;
    setState(() {
      _scheduledStart = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _create() async {
    final packId = _packId;
    if (packId == null || !_isPlanValid) {
      setState(() => _invalid = true);
      return;
    }
    setState(() => _invalid = false);
    final created = await ref
        .read(sessionPlannerControllerProvider.notifier)
        .create(
          packId: packId,
          scheduledStartAt: _scheduledStart,
          eligibilityScope: _eligibility,
          displayIds: _displayIds.toList(growable: false),
          inviteeUserIds: _inviteeUserIds.toList(growable: false),
        );
    if (!mounted || !created) return;
    final sessionId = ref
        .read(sessionPlannerControllerProvider)
        .createdSession
        ?.id;
    if (sessionId != null) {
      context.go('/game-operations/sessions/$sessionId');
    }
  }

  bool get _isPlanValid {
    final scoped = _eligibility != 'club_membership';
    final invitationOnly = _eligibility == 'invitation_only';
    return _packId != null &&
        !_scheduledStart.isBefore(
          _now().subtract(const Duration(minutes: 5)),
        ) &&
        (!scoped || invitationOnly || _displayIds.isNotEmpty) &&
        (!invitationOnly || _inviteeUserIds.isNotEmpty);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sessionPlannerControllerProvider);
    final l10n = context.afriL10n;
    return AfriScreenScaffold(
      backgroundColor: ColorTokens.background,
      appBar: gameOperationsAppBar(
        context,
        l10n.gameSessionPlannerTitle,
        fallbackPath: '/game-operations/sessions',
        titleRevision:
            '${state.status.name}-${state.failure?.kind.name ?? 'none'}-'
            '${state.submitting}',
      ),
      scrollable: false,
      child: Padding(
        padding: const EdgeInsets.all(SpacingTokens.screenPadding),
        child: _body(context, state),
      ),
    );
  }

  Widget _body(BuildContext context, SessionPlannerState state) {
    final controller = ref.read(sessionPlannerControllerProvider.notifier);
    if (state.status == GameOperationsLoadStatus.loading &&
        state.options == null) {
      return AfriStateView.loading(
        title: context.afriL10n.gameSyncing,
        message: context.afriL10n.gameManagedGamesSubtitle,
      );
    }
    if (state.status == GameOperationsLoadStatus.failure &&
        state.options == null) {
      return gameOperationsFailureView(
        context,
        state.failure,
        controller.load,
        offlineDescription:
            context.afriL10n.gameOrganizerOperationsOfflineDescription,
      );
    }
    final options = state.options;
    if (options == null || options.packs.isEmpty) {
      return AfriStateView.empty(
        title: context.afriL10n.gamePlannerNoPacks,
        message: context.afriL10n.gamePlannerNoPacksDescription,
        icon: AfriIcons.live,
        actionLabel: context.afriL10n.gameRefresh,
        onAction: controller.load,
      );
    }
    _packId ??= options.packs.first.id;
    final canEdit = state.canEditPlan;
    final eligibleDisplays = options.displays
        .where((display) {
          if (!display.isAvailable) return false;
          if (_eligibility == 'home_owner') return display.scopeType == 'home';
          if (_eligibility == 'venue') return display.scopeType == 'venue';
          return true;
        })
        .toList(growable: false);
    final locale = Localizations.localeOf(context).toLanguageTag();
    return ListView(
      children: [
        if (state.status == GameOperationsLoadStatus.loading) ...[
          AfriInlineValidation(
            key: const ValueKey<String>('planner-syncing-warning'),
            message: context.afriL10n.gameManagedGamesRefreshing,
          ),
          const SizedBox(height: SpacingTokens.spacing4),
        ],
        AfriDropdownField<String>(
          key: const ValueKey<String>('planner-pack'),
          initialValue: _packId,
          label: context.afriL10n.gameQuestionPack,
          hint: context.afriL10n.gameSelectQuestionPack,
          items: options.packs
              .map(
                (pack) =>
                    DropdownMenuItem(value: pack.id, child: Text(pack.title)),
              )
              .toList(growable: false),
          enabled: canEdit,
          onChanged: (value) => setState(() => _packId = value),
        ),
        const SizedBox(height: SpacingTokens.spacing4),
        AfriDropdownField<String>(
          key: const ValueKey<String>('planner-eligibility'),
          initialValue: _eligibility,
          label: context.afriL10n.gameEligibility,
          items: options.allowedEligibilityScopes
              .map(
                (scope) => DropdownMenuItem(
                  value: scope,
                  child: Text(localizedEligibility(context.afriL10n, scope)),
                ),
              )
              .toList(growable: false),
          enabled: canEdit,
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              _eligibility = value;
              _displayIds.clear();
              _inviteeUserIds.clear();
            });
          },
        ),
        const SizedBox(height: SpacingTokens.spacing4),
        AfriSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GameOperationsInfoRow(
                label: context.afriL10n.gameScheduleStart,
                value: DateFormat.yMMMd(
                  locale,
                ).add_jm().format(_scheduledStart),
              ),
              const SizedBox(height: SpacingTokens.spacing3),
              AfriButton(
                key: const ValueKey<String>('planner-schedule'),
                label: context.afriL10n.gameChooseScheduleStart,
                icon: AfriIcons.calendar,
                variant: AfriButtonVariant.outline,
                enabled: canEdit,
                onTap: _chooseStart,
              ),
            ],
          ),
        ),
        const SizedBox(height: SpacingTokens.spacing5),
        AfriSectionHeader(title: context.afriL10n.gameSelectedDisplays),
        if (eligibleDisplays.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(
              vertical: SpacingTokens.spacing3,
            ),
            child: Text(
              context.afriL10n.gameNoAssignableDisplays,
              style: TypographyTokens.bodyMedium(
                context.afriSemanticColors.secondaryText,
              ),
            ),
          )
        else
          ...eligibleDisplays.map(
            (display) => AfriCheckbox(
              key: ValueKey<String>('planner-display-${display.id}'),
              label: display.name,
              subtitle: localizedDisplayScope(
                context.afriL10n,
                display.scopeType,
              ),
              value: _displayIds.contains(display.id),
              onChanged: canEdit
                  ? (selected) {
                      setState(() {
                        if (selected == true) {
                          _displayIds.add(display.id);
                        } else {
                          _displayIds.remove(display.id);
                        }
                      });
                    }
                  : null,
            ),
          ),
        const SizedBox(height: SpacingTokens.spacing5),
        AfriSectionHeader(title: context.afriL10n.gameSelectedInvitees),
        Padding(
          padding: const EdgeInsets.only(top: SpacingTokens.spacing2),
          child: Text(
            _eligibility == 'invitation_only'
                ? context.afriL10n.gameInviteesRequiredDescription
                : context.afriL10n.gameInviteesOptionalDescription,
            style: TypographyTokens.bodySmall(
              context.afriSemanticColors.secondaryText,
            ),
          ),
        ),
        if (options.invitees.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(
              vertical: SpacingTokens.spacing3,
            ),
            child: Text(
              context.afriL10n.gameNoInviteesDescription,
              style: TypographyTokens.bodyMedium(
                context.afriSemanticColors.secondaryText,
              ),
            ),
          )
        else
          ...options.invitees.map(
            (invitee) => AfriCheckbox(
              key: ValueKey<String>('planner-invitee-${invitee.userId}'),
              label: invitee.displayName,
              subtitle: '#${invitee.publicUserId}',
              value: _inviteeUserIds.contains(invitee.userId),
              onChanged: canEdit
                  ? (selected) {
                      setState(() {
                        if (selected == true) {
                          _inviteeUserIds.add(invitee.userId);
                        } else {
                          _inviteeUserIds.remove(invitee.userId);
                        }
                      });
                    }
                  : null,
            ),
          ),
        if (_invalid) ...[
          const SizedBox(height: SpacingTokens.spacing3),
          AfriInlineValidation(
            tone: AfriInlineValidationTone.error,
            message: context.afriL10n.gamePlannerFormInvalid,
          ),
        ],
        if (state.failure != null) ...[
          const SizedBox(height: SpacingTokens.spacing3),
          AfriInlineValidation(
            tone: AfriInlineValidationTone.error,
            message: gameOperationsFailureDescription(
              context.afriL10n,
              state.failure!,
              offlineDescription:
                  context.afriL10n.gameOrganizerOperationsOfflineDescription,
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing3),
          AfriButton(
            key: const ValueKey<String>('planner-refresh-after-timeout'),
            label: context.afriL10n.gameRefresh,
            icon: AfriIcons.refresh,
            variant: AfriButtonVariant.outline,
            onTap: controller.load,
          ),
        ],
        const SizedBox(height: SpacingTokens.spacing6),
        AfriButton(
          key: const ValueKey<String>('planner-create'),
          label: context.afriL10n.gameCreateSession,
          icon: AfriIcons.check,
          labelMaxLines: 3,
          isLoading: state.submitting,
          enabled: state.canSubmit && _isPlanValid,
          autofocus: widget.autofocusCreateAction,
          onTap: _create,
        ),
      ],
    );
  }
}
