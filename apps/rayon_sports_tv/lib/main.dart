import 'dart:async';

import 'package:club_rayon_sports/club_rayon_sports.dart';
import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/tv_runtime.dart';
import 'src/tv_runtime_controller.dart';

export 'src/tv_runtime.dart';
export 'src/tv_runtime_controller.dart';

const _rayonConfig = RayonSportsConfig();
const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
const _clubId = int.fromEnvironment('CLUB_ID');
const _homeVenueName = String.fromEnvironment(
  'HOME_VENUE_NAME',
  defaultValue: 'Home Stadium',
);
var _supabaseReady = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ColorTokens.init(_rayonConfig.colors);
  RuntimeBranding.configure(
    appName: '${_rayonConfig.appName} TV',
    clubName: _rayonConfig.clubName,
    countryCode: _rayonConfig.countryCode,
    currencyCode: _rayonConfig.currency,
    currencySymbol: _rayonConfig.currencySymbol,
    homeVenueName: _homeVenueName,
    primaryCompetitionName: 'Matchday live',
  );

  if (_supabaseUrl.trim().isNotEmpty && _supabaseAnonKey.trim().isNotEmpty) {
    await Supabase.initialize(url: _supabaseUrl, anonKey: _supabaseAnonKey);
    _supabaseReady = true;
  }

  runApp(const RayonSportsTvApp());
}

class RayonSportsTvApp extends StatelessWidget {
  const RayonSportsTvApp({
    super.key,
    this.previewState,
    this.runtimeController,
  });

  final TvRuntimeState? previewState;
  final TvRuntimeController? runtimeController;

  @override
  Widget build(BuildContext context) {
    ColorTokens.init(_rayonConfig.colors);
    final appLocale =
        AfriLocalizations.supportedLocales.any(
          (locale) => locale.languageCode == _rayonConfig.language,
        )
        ? Locale(_rayonConfig.language)
        : const Locale('en');

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (_) =>
          lookupAfriLocalizations(appLocale).tvAppTitle(_rayonConfig.appName),
      theme: ClubTheme.from(_rayonConfig),
      locale: appLocale.languageCode == 'rw' ? const Locale('en') : appLocale,
      supportedLocales: const <Locale>[Locale('en'), Locale('fr')],
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AfriLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => AfriLocalizationsScope(
        locale: appLocale,
        child: child ?? const SizedBox.shrink(),
      ),
      home: previewState != null
          ? RayonSportsTvScreen(state: previewState!)
          : TvRuntimeHost(controller: runtimeController),
    );
  }
}

class TvRuntimeHost extends StatefulWidget {
  const TvRuntimeHost({super.key, this.controller});

  final TvRuntimeController? controller;

  @override
  State<TvRuntimeHost> createState() => _TvRuntimeHostState();
}

class _TvRuntimeHostState extends State<TvRuntimeHost>
    with WidgetsBindingObserver {
  late final TvRuntimeController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? _createRuntimeController();
    _controller.addListener(_onChanged);
    unawaited(_controller.start());
  }

  TvRuntimeController _createRuntimeController() {
    final runtimeConfigurationAvailable = _supabaseReady && _clubId > 0;
    final gateway = runtimeConfigurationAvailable
        ? SupabaseTvRuntimeGateway(
            client: Supabase.instance.client,
            expectedClubId: _clubId.toString(),
          )
        : const _UnavailableTvRuntimeGateway();
    return TvRuntimeController(
      gateway: gateway,
      store: SecureTvCredentialStore(),
      configurationAvailable: runtimeConfigurationAvailable,
    );
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_controller.retry());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_onChanged);
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RayonSportsTvScreen(
      state: _controller.state,
      onRetry: () => unawaited(_controller.retry()),
      onNewPairingChallenge: () =>
          unawaited(_controller.renewPairingChallenge()),
    );
  }
}

class _UnavailableTvRuntimeGateway implements TvRuntimeGateway {
  const _UnavailableTvRuntimeGateway();

  @override
  Future<void> prepareDeviceIdentity() {
    throw const TvRuntimeFailure(TvRuntimeFailureKind.unavailable);
  }

  @override
  Future<TvBootstrapChallenge> createPairingChallenge({
    required String installationNonce,
  }) {
    throw const TvRuntimeFailure(TvRuntimeFailureKind.unavailable);
  }

  @override
  Future<TvCredentialExchange> exchangePairingChallenge({
    required String challenge,
    required String installationNonce,
  }) {
    throw const TvRuntimeFailure(TvRuntimeFailureKind.unavailable);
  }

  @override
  Future<TvRealtimeIdentity> bindRealtimeIdentity(String credential) {
    throw const TvRuntimeFailure(TvRuntimeFailureKind.unavailable);
  }

  @override
  Future<TvGameProjection> fetchProjection(String credential) {
    throw const TvRuntimeFailure(TvRuntimeFailureKind.unavailable);
  }

  @override
  Stream<TvRealtimeSignal> watchInvalidations({
    required String clubId,
    required String sessionId,
  }) {
    return Stream<TvRealtimeSignal>.error(
      const TvRuntimeFailure(TvRuntimeFailureKind.unavailable),
    );
  }
}

class TvRetryIntent extends Intent {
  const TvRetryIntent();
}

class TvBackIntent extends Intent {
  const TvBackIntent();
}

class TvContextMenuIntent extends Intent {
  const TvContextMenuIntent();
}

class TvRemoteControlScope extends StatelessWidget {
  const TvRemoteControlScope({
    super.key,
    required this.child,
    this.onRetry,
    this.onBack,
  });

  static const Map<ShortcutActivator, Intent> shortcuts =
      <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.arrowUp): DirectionalFocusIntent(
          TraversalDirection.up,
        ),
        SingleActivator(LogicalKeyboardKey.arrowDown): DirectionalFocusIntent(
          TraversalDirection.down,
        ),
        SingleActivator(LogicalKeyboardKey.arrowLeft): DirectionalFocusIntent(
          TraversalDirection.left,
        ),
        SingleActivator(LogicalKeyboardKey.arrowRight): DirectionalFocusIntent(
          TraversalDirection.right,
        ),
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.gameButtonA): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.escape): TvBackIntent(),
        SingleActivator(LogicalKeyboardKey.browserBack): TvBackIntent(),
        SingleActivator(LogicalKeyboardKey.goBack): TvBackIntent(),
        SingleActivator(LogicalKeyboardKey.gameButtonB): TvBackIntent(),
        SingleActivator(LogicalKeyboardKey.contextMenu): TvContextMenuIntent(),
        SingleActivator(LogicalKeyboardKey.keyR): TvRetryIntent(),
        SingleActivator(LogicalKeyboardKey.f5): TvRetryIntent(),
      };

  final Widget child;
  final VoidCallback? onRetry;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (remoteContext) => Shortcuts(
        shortcuts: shortcuts,
        child: Actions(
          actions: <Type, Action<Intent>>{
            DirectionalFocusIntent: CallbackAction<DirectionalFocusIntent>(
              onInvoke: (intent) {
                return FocusManager.instance.primaryFocus?.focusInDirection(
                      intent.direction,
                    ) ??
                    false;
              },
            ),
            TvRetryIntent: CallbackAction<TvRetryIntent>(
              onInvoke: (_) {
                onRetry?.call();
                return null;
              },
            ),
            TvBackIntent: CallbackAction<TvBackIntent>(
              onInvoke: (_) {
                if (onBack != null) {
                  onBack!.call();
                } else {
                  unawaited(Navigator.of(remoteContext).maybePop());
                }
                return null;
              },
            ),
            TvContextMenuIntent: CallbackAction<TvContextMenuIntent>(
              onInvoke: (_) {
                unawaited(_showTvContextMenu(remoteContext, onRetry: onRetry));
                return null;
              },
            ),
          },
          child: FocusTraversalGroup(
            policy: ReadingOrderTraversalPolicy(),
            child: child,
          ),
        ),
      ),
    );
  }
}

Future<void> _showTvContextMenu(
  BuildContext context, {
  VoidCallback? onRetry,
}) async {
  final l10n = context.afriL10n;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AfriAlertDialog(
      key: const ValueKey<String>('tv-remote-context-menu'),
      title: Text(l10n.tvRemoteMenuTitle),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Text(l10n.tvRemoteMenuDescription),
      ),
      actions: [
        if (onRetry != null)
          AfriTextButton(
            key: const ValueKey<String>('tv-remote-context-retry'),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              onRetry();
            },
            child: Text(l10n.tvRemoteMenuRetry),
          ),
        AfriButton(
          key: const ValueKey<String>('tv-remote-context-close'),
          autofocus: true,
          label: l10n.tvRemoteMenuClose,
          onTap: () => Navigator.of(dialogContext).pop(),
          fullWidth: false,
        ),
      ],
    ),
  );
}

class RayonSportsTvScreen extends StatelessWidget {
  const RayonSportsTvScreen({
    super.key,
    required this.state,
    this.onRetry,
    this.onNewPairingChallenge,
  });

  final TvRuntimeState state;
  final VoidCallback? onRetry;
  final VoidCallback? onNewPairingChallenge;

  @override
  Widget build(BuildContext context) {
    if (state.status == TvRuntimeStatus.awaitingOwner &&
        state.challenge != null) {
      return TvPairingChallengeScreen(
        challenge: state.challenge!,
        onNewPairingChallenge: onNewPairingChallenge ?? onRetry,
      );
    }
    if (state.projection != null && !state.projection!.isEmpty) {
      return _TvGameProjectionScreen(state: state, onRetry: onRetry);
    }
    if (state.status == TvRuntimeStatus.empty && state.projection != null) {
      return _TvEmptyDisplayScreen(state: state, onRetry: onRetry);
    }
    return _TvRuntimeStatusScreen(state: state, onRetry: onRetry);
  }
}

class TvPairingChallengeScreen extends StatelessWidget {
  const TvPairingChallengeScreen({
    super.key,
    required this.challenge,
    this.onNewPairingChallenge,
  });

  final TvBootstrapChallenge challenge;
  final VoidCallback? onNewPairingChallenge;

  @override
  Widget build(BuildContext context) {
    final l10n = context.afriL10n;
    return _TvFrame(
      statusLabel: l10n.tvPairingWaitingOwner,
      onRetry: onNewPairingChallenge,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: SpacingTokens.spacing8,
          vertical: SpacingTokens.spacing4,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040),
            child: AfriSurfaceCard(
              child: Padding(
                padding: const EdgeInsets.all(SpacingTokens.spacing8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Semantics(
                      label: l10n.tvPairingChallengeSemantic(
                        challenge.challenge,
                      ),
                      image: true,
                      child: Container(
                        padding: const EdgeInsets.all(SpacingTokens.spacing4),
                        decoration: BoxDecoration(
                          color: ColorTokens.machineCodeLight,
                          borderRadius: BorderRadius.circular(
                            ShapeTokens.radiusLg,
                          ),
                        ),
                        child: QrImageView(
                          key: const ValueKey<String>('tv-pairing-qr'),
                          data: challenge.qrPayload,
                          size: 228,
                          backgroundColor: ColorTokens.machineCodeLight,
                          eyeStyle: const QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: ColorTokens.machineCodeDark,
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: ColorTokens.machineCodeDark,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: SpacingTokens.spacing8),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.tvPairThisDisplay,
                            style: TypographyTokens.displaySmall().copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: SpacingTokens.spacing4),
                          Text(
                            l10n.tvPairingChallengeDescription,
                            style: TypographyTokens.titleLarge().copyWith(
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: SpacingTokens.spacing5),
                          Semantics(
                            label: l10n.tvPairingChallengeSemantic(
                              challenge.challenge,
                            ),
                            child: Text(
                              challenge.challenge,
                              key: const ValueKey<String>(
                                'tv-pairing-challenge',
                              ),
                              style: TypographyTokens.displayLarge().copyWith(
                                color: ColorTokens.clubAccent,
                                fontSize: 72,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 8,
                              ),
                            ),
                          ),
                          const SizedBox(height: SpacingTokens.spacing4),
                          Wrap(
                            spacing: SpacingTokens.spacing5,
                            runSpacing: SpacingTokens.spacing4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              _StatusPill(
                                label: l10n.tvPairingExpiresAt(
                                  _clockTime(challenge.expiresAt),
                                ),
                                icon: AfriIcons.timer,
                              ),
                              AfriButton(
                                key: const ValueKey<String>(
                                  'tv-new-pairing-code',
                                ),
                                autofocus: true,
                                label: l10n.tvCreateNewPairingCode,
                                onTap: onNewPairingChallenge ?? () {},
                                enabled: onNewPairingChallenge != null,
                                icon: AfriIcons.refresh,
                                fullWidth: false,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TvRuntimeStatusScreen extends StatelessWidget {
  const _TvRuntimeStatusScreen({required this.state, this.onRetry});

  final TvRuntimeState state;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.afriL10n;
    final (title, message, canRetry) = switch (state.status) {
      TvRuntimeStatus.configurationMissing => (
        l10n.tvPreparingDisplay,
        l10n.tvConfigurationMissing,
        false,
      ),
      TvRuntimeStatus.revoked => (
        l10n.tvPairThisDisplay,
        l10n.tvCredentialRevoked,
        true,
      ),
      TvRuntimeStatus.secureStorageFailure => (
        l10n.gameOperationsUnavailable,
        l10n.tvSecureStorageUnavailable,
        true,
      ),
      TvRuntimeStatus.securityTimeout => (
        l10n.tvSessionCheckTimedOut,
        l10n.tvSessionCheckTimedOutBody,
        true,
      ),
      TvRuntimeStatus.failure
          when state.failure?.kind == TvRuntimeFailureKind.challengeExpired =>
        (l10n.tvPairThisDisplay, l10n.tvPairingExpired, true),
      TvRuntimeStatus.failure => (
        l10n.gameOperationsUnavailable,
        l10n.tvPairingUnavailable,
        true,
      ),
      _ => (l10n.tvPreparingDisplay, l10n.tvPairingWaitingOwner, false),
    };
    return _TvFrame(
      statusLabel: title,
      onRetry: canRetry ? onRetry : null,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: AfriSurfaceCard(
            child: Padding(
              padding: const EdgeInsets.all(SpacingTokens.spacing10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    canRetry ? AfriIcons.statusError : AfriIcons.live,
                    size: 72,
                    color: ColorTokens.clubAccent,
                  ),
                  const SizedBox(height: SpacingTokens.spacing6),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TypographyTokens.displaySmall(),
                  ),
                  const SizedBox(height: SpacingTokens.spacing4),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TypographyTokens.titleLarge().copyWith(height: 1.3),
                  ),
                  if (canRetry) ...[
                    const SizedBox(height: SpacingTokens.spacing8),
                    AfriButton(
                      key: const ValueKey<String>('tv-runtime-retry'),
                      autofocus: true,
                      label: l10n.tvRetry,
                      onTap: onRetry ?? () {},
                      enabled: onRetry != null,
                      icon: AfriIcons.refresh,
                      fullWidth: false,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TvEmptyDisplayScreen extends StatelessWidget {
  const _TvEmptyDisplayScreen({required this.state, this.onRetry});

  final TvRuntimeState state;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.afriL10n;
    return _TvFrame(
      statusLabel: state.lastUpdated == null
          ? l10n.tvLiveSyncing
          : l10n.tvLiveUpdatedAt(_clockTime(state.lastUpdated!)),
      onRetry: onRetry,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: AfriSurfaceCard(
            child: Padding(
              padding: const EdgeInsets.all(SpacingTokens.spacing10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(AfriIcons.live, size: 72, color: ColorTokens.clubAccent),
                  const SizedBox(height: SpacingTokens.spacing6),
                  Text(
                    l10n.tvDisplayPairedNoGame,
                    textAlign: TextAlign.center,
                    style: TypographyTokens.displaySmall(),
                  ),
                  const SizedBox(height: SpacingTokens.spacing4),
                  Text(
                    l10n.tvDisplayPairedNoGameDescription,
                    textAlign: TextAlign.center,
                    style: TypographyTokens.titleLarge().copyWith(height: 1.3),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TvGameProjectionScreen extends StatelessWidget {
  const _TvGameProjectionScreen({required this.state, this.onRetry});

  final TvRuntimeState state;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final projection = state.projection!;
    final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.5;
    final statusLabel = switch (state.status) {
      TvRuntimeStatus.offline || TvRuntimeStatus.securityTimeout =>
        context.afriL10n.tvOfflineLastConfirmed,
      TvRuntimeStatus.syncing => context.afriL10n.tvLiveSyncing,
      _ =>
        state.lastUpdated == null
            ? context.afriL10n.tvLiveSyncing
            : context.afriL10n.tvLiveUpdatedAt(_clockTime(state.lastUpdated!)),
    };

    final content = largeText
        ? SingleChildScrollView(
            padding: const EdgeInsets.all(SpacingTokens.spacing10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _GameStagePanel(projection: projection, reflowed: true),
                const SizedBox(height: SpacingTokens.spacing8),
                _LeaderboardPanel(projection: projection, reflowed: true),
              ],
            ),
          )
        : Padding(
            padding: const EdgeInsets.all(SpacingTokens.spacing10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 3,
                  child: _GameStagePanel(projection: projection),
                ),
                const SizedBox(width: SpacingTokens.spacing8),
                Expanded(
                  flex: 2,
                  child: _LeaderboardPanel(projection: projection),
                ),
              ],
            ),
          );

    return _TvFrame(
      statusLabel: statusLabel,
      onRetry:
          state.status == TvRuntimeStatus.offline ||
              state.status == TvRuntimeStatus.securityTimeout
          ? onRetry
          : null,
      child: content,
    );
  }
}

class _GameStagePanel extends StatelessWidget {
  const _GameStagePanel({required this.projection, this.reflowed = false});

  final TvGameProjection projection;
  final bool reflowed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.afriL10n;
    final phase = projection.phase ?? 'scheduled';
    final question = projection.question;
    final phaseTitle = switch (phase) {
      'scheduled' => l10n.tvGameScheduledTitle,
      'activated_lobby' => l10n.tvGameLobbyTitle,
      'paused' => l10n.tvGamePausedTitle,
      'completed' => l10n.tvGameCompletedTitle,
      'cancelled' => l10n.tvGameCancelledTitle,
      'reveal' => l10n.gameRevealTitle,
      'question_open' =>
        question == null
            ? l10n.gameQuestionTitle
            : l10n.tvQuestionNumber(question.ordinal),
      _ => l10n.gameQuestionTitle,
    };

    return AfriSurfaceCard(
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(SpacingTokens.spacing8),
        child: Column(
          mainAxisSize: reflowed ? MainAxisSize.min : MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StatusPill(label: phaseTitle, icon: AfriIcons.timer),
            const SizedBox(height: SpacingTokens.spacing5),
            Text(
              projection.sessionTitle ?? l10n.gameLiveGamesTitle,
              style: TypographyTokens.displaySmall().copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing6),
            if (question != null) ...[
              Text(
                question.prompt,
                style: TypographyTokens.headlineMedium().copyWith(height: 1.2),
              ),
              const SizedBox(height: SpacingTokens.spacing6),
              Wrap(
                spacing: SpacingTokens.spacing4,
                runSpacing: SpacingTokens.spacing4,
                children: question.options
                    .map(
                      (option) => _QuestionOptionCard(
                        option: option,
                        revealed: phase == 'reveal' || phase == 'completed',
                        correct: question.correctOptionKey == option.key,
                      ),
                    )
                    .toList(growable: false),
              ),
            ] else ...[
              _PhaseMessage(phase: phase),
            ],
            if (projection.phaseDeadline != null &&
                phase == 'question_open') ...[
              const SizedBox(height: SpacingTokens.spacing6),
              _DeadlinePill(deadline: projection.phaseDeadline!),
            ],
          ],
        ),
      ),
    );
  }
}

class _PhaseMessage extends StatelessWidget {
  const _PhaseMessage({required this.phase});

  final String phase;

  @override
  Widget build(BuildContext context) {
    final l10n = context.afriL10n;
    final message = switch (phase) {
      'scheduled' => l10n.gameScheduledDescription,
      'activated_lobby' => l10n.gameLobbyDescription,
      'paused' => l10n.gamePausedDescription,
      'completed' => l10n.gameCompletedDescription,
      'cancelled' => l10n.gameCancelledDescription,
      _ => l10n.gameNoCurrentQuestion,
    };
    return Text(
      message,
      style: TypographyTokens.titleLarge().copyWith(
        color: ColorTokens.onSurfaceVariant,
        height: 1.3,
      ),
    );
  }
}

class _QuestionOptionCard extends StatelessWidget {
  const _QuestionOptionCard({
    required this.option,
    required this.revealed,
    required this.correct,
  });

  final TvQuestionOption option;
  final bool revealed;
  final bool correct;

  @override
  Widget build(BuildContext context) {
    final highlight = revealed && correct;
    return Semantics(
      label: highlight
          ? context.afriL10n.tvCorrectAnswerSemantic(option.label)
          : option.label,
      child: Container(
        constraints: const BoxConstraints(minWidth: 220),
        padding: const EdgeInsets.all(SpacingTokens.spacing5),
        decoration: BoxDecoration(
          color: highlight
              ? ColorTokens.clubAccent.withValues(alpha: 0.18)
              : ColorTokens.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(ShapeTokens.radiusLg),
          border: Border.all(
            color: highlight
                ? ColorTokens.clubAccent
                : ColorTokens.outlineVariant,
            width: highlight ? 3 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              option.key.toUpperCase(),
              style: TypographyTokens.titleLarge().copyWith(
                color: ColorTokens.clubAccent,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: SpacingTokens.spacing4),
            Flexible(
              child: Text(option.label, style: TypographyTokens.titleLarge()),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeaderboardPanel extends StatelessWidget {
  const _LeaderboardPanel({required this.projection, this.reflowed = false});

  final TvGameProjection projection;
  final bool reflowed;

  @override
  Widget build(BuildContext context) {
    final entries = projection.leaderboard.take(8).toList(growable: false);
    return AfriSurfaceCard(
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(SpacingTokens.spacing8),
        child: Column(
          mainAxisSize: reflowed ? MainAxisSize.min : MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.afriL10n.gameLeaderboardTitle,
              style: TypographyTokens.displaySmall().copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing6),
            if (entries.isEmpty)
              Text(
                context.afriL10n.tvLeaderboardEmpty,
                style: TypographyTokens.titleLarge().copyWith(
                  color: ColorTokens.onSurfaceVariant,
                ),
              )
            else
              ...entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(
                    bottom: SpacingTokens.spacing3,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 54,
                        child: Text(
                          '${entry.rank}',
                          style: TypographyTokens.titleLarge().copyWith(
                            color: ColorTokens.clubAccent,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          entry.publicAlias,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TypographyTokens.titleLarge(),
                        ),
                      ),
                      const SizedBox(width: SpacingTokens.spacing3),
                      Text(
                        '${entry.score}',
                        style: TypographyTokens.titleLarge().copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DeadlinePill extends StatefulWidget {
  const _DeadlinePill({required this.deadline});

  final DateTime deadline;

  @override
  State<_DeadlinePill> createState() => _DeadlinePillState();
}

class _DeadlinePillState extends State<_DeadlinePill> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.deadline.difference(DateTime.now().toUtc());
    final seconds = remaining.isNegative ? 0 : remaining.inSeconds;
    return _StatusPill(
      label: context.afriL10n.tvSecondsRemaining(seconds),
      icon: AfriIcons.timer,
    );
  }
}

class _TvFrame extends StatelessWidget {
  const _TvFrame({
    required this.statusLabel,
    required this.child,
    this.onRetry,
  });

  final String statusLabel;
  final Widget child;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.5;
    return TvRemoteControlScope(
      onRetry: onRetry,
      child: AfriScreenScaffold(
        backgroundColor: ColorTokens.background,
        showAppBar: false,
        showBackButton: false,
        scrollable: false,
        constrainContent: false,
        bodyWrapper: (child) => GradientBackground(child: child),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  SpacingTokens.spacing10,
                  SpacingTokens.spacing8,
                  SpacingTokens.spacing10,
                  0,
                ),
                child: Row(
                  children: [
                    AfriBrandMark(
                      label: _rayonConfig.clubName,
                      size: 84,
                      semanticLabel: context.afriL10n.tvBrandMarkSemantic(
                        _rayonConfig.clubName,
                      ),
                    ),
                    const SizedBox(width: SpacingTokens.spacing5),
                    Expanded(
                      child: Text(
                        context.afriL10n.tvAppTitle(_rayonConfig.appName),
                        maxLines: largeText ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                        style: TypographyTokens.displaySmall().copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: largeText ? 480 : double.infinity,
                      ),
                      child: _StatusPill(
                        label: statusLabel,
                        icon: AfriIcons.live,
                      ),
                    ),
                    if (onRetry != null) ...[
                      const SizedBox(width: SpacingTokens.spacing4),
                      AfriButton(
                        key: const ValueKey<String>('tv-header-retry'),
                        label: context.afriL10n.tvRetry,
                        onTap: onRetry!,
                        icon: AfriIcons.refresh,
                        fullWidth: false,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: SpacingTokens.spacing4),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.spacing4,
        vertical: SpacingTokens.spacing3,
      ),
      decoration: BoxDecoration(
        color: ColorTokens.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(ShapeTokens.radiusFull),
        border: Border.all(color: ColorTokens.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: ColorTokens.clubAccent),
          const SizedBox(width: SpacingTokens.spacing2),
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TypographyTokens.labelLarge(),
            ),
          ),
        ],
      ),
    );
  }
}

String _clockTime(DateTime value) {
  final local = value.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}
