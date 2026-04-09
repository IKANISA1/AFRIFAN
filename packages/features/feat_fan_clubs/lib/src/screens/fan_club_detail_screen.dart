import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

int? _currentClubId(SupabaseClient client) {
  final user = client.auth.currentUser;
  final candidates = <Object?>[
    user?.appMetadata['club_id'],
    user?.userMetadata?['club_id'],
    user?.appMetadata['clubId'],
    user?.userMetadata?['clubId'],
  ];

  for (final candidate in candidates) {
    final parsed = int.tryParse(candidate?.toString().trim() ?? '');
    if (parsed != null) {
      return parsed;
    }
  }

  return null;
}

class FanClubDetailScreen extends ConsumerStatefulWidget {
  const FanClubDetailScreen({required this.clubId, super.key});

  final String clubId;

  @override
  ConsumerState<FanClubDetailScreen> createState() =>
      _FanClubDetailScreenState();
}

class _FanClubDetailScreenState extends ConsumerState<FanClubDetailScreen> {
  Map<String, dynamic>? _club;
  Map<String, dynamic>? _upcomingMatch;
  bool _joined = false;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadClub();
  }

  Future<void> _loadClub() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final client = ref.read(supabaseClientProvider);
      final clubId = _currentClubId(client);
      if (clubId == null) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _error = 'Could not resolve the active club.';
        });
        return;
      }
      final clubRow = await client
          .from('fan_clubs')
          .select()
          .eq('id', widget.clubId)
          .eq('club_id', clubId)
          .maybeSingle();

      if (clubRow == null) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _error = 'This fan club is no longer available.';
        });
        return;
      }

      Map<String, dynamic>? matchRow;
      try {
        matchRow = await client
            .from('matches')
            .select()
            .eq('is_on_sale', true)
            .eq('club_id', clubId)
            .order('match_date', ascending: true)
            .limit(1)
            .maybeSingle();
      } catch (_) {
        matchRow = null;
      }

      var joined = false;
      final userId = client.auth.currentUser?.id;
      if (userId != null) {
        try {
          final membership = await client
              .from('fan_club_members')
              .select('club_id')
              .eq('club_id', widget.clubId)
              .eq('user_id', userId)
              .maybeSingle();
          joined = membership != null;
        } catch (_) {
          joined = false;
        }
      }

      if (!mounted) return;
      setState(() {
        _club = Map<String, dynamic>.from(clubRow);
        _upcomingMatch = matchRow == null
            ? null
            : Map<String, dynamic>.from(matchRow);
        _joined = joined;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Could not load this fan club.';
      });
    }
  }

  Future<void> _toggleJoin() async {
    final club = _club;
    final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;
    if (club == null) return;

    if (userId == null) {
      context.go('/onboarding');
      return;
    }

    final clubId = club['id']?.toString();
    if (clubId == null || clubId.isEmpty) {
      return;
    }

    HapticFeedback.mediumImpact();
    try {
      if (_joined) {
        await ref
            .read(supabaseClientProvider)
            .from('fan_club_members')
            .delete()
            .eq('club_id', clubId)
            .eq('user_id', userId);
      } else {
        await ref.read(supabaseClientProvider).from('fan_club_members').insert({
          'club_id': clubId,
          'user_id': userId,
        });
      }

      if (!mounted) return;
      final currentMembers = (club['member_count'] as num?)?.toInt() ?? 0;
      setState(() {
        _joined = !_joined;
        _club = <String, dynamic>{
          ...club,
          'member_count': _joined
              ? currentMembers + 1
              : (currentMembers - 1).clamp(0, currentMembers),
        };
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _joined
                ? 'Could not leave this fan club right now.'
                : 'Could not join this fan club right now.',
          ),
          backgroundColor: ColorTokens.error,
        ),
      );
    }
  }

  Future<void> _copyShareLink() async {
    await Clipboard.setData(
      ClipboardData(
        text:
            'Join this ${RuntimeBranding.displayAppName} fan club: /fan-clubs/${widget.clubId}',
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Fan club link copied.')));
  }

  bool _isOfficial(Map<String, dynamic> club) {
    final members = (club['member_count'] as num?)?.toInt() ?? 0;
    final rating = (club['rating'] as num?)?.toDouble() ?? 0;
    return members >= 300 || rating >= 4.8;
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

    if (_error != null || _club == null) {
      return Scaffold(
        backgroundColor: ColorTokens.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(SpacingTokens.spacing6),
            child: Text(
              _error ?? 'Fan club unavailable.',
              textAlign: TextAlign.center,
              style: TypographyTokens.bodyLarge(),
            ),
          ),
        ),
      );
    }

    final club = _club!;
    final primary = Theme.of(context).colorScheme.primary;
    final name = club['name']?.toString() ?? 'Fan Club';
    final description = club['description']?.toString() ?? '';
    final region = club['region']?.toString() ?? 'Unknown';
    final members = (club['member_count'] as num?)?.toInt() ?? 0;
    final events = (club['event_count'] as num?)?.toInt() ?? 0;
    final rating = (club['rating'] as num?)?.toDouble() ?? 0;
    // Removed emoji string loading
    final match = _upcomingMatch;

    return Scaffold(
      backgroundColor: ColorTokens.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            backgroundColor: ColorTokens.background,
            pinned: true,
            leading: IconButton(
              onPressed: () => context.pop(),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      ColorTokens.clubPrimary.withValues(alpha: 0.6),
                      ColorTokens.surfaceContainerLow,
                      ColorTokens.surfaceContainerLowest,
                    ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(SpacingTokens.spacing6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Spacer(),
                      Row(
                        children: [
                          Icon(
                            Icons.groups_rounded,
                            size: 32,
                            color: ColorTokens.onSurface,
                          ),
                          const SizedBox(width: SpacingTokens.spacing3),
                          if (_isOfficial(club))
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: ColorTokens.clubAccent.withValues(
                                  alpha: 0.14,
                                ),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'OFFICIAL',
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: ColorTokens.clubAccent,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: SpacingTokens.spacing4),
                      Text(
                        name.toUpperCase(),
                        style: GoogleFonts.barlowCondensed(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          color: ColorTokens.onSurface,
                          height: 1,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: SpacingTokens.spacing2),
                      Text(
                        description,
                        style: TypographyTokens.bodyMedium().copyWith(
                          color: ColorTokens.onSurface.withValues(alpha: 0.88),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(SpacingTokens.spacing6),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _DetailStat(label: 'MEMBERS', value: '$members'),
                      ),
                      const SizedBox(width: SpacingTokens.spacing3),
                      Expanded(
                        child: _DetailStat(label: 'EVENTS', value: '$events'),
                      ),
                      const SizedBox(width: SpacingTokens.spacing3),
                      Expanded(
                        child: _DetailStat(
                          label: 'RATING',
                          value: rating == 0
                              ? 'NEW'
                              : rating.toStringAsFixed(1),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: SpacingTokens.spacing6),
                  GlassCard(
                    animate: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ABOUT THIS CLUB',
                          style: GoogleFonts.barlowCondensed(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: ColorTokens.onSurface,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: SpacingTokens.spacing3),
                        Text(description, style: TypographyTokens.bodyMedium()),
                        const SizedBox(height: SpacingTokens.spacing3),
                        Text(
                          'Region: $region',
                          style: TypographyTokens.bodySmall(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: SpacingTokens.spacing4),
                  GlassCard(
                    animate: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CIRCLE SNAPSHOT',
                          style: GoogleFonts.barlowCondensed(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: ColorTokens.onSurface,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: SpacingTokens.spacing3),
                        _SnapshotRow(
                          title: _joined
                              ? 'You are a member.'
                              : 'Join for updates & matchday coordination.',
                        ),
                        const SizedBox(height: SpacingTokens.spacing2),
                        _SnapshotRow(title: '$events events recorded.'),
                        const SizedBox(height: SpacingTokens.spacing2),
                        _SnapshotRow(title: '$members fans in this circle.'),
                      ],
                    ),
                  ),
                  const SizedBox(height: SpacingTokens.spacing4),
                  GlassCard(
                    animate: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MATCHDAY AGENDA',
                          style: GoogleFonts.barlowCondensed(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: ColorTokens.onSurface,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: SpacingTokens.spacing3),
                        if (match == null)
                          Text(
                            'No upcoming club fixture is linked to this chapter yet.',
                            style: TypographyTokens.bodyMedium(),
                          )
                        else ...[
                          Text(
                            '${match['home_team']} vs ${match['away_team']}',
                            style: GoogleFonts.barlowCondensed(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: ColorTokens.onSurface,
                            ),
                          ),
                          const SizedBox(height: SpacingTokens.spacing2),
                          Text(
                            '${match['competition']}  •  ${match['venue']}',
                            style: TypographyTokens.bodyMedium(),
                          ),
                          const SizedBox(height: SpacingTokens.spacing2),
                          Text(
                            '${match['match_date']}  •  ${match['kickoff_time']}',
                            style: TypographyTokens.bodySmall(),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: SpacingTokens.spacing6),
                  Row(
                    children: [
                      Expanded(
                        child: ClaymorphicButton(
                          label: _joined ? 'JOINED' : 'JOIN CLUB',
                          onPressed: _toggleJoin,
                        ),
                      ),
                      const SizedBox(width: SpacingTokens.spacing3),
                      SizedBox(
                        width: 58,
                        height: 58,
                        child: OutlinedButton(
                          onPressed: _copyShareLink,
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: primary),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: const Icon(Icons.share_rounded),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailStat extends StatelessWidget {
  const _DetailStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      animate: false,
      child: Column(
        children: [
          Text(label, style: TypographyTokens.labelSmall()),
          const SizedBox(height: SpacingTokens.spacing2),
          Text(
            value,
            style: GoogleFonts.barlowCondensed(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: ColorTokens.clubAccent,
            ),
          ),
        ],
      ),
    );
  }
}

class _SnapshotRow extends StatelessWidget {
  const _SnapshotRow({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(SpacingTokens.spacing3),
      decoration: BoxDecoration(
        color: ColorTokens.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(title, style: TypographyTokens.bodyMedium()),
    );
  }
}
