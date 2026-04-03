import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class FanClubsListScreen extends ConsumerStatefulWidget {
  const FanClubsListScreen({super.key});

  @override
  ConsumerState<FanClubsListScreen> createState() => _FanClubsListScreenState();
}

class _FanClubsListScreenState extends ConsumerState<FanClubsListScreen> {
  final _searchController = TextEditingController();
  final Set<String> _joinedClubIds = <String>{};

  List<Map<String, dynamic>> _clubs = const <Map<String, dynamic>>[];
  bool _isLoading = true;
  String? _error;
  String _activeFilter = 'ALL';

  static const _filters = <String>[
    'ALL',
    'KIGALI',
    'INTERNATIONAL',
    'OFFICIAL',
  ];

  @override
  void initState() {
    super.initState();
    _loadClubs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadClubs() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final client = ref.read(supabaseClientProvider);
      final clubs = await client
          .from('fan_clubs')
          .select()
          .order('member_count', ascending: false);

      final userId = client.auth.currentUser?.id;
      final joined = <String>{};
      if (userId != null) {
        try {
          final memberships = await client
              .from('fan_club_members')
              .select('club_id')
              .eq('user_id', userId);
          for (final row in memberships) {
            final clubId = row['club_id']?.toString();
            if (clubId != null && clubId.isNotEmpty) {
              joined.add(clubId);
            }
          }
        } catch (_) {
          // Keep rendering the list even if membership lookups are locked down.
        }
      }

      if (!mounted) return;
      setState(() {
        _clubs = List<Map<String, dynamic>>.from(clubs);
        _joinedClubIds
          ..clear()
          ..addAll(joined);
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Could not load fan clubs right now.';
      });
    }
  }

  Future<void> _toggleJoin(Map<String, dynamic> club) async {
    final clubId = club['id']?.toString();
    final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;

    if (clubId == null || clubId.isEmpty) {
      return;
    }

    if (userId == null) {
      context.go('/onboarding');
      return;
    }

    final isJoined = _joinedClubIds.contains(clubId);
    HapticFeedback.lightImpact();

    try {
      if (isJoined) {
        await ref.read(supabaseClientProvider)
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
      setState(() {
        if (isJoined) {
          _joinedClubIds.remove(clubId);
        } else {
          _joinedClubIds.add(clubId);
        }

        _clubs = _clubs
            .map((entry) {
              if (entry['id']?.toString() != clubId) {
                return entry;
              }

              final current = (entry['member_count'] as num?)?.toInt() ?? 0;
              return <String, dynamic>{
                ...entry,
                'member_count': isJoined
                    ? (current - 1).clamp(0, current)
                    : current + 1,
              };
            })
            .toList(growable: false);
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isJoined
                ? 'Could not leave this fan club right now.'
                : 'Could not join this fan club right now.',
          ),
          backgroundColor: ColorTokens.error,
        ),
      );
    }
  }

  bool _isOfficial(Map<String, dynamic> club) {
    final members = (club['member_count'] as num?)?.toInt() ?? 0;
    final rating = (club['rating'] as num?)?.toDouble() ?? 0;
    return members >= 300 || rating >= 4.8;
  }

  List<Map<String, dynamic>> get _visibleClubs {
    final query = _searchController.text.trim().toLowerCase();
    return _clubs
        .where((club) {
          final region = club['region']?.toString().toLowerCase() ?? '';
          final name = club['name']?.toString().toLowerCase() ?? '';
          final matchesFilter = switch (_activeFilter) {
            'KIGALI' => region.contains('kigali'),
            'INTERNATIONAL' =>
              !(region.contains('kigali') ||
                  region.contains('northern') ||
                  region.contains('southern') ||
                  region.contains('western') ||
                  region.contains('eastern')),
            'OFFICIAL' => _isOfficial(club),
            _ => true,
          };
          final matchesQuery =
              query.isEmpty ||
              name.contains(query) ||
              region.contains(query) ||
              (club['description']?.toString().toLowerCase() ?? '').contains(
                query,
              );
          return matchesFilter && matchesQuery;
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final featuredClub = _clubs.isEmpty ? null : _clubs.first;

    return Scaffold(
      backgroundColor: ColorTokens.background,
      body: GradientBackground(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _loadClubs,
            color: primary,
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
                      0,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => context.pop(),
                          icon: Icon(
                            Icons.arrow_back_rounded,
                            color: ColorTokens.onSurface,
                          ),
                        ),
                        const SizedBox(width: SpacingTokens.spacing2),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'THE COMMUNITY',
                                style: GoogleFonts.barlowCondensed(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: ColorTokens.onSurfaceVariant,
                                  letterSpacing: 2.0,
                                ),
                              ),
                              Text(
                                'FAN CLUBS',
                                style: TypographyTokens.displaySmall(primary),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => context.push('/fan-clubs/create'),
                          icon: Icon(
                            Icons.add_circle_outline_rounded,
                            color: ColorTokens.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(SpacingTokens.spacing6),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        hintText: 'Search clubs or regions',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                    ),
                  ),
                ),
                if (featuredClub != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: SpacingTokens.spacing6,
                      ),
                      child: GlassCard(
                        padding: EdgeInsets.zero,
                        onTap: () =>
                            context.push('/fan-clubs/${featuredClub['id']}'),
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 200),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                ColorTokens.clubPrimary.withValues(alpha: 0.33),
                                ColorTokens.background.withValues(alpha: 0.67),
                                ColorTokens.surfaceContainerLowest,
                              ],
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(
                              SpacingTokens.spacing6,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: ColorTokens.clubAccent.withValues(
                                      alpha: 0.16,
                                    ),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    'FEATURED CLUB',
                                    style: GoogleFonts.inter(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: ColorTokens.clubAccent,
                                      letterSpacing: 1.3,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: SpacingTokens.spacing3),
                                Text(
                                  (featuredClub['name']?.toString() ??
                                          'FAN CLUB')
                                      .toUpperCase(),
                                  style: GoogleFonts.barlowCondensed(
                                    fontSize: 30,
                                    fontWeight: FontWeight.w800,
                                    color: ColorTokens.onSurface,
                                    letterSpacing: 0.6,
                                    height: 1,
                                  ),
                                ),
                                const SizedBox(height: SpacingTokens.spacing2),
                                Text(
                                  featuredClub['description']?.toString() ??
                                      'View chapter details.',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TypographyTokens.bodyMedium().copyWith(
                                    color: ColorTokens.onSurface.withValues(
                                      alpha: 0.88,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: SpacingTokens.spacing4),
                                Row(
                                  children: [
                                    _FeaturedMeta(
                                      label: 'REGION',
                                      value:
                                          featuredClub['region']?.toString() ??
                                          'Unknown',
                                    ),
                                    const SizedBox(
                                      width: SpacingTokens.spacing3,
                                    ),
                                    _FeaturedMeta(
                                      label: 'MEMBERS',
                                      value:
                                          '${(featuredClub['member_count'] as num?)?.toInt() ?? 0}',
                                    ),
                                    const SizedBox(
                                      width: SpacingTokens.spacing3,
                                    ),
                                    _FeaturedMeta(
                                      label: 'EVENTS',
                                      value:
                                          '${(featuredClub['event_count'] as num?)?.toInt() ?? 0}',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      SpacingTokens.spacing6,
                      SpacingTokens.spacing5,
                      SpacingTokens.spacing6,
                      0,
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _filters
                            .map((filter) {
                              final selected = filter == _activeFilter;
                              return Padding(
                                padding: const EdgeInsets.only(
                                  right: SpacingTokens.spacing2,
                                ),
                                child: ChoiceChip(
                                  selected: selected,
                                  label: Text(filter),
                                  onSelected: (_) =>
                                      setState(() => _activeFilter = filter),
                                ),
                              );
                            })
                            .toList(growable: false),
                      ),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: SpacingTokens.spacing4),
                ),
                if (_isLoading)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: SpacingTokens.spacing6,
                      ),
                      child: AfriSkeletonList(),
                    ),
                  )
                else if (_error != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(SpacingTokens.spacing6),
                      child: GlassCard(
                        animate: false,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_error!, style: TypographyTokens.bodyLarge()),
                            const SizedBox(height: SpacingTokens.spacing3),
                            ClaymorphicButton(
                              label: 'TRY AGAIN',
                              width: double.infinity,
                              onPressed: _loadClubs,
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else if (_visibleClubs.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(SpacingTokens.spacing6),
                      child: GlassCard(
                        animate: false,
                        child: Column(
                          children: [
                            Icon(
                              Icons.groups_rounded,
                              size: 42,
                              color: ColorTokens.onSurfaceVariant,
                            ),
                            const SizedBox(height: SpacingTokens.spacing3),
                            Text(
                              'No fan clubs match this filter yet.',
                              style: TypographyTokens.bodyLarge(),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final club = _visibleClubs[index];
                      final clubId = club['id']?.toString() ?? '';
                      final joined = _joinedClubIds.contains(clubId);
                      final members =
                          (club['member_count'] as num?)?.toInt() ?? 0;
                      final rating = (club['rating'] as num?)?.toDouble() ?? 0;

                      return Padding(
                        padding: EdgeInsets.fromLTRB(
                          SpacingTokens.spacing6,
                          0,
                          SpacingTokens.spacing6,
                          index == _visibleClubs.length - 1
                              ? SpacingTokens.spacing20
                              : SpacingTokens.spacing3,
                        ),
                        child: GlassCard(
                          animate: false,
                          onTap: () => context.push('/fan-clubs/$clubId'),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          (club['name']?.toString() ??
                                                  'Fan Club')
                                              .toUpperCase(),
                                          style: GoogleFonts.barlowCondensed(
                                            fontSize: 24,
                                            fontWeight: FontWeight.w800,
                                            color: ColorTokens.onSurface,
                                            height: 1,
                                          ),
                                        ),
                                        const SizedBox(
                                          height: SpacingTokens.spacing2,
                                        ),
                                        Text(
                                          club['description']?.toString() ??
                                              'Supporter chapter details unavailable.',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TypographyTokens.bodyMedium(),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: SpacingTokens.spacing3),
                                  if (_isOfficial(club))
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: ColorTokens.clubAccent
                                            .withValues(alpha: 0.14),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Text(
                                        'OFFICIAL',
                                        style: GoogleFonts.inter(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: ColorTokens.clubAccent,
                                          letterSpacing: 1.1,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: SpacingTokens.spacing4),
                              Wrap(
                                spacing: SpacingTokens.spacing2,
                                runSpacing: SpacingTokens.spacing2,
                                children: [
                                  _MetaPill(
                                    icon: Icons.place_outlined,
                                    label:
                                        club['region']?.toString() ?? 'Unknown',
                                  ),
                                  _MetaPill(
                                    icon: Icons.people_outline_rounded,
                                    label: '$members members',
                                  ),
                                  _MetaPill(
                                    icon: Icons.star_rounded,
                                    label: rating == 0
                                        ? 'New'
                                        : rating.toStringAsFixed(1),
                                  ),
                                ],
                              ),
                              const SizedBox(height: SpacingTokens.spacing4),
                              Column(
                                children: [
                                  ClaymorphicButton(
                                    label: joined ? 'JOINED' : 'JOIN CLUB',
                                    width: double.infinity,
                                    onPressed: () => _toggleJoin(club),
                                  ),
                                  const SizedBox(height: SpacingTokens.spacing2),
                                  OutlinedButton(
                                    onPressed: () =>
                                        context.push('/fan-clubs/$clubId'),
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(
                                        double.infinity,
                                        52,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          18,
                                        ),
                                      ),
                                    ),
                                    child: const Text('VIEW DETAILS'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }, childCount: _visibleClubs.length),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeaturedMeta extends StatelessWidget {
  const _FeaturedMeta({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: ColorTokens.onSurfaceVariant,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.barlowCondensed(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: ColorTokens.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: ColorTokens.surfaceContainerLow,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: ColorTokens.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: ColorTokens.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
