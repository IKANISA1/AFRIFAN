import 'package:club_rayon_sports/club_rayon_sports.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _rayonConfig = RayonSportsConfig();
const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
const _tvDeviceId = String.fromEnvironment('TV_DEVICE_ID');
const _tvPairingCode = String.fromEnvironment('TV_PAIRING_CODE');
const _clubId = int.fromEnvironment('CLUB_ID');
var _supabaseReady = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ColorTokens.init(_rayonConfig.colors);
  RuntimeBranding.configure(
    appName: 'Gikundiro TV',
    clubName: _rayonConfig.clubName,
    countryCode: _rayonConfig.countryCode,
    currencyCode: _rayonConfig.currency,
    currencySymbol: _rayonConfig.currencySymbol,
    homeVenueName: 'Kigali Pele Stadium',
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

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Gikundiro TV',
      theme: ClubTheme.from(_rayonConfig),
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
  late final Future<TvDisplayState> _stateFuture = _loadTvDisplayState();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TvDisplayState>(
      future: _stateFuture,
      builder: (context, snapshot) {
        return RayonSportsTvScreen(
          state: snapshot.data ?? TvDisplayState.unpaired,
        );
      },
    );
  }
}

Future<TvDisplayState> _loadTvDisplayState() async {
  if (!_supabaseReady) {
    return TvDisplayState.unpaired;
  }

  try {
    final response = await Supabase.instance.client.rpc(
      'get_tv_display_state',
      params: <String, dynamic>{
        'p_device_id': _tvDeviceId.trim().isEmpty ? null : _tvDeviceId.trim(),
        'p_pairing_code': _tvPairingCode.trim().isEmpty
            ? null
            : _tvPairingCode.trim(),
        'p_club_id': _clubId == 0 ? null : _clubId,
      },
    );
    return TvDisplayState.fromRpcPayload(response);
  } catch (_) {
    return TvDisplayState.unpaired;
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

class RayonSportsTvScreen extends StatelessWidget {
  const RayonSportsTvScreen({super.key, required this.state});

  final TvDisplayState state;

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      policy: ReadingOrderTraversalPolicy(),
      child: Scaffold(
        backgroundColor: ColorTokens.background,
        body: GradientBackground(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(SpacingTokens.spacing10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TvHeader(venueName: state.venueName),
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
      ),
    );
  }
}

class _TvHeader extends StatelessWidget {
  const _TvHeader({required this.venueName});

  final String venueName;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const AfriBrandMark(
          label: 'Rayon Sports',
          size: 96,
          semanticLabel: 'Rayon Sports generated TV brand mark',
        ),
        const SizedBox(width: SpacingTokens.spacing6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Gikundiro TV',
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
        _StatusPill(label: 'Read-only display', icon: AfriIcons.live),
      ],
    );
  }
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
                  label: 'Expires ${state.expiresAt}',
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
              'Screen-safe state',
              style: TypographyTokens.displaySmall().copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing4),
            Text(
              'This native TV app shows venue code, expiry, challenge phase, and reward only.',
              style: TypographyTokens.titleLarge().copyWith(
                color: ColorTokens.onSurfaceVariant,
                height: 1.25,
              ),
            ),
            const Spacer(),
            _SafetyRow(icon: AfriIcons.lock, label: 'No personal identity'),
            const SizedBox(height: SpacingTokens.spacing4),
            _SafetyRow(
              icon: AfriIcons.visibilityOff,
              label: 'No private balances',
            ),
            const SizedBox(height: SpacingTokens.spacing4),
            _SafetyRow(
              icon: AfriIcons.statusSuccess,
              label: 'Remote-control friendly focus',
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
