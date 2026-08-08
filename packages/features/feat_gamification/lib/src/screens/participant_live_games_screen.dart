import 'dart:async';

import 'package:core_l10n/core_l10n.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../controllers/live_game_v2_answer_controller.dart';
import '../controllers/live_game_v2_discovery_controller.dart';
import '../controllers/live_game_v2_entry_controller.dart';
import '../controllers/live_game_v2_participant_controller.dart';
import '../controllers/live_game_v2_synchronizer.dart';
import '../live_game_v2_providers.dart';
import '../models/live_game_v2_discovery_models.dart';
import '../models/live_game_v2_models.dart';

class ParticipantLiveGamesScreen extends ConsumerStatefulWidget {
  const ParticipantLiveGamesScreen({
    super.key,
    this.initialSessionId,
    this.autofocusPrimaryAction = false,
    this.autoOpenInitialSession = true,
  });

  final String? initialSessionId;

  @visibleForTesting
  final bool autofocusPrimaryAction;

  @visibleForTesting
  final bool autoOpenInitialSession;

  @override
  ConsumerState<ParticipantLiveGamesScreen> createState() =>
      _ParticipantLiveGamesScreenState();
}

class _ParticipantLiveGamesScreenState
    extends ConsumerState<ParticipantLiveGamesScreen>
    with WidgetsBindingObserver {
  late bool _wasOnline;
  bool _deepLinkAttempted = false;
  bool _resyncOnResume = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _wasOnline = ConnectivityService.isOnline;
    ConnectivityService.onlineNotifier.addListener(_handleConnectivityChange);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ConnectivityService.onlineNotifier.removeListener(
      _handleConnectivityChange,
    );
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!_resyncOnResume || !mounted) return;
      _resyncOnResume = false;
      unawaited(
        ref.read(participantGameEntryControllerProvider.notifier).reconnect(),
      );
      return;
    }
    _resyncOnResume = true;
  }

  void _handleConnectivityChange() {
    final online = ConnectivityService.isOnline;
    final restored = !_wasOnline && online;
    _wasOnline = online;
    if (!mounted) return;
    final controller = ref.read(
      participantGameEntryControllerProvider.notifier,
    );
    if (!online) {
      controller.markOffline();
    } else if (restored) {
      unawaited(controller.reconnect());
    }
    setState(() {});
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/fanzone');
    }
  }

  void _backToGames() {
    context.go('/fanzone/game');
  }

  void _scheduleDeepLinkOpen(ParticipantGameEntryState state) {
    final sessionId = widget.initialSessionId?.trim();
    if (!widget.autoOpenInitialSession ||
        _deepLinkAttempted ||
        sessionId == null ||
        sessionId.isEmpty ||
        state.feed == null) {
      return;
    }
    _deepLinkAttempted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        ref
            .read(participantGameEntryControllerProvider.notifier)
            .openEligibleSession(sessionId, reauthorizeDeepLink: true),
      );
    });
  }

  Future<void> _openSession(String sessionId) {
    return ref
        .read(participantGameEntryControllerProvider.notifier)
        .openEligibleSession(sessionId);
  }

  Future<void> _submitAnswer(String optionKey) async {
    await ref
        .read(participantGameEntryControllerProvider.notifier)
        .submitAnswer(optionKey);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.afriL10n;
    final state = ref.watch(participantGameEntryControllerProvider);
    _scheduleDeepLinkOpen(state);

    return AfriScreenScaffold(
      backgroundColor: ColorTokens.background,
      appBar: AfriAppBar(
        title: Text(
          l10n.gameLiveGamesTitle,
          style: TypographyTokens.headlineSmall().copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: AfriIconButton(
          key: const ValueKey<String>('participant-live-games-back'),
          icon: AfriIcons.back,
          onTap: _close,
          tooltip: l10n.gameBack,
        ),
      ),
      scrollable: false,
      constrainContent: true,
      child: SafeArea(child: _buildState(state)),
    );
  }

  Widget _buildState(ParticipantGameEntryState state) {
    final retained = state.feed != null || state.runtime?.projection != null;
    if (state.status == ParticipantGameEntryStatus.discovering && !retained) {
      return Padding(
        padding: const EdgeInsets.all(SpacingTokens.screenPadding),
        child: AfriStateView.loading(
          key: const ValueKey<String>('participant-games-loading'),
          title: context.afriL10n.gameDiscoveringSessions,
          message: context.afriL10n.gameDiscoveringSessionsDescription,
        ),
      );
    }

    if (state.status == ParticipantGameEntryStatus.empty) {
      return _singleState(
        AfriStateView.empty(
          key: const ValueKey<String>('participant-games-empty'),
          title: context.afriL10n.gameNoEligibleSessions,
          message: context.afriL10n.gameNoEligibleSessionsDescription,
          icon: AfriIcons.live,
          actionLabel: context.afriL10n.gameRefresh,
          onAction: () => unawaited(
            ref
                .read(participantGameEntryControllerProvider.notifier)
                .refreshDiscovery(),
          ),
        ),
      );
    }

    if (state.status == ParticipantGameEntryStatus.failure && !retained) {
      return _singleState(_failureState(state));
    }

    if (state.status == ParticipantGameEntryStatus.live ||
        state.status == ParticipantGameEntryStatus.entering ||
        state.runtime?.projection != null) {
      return _LiveRuntimeView(
        state: state,
        autofocusPrimaryAction: widget.autofocusPrimaryAction,
        onRefresh: () => ref
            .read(participantGameEntryControllerProvider.notifier)
            .reconnect(),
        onSubmitAnswer: _submitAnswer,
        onBackToGames: _backToGames,
      );
    }

    if (state.status == ParticipantGameEntryStatus.scheduled &&
        state.selectedSession != null) {
      return _ScheduledGameView(
        session: state.selectedSession!,
        onRefresh: () => ref
            .read(participantGameEntryControllerProvider.notifier)
            .reconnect(),
        onBackToGames: _backToGames,
      );
    }

    return _DiscoveryView(
      state: state,
      autofocusPrimaryAction: widget.autofocusPrimaryAction,
      onRefresh: () => ref
          .read(participantGameEntryControllerProvider.notifier)
          .refreshDiscovery(),
      onReconnect: () =>
          ref.read(participantGameEntryControllerProvider.notifier).reconnect(),
      onOpen: _openSession,
    );
  }

  Widget _failureState(ParticipantGameEntryState state) {
    final l10n = context.afriL10n;
    if (state.entryFailureKind == ParticipantGameEntryFailureKind.notEligible) {
      return AfriStateView.error(
        key: const ValueKey<String>('participant-games-not-eligible'),
        title: l10n.gameNotEligible,
        message: l10n.gameNotEligibleDescription,
        actionLabel: l10n.gameBackToGames,
        onAction: _backToGames,
      );
    }
    if (state.entryFailureKind ==
            ParticipantGameEntryFailureKind.aliasMismatch ||
        state.discoveryFailureKind ==
            ParticipantDiscoveryFailureKind.contract) {
      return AfriStateView.error(
        key: const ValueKey<String>('participant-games-conflict'),
        title: l10n.gameDiscoveryConflict,
        message: l10n.gameDiscoveryConflictDescription,
        actionLabel: l10n.gameRefresh,
        onAction: () => unawaited(
          ref
              .read(participantGameEntryControllerProvider.notifier)
              .refreshDiscovery(),
        ),
      );
    }
    if (state.discoveryFailureKind == ParticipantDiscoveryFailureKind.timeout) {
      return AfriStateView.error(
        key: const ValueKey<String>('participant-games-security-timeout'),
        title: l10n.gameLiveSessionTimeout,
        message: l10n.gameLiveSessionTimeoutDescription,
        actionLabel: l10n.gameRefresh,
        onAction: () => unawaited(
          ref
              .read(participantGameEntryControllerProvider.notifier)
              .refreshDiscovery(),
        ),
      );
    }
    if (state.entryFailureKind ==
            ParticipantGameEntryFailureKind.permissionDenied ||
        state.discoveryFailureKind ==
            ParticipantDiscoveryFailureKind.permissionDenied) {
      return AfriStateView.error(
        key: const ValueKey<String>('participant-games-access-denied'),
        title: l10n.gameLiveAccessDeniedV2,
        message: l10n.gameLiveAccessDeniedV2Description,
        actionLabel: l10n.gameBackToFanZoneUpper,
        onAction: _close,
      );
    }
    return AfriStateView.error(
      key: const ValueKey<String>('participant-games-failure'),
      title: l10n.gameDiscoveryUnavailable,
      message: l10n.gameDiscoveryUnavailableDescription,
      actionLabel: l10n.gameRefresh,
      onAction: () => unawaited(
        ref
            .read(participantGameEntryControllerProvider.notifier)
            .refreshDiscovery(),
      ),
    );
  }

  Widget _singleState(Widget child) {
    return ListView(
      padding: const EdgeInsets.all(SpacingTokens.screenPadding),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [child],
    );
  }
}

class _DiscoveryView extends StatelessWidget {
  const _DiscoveryView({
    required this.state,
    required this.autofocusPrimaryAction,
    required this.onRefresh,
    required this.onReconnect,
    required this.onOpen,
  });

  final ParticipantGameEntryState state;
  final bool autofocusPrimaryAction;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onReconnect;
  final Future<void> Function(String sessionId) onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.afriL10n;
    final feed = state.feed;
    final sessions = feed?.sessions ?? const <ParticipantGameDiscoveryItem>[];
    final live = sessions
        .where(
          (session) =>
              session.availability == ParticipantDiscoveryAvailability.liveNow,
        )
        .toList(growable: false);
    final scheduled = sessions
        .where(
          (session) =>
              session.availability ==
              ParticipantDiscoveryAvailability.scheduled,
        )
        .toList(growable: false);
    final offline = state.status == ParticipantGameEntryStatus.offline;
    final failed = state.status == ParticipantGameEntryStatus.failure;
    final syncing = state.status == ParticipantGameEntryStatus.discovering;
    final conflict =
        state.entryFailureKind ==
            ParticipantGameEntryFailureKind.aliasMismatch ||
        state.discoveryFailureKind == ParticipantDiscoveryFailureKind.contract;
    final securityTimeout =
        state.discoveryFailureKind == ParticipantDiscoveryFailureKind.timeout;

    return AfriRefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        key: const ValueKey<String>('participant-games-discovery'),
        padding: const EdgeInsets.all(SpacingTokens.screenPadding),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (syncing) ...[
            AfriStateView.loading(
              key: const ValueKey<String>('participant-games-syncing'),
              compact: true,
              title: l10n.gameDiscoveryRefreshing,
              message: l10n.gameDiscoveryRefreshingDescription,
            ),
            const SizedBox(height: SpacingTokens.spacing4),
          ],
          if (offline || failed) ...[
            AfriStateView(
              compact: true,
              tone: offline ? AfriStateTone.offline : AfriStateTone.error,
              title: offline
                  ? l10n.gameLiveGamesConnectionRequired
                  : conflict
                  ? l10n.gameDiscoveryConflict
                  : securityTimeout
                  ? l10n.gameLiveSessionTimeout
                  : l10n.gameDiscoveryUnavailable,
              message: conflict
                  ? l10n.gameDiscoveryConflictDescription
                  : securityTimeout
                  ? l10n.gameLiveSessionTimeoutDescription
                  : l10n.gameDiscoveryUnavailableDescription,
              icon: offline ? AfriIcons.offline : AfriIcons.statusError,
              actionLabel: offline ? l10n.gameReconnect : l10n.gameRefresh,
              onAction: () => unawaited(offline ? onReconnect() : onRefresh()),
            ),
            const SizedBox(height: SpacingTokens.spacing4),
          ],
          Text(
            l10n.gameLiveGamesSubtitle,
            style: TypographyTokens.bodyLarge(
              context.afriSemanticColors.secondaryText,
            ),
          ),
          if (feed != null) ...[
            const SizedBox(height: SpacingTokens.spacing4),
            AfriInfoChip(
              label: l10n.gamePlayingAsAlias(feed.publicAlias),
              icon: AfriIcons.profile,
            ),
          ],
          if (live.isNotEmpty) ...[
            const SizedBox(height: SpacingTokens.sectionGap),
            _SectionHeading(
              label: l10n.gameLiveNow,
              icon: AfriIcons.statusLive,
            ),
            const SizedBox(height: SpacingTokens.spacing3),
            for (final session in live) ...[
              _DiscoveryGameCard(
                session: session,
                enabled: !offline,
                autofocus:
                    autofocusPrimaryAction &&
                    session.sessionId == live.first.sessionId,
                onTap: () => unawaited(onOpen(session.sessionId)),
              ),
              const SizedBox(height: SpacingTokens.spacing3),
            ],
          ],
          if (scheduled.isNotEmpty) ...[
            const SizedBox(height: SpacingTokens.sectionGap),
            _SectionHeading(
              label: l10n.gameScheduled,
              icon: AfriIcons.calendar,
            ),
            const SizedBox(height: SpacingTokens.spacing3),
            for (final session in scheduled) ...[
              _DiscoveryGameCard(
                session: session,
                enabled: true,
                onTap: () => unawaited(onOpen(session.sessionId)),
              ),
              const SizedBox(height: SpacingTokens.spacing3),
            ],
          ],
          if (sessions.isEmpty) ...[
            const SizedBox(height: SpacingTokens.sectionGap),
            AfriStateView.empty(
              compact: true,
              title: l10n.gameNoEligibleSessions,
              message: l10n.gameNoEligibleSessionsDescription,
              icon: AfriIcons.live,
            ),
          ],
          const SizedBox(height: SpacingTokens.spacing8),
        ],
      ),
    );
  }
}

class _DiscoveryGameCard extends StatelessWidget {
  const _DiscoveryGameCard({
    required this.session,
    required this.enabled,
    this.autofocus = false,
    required this.onTap,
  });

  final ParticipantGameDiscoveryItem session;
  final bool enabled;
  final bool autofocus;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.afriL10n;
    final scheduled =
        session.availability == ParticipantDiscoveryAvailability.scheduled;
    return AfriSurfaceCard(
      key: ValueKey<String>('participant-game-${session.sessionId}'),
      onTap: onTap,
      enabled: enabled,
      autofocus: autofocus,
      semanticsLabel:
          '${session.title}, ${scheduled ? l10n.gameScheduled : l10n.gameLiveNow}',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            scheduled ? AfriIcons.calendar : AfriIcons.statusLive,
            color: scheduled
                ? context.afriSemanticColors.secondaryText
                : context.afriSemanticColors.accent,
          ),
          const SizedBox(width: SpacingTokens.spacing3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.title,
                  style: TypographyTokens.titleMedium().copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: SpacingTokens.spacing2),
                Text(
                  scheduled
                      ? _scheduledTime(context, session.availableFrom)
                      : l10n.gameLiveNow,
                  style: TypographyTokens.bodySmall(
                    context.afriSemanticColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: SpacingTokens.spacing2),
          Icon(
            AfriIcons.chevronRight,
            color: context.afriSemanticColors.secondaryText,
          ),
        ],
      ),
    );
  }
}

class _ScheduledGameView extends StatelessWidget {
  const _ScheduledGameView({
    required this.session,
    required this.onRefresh,
    required this.onBackToGames,
  });

  final ParticipantGameDiscoveryItem session;
  final Future<void> Function() onRefresh;
  final VoidCallback onBackToGames;

  @override
  Widget build(BuildContext context) {
    final l10n = context.afriL10n;
    return AfriRefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        key: const ValueKey<String>('participant-game-scheduled'),
        padding: const EdgeInsets.all(SpacingTokens.screenPadding),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          AfriSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AfriInfoChip(
                  label: l10n.gameScheduled,
                  icon: AfriIcons.calendar,
                ),
                const SizedBox(height: SpacingTokens.spacing4),
                Text(
                  session.title,
                  style: TypographyTokens.headlineSmall().copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: SpacingTokens.spacing3),
                Text(
                  _scheduledTime(context, session.availableFrom),
                  style: TypographyTokens.bodyLarge(),
                ),
                const SizedBox(height: SpacingTokens.spacing4),
                Text(
                  l10n.gameScheduledDescription,
                  style: TypographyTokens.bodyMedium(
                    context.afriSemanticColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing5),
          AfriButton(
            label: l10n.gameBackToGames,
            variant: AfriButtonVariant.secondary,
            icon: AfriIcons.back,
            onTap: onBackToGames,
          ),
        ],
      ),
    );
  }
}

class _LiveRuntimeView extends StatelessWidget {
  const _LiveRuntimeView({
    required this.state,
    required this.autofocusPrimaryAction,
    required this.onRefresh,
    required this.onSubmitAnswer,
    required this.onBackToGames,
  });

  final ParticipantGameEntryState state;
  final bool autofocusPrimaryAction;
  final Future<void> Function() onRefresh;
  final Future<void> Function(String optionKey) onSubmitAnswer;
  final VoidCallback onBackToGames;

  @override
  Widget build(BuildContext context) {
    final runtime = state.runtime;
    final projection = runtime?.projection;
    if (runtime == null || projection == null) {
      return Padding(
        padding: const EdgeInsets.all(SpacingTokens.screenPadding),
        child: AfriStateView.loading(
          key: const ValueKey<String>('participant-game-entering'),
          title: context.afriL10n.gameSyncing,
          message: context.afriL10n.gameDiscoveringSessionsDescription,
        ),
      );
    }

    return AfriRefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        key: const ValueKey<String>('participant-game-live'),
        padding: const EdgeInsets.all(SpacingTokens.screenPadding),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (_runtimeStatus(context, runtime) case final status?) ...[
            status,
            const SizedBox(height: SpacingTokens.spacing4),
          ],
          _LiveHeader(
            title: state.selectedSession?.title,
            projection: projection,
          ),
          const SizedBox(height: SpacingTokens.sectionGap),
          _PhaseContent(
            runtime: runtime,
            projection: projection,
            autofocusPrimaryAction: autofocusPrimaryAction,
            onSubmitAnswer: onSubmitAnswer,
          ),
          const SizedBox(height: SpacingTokens.sectionGap),
          _Leaderboard(rows: projection.leaderSummary),
          const SizedBox(height: SpacingTokens.spacing5),
          AfriButton(
            label: context.afriL10n.gameBackToGames,
            variant: AfriButtonVariant.secondary,
            icon: AfriIcons.back,
            onTap: onBackToGames,
          ),
          const SizedBox(height: SpacingTokens.spacing8),
        ],
      ),
    );
  }

  Widget? _runtimeStatus(
    BuildContext context,
    ParticipantLiveGameRuntimeState runtime,
  ) {
    final l10n = context.afriL10n;
    if (state.entryFailureKind ==
            ParticipantGameEntryFailureKind.permissionDenied ||
        runtime.syncFailureKind == LiveGameSyncFailureKind.permissionDenied) {
      return AfriStateView.error(
        compact: true,
        title: l10n.gameLiveAccessDeniedV2,
        message: l10n.gameLiveAccessDeniedV2Description,
        actionLabel: l10n.gameBackToGames,
        onAction: onBackToGames,
      );
    }
    if (state.entryFailureKind ==
            ParticipantGameEntryFailureKind.aliasMismatch ||
        runtime.syncFailureKind == LiveGameSyncFailureKind.contract) {
      return AfriStateView.error(
        compact: true,
        title: l10n.gameLiveSessionConflict,
        message: l10n.gameLiveSessionConflictDescription,
        actionLabel: l10n.gameRefresh,
        onAction: () => unawaited(onRefresh()),
      );
    }
    if (runtime.syncFailureKind == LiveGameSyncFailureKind.timeout) {
      return AfriStateView.error(
        compact: true,
        title: l10n.gameLiveSessionTimeout,
        message: l10n.gameLiveSessionTimeoutDescription,
        actionLabel: l10n.gameRefresh,
        onAction: () => unawaited(onRefresh()),
      );
    }
    if (runtime.answerStatus == ParticipantAnswerSubmissionStatus.uncertain) {
      return AfriStateView.error(
        compact: true,
        title: l10n.gameAnswerUncertain,
        message: l10n.gameAnswerUncertainDescription,
        actionLabel: l10n.gameRefresh,
        onAction: () => unawaited(onRefresh()),
      );
    }
    if (runtime.answerStatus == ParticipantAnswerSubmissionStatus.submitting) {
      return AfriStateView.loading(
        compact: true,
        title: l10n.gameAnswerSubmitting,
        message: l10n.gameUsingLastConfirmed,
      );
    }
    if (runtime.answerStatus == ParticipantAnswerSubmissionStatus.accepted) {
      return AfriStateView.success(
        compact: true,
        title: l10n.gameAnswerConfirmed,
        message: l10n.gameUsingLastConfirmed,
      );
    }
    if (runtime.syncStatus == LiveGameSyncStatus.offline ||
        runtime.syncStatus == LiveGameSyncStatus.reconnecting ||
        runtime.syncStatus == LiveGameSyncStatus.failure) {
      final lastEventAt = runtime.projection?.version.freshness.lastEventAt;
      final lastConfirmedMessage = lastEventAt == null
          ? l10n.gameUsingLastConfirmed
          : '${l10n.gameUsingLastConfirmed} '
                '${l10n.gameLastConfirmedAt(MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(lastEventAt.toLocal())))}';
      return AfriStateView.offline(
        compact: true,
        title: runtime.syncStatus == LiveGameSyncStatus.reconnecting
            ? l10n.tvPhaseReconnecting
            : l10n.gameLiveGamesConnectionRequired,
        message: lastConfirmedMessage,
        actionLabel: l10n.gameReconnect,
        onAction: () => unawaited(onRefresh()),
      );
    }
    if (runtime.syncStatus == LiveGameSyncStatus.refreshing) {
      return AfriStateView.loading(
        compact: true,
        title: l10n.gameSyncing,
        message: l10n.gameUsingLastConfirmed,
      );
    }
    return null;
  }
}

class _LiveHeader extends StatelessWidget {
  const _LiveHeader({required this.title, required this.projection});

  final String? title;
  final ParticipantGameProjection projection;

  @override
  Widget build(BuildContext context) {
    final l10n = context.afriL10n;
    return AfriSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeading(
            label: _phaseLabel(context, projection.version.phase),
            icon: AfriIcons.statusLive,
          ),
          const SizedBox(height: SpacingTokens.spacing3),
          if (title != null)
            Text(
              title!,
              style: TypographyTokens.headlineSmall().copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          if (title != null) const SizedBox(height: SpacingTokens.spacing3),
          AfriInfoChip(
            label: l10n.gamePlayingAsAlias(projection.publicAlias),
            icon: AfriIcons.profile,
          ),
          if (projection.version.phaseDeadline != null) ...[
            const SizedBox(height: SpacingTokens.spacing3),
            Text(
              _deadlineTime(context, projection.version.phaseDeadline!),
              style: TypographyTokens.bodySmall(
                context.afriSemanticColors.secondaryText,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PhaseContent extends StatelessWidget {
  const _PhaseContent({
    required this.runtime,
    required this.projection,
    required this.autofocusPrimaryAction,
    required this.onSubmitAnswer,
  });

  final ParticipantLiveGameRuntimeState runtime;
  final ParticipantGameProjection projection;
  final bool autofocusPrimaryAction;
  final Future<void> Function(String optionKey) onSubmitAnswer;

  @override
  Widget build(BuildContext context) {
    return switch (projection.version.phase) {
      LiveGamePhase.activatedLobby => _PhaseStateCard(
        icon: AfriIcons.people,
        title: context.afriL10n.gameLobbyTitle,
        message: context.afriL10n.gameLobbyDescription,
      ),
      LiveGamePhase.paused => _PhaseStateCard(
        icon: AfriIcons.statusWait,
        title: context.afriL10n.gamePausedTitle,
        message: context.afriL10n.gamePausedDescription,
      ),
      LiveGamePhase.questionOpen || LiveGamePhase.reveal => _QuestionView(
        runtime: runtime,
        projection: projection,
        autofocusPrimaryAction: autofocusPrimaryAction,
        onSubmitAnswer: onSubmitAnswer,
      ),
      LiveGamePhase.completed => _PhaseStateCard(
        icon: AfriIcons.rank,
        title: context.afriL10n.gameCompletedTitle,
        message: context.afriL10n.gameCompletedDescription,
      ),
      LiveGamePhase.cancelled => _PhaseStateCard(
        icon: AfriIcons.statusBlocked,
        title: context.afriL10n.gameCancelledTitle,
        message: context.afriL10n.gameCancelledDescription,
      ),
      _ => _PhaseStateCard(
        icon: AfriIcons.statusWait,
        title: context.afriL10n.gameSyncing,
        message: context.afriL10n.gameUsingLastConfirmed,
      ),
    };
  }
}

class _QuestionView extends StatelessWidget {
  const _QuestionView({
    required this.runtime,
    required this.projection,
    required this.autofocusPrimaryAction,
    required this.onSubmitAnswer,
  });

  final ParticipantLiveGameRuntimeState runtime;
  final ParticipantGameProjection projection;
  final bool autofocusPrimaryAction;
  final Future<void> Function(String optionKey) onSubmitAnswer;

  @override
  Widget build(BuildContext context) {
    final l10n = context.afriL10n;
    final question = projection.question;
    if (question == null) {
      return _PhaseStateCard(
        icon: AfriIcons.statusWait,
        title: l10n.gameSyncing,
        message: l10n.gameUsingLastConfirmed,
      );
    }
    final reveal = projection.version.phase == LiveGamePhase.reveal;

    return AfriSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeading(
            label: reveal ? l10n.gameRevealTitle : l10n.gameQuestionTitle,
            icon: reveal ? AfriIcons.visibility : AfriIcons.help,
          ),
          const SizedBox(height: SpacingTokens.spacing4),
          Text(
            question.prompt,
            style: TypographyTokens.titleLarge().copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing3),
          Text(
            reveal
                ? '${l10n.gameCorrectAnswer}: ${_correctAnswer(question)}'
                : l10n.gameChooseAnswer,
            style: TypographyTokens.bodyMedium(
              context.afriSemanticColors.secondaryText,
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing5),
          for (final option in question.options) ...[
            _AnswerOption(
              option: option,
              autofocus:
                  autofocusPrimaryAction &&
                  option.key == question.options.first.key,
              selected: runtime.selectedOptionKey == option.key,
              correct: reveal && question.correctOptionKey == option.key,
              enabled: !runtime.actionsBlocked,
              submitting:
                  runtime.answerStatus ==
                      ParticipantAnswerSubmissionStatus.submitting &&
                  runtime.selectedOptionKey == option.key,
              onTap: () => unawaited(onSubmitAnswer(option.key)),
            ),
            const SizedBox(height: SpacingTokens.spacing3),
          ],
        ],
      ),
    );
  }

  String _correctAnswer(LiveGameQuestionProjection question) {
    for (final option in question.options) {
      if (option.key == question.correctOptionKey) return option.label;
    }
    return '';
  }
}

class _AnswerOption extends StatelessWidget {
  const _AnswerOption({
    required this.option,
    required this.autofocus,
    required this.selected,
    required this.correct,
    required this.enabled,
    required this.submitting,
    required this.onTap,
  });

  final LiveGameOption option;
  final bool autofocus;
  final bool selected;
  final bool correct;
  final bool enabled;
  final bool submitting;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      label: selected
          ? context.afriL10n.gameSelectedAnswerSemantics(option.label)
          : option.label,
      child: AfriButton(
        key: ValueKey<String>('participant-answer-${option.key}'),
        label: option.label,
        labelMaxLines: 3,
        icon: correct || selected ? AfriIcons.check : null,
        variant: correct
            ? AfriButtonVariant.accent
            : selected
            ? AfriButtonVariant.secondary
            : AfriButtonVariant.outline,
        enabled: enabled,
        autofocus: autofocus,
        isLoading: submitting,
        onTap: onTap,
      ),
    );
  }
}

class _Leaderboard extends StatelessWidget {
  const _Leaderboard({required this.rows});

  final List<LiveGameLeaderSummaryRow> rows;

  @override
  Widget build(BuildContext context) {
    final l10n = context.afriL10n;
    return AfriSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeading(
            label: l10n.gameLeaderboardTitle,
            icon: AfriIcons.leaderboard,
          ),
          const SizedBox(height: SpacingTokens.spacing4),
          if (rows.isEmpty)
            Text(
              l10n.gameNoScores,
              style: TypographyTokens.bodyMedium(
                context.afriSemanticColors.secondaryText,
              ),
            )
          else
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: SpacingTokens.spacing2,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: AfriComponentSizes.leaderboardRankWidth,
                      child: Text(
                        l10n.gameLeaderboardRank(row.rank),
                        style: TypographyTokens.labelLarge(),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        row.publicAlias,
                        style: TypographyTokens.bodyMedium(),
                      ),
                    ),
                    Text(
                      row.score.toString(),
                      style: TypographyTokens.titleMedium().copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _PhaseStateCard extends StatelessWidget {
  const _PhaseStateCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return AfriStateView.empty(
      key: ValueKey<String>('participant-phase-$title'),
      title: title,
      message: message,
      icon: icon,
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: SizeTokens.iconSm),
        const SizedBox(width: SpacingTokens.spacing2),
        Expanded(
          child: Text(
            label,
            style: TypographyTokens.labelLarge().copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

String _scheduledTime(BuildContext context, DateTime? value) {
  if (value == null) return context.afriL10n.gameScheduled;
  final local = value.toLocal();
  final material = MaterialLocalizations.of(context);
  return '${context.afriL10n.gameStartsAt} '
      '${material.formatMediumDate(local)} · '
      '${material.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
}

String _deadlineTime(BuildContext context, DateTime value) {
  final local = value.toLocal();
  final material = MaterialLocalizations.of(context);
  return '${context.afriL10n.gamePhaseEndsAt} '
      '${material.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
}

String _phaseLabel(BuildContext context, LiveGamePhase phase) {
  final l10n = context.afriL10n;
  return switch (phase) {
    LiveGamePhase.scheduled => l10n.gameScheduled,
    LiveGamePhase.activatedLobby => l10n.gameLobbyTitle,
    LiveGamePhase.questionOpen => l10n.gameQuestionTitle,
    LiveGamePhase.reveal => l10n.gameRevealTitle,
    LiveGamePhase.paused => l10n.gamePausedTitle,
    LiveGamePhase.completed => l10n.gameCompletedTitle,
    LiveGamePhase.cancelled => l10n.gameCancelledTitle,
    _ => l10n.gameSyncing,
  };
}
