import 'dart:async';

import 'package:core_l10n/core_l10n.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../widgets/live_match_widgets.dart';

class LiveMatchScreen extends ConsumerStatefulWidget {
  const LiveMatchScreen({super.key});

  @override
  ConsumerState<LiveMatchScreen> createState() => _LiveMatchScreenState();
}

class _LiveMatchScreenState extends ConsumerState<LiveMatchScreen> {
  Map<String, dynamic>? _match;
  bool _isLoading = true;
  String? _error;
  RealtimeService? _realtimeService;

  @override
  void initState() {
    super.initState();
    unawaited(_loadMatch());
  }

  @override
  void dispose() {
    unawaited(_realtimeService?.dispose());
    super.dispose();
  }

  Future<void> _loadMatch() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final client = ref.read(supabaseClientProvider);
      final resolver = ClubScopeResolver(client: client);
      final scope = await resolver.requireResolved();
      var query = client.from('unified_matches').select();
      query = resolver.apply(query, scope);
      final rows = await query.order('match_date', ascending: true).limit(12);
      final matches = List<Map<String, dynamic>>.from(rows);
      final selected = _pickFeaturedMatch(matches);

      if (!mounted) return;

      setState(() {
        _match = selected;
        _isLoading = false;
        _error = null;
      });

      if (selected != null) {
        unawaited(_subscribeToMatch(scope, selected['id']?.toString()));
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = context.afriL10n.liveMatchLoadError;
        _isLoading = false;
      });
    }
  }

  Map<String, dynamic>? _pickFeaturedMatch(List<Map<String, dynamic>> matches) {
    if (matches.isEmpty) return null;

    final priority = <String, int>{
      'live': 0,
      'halftime': 1,
      'scheduled': 2,
      'fulltime': 3,
      'postponed': 4,
      'cancelled': 5,
    };

    matches.sort((left, right) {
      final leftPriority = priority[_statusOf(left)] ?? 10;
      final rightPriority = priority[_statusOf(right)] ?? 10;
      if (leftPriority != rightPriority) {
        return leftPriority.compareTo(rightPriority);
      }

      final leftDate = DateTime.tryParse(left['match_date']?.toString() ?? '');
      final rightDate = DateTime.tryParse(
        right['match_date']?.toString() ?? '',
      );
      if (leftDate == null && rightDate == null) return 0;
      if (leftDate == null) return 1;
      if (rightDate == null) return -1;
      return leftDate.compareTo(rightDate);
    });

    return matches.first;
  }

  Future<void> _subscribeToMatch(ClubScope scope, String? matchId) async {
    if (matchId == null || matchId.isEmpty) {
      return;
    }

    final client = ref.read(supabaseClientProvider);
    await _realtimeService?.dispose();
    final realtimeService = RealtimeService(
      clubId: _realtimeScopeId(scope),
      client: client,
    );
    realtimeService.onTableChanges(
      table: 'matches',
      filterColumn: 'id',
      filterValue: matchId,
      callback: (payload) {
        final next = payload.newRecord;
        if (!mounted || next.isEmpty) return;
        setState(() {
          _match = Map<String, dynamic>.from(next);
        });
      },
    );

    if (!mounted) {
      await realtimeService.dispose();
      return;
    }
    _realtimeService = realtimeService;
  }

  String _realtimeScopeId(ClubScope scope) {
    return scope.clubId?.toString() ?? scope.partnerId;
  }

  String _statusOf(Map<String, dynamic> match) {
    final raw = match['match_status']?.toString().trim().toLowerCase();
    if (raw != null && raw.isNotEmpty) {
      return raw;
    }

    final matchDate = DateTime.tryParse(match['match_date']?.toString() ?? '');
    if (matchDate == null) return 'scheduled';
    return matchDate.isBefore(DateTime.now()) ? 'fulltime' : 'scheduled';
  }

  String _statusLabel(String status) {
    return switch (status) {
      'live' => context.afriL10n.liveStatusLive,
      'halftime' => context.afriL10n.liveStatusHalfTime,
      'fulltime' => context.afriL10n.liveStatusFullTime,
      'postponed' => context.afriL10n.liveStatusPostponed,
      'cancelled' => context.afriL10n.liveStatusCancelled,
      _ => context.afriL10n.liveStatusUpcoming,
    };
  }

  String _timeAndVenue(Map<String, dynamic> match, String status) {
    final venue = _resolveText(
      match['venue']?.toString(),
      RuntimeBranding.displayHomeVenueName,
    );
    final liveMinute = (match['live_minute'] as num?)?.toInt();
    final matchDate = DateTime.tryParse(match['match_date']?.toString() ?? '');

    if ((status == 'live' || status == 'halftime') && liveMinute != null) {
      return context.afriL10n.liveTimeVenue(
        "$liveMinute'",
        venue.toUpperCase(),
      );
    }

    if (status == 'fulltime') {
      return context.afriL10n.liveTimeVenue(
        context.afriL10n.liveStatusFinal,
        venue.toUpperCase(),
      );
    }

    if (matchDate != null) {
      final local = matchDate.toLocal();
      final hour = local.hour.toString().padLeft(2, '0');
      final minute = local.minute.toString().padLeft(2, '0');
      return context.afriL10n.liveTimeVenue(
        '$hour:$minute',
        venue.toUpperCase(),
      );
    }

    return venue.toUpperCase();
  }

  List<MatchIntelEvent> _eventsFor(Map<String, dynamic> match) {
    final raw = match['live_events'];
    if (raw is List) {
      final parsed = raw
          .whereType<Map>()
          .map(
            (entry) => MatchIntelEvent(
              minute: entry['minute']?.toString() ?? '',
              title:
                  entry['title']?.toString() ??
                  context.afriL10n.liveMatchUpdate,
              body: entry['body']?.toString() ?? '',
            ),
          )
          .where((entry) => entry.title.trim().isNotEmpty)
          .toList(growable: false);
      if (parsed.isNotEmpty) return parsed;
    }

    final status = _statusOf(match);
    final summary = match['match_summary']?.toString().trim() ?? '';
    final homeTeam = _resolveText(
      match['home_team']?.toString(),
      RuntimeBranding.displayHomeTeamName,
    );
    final awayTeam = _resolveText(
      match['away_team']?.toString(),
      RuntimeBranding.displayRivalTeamName,
    );
    final liveMinute = (match['live_minute'] as num?)?.toInt();

    if (status == 'live' || status == 'halftime') {
      return <MatchIntelEvent>[
        MatchIntelEvent(
          minute: liveMinute == null
              ? context.afriL10n.liveStatusLive
              : "$liveMinute'",
          title: context.afriL10n.liveMatchTeamsUpper(
            homeTeam.toUpperCase(),
            awayTeam.toUpperCase(),
          ),
          body: summary.isEmpty ? context.afriL10n.liveModeActive : summary,
        ),
      ];
    }

    if (status == 'fulltime') {
      return <MatchIntelEvent>[
        MatchIntelEvent(
          minute: 'FT',
          title: context.afriL10n.liveMatchReport,
          body: summary.isEmpty
              ? context.afriL10n.liveMatchFinishedPending
              : summary,
        ),
      ];
    }

    return <MatchIntelEvent>[
      MatchIntelEvent(
        minute: 'PRE',
        title: context.afriL10n.liveMatchdayIntel,
        body: summary.isEmpty ? context.afriL10n.liveFixturePublished : summary,
      ),
    ];
  }

  Map<String, String> _statsFor(Map<String, dynamic> match) {
    final raw = match['live_stats'];
    if (raw is Map) {
      final stats = Map<String, dynamic>.from(raw);
      return <String, String>{
        'POSSESSION':
            stats['possession']?.toString() ?? context.afriL10n.liveStatPending,
        'SHOTS': stats['shots']?.toString() ?? context.afriL10n.liveStatPending,
        'CORNERS':
            stats['corners']?.toString() ?? context.afriL10n.liveStatPending,
      };
    }

    final status = _statusOf(match);
    if (status == 'live' || status == 'halftime' || status == 'fulltime') {
      return <String, String>{
        'POSSESSION': context.afriL10n.liveStatusLive,
        'SHOTS': context.afriL10n.liveStatusLive,
        'CORNERS': context.afriL10n.liveStatusLive,
      };
    }

    return <String, String>{
      'POSSESSION': context.afriL10n.liveStatPending,
      'SHOTS': context.afriL10n.liveStatPending,
      'CORNERS': context.afriL10n.liveStatPending,
    };
  }

  String _resolveText(String? value, String fallback) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? fallback : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return AfriScreenScaffold(
        backgroundColor: ColorTokens.background,
        showAppBar: false,
        showBackButton: false,
        scrollable: false,
        constrainContent: true,
        child: const SafeArea(
          child: Padding(
            padding: EdgeInsets.all(SpacingTokens.spacing6),
            child: AfriSkeletonList(),
          ),
        ),
      );
    }

    if (_match == null) {
      return AfriScreenScaffold(
        backgroundColor: ColorTokens.background,
        showAppBar: false,
        showBackButton: false,
        scrollable: false,
        constrainContent: true,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(SpacingTokens.spacing6),
            child: Column(
              children: [
                Row(
                  children: [
                    if (context.canPop())
                      AfriIconButton(
                        icon: AfriIcons.back,
                        onTap: () => context.pop(),
                        tooltip: context.afriL10n.authBack,
                      ),
                  ],
                ),
                Expanded(
                  child: LiveMatchFallbackContent(
                    error: _error,
                    onRetry: () => unawaited(_loadMatch()),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final match = _match!;
    final status = _statusOf(match);
    final statusLabel = _statusLabel(status);
    final homeTeam = _resolveText(
      match['home_team']?.toString(),
      RuntimeBranding.displayHomeTeamName,
    );
    final awayTeam = _resolveText(
      match['away_team']?.toString(),
      RuntimeBranding.displayRivalTeamName,
    );
    final homeScore = (match['home_score'] as num?)?.toInt() ?? 0;
    final awayScore = (match['away_score'] as num?)?.toInt() ?? 0;
    final competition = _resolveText(
      match['competition']?.toString(),
      RuntimeBranding.displayCompetitionName,
    );
    final stats = _statsFor(match);
    final events = _eventsFor(match);
    final homeLogoUrl = match['home_team_logo']?.toString();
    final awayLogoUrl = match['away_team_logo']?.toString();
    final homeLogoProvenance =
        match['home_team_logo_provenance_id']?.toString().trim() ?? '';
    final awayLogoProvenance =
        match['away_team_logo_provenance_id']?.toString().trim() ?? '';
    final homeLogoRightsApproved =
        match['home_team_logo_rights_approved'] == true &&
        homeLogoProvenance.isNotEmpty;
    final awayLogoRightsApproved =
        match['away_team_logo_rights_approved'] == true &&
        awayLogoProvenance.isNotEmpty;

    return AfriScreenScaffold(
      backgroundColor: ColorTokens.background,
      appBar: AfriAppBar(
        backgroundColor: ColorTokens.transparent,
        title: Text(
          context.afriL10n.liveMatchCenter,
          style: TypographyTokens.headlineSmall(),
        ),
        leading: AfriIconButton(
          icon: AfriIcons.back,
          onTap: () => context.pop(),
          tooltip: context.afriL10n.authBack,
        ),
        actions: [
          AfriIconButton(
            icon: AfriIcons.history,
            onTap: () => unawaited(context.push('/fanzone/my')),
            tooltip: context.afriL10n.liveMyPredictions,
          ),
        ],
      ),
      scrollable: false,
      constrainContent: false,
      child: AfriRefreshIndicator(
        onRefresh: _loadMatch,
        color: ColorTokens.clubAccent,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  SpacingTokens.spacing6,
                  SpacingTokens.spacing4,
                  SpacingTokens.spacing6,
                  SpacingTokens.spacing5,
                ),
                child: GlassCard(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            competition,
                            style: TypographyTokens.labelSmall(
                              ColorTokens.onSurfaceVariant,
                            ),
                          ),
                          AfriStatusChip(
                            label: statusLabel,
                            tone: status == 'live'
                                ? AfriStatusTone.success
                                : AfriStatusTone.live,
                          ),
                        ],
                      ),
                      const SizedBox(height: SpacingTokens.spacing6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildTeamBox(
                            homeTeam,
                            logoUrl: homeLogoUrl,
                            provenanceId: homeLogoProvenance,
                            rightsApproved: homeLogoRightsApproved,
                          ),
                          const SizedBox(width: SpacingTokens.spacing6),
                          Text(
                            context.afriL10n.liveScore(homeScore, awayScore),
                            style: TypographyTokens.displayMedium(),
                          ),
                          const SizedBox(width: SpacingTokens.spacing6),
                          _buildTeamBox(
                            awayTeam,
                            logoUrl: awayLogoUrl,
                            provenanceId: awayLogoProvenance,
                            rightsApproved: awayLogoRightsApproved,
                          ),
                        ],
                      ),
                      const SizedBox(height: SpacingTokens.spacing6),
                      Text(
                        _timeAndVenue(match, status).replaceAll('•', '·'),
                        textAlign: TextAlign.center,
                        style: TypographyTokens.bodyMedium(
                          ColorTokens.clubAccent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: SpacingTokens.spacing6,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: AfriMetricTile(
                        label: context.afriL10n.liveStatPossession,
                        value: stats['POSSESSION']!,
                      ),
                    ),
                    const SizedBox(width: SpacingTokens.spacing3),
                    Expanded(
                      child: AfriMetricTile(
                        label: context.afriL10n.liveStatShots,
                        value: stats['SHOTS']!,
                      ),
                    ),
                    const SizedBox(width: SpacingTokens.spacing3),
                    Expanded(
                      child: AfriMetricTile(
                        label: context.afriL10n.liveStatCorners,
                        value: stats['CORNERS']!,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(
                  top: SpacingTokens.spacing8,
                  bottom: SpacingTokens.spacing4,
                ),
                child: AfriSectionHeader(
                  title: context.afriL10n.liveMatchIntel,
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildListDelegate(
                events
                    .map(
                      (event) => Padding(
                        padding: const EdgeInsets.fromLTRB(
                          SpacingTokens.spacing6,
                          0,
                          SpacingTokens.spacing6,
                          SpacingTokens.spacing3,
                        ),
                        child: CommentaryCard(
                          minute: event.minute,
                          title: event.title,
                          body: event.body,
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(SpacingTokens.spacing6),
                child: Column(
                  children: [
                    AfriButton(
                      label: context.afriL10n.liveBrowsePredictions,
                      onTap: () => context.go('/fanzone/fixtures'),
                    ),
                    const SizedBox(height: SpacingTokens.spacing3),
                    AfriButton(
                      label: context.afriL10n.liveShareMatch,
                      variant: AfriButtonVariant.outline,
                      onTap: () async {
                        await Clipboard.setData(
                          ClipboardData(
                            text: context.afriL10n.liveShareText(
                              RuntimeBranding.displayAppName,
                              homeTeam,
                              homeScore,
                              awayScore,
                              awayTeam,
                              statusLabel,
                            ),
                          ),
                        );
                        if (context.mounted) {
                          AfriToast.success(
                            context,
                            context.afriL10n.liveMatchCopied,
                          );
                        }
                      },
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

  Widget _buildTeamBox(
    String team, {
    String? logoUrl,
    String? provenanceId,
    bool rightsApproved = false,
  }) {
    return Column(
      children: [
        TeamBadge(
          label: _abbreviate(team),
          logoUrl: logoUrl,
          provenanceId: provenanceId,
          rightsApproved: rightsApproved,
        ),
        const SizedBox(height: SpacingTokens.spacing2),
        SizedBox(
          width: 80,
          child: Text(
            team,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TypographyTokens.labelSmall(),
          ),
        ),
      ],
    );
  }

  static String _abbreviate(String value) {
    final parts = value
        .split(RegExp(r'\s+'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) {
      return 'FC';
    }
    if (parts.length == 1) {
      final token = parts.first.toUpperCase();
      final end = token.length > 3 ? 3 : token.length;
      return token.substring(0, end);
    }
    return parts.take(3).map((part) => part[0].toUpperCase()).join();
  }
}

class LiveMatchFallbackContent extends StatelessWidget {
  const LiveMatchFallbackContent({
    super.key,
    required this.error,
    required this.onRetry,
  });

  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (error == null) {
      return const SizedBox.shrink();
    }

    return Center(
      child: AfriSurfaceCard(
        padding: const EdgeInsets.all(SpacingTokens.spacing6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.afriL10n.liveCenterUnavailable,
              style: TypographyTokens.headlineMedium(ColorTokens.onDark)
                  .copyWith(
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: SpacingTokens.spacing3),
            Text(
              error!,
              style: TypographyTokens.bodyMedium(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: SpacingTokens.spacing5),
            AfriButton(
              label: context.afriL10n.liveRefresh,
              fullWidth: true,
              onTap: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
