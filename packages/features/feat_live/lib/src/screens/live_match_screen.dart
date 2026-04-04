import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _loadMatch();
  }

  @override
  void dispose() {
    unawaited(_channel?.unsubscribe());
    super.dispose();
  }

  Future<void> _loadMatch() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final client = ref.read(supabaseClientProvider);
      final rows = await client
          .from('matches')
          .select()
          .order('match_date', ascending: true)
          .limit(12);
      final matches = List<Map<String, dynamic>>.from(rows);
      final selected = _pickFeaturedMatch(matches);

      if (!mounted) return;

      setState(() {
        _match = selected;
        _isLoading = false;
        _error = selected == null
            ? 'No live or upcoming fixture has been published yet.'
            : null;
      });

      if (selected != null) {
        _subscribeToMatch(selected['id']?.toString());
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

  void _subscribeToMatch(String? matchId) {
    if (matchId == null || matchId.isEmpty) {
      return;
    }

    unawaited(_channel?.unsubscribe());
    final client = ref.read(supabaseClientProvider);
    final channel = client.channel('live-match-$matchId');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'matches',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'id',
        value: matchId,
      ),
      callback: (payload) {
        final next = payload.newRecord;
        if (!mounted || next.isEmpty) return;
        setState(() {
          _match = Map<String, dynamic>.from(next);
        });
      },
    );
    channel.subscribe();
    _channel = channel;
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
      return '${liveMinute.toString()}\'  •  ${venue.toUpperCase()}';
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
          minute: liveMinute == null ? 'LIVE' : '${liveMinute.toString()}\'',
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
          body: summary.isEmpty
              ? 'Match finished. Summary pending.'
              : summary,
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
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                  ],
                ),
                const Spacer(),
                ClayCard(
                  padding: const EdgeInsets.all(SpacingTokens.spacing6),
                  child: Column(
                    children: [
                      Text(
                        'LIVE CENTER UNAVAILABLE',
                        style: TypographyTokens.headlineMedium().copyWith(
                          color: ColorTokens.onSurface,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: SpacingTokens.spacing3),
                      Text(
                        _error ??
                            'No live or upcoming fixture is available for Rayon Sports right now.',
                        style: TypographyTokens.bodyMedium(),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: SpacingTokens.spacing5),
                      ClaymorphicButton(
                        label: 'REFRESH',
                        width: double.infinity,
                        onPressed: _loadMatch,
                      ),
                    ],
                  ),
                ),
                const Spacer(),
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

    return Scaffold(
      backgroundColor: ColorTokens.background,
      body: GradientBackground(
        child: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(SpacingTokens.spacing6),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => context.pop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color:
                              (status == 'live'
                                      ? ColorTokens.success
                                      : ColorTokens.clubAccent)
                                  .withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          statusLabel,
                          style: TypographyTokens.bodyLarge(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: SpacingTokens.spacing6,
                  ),
                  child: ClayCard(
                    padding: const EdgeInsets.all(SpacingTokens.spacing6),
                    child: Column(
                      children: [
                        Text(
                          competition.toUpperCase(),
                          style: TypographyTokens.titleSmall().copyWith(
                            letterSpacing: 1.3,
                          ),
                        ),
                        const SizedBox(height: SpacingTokens.spacing3),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TeamBadge(label: _abbreviate(homeTeam)),
                            const SizedBox(width: SpacingTokens.spacing6),
                            Text(
                              '$homeScore - $awayScore',
                              style: TypographyTokens.displayLarge().copyWith(
                                color: ColorTokens.onSurface,
                              ),
                            ),
                            const SizedBox(width: SpacingTokens.spacing6),
                            TeamBadge(label: _abbreviate(awayTeam)),
                          ],
                        ),
                        const SizedBox(height: SpacingTokens.spacing3),
                        Text(
                          '${homeTeam.toUpperCase()}  •  ${awayTeam.toUpperCase()}',
                          textAlign: TextAlign.center,
                          style: TypographyTokens.headlineSmall().copyWith(
                            color: ColorTokens.onSurface,
                          ),
                        ),
                        const SizedBox(height: SpacingTokens.spacing2),
                        Text(
                          _timeAndVenue(match, status),
                          style: TypographyTokens.headlineSmall().copyWith(
                            color: ColorTokens.clubAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(SpacingTokens.spacing6),
                  child: Row(
                    children: [
                      LiveStatBox(
                        label: 'POSSESSION',
                        value: stats['POSSESSION']!,
                      ),
                      const SizedBox(width: SpacingTokens.spacing3),
                      LiveStatBox(label: 'SHOTS', value: stats['SHOTS']!),
                      const SizedBox(width: SpacingTokens.spacing3),
                      LiveStatBox(label: 'CORNERS', value: stats['CORNERS']!),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: SpacingTokens.spacing6,
                  ),
                  child: Text(
                    'MATCH INTEL',
                    style: TypographyTokens.titleMedium().copyWith(
                      letterSpacing: 1.4,
                    ),
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildListDelegate(
                  events
                      .map(
                        (event) => RepaintBoundary(
                          child: Padding(
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
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(SpacingTokens.spacing6),
                  child: ClaymorphicButton(
                    label: 'SHARE MATCH',
                    width: double.infinity,
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(
                          text:
                              '${RuntimeBranding.displayAppName}: $homeTeam $homeScore-$awayScore $awayTeam ($statusLabel)',
                        ),
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Match update copied to clipboard.'),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
