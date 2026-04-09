import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/fan_club_cards.dart';

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
    'OFFICIAL',
    'KIGALI',
    'NORTHERN',
    'SOUTHERN',
    'EASTERN',
    'WESTERN',
    'INTERNATIONAL',
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
      final clubId = _currentClubId(client);
      if (clubId == null) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _error = 'Could not resolve the active club.';
        });
        return;
      }
      final clubs = await client
          .from('fan_clubs')
          .select()
          .eq('club_id', clubId)
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
            'NORTHERN' => region.contains('northern'),
            'SOUTHERN' => region.contains('southern'),
            'WESTERN' => region.contains('western'),
            'EASTERN' => region.contains('eastern'),
            'INTERNATIONAL' =>
              region.contains('international') ||
                  (!region.contains('kigali') &&
                      !region.contains('northern') &&
                      !region.contains('southern') &&
                      !region.contains('western') &&
                      !region.contains('eastern') &&
                      region != 'official'),
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
                      child: FanClubFeaturedCard(
                        club: featuredClub,
                        onTap: () =>
                            context.push('/fan-clubs/${featuredClub['id']}'),
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

                      return Padding(
                        padding: EdgeInsets.fromLTRB(
                          SpacingTokens.spacing6,
                          0,
                          SpacingTokens.spacing6,
                          index == _visibleClubs.length - 1
                              ? SpacingTokens.spacing20
                              : SpacingTokens.spacing3,
                        ),
                        child: FanClubListItem(
                          club: club,
                          isJoined: joined,
                          isOfficial: _isOfficial(club),
                          onTap: () => context.push('/fan-clubs/$clubId'),
                          onJoinToggled: () => _toggleJoin(club),
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
