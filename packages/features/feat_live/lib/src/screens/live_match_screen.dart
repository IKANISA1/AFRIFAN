import 'dart:async';

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
        _error = 'Could not load the live match center right now.';
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
      'live' => 'LIVE',
      'halftime' => 'HALF-TIME',
      'fulltime' => 'FULL-TIME',
      'postponed' => 'POSTPONED',
      'cancelled' => 'CANCELLED',
      _ => 'UPCOMING',
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
      return '$liveMinute\'  •  ${venue.toUpperCase()}';
    }

    if (status == 'fulltime') {
      return 'FINAL  •  ${venue.toUpperCase()}';
    }

    if (matchDate != null) {
      final local = matchDate.toLocal();
      final hour = local.hour.toString().padLeft(2, '0');
      final minute = local.minute.toString().padLeft(2, '0');
      return '$hour:$minute  •  ${venue.toUpperCase()}';
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
              title: entry['title']?.toString() ?? 'Match update',
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
          minute: liveMinute == null ? 'LIVE' : '$liveMinute\'',
          title: '${homeTeam.toUpperCase()} VS ${awayTeam.toUpperCase()}',
          body: summary.isEmpty
              ? 'Live mode active. Events appear in real time.'
              : summary,
        ),
      ];
    }

    if (status == 'fulltime') {
      return <MatchIntelEvent>[
        MatchIntelEvent(
          minute: 'FT',
          title: 'MATCH REPORT',
          body: summary.isEmpty ? 'Match finished. Summary pending.' : summary,
        ),
      ];
    }

    return <MatchIntelEvent>[
      MatchIntelEvent(
        minute: 'PRE',
        title: 'MATCHDAY INTEL',
        body: summary.isEmpty
            ? 'Fixture published. Live updates start near kickoff.'
            : summary,
      ),
    ];
  }

  Map<String, String> _statsFor(Map<String, dynamic> match) {
    final raw = match['live_stats'];
    if (raw is Map) {
      final stats = Map<String, dynamic>.from(raw);
      return <String, String>{
        'POSSESSION': stats['possession']?.toString() ?? 'TBD',
        'SHOTS': stats['shots']?.toString() ?? 'TBD',
        'CORNERS': stats['corners']?.toString() ?? 'TBD',
      };
    }

    final status = _statusOf(match);
    if (status == 'live' || status == 'halftime' || status == 'fulltime') {
      return const <String, String>{
        'POSSESSION': 'LIVE',
        'SHOTS': 'LIVE',
        'CORNERS': 'LIVE',
      };
    }

    return const <String, String>{
      'POSSESSION': 'TBD',
      'SHOTS': 'TBD',
      'CORNERS': 'TBD',
    };
  }

  String _resolveText(String? value, String fallback) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? fallback : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: ColorTokens.background,
        body: const SafeArea(
          child: Padding(
            padding: EdgeInsets.all(SpacingTokens.spacing6),
            child: AfriSkeletonList(),
          ),
        ),
      );
    }

    if (_match == null) {
      return Scaffold(
        backgroundColor: ColorTokens.background,
        body: SafeArea(
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
                        tooltip: 'Back',
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

    return Scaffold(
      backgroundColor: ColorTokens.background,
      appBar: AfriAppBar(
        backgroundColor: ColorTokens.transparent,
        title: Text('Match Center', style: TypographyTokens.headlineSmall()),
        leading: AfriIconButton(
          icon: AfriIcons.back,
          onTap: () => context.pop(),
          tooltip: 'Back',
        ),
        actions: [
          AfriIconButton(
            icon: AfriIcons.history,
            onTap: () => unawaited(context.push('/fanzone/my')),
            tooltip: 'My Predictions',
          ),
        ],
      ),
      body: AfriRefreshIndicator(
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
                          _buildTeamBox(homeTeam, logoUrl: homeLogoUrl),
                          const SizedBox(width: SpacingTokens.spacing6),
                          Text(
                            '$homeScore - $awayScore',
                            style: TypographyTokens.displayMedium(),
                          ),
                          const SizedBox(width: SpacingTokens.spacing6),
                          _buildTeamBox(awayTeam, logoUrl: awayLogoUrl),
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
                        label: 'Possession',
                        value: stats['POSSESSION']!,
                      ),
                    ),
                    const SizedBox(width: SpacingTokens.spacing3),
                    Expanded(
                      child: AfriMetricTile(
                        label: 'Shots',
                        value: stats['SHOTS']!,
                      ),
                    ),
                    const SizedBox(width: SpacingTokens.spacing3),
                    Expanded(
                      child: AfriMetricTile(
                        label: 'Corners',
                        value: stats['CORNERS']!,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(
                  top: SpacingTokens.spacing8,
                  bottom: SpacingTokens.spacing4,
                ),
                child: AfriSectionHeader(title: 'Match Intel'),
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
                      label: 'Browse predictions',
                      onTap: () => context.go('/fanzone/fixtures'),
                    ),
                    const SizedBox(height: SpacingTokens.spacing3),
                    AfriButton(
                      label: 'Share match',
                      variant: AfriButtonVariant.outline,
                      onTap: () async {
                        await Clipboard.setData(
                          ClipboardData(
                            text:
                                '${RuntimeBranding.displayAppName}: $homeTeam $homeScore-$awayScore $awayTeam ($statusLabel)',
                          ),
                        );
                        if (context.mounted) {
                          AfriToast.success(
                            context,
                            'Match update copied to clipboard.',
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

  Widget _buildTeamBox(String team, {String? logoUrl}) {
    return Column(
      children: [
        TeamBadge(label: _abbreviate(team), logoUrl: logoUrl),
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
              'LIVE CENTER UNAVAILABLE',
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
            AfriButton(label: 'Refresh', fullWidth: true, onTap: onRetry),
          ],
        ),
      ),
    );
  }
}
