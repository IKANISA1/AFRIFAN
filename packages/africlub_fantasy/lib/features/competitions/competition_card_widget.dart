import 'package:africlub_fantasy/core/constants.dart';
import 'package:africlub_fantasy/core/extensions.dart';
import 'package:africlub_fantasy/models/competition.dart';
import 'package:africlub_fantasy/models/fantasy_entry.dart';
import 'package:africlub_fantasy/models/gameweek.dart';
import 'package:africlub_fantasy/providers/realtime_providers.dart';
import 'package:africlub_fantasy/features/shared/fantasy_ui.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CompetitionCardWidget extends ConsumerWidget {
  const CompetitionCardWidget({
    required this.competition,
    required this.entry,
    required this.gameweek,
    required this.onOpen,
    super.key,
  });

  final Competition competition;
  final FantasyEntry? entry;
  final Gameweek? gameweek;
  final VoidCallback onOpen;

  Color get _statusColor {
    switch (competition.status) {
      case CompetitionStatus.active:
        return FantasyColors.successGreen;
      case CompetitionStatus.draft:
        return FantasyColors.warningAmber;
      case CompetitionStatus.finished:
        return FantasyColors.textMuted;
    }
  }

  String get _statusLabel {
    switch (competition.status) {
      case CompetitionStatus.active:
        return 'Live';
      case CompetitionStatus.draft:
        return 'Draft';
      case CompetitionStatus.finished:
        return 'Finished';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deadlineAsync = gameweek == null
        ? const AsyncValue<Duration>.data(Duration.zero)
        : ref.watch(deadlineCountdownProvider(gameweek!.deadlineAt));

    return FantasyGlassCard(
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              _CompetitionLogo(
                logoUrl: competition.logoUrl,
                fallbackColor: Color(
                  int.parse(competition.primaryColor.replaceFirst('#', '0xFF')),
                ),
              ),
              const SizedBox(width: FantasySpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      competition.name,
                      style: FantasyTypography.body.copyWith(
                        color: FantasyColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: FantasySpacing.xs),
                    Text(
                      competition.season,
                      style: FantasyTypography.caption.copyWith(
                        color: FantasyColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              FantasyStatusBadge(label: _statusLabel, color: _statusColor),
            ],
          ),
          const SizedBox(height: FantasySpacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: deadlineAsync.when(
                  data: (duration) => Text(
                    gameweek == null
                        ? 'No active gameweek'
                        : 'Deadline ${duration.countdownLabel}',
                    style: FantasyTypography.caption.copyWith(
                      color: FantasyColors.textSecondary,
                    ),
                  ),
                  error: (_, __) => Text(
                    'Deadline unavailable',
                    style: FantasyTypography.caption.copyWith(
                      color: FantasyColors.textMuted,
                    ),
                  ),
                  loading: () => const AfriSkeleton.line(width: 120),
                ),
              ),
              const SizedBox(width: FantasySpacing.md),
              AfriButton(
                label: entry == null ? 'Enter' : 'Manage',
                onTap: onOpen,
                variant: AfriButtonVariant.accent,
                fullWidth: false,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompetitionLogo extends StatelessWidget {
  const _CompetitionLogo({required this.logoUrl, required this.fallbackColor});

  final String? logoUrl;
  final Color fallbackColor;

  @override
  Widget build(BuildContext context) {
    final child = logoUrl == null || logoUrl!.isEmpty
        ? _FallbackCompetitionLogo(color: fallbackColor)
        : ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: logoUrl!,
              width: 40,
              height: 40,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) =>
                  _FallbackCompetitionLogo(color: fallbackColor),
            ),
          );

    return SizedBox(width: 40, height: 40, child: child);
  }
}

class _FallbackCompetitionLogo extends StatelessWidget {
  const _FallbackCompetitionLogo({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Icon(
          Icons.shield_outlined,
          color: FantasyColors.textPrimary,
          size: 18,
        ),
      ),
    );
  }
}
