import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';

/// Fanzone settings section — odds format and notification toggles.
///
/// Mirrors the fanafrika `Settings.tsx` PREFERENCES + NOTIFICATIONS sections.
/// Drop-in widget to embed in the app's existing settings screen.
///
/// Persists all values via HiveCacheService with 365-day TTL.
class FanzoneSettingsSection extends StatefulWidget {
  const FanzoneSettingsSection({super.key});

  @override
  State<FanzoneSettingsSection> createState() => _FanzoneSettingsSectionState();
}

class _FanzoneSettingsSectionState extends State<FanzoneSettingsSection> {
  static const _oddsFormatKey = 'fanzone_pref:odds_format';
  static const _kickoffAlertsKey = 'fanzone_pref:kickoff_alerts';
  static const _settlementAlertsKey = 'fanzone_pref:settlement_alerts';
  static const _challengeAlertsKey = 'fanzone_pref:challenge_alerts';
  static const _persistTtl = Duration(days: 365);

  late String _oddsFormat;
  late bool _kickoffAlerts;
  late bool _settlementAlerts;
  late bool _challengeAlerts;

  static const _oddsFormatOptions = <String>[
    'Decimal (1.85)',
    'Fractional (17/20)',
    'American (-118)',
  ];

  @override
  void initState() {
    super.initState();
    // Restore persisted values.
    _oddsFormat = HiveCacheService.getJson<String>(_oddsFormatKey) ??
        'Decimal (1.85)';
    _kickoffAlerts =
        HiveCacheService.getJson<bool>(_kickoffAlertsKey) ?? true;
    _settlementAlerts =
        HiveCacheService.getJson<bool>(_settlementAlertsKey) ?? true;
    _challengeAlerts =
        HiveCacheService.getJson<bool>(_challengeAlertsKey) ?? false;
  }

  void _setOddsFormat(String value) {
    setState(() => _oddsFormat = value);
    HiveCacheService.putJson(_oddsFormatKey, value, ttl: _persistTtl);
  }

  void _setKickoffAlerts(bool value) {
    setState(() => _kickoffAlerts = value);
    HiveCacheService.putJson(_kickoffAlertsKey, value, ttl: _persistTtl);
  }

  void _setSettlementAlerts(bool value) {
    setState(() => _settlementAlerts = value);
    HiveCacheService.putJson(_settlementAlertsKey, value, ttl: _persistTtl);
  }

  void _setChallengeAlerts(bool value) {
    setState(() => _challengeAlerts = value);
    HiveCacheService.putJson(_challengeAlertsKey, value, ttl: _persistTtl);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Preferences Section ──
        Text(
          'PREFERENCES',
          style: TypographyTokens.editorialFont(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: ColorTokens.onSurfaceVariant,
            letterSpacing: 1.6,
          ),
        ),
        const SizedBox(height: SpacingTokens.spacing3),
        ClayCard(
          child: Column(
            children: [
              // Odds format dropdown
              Row(
                children: [
                  Icon(
                    AfriIcons.language,
                    size: 20,
                    color: ColorTokens.onSurfaceVariant,
                  ),
                  const SizedBox(width: SpacingTokens.spacing3),
                  Expanded(
                    child: Text(
                      'Odds Format',
                      style: TypographyTokens.titleSmall(),
                    ),
                  ),
                  DropdownButton<String>(
                    value: _oddsFormat,
                    items: _oddsFormatOptions
                        .map((format) => DropdownMenuItem<String>(
                              value: format,
                              child: Text(
                                format,
                                style: TypographyTokens.bodySmall(),
                              ),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        _setOddsFormat(value);
                      }
                    },
                    underline: const SizedBox.shrink(),
                    dropdownColor: ColorTokens.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12),
                    icon: Icon(
                      AfriIcons.chevronDown,
                      color: ColorTokens.onSurfaceVariant,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: SpacingTokens.spacing5),

        // ── Notifications Section ──
        Text(
          'NOTIFICATIONS',
          style: TypographyTokens.editorialFont(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: ColorTokens.onSurfaceVariant,
            letterSpacing: 1.6,
          ),
        ),
        const SizedBox(height: SpacingTokens.spacing3),
        ClayCard(
          child: Column(
            children: [
              _ToggleRow(
                icon: AfriIcons.notificationsActive,
                title: 'Match Kick-off Alerts',
                value: _kickoffAlerts,
                onChanged: _setKickoffAlerts,
              ),
              Divider(height: 1, color: ColorTokens.ghostBorder),
              _ToggleRow(
                icon: AfriIcons.checkGroup,
                title: 'Prediction Settlement',
                value: _settlementAlerts,
                onChanged: _setSettlementAlerts,
              ),
              Divider(height: 1, color: ColorTokens.ghostBorder),
              _ToggleRow(
                icon: AfriIcons.predict,
                title: 'Friend Challenges',
                value: _challengeAlerts,
                onChanged: _setChallengeAlerts,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SpacingTokens.spacing1),
      child: Row(
        children: [
          Icon(icon, size: 20, color: ColorTokens.onSurfaceVariant),
          const SizedBox(width: SpacingTokens.spacing3),
          Expanded(
            child: Text(title, style: TypographyTokens.titleSmall()),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: ColorTokens.clubAccent,
          ),
        ],
      ),
    );
  }
}
