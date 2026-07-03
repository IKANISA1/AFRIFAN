import 'package:club_rayon_sports/club_rayon_sports.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';

const _rayonConfig = RayonSportsConfig();

void main() {
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
}

class RayonSportsTvApp extends StatelessWidget {
  const RayonSportsTvApp({
    super.key,
    this.state = const TvDisplayState(
      venueName: 'Kigali Arena',
      sessionCode: 'RAYON-42',
      expiresAt: '21:45',
      fetReward: 25,
      prompt: 'Join the matchday challenge from the supporter app.',
      phase: 'Waiting for supporters',
    ),
  });

  final TvDisplayState state;

  @override
  Widget build(BuildContext context) {
    ColorTokens.init(_rayonConfig.colors);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Gikundiro TV',
      theme: ClubTheme.from(_rayonConfig),
      home: RayonSportsTvScreen(state: state),
    );
  }
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
