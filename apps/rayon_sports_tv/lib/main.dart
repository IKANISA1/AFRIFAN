import 'dart:async';

import 'package:club_rayon_sports/club_rayon_sports.dart';
import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _rayonConfig = RayonSportsConfig();
const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
const _clubId = int.fromEnvironment('CLUB_ID');
const _homeVenueName = String.fromEnvironment(
  'HOME_VENUE_NAME',
  defaultValue: 'Home Stadium',
);
const _credentialStorageKey = 'africlub_tv_device_credential_v1';
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

class TvDisplayState {
  const TvDisplayState({
    required this.venueName,
    required this.sessionCode,
    required this.expiresAt,
    required this.fetReward,
    required this.prompt,
    required this.phase,
  });

  final String venueName;
  final String sessionCode;
  final String expiresAt;
  final int fetReward;
  final String prompt;
  final String phase;

  String expiryLabel([DateTime? now]) {
    final parsed = DateTime.tryParse(expiresAt);
    if (parsed == null) return expiresAt;
    final remaining = parsed.difference(now ?? DateTime.now());
    if (remaining <= Duration.zero) return 'expired';
    if (remaining.inMinutes < 1) return 'in <1 min';
    if (remaining.inHours < 1) return 'in ${remaining.inMinutes} min';
    return 'in ${remaining.inHours}h ${remaining.inMinutes.remainder(60)}m';
  }

  static const unpaired = TvDisplayState(
    venueName: 'Unpaired TV display',
    sessionCode: 'PAIR TV',
    expiresAt: '--',
    fetReward: 0,
    prompt: 'Pair this TV display from the admin panel.',
    phase: 'Offline',
  );

  factory TvDisplayState.fromRpcPayload(Object? payload) {
    if (payload is! Map) {
      return TvDisplayState.unpaired;
    }
    final data = Map<String, dynamic>.from(payload);
    return TvDisplayState(
      venueName: _stringValue(data['venue_name'], 'Unpaired TV display'),
      sessionCode: _stringValue(data['session_code'], 'PAIR TV'),
      expiresAt: _stringValue(data['expires_at'], '--'),
      fetReward: _intValue(data['fet_reward']),
      prompt: _stringValue(
        data['prompt'],
        'Pair this TV display from the admin panel.',
      ),
      phase: _stringValue(data['phase'], 'Offline'),
    );
  }
}

class RayonSportsTvApp extends StatelessWidget {
  const RayonSportsTvApp({super.key, this.state});

  final TvDisplayState? state;

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
      title: '${_rayonConfig.appName} TV',
      theme: ClubTheme.from(_rayonConfig),
      locale: const Locale('en'),
      supportedLocales: const <Locale>[Locale('en')],
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
      home: state == null
          ? const _TvDisplayStateLoader()
          : RayonSportsTvScreen(state: state!),
    );
  }
}

class _TvDisplayStateLoader extends StatefulWidget {
  const _TvDisplayStateLoader();

  @override
  State<_TvDisplayStateLoader> createState() => _TvDisplayStateLoaderState();
}

class _TvDisplayStateLoaderState extends State<_TvDisplayStateLoader> {
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  Timer? _refreshTimer;
  String? _credential;
  TvDisplayState _displayState = TvDisplayState.unpaired;
  TvConnectionState _connectionState = TvConnectionState.connecting;
  DateTime? _lastUpdated;
  int _failureCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(_lifecycleObserver);
    unawaited(_restoreAndRefresh());
  }

  late final _TvLifecycleObserver _lifecycleObserver = _TvLifecycleObserver(
    onResume: () => unawaited(_refresh()),
  );

  @override
  void dispose() {
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
    super.dispose();
  }

  Future<void> _restoreAndRefresh() async {
    if (!_supabaseReady) {
      if (mounted) {
        setState(
          () => _connectionState = TvConnectionState.configurationMissing,
        );
      }
      return;
    }
    try {
      _credential = await _storage.read(key: _credentialStorageKey);
    } catch (_) {
      _recordTvEvent('credential_storage_unavailable');
      if (mounted) {
        setState(() => _connectionState = TvConnectionState.serviceUnavailable);
      }
      return;
    }
    if ((_credential ?? '').isEmpty) {
      if (mounted) {
        setState(() => _connectionState = TvConnectionState.unpaired);
      }
      return;
    }
    await _refresh();
  }

  Future<void> _refresh() async {
    final credential = _credential;
    if (!_supabaseReady || credential == null || credential.isEmpty) return;
    _refreshTimer?.cancel();
    if (mounted) {
      setState(() => _connectionState = TvConnectionState.connecting);
    }
    try {
      final response = await Supabase.instance.client.rpc(
        'get_tv_display_state_with_credential',
        params: <String, dynamic>{'p_device_token': credential},
      );
      final payload = response is Map
          ? Map<String, dynamic>.from(response)
          : <String, dynamic>{};
      final code = payload['code']?.toString();
      if (code == 'credential_revoked_or_invalid' ||
          code == 'credential_invalid') {
        _recordTvEvent('credential_rejected');
        await _storage.delete(key: _credentialStorageKey);
        _credential = null;
        if (mounted) {
          setState(() {
            _displayState = TvDisplayState.unpaired;
            _connectionState = TvConnectionState.revoked;
          });
        }
        return;
      }
      _failureCount = 0;
      _recordTvEvent('refresh_success');
      if (mounted) {
        setState(() {
          _displayState = TvDisplayState.fromRpcPayload(payload);
          _connectionState = TvConnectionState.connected;
          _lastUpdated = DateTime.now();
        });
      }
      _scheduleRefresh(const Duration(seconds: 20));
    } catch (_) {
      _failureCount += 1;
      _recordTvEvent('refresh_failed', retryAttempt: _failureCount);
      if (mounted) {
        setState(() => _connectionState = TvConnectionState.serviceUnavailable);
      }
      final seconds = (5 * (1 << (_failureCount - 1).clamp(0, 4))).clamp(5, 80);
      _scheduleRefresh(Duration(seconds: seconds));
    }
  }

  void _scheduleRefresh(Duration delay) {
    _refreshTimer?.cancel();
    _refreshTimer = Timer(delay, () => unawaited(_refresh()));
  }

  Future<String?> _pair(String code) async {
    if (!_supabaseReady) return 'Backend configuration is missing.';
    final pairingUnavailable = context.afriL10n.tvPairingUnavailable;
    try {
      final response = await Supabase.instance.client.rpc(
        'exchange_tv_pairing_code',
        params: <String, dynamic>{
          'p_pairing_code': code.trim().toUpperCase(),
          'p_club_id': _clubId == 0 ? null : _clubId,
        },
      );
      final payload = response is Map
          ? Map<String, dynamic>.from(response)
          : <String, dynamic>{};
      final token = payload['device_token']?.toString() ?? '';
      if (payload['code'] != 'paired' || token.length != 64) {
        return 'That pairing code is invalid or expired.';
      }
      await _storage.write(key: _credentialStorageKey, value: token);
      _credential = token;
      _recordTvEvent('pairing_success');
      await _refresh();
      return null;
    } catch (_) {
      _recordTvEvent('pairing_failed');
      return pairingUnavailable;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_connectionState == TvConnectionState.unpaired ||
        _connectionState == TvConnectionState.revoked ||
        _connectionState == TvConnectionState.configurationMissing) {
      return TvPairingScreen(state: _connectionState, onPair: _pair);
    }
    return RayonSportsTvScreen(
      state: _displayState,
      connectionState: _connectionState,
      lastUpdated: _lastUpdated,
      onRetry: _restoreAndRefresh,
    );
  }
}

enum TvConnectionState {
  connecting,
  connected,
  serviceUnavailable,
  unpaired,
  revoked,
  configurationMissing,
}

class _TvLifecycleObserver with WidgetsBindingObserver {
  _TvLifecycleObserver({required this.onResume});
  final VoidCallback onResume;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) onResume();
  }
}

String _stringValue(Object? value, String fallback) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

int _intValue(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

class TvRetryIntent extends Intent {
  const TvRetryIntent();
}

class TvSubmitPairingIntent extends Intent {
  const TvSubmitPairingIntent();
}

class TvBackIntent extends Intent {
  const TvBackIntent();
}

/// Explicit remote-control contract shared by every native TV state.
class TvRemoteControlScope extends StatelessWidget {
  const TvRemoteControlScope({
    super.key,
    required this.child,
    this.onRetry,
    this.onSubmit,
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
        SingleActivator(LogicalKeyboardKey.contextMenu): TvBackIntent(),
        SingleActivator(LogicalKeyboardKey.keyR): TvRetryIntent(),
        SingleActivator(LogicalKeyboardKey.f5): TvRetryIntent(),
        SingleActivator(LogicalKeyboardKey.navigateIn): TvSubmitPairingIntent(),
        SingleActivator(LogicalKeyboardKey.gameButtonX):
            TvSubmitPairingIntent(),
      };

  final Widget child;
  final VoidCallback? onRetry;
  final VoidCallback? onSubmit;
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
            TvSubmitPairingIntent: CallbackAction<TvSubmitPairingIntent>(
              onInvoke: (_) {
                onSubmit?.call();
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

class RayonSportsTvScreen extends StatelessWidget {
  const RayonSportsTvScreen({
    super.key,
    required this.state,
    this.connectionState = TvConnectionState.connected,
    this.lastUpdated,
    this.onRetry,
  });

  final TvDisplayState state;
  final TvConnectionState connectionState;
  final DateTime? lastUpdated;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
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
          child: Padding(
            padding: const EdgeInsets.all(SpacingTokens.spacing10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TvHeader(
                  venueName: state.venueName,
                  connectionState: connectionState,
                  lastUpdated: lastUpdated,
                  onRetry: onRetry,
                ),
                const SizedBox(height: SpacingTokens.spacing12),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 3, child: _SessionPanel(state: state)),
                      const SizedBox(width: SpacingTokens.spacing10),
                      Expanded(flex: 2, child: _SafetyPanel(state: state)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TvHeader extends StatelessWidget {
  const _TvHeader({
    required this.venueName,
    required this.connectionState,
    this.lastUpdated,
    this.onRetry,
  });

  final String venueName;
  final TvConnectionState connectionState;
  final DateTime? lastUpdated;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AfriBrandMark(
          label: _rayonConfig.clubName,
          size: 96,
          semanticLabel: '${_rayonConfig.clubName} generated TV brand mark',
        ),
        const SizedBox(width: SpacingTokens.spacing6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_rayonConfig.appName} TV',
                style: TypographyTokens.displaySmall().copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: SpacingTokens.spacing2),
              Text(
                venueName,
                style: TypographyTokens.titleLarge().copyWith(
                  color: ColorTokens.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (connectionState == TvConnectionState.serviceUnavailable)
          AfriButton(
            key: const ValueKey<String>('tv-retry-button'),
            autofocus: true,
            label: context.afriL10n.tvConnectionLostRetry,
            onTap: onRetry ?? () {},
            enabled: onRetry != null,
            icon: AfriIcons.refresh,
            fullWidth: false,
          )
        else
          _StatusPill(
            label: lastUpdated == null
                ? 'Connecting'
                : 'Live · updated ${_clockTime(lastUpdated!)}',
            icon: AfriIcons.live,
          ),
      ],
    );
  }
}

class TvPairingScreen extends StatefulWidget {
  const TvPairingScreen({super.key, required this.state, required this.onPair});

  final TvConnectionState state;
  final Future<String?> Function(String code) onPair;

  @override
  State<TvPairingScreen> createState() => _TvPairingScreenState();
}

class _TvPairingScreenState extends State<TvPairingScreen> {
  final _controller = TextEditingController();
  final _submitFocusNode = FocusNode(debugLabel: 'TV pair display');
  late final _codeFocusNode = FocusNode(
    debugLabel: 'TV pairing code',
    onKeyEvent: _handleCodeKeyEvent,
  );
  bool _submitting = false;
  String? _error;

  KeyEventResult _handleCodeKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _submitFocusNode.requestFocus();
      return KeyEventResult.handled;
    }
    if (event is KeyDownEvent &&
        <LogicalKeyboardKey>{
          LogicalKeyboardKey.escape,
          LogicalKeyboardKey.browserBack,
          LogicalKeyboardKey.goBack,
          LogicalKeyboardKey.gameButtonB,
          LogicalKeyboardKey.contextMenu,
        }.contains(event.logicalKey)) {
      _handleBack();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    _controller.dispose();
    _codeFocusNode.dispose();
    _submitFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_controller.text.trim().length < 6 || _submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final error = await widget.onPair(_controller.text);
    if (mounted) {
      setState(() {
        _submitting = false;
        _error = error;
      });
      if (error != null) {
        _controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _controller.text.length,
        );
        _codeFocusNode.requestFocus();
      }
    }
  }

  void _handleBack() {
    if (_controller.text.isEmpty && _error == null) return;
    setState(() {
      _controller.clear();
      _error = null;
    });
    _codeFocusNode.requestFocus();
  }

  void _handleSystemBack(bool didPop, Object? result) {
    if (didPop) return;
    _handleBack();
  }

  @override
  Widget build(BuildContext context) {
    final configurationMissing =
        widget.state == TvConnectionState.configurationMissing;
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: _handleSystemBack,
      child: TvRemoteControlScope(
        onSubmit: _submit,
        onBack: _handleBack,
        child: AfriScreenScaffold(
          backgroundColor: ColorTokens.background,
          showAppBar: false,
          showBackButton: false,
          scrollable: false,
          constrainContent: false,
          bodyWrapper: (child) => GradientBackground(child: child),
          child: SafeArea(
            child: Center(
              child: SizedBox(
                width: 720,
                child: AfriSurfaceCard(
                  child: Padding(
                    padding: const EdgeInsets.all(SpacingTokens.spacing8),
                    child: FocusTraversalGroup(
                      policy: OrderedTraversalPolicy(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Pair this TV',
                            style: TypographyTokens.displaySmall(),
                          ),
                          const SizedBox(height: SpacingTokens.spacing4),
                          Text(
                            configurationMissing
                                ? context.afriL10n.tvConfigurationMissing
                                : widget.state == TvConnectionState.revoked
                                ? context.afriL10n.tvCredentialRevoked
                                : context.afriL10n.tvEnterAdminCode,
                            style: TypographyTokens.titleLarge(),
                          ),
                          if (!configurationMissing) ...[
                            const SizedBox(height: SpacingTokens.spacing6),
                            FocusTraversalOrder(
                              order: const NumericFocusOrder(1),
                              child: AfriInputField(
                                key: const ValueKey<String>(
                                  'tv-pairing-code-input',
                                ),
                                controller: _controller,
                                focusNode: _codeFocusNode,
                                enabled: !_submitting,
                                autofocus: true,
                                textCapitalization:
                                    TextCapitalization.characters,
                                textInputAction: TextInputAction.done,
                                maxLength: 12,
                                onSubmitted: (_) => _submit(),
                                label: 'One-time pairing code',
                                helperText: '6–12 characters',
                                errorText: _error,
                                autofillHints: const <String>[],
                                enableSuggestions: false,
                                autocorrect: false,
                              ),
                            ),
                            const SizedBox(height: SpacingTokens.spacing4),
                            FocusTraversalOrder(
                              order: const NumericFocusOrder(2),
                              child: AfriButton(
                                key: const ValueKey<String>(
                                  'tv-pairing-submit-button',
                                ),
                                label: _submitting
                                    ? 'Pairing…'
                                    : 'Pair display',
                                onTap: _submit,
                                focusNode: _submitFocusNode,
                                enabled: !_submitting,
                                isLoading: _submitting,
                                icon: AfriIcons.link,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _clockTime(DateTime value) {
  final local = value.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

void _recordTvEvent(String name, {int? retryAttempt}) {
  // Screen-safe operational telemetry only: never include pairing codes,
  // credentials, device identifiers, venue names, or supporter data.
  debugPrint(
    '[TV_EVENT] name=$name${retryAttempt == null ? '' : ' retry_attempt=$retryAttempt'}',
  );
}

class _SessionPanel extends StatelessWidget {
  const _SessionPanel({required this.state});

  final TvDisplayState state;

  @override
  Widget build(BuildContext context) {
    return AfriSurfaceCard(
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(SpacingTokens.spacing8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StatusPill(label: state.phase, icon: AfriIcons.timer),
            const Spacer(),
            Text(
              'Enter this code in Fan Zone',
              style: TypographyTokens.headlineSmall().copyWith(
                color: ColorTokens.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing4),
            Semantics(
              label: 'TV session code ${state.sessionCode}',
              child: Text(
                state.sessionCode,
                style: TypographyTokens.displayLarge().copyWith(
                  color: ColorTokens.clubAccent,
                  fontSize: 86,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                  height: 1,
                ),
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing6),
            Text(
              state.prompt,
              style: TypographyTokens.headlineSmall().copyWith(height: 1.18),
            ),
            const Spacer(),
            Wrap(
              spacing: SpacingTokens.spacing4,
              runSpacing: SpacingTokens.spacing3,
              children: [
                _MetricChip(
                  icon: AfriIcons.fetToken,
                  label: '${state.fetReward} FET reward',
                ),
                _MetricChip(
                  icon: AfriIcons.statusPending,
                  label: 'Expires ${state.expiryLabel()}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SafetyPanel extends StatelessWidget {
  const _SafetyPanel({required this.state});

  final TvDisplayState state;

  @override
  Widget build(BuildContext context) {
    return AfriSurfaceCard(
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(SpacingTokens.spacing8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              AfriIcons.shield,
              size: SpacingTokens.spacing12,
              color: ColorTokens.clubAccent,
            ),
            const SizedBox(height: SpacingTokens.spacing6),
            Text(
              'Venue session details',
              style: TypographyTokens.displaySmall().copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing4),
            Text(
              context.afriL10n.tvJoinFromFanZone,
              style: TypographyTokens.titleLarge().copyWith(
                color: ColorTokens.onSurfaceVariant,
                height: 1.25,
              ),
            ),
            const Spacer(),
            _SafetyRow(icon: AfriIcons.lock, label: 'Venue session only'),
            const SizedBox(height: SpacingTokens.spacing4),
            _SafetyRow(
              icon: AfriIcons.visibilityOff,
              label: 'No supporter details shown',
            ),
            const SizedBox(height: SpacingTokens.spacing4),
            _SafetyRow(
              icon: AfriIcons.statusSuccess,
              label: 'Pairing status and expiry',
            ),
          ],
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ColorTokens.surfaceContainerHigh,
        borderRadius: ShapeTokens.chipRadius,
        border: BorderTokens.all(color: ColorTokens.chromeBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: SpacingTokens.spacing4,
          vertical: SpacingTokens.spacing3,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: ColorTokens.clubAccent,
              size: AfriIcons.sizeInline,
            ),
            const SizedBox(width: SpacingTokens.spacing2),
            Text(label, style: TypographyTokens.labelLarge()),
          ],
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return _StatusPill(label: label, icon: icon);
  }
}

class _SafetyRow extends StatelessWidget {
  const _SafetyRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: ColorTokens.clubAccent, size: AfriIcons.sizeNav),
        const SizedBox(width: SpacingTokens.spacing3),
        Expanded(child: Text(label, style: TypographyTokens.titleLarge())),
      ],
    );
  }
}
