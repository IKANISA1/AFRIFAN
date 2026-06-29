import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class FanClubDetailScreen extends ConsumerStatefulWidget {
  const FanClubDetailScreen({required this.clubId, super.key});

  final String clubId;

  @override
  ConsumerState<FanClubDetailScreen> createState() =>
      _FanClubDetailScreenState();
}

void _reportNonCriticalError(Object error, StackTrace stackTrace) {
  FlutterError.reportError(
    FlutterErrorDetails(
      exception: error,
      stack: stackTrace,
      library: 'feat_fan_clubs',
      context: ErrorDescription('FanClubDetailScreen non-critical operation'),
    ),
  );
}

class _FanClubDetailScreenState extends ConsumerState<FanClubDetailScreen> {
  Map<String, dynamic>? _club;
  Map<String, dynamic>? _upcomingMatch;
  bool _joined = false;
  bool _isJoinMutationPending = false;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_loadClub());
  }

  Future<void> _loadClub() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final client = ref.read(supabaseClientProvider);
      final resolver = ClubScopeResolver(client: client);
      final scope = await resolver.requireResolved();
      if (scope.clubId == null) {
        throw StateError('Fan clubs require a numeric club scope.');
      }
      final clubRow = await client
          .from('fan_clubs')
          .select()
          .eq('id', widget.clubId)
          .eq('club_id', scope.clubId!)
          .maybeSingle();

      if (clubRow == null) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _error = 'This fan club is unavailable.';
        });
        return;
      }

      Map<String, dynamic>? matchRow;
      try {
        var query = client
            .from('unified_matches')
            .select()
            .eq('is_on_sale', true);
        query = resolver.apply(query, scope);
        matchRow = await query
            .order('match_date', ascending: true)
            .limit(1)
            .maybeSingle();
      } catch (error, stackTrace) {
        _reportNonCriticalError(error, stackTrace);
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
        } catch (error, stackTrace) {
          _reportNonCriticalError(error, stackTrace);
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
    } catch (error, stackTrace) {
      _reportNonCriticalError(error, stackTrace);
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
    if (club == null || _isJoinMutationPending) return;
    if (!(club['is_active'] as bool? ?? true)) {
      return;
    }

    if (userId == null) {
      context.go('/onboarding');
      return;
    }

    final clubId = club['id']?.toString();
    if (clubId == null || clubId.isEmpty) {
      return;
    }

    unawaited(HapticFeedback.mediumImpact());
    setState(() => _isJoinMutationPending = true);
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
    } catch (error, stackTrace) {
      _reportNonCriticalError(error, stackTrace);
      if (!mounted) return;
      AfriToast.error(
        context,
        _joined
            ? 'Could not leave this fan club right now.'
            : 'Could not join this fan club right now.',
      );
    } finally {
      if (mounted) {
        setState(() => _isJoinMutationPending = false);
      }
    }
  }

  Future<void> _copyShareLink() async {
    const websiteUrl = String.fromEnvironment(
      'APP_WEBSITE_URL',
      defaultValue: '',
    );
    final normalizedWebsite = websiteUrl.trim().replaceAll(RegExp(r'/$'), '');
    final shareTarget = normalizedWebsite.isNotEmpty
        ? '$normalizedWebsite/fan-clubs/${widget.clubId}'
        : 'Open ${RuntimeBranding.displayAppName} and visit the Fan Clubs section.';
    await Clipboard.setData(
      ClipboardData(
        text:
            'Join this ${RuntimeBranding.displayAppName} fan club: $shareTarget',
      ),
    );
    if (!mounted) return;
    AfriToast.success(context, 'Fan club link copied.');
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
        appBar: AfriAppBar(
          backgroundColor: ColorTokens.transparent,
          leading: AfriIconButton(
            icon: AfriIcons.back,
            onTap: () => context.pop(),
            tooltip: 'Back',
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
    final primary = ColorTokens.clubAccent;
    final name = club['name']?.toString() ?? 'Fan Club';
    final description = club['description']?.toString() ?? '';
    final region = club['region']?.toString() ?? 'Unknown';
    final members = (club['member_count'] as num?)?.toInt() ?? 0;
    final events = (club['event_count'] as num?)?.toInt() ?? 0;
    final rating = (club['rating'] as num?)?.toDouble() ?? 0;
    final isActive = club['is_active'] as bool? ?? true;
    final match = _upcomingMatch;

    return Scaffold(
      backgroundColor: ColorTokens.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          AfriSliverAppBar(
            expandedHeight: 280,
            backgroundColor: ColorTokens.background,
            pinned: true,
            leading: AfriIconButton(
              icon: AfriIcons.back,
              onTap: () => context.pop(),
              tooltip: 'Back',
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: ColorTokens.borrowedGradient(
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
                            AfriIcons.groups,
                            size: 32,
                            color: ColorTokens.onSurface,
                          ),
                          const SizedBox(width: SpacingTokens.spacing3),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? ColorTokens.clubAccent.withValues(
                                      alpha: 0.14,
                                    )
                                  : ColorTokens.warning.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              isActive ? 'ACTIVE' : 'PENDING REVIEW',
                              style:
                                  TypographyTokens.labelMedium(
                                    isActive
                                        ? ColorTokens.clubAccent
                                        : ColorTokens.warning,
                                  ).copyWith(
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.2,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: SpacingTokens.spacing4),
                      Text(
                        name.toUpperCase(),
                        style: TypographyTokens.displaySmall().copyWith(
                          fontWeight: FontWeight.w800,
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
                          style: TypographyTokens.titleLarge().copyWith(
                            fontWeight: FontWeight.w700,
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
                          'Group SNAPSHOT',
                          style: TypographyTokens.titleLarge().copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: SpacingTokens.spacing3),
                        _SnapshotRow(
                          title: !isActive
                              ? 'This fan club is waiting for admin approval.'
                              : _joined
                              ? 'You are a member.'
                              : 'Join for updates & matchday coordination.',
                        ),
                        const SizedBox(height: SpacingTokens.spacing2),
                        _SnapshotRow(title: '$events events recorded.'),
                        const SizedBox(height: SpacingTokens.spacing2),
                        _SnapshotRow(title: '$members fans in this Group.'),
                      ],
                    ),
                  ),
                  const SizedBox(height: SpacingTokens.spacing4),
                  FanClubMatchdayAgendaSection(
                    isActive: isActive,
                    match: match,
                  ),
                  const SizedBox(height: SpacingTokens.spacing6),
                  Row(
                    children: [
                      Expanded(
                        child: AfriButton(
                          label: !isActive
                              ? 'PENDING REVIEW'
                              : _isJoinMutationPending
                              ? 'UPDATING...'
                              : _joined
                              ? 'JOINED'
                              : 'JOIN CLUB',
                          variant: AfriButtonVariant.primary,
                          enabled: isActive && !_isJoinMutationPending,
                          isLoading: isActive && _isJoinMutationPending,
                          onTap: _toggleJoin,
                        ),
                      ),
                      const SizedBox(width: SpacingTokens.spacing3),
                      if (isActive)
                        SizedBox(
                          width: 58,
                          height: 58,
                          child: AfriOutlinedButton(
                            onPressed: _copyShareLink,
                            style: AfriOutlinedButton.styleFrom(
                              side: BorderTokens.side(color: primary),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            child: const Icon(AfriIcons.share),
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

class FanClubMatchdayAgendaSection extends StatelessWidget {
  const FanClubMatchdayAgendaSection({
    required this.isActive,
    required this.match,
    super.key,
  });

  final bool isActive;
  final Map<String, dynamic>? match;

  @override
  Widget build(BuildContext context) {
    final agendaMatch = match;
    if (!isActive || agendaMatch == null) {
      return const SizedBox.shrink(
        key: ValueKey<String>('fan-club-matchday-agenda-empty'),
      );
    }

    return GlassCard(
      animate: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MATCHDAY AGENDA',
            style: TypographyTokens.titleLarge().copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing3),
          Text(
            '${agendaMatch['home_team']} vs ${agendaMatch['away_team']}',
            style: TypographyTokens.headlineMedium().copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing2),
          Text(
            '${agendaMatch['competition']}  •  ${agendaMatch['venue']}',
            style: TypographyTokens.bodyMedium(),
          ),
          const SizedBox(height: SpacingTokens.spacing2),
          Text(
            '${agendaMatch['match_date']}  •  ${agendaMatch['kickoff_time']}',
            style: TypographyTokens.bodySmall(),
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
            style: TypographyTokens.headlineLarge(
              ColorTokens.clubAccent,
            ).copyWith(fontWeight: FontWeight.w800),
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
