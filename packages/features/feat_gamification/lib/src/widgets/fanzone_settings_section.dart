import 'dart:async';

import 'package:core_l10n/core_l10n.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';

/// Fanzone settings section for notification toggles.
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
  static const _kickoffAlertsKey = 'fanzone_pref:kickoff_alerts';
  static const _settlementAlertsKey = 'fanzone_pref:settlement_alerts';
  static const _challengeAlertsKey = 'fanzone_pref:challenge_alerts';
  static const _persistTtl = Duration(days: 365);

  late bool _kickoffAlerts;
  late bool _settlementAlerts;
  late bool _challengeAlerts;

  @override
  void initState() {
    super.initState();
    // Restore persisted values.
    _kickoffAlerts = HiveCacheService.getJson<bool>(_kickoffAlertsKey) ?? true;
    _settlementAlerts =
        HiveCacheService.getJson<bool>(_settlementAlertsKey) ?? true;
    _challengeAlerts =
        HiveCacheService.getJson<bool>(_challengeAlertsKey) ?? false;
  }

  void _setKickoffAlerts(bool value) {
    setState(() => _kickoffAlerts = value);
    unawaited(
      HiveCacheService.putJson(_kickoffAlertsKey, value, ttl: _persistTtl),
    );
  }

  void _setSettlementAlerts(bool value) {
    setState(() => _settlementAlerts = value);
    unawaited(
      HiveCacheService.putJson(_settlementAlertsKey, value, ttl: _persistTtl),
    );
  }

  void _setChallengeAlerts(bool value) {
    setState(() => _challengeAlerts = value);
    unawaited(
      HiveCacheService.putJson(_challengeAlertsKey, value, ttl: _persistTtl),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Notifications Section ──
        Text(
          context.afriL10n.gameNotificationsUpper,
          style: TypographyTokens.labelSmall(
            ColorTokens.onSurfaceVariant,
          ).copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: SpacingTokens.spacing3),
        AfriSurfaceCard(
          child: Column(
            children: [
              _ToggleRow(
                icon: AfriIcons.notificationsActive,
                title: context.afriL10n.gameKickoffAlerts,
                value: _kickoffAlerts,
                onChanged: _setKickoffAlerts,
              ),
              const AfriDivider(),
              _ToggleRow(
                icon: AfriIcons.checkGroup,
                title: context.afriL10n.gameRoundResults,
                value: _settlementAlerts,
                onChanged: _setSettlementAlerts,
              ),
              const AfriDivider(),
              _ToggleRow(
                icon: AfriIcons.predict,
                title: context.afriL10n.gameFriendChallenges,
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
          Icon(
            icon,
            size: SpacingTokens.spacing5,
            color: ColorTokens.onSurfaceVariant,
          ),
          const SizedBox(width: SpacingTokens.spacing3),
          Expanded(child: Text(title, style: TypographyTokens.titleSmall())),
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
