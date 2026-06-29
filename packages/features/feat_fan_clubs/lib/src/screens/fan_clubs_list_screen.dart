import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../widgets/fan_club_cards.dart';

class FanClubsListScreen extends ConsumerStatefulWidget {
  const FanClubsListScreen({super.key});

  @override
  ConsumerState<FanClubsListScreen> createState() => _FanClubsListScreenState();
}

class _FanClubsListScreenState extends ConsumerState<FanClubsListScreen> {
  final _searchController = TextEditingController();
  final Set<String> _joinedClubIds = <String>{};
  final Set<String> _pendingClubIds = <String>{};

  List<Map<String, dynamic>> _clubs = const <Map<String, dynamic>>[];
  bool _isLoading = true;
  String? _error;
  String _activeFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    unawaited(_loadClubs());
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
      final resolver = ClubScopeResolver(client: client);
      final scope = await resolver.requireResolved();
      if (scope.clubId == null) {
        throw StateError('Fan clubs require a numeric club scope.');
      }
      final clubs = await client
          .from('fan_clubs')
          .select()
          .eq('club_id', scope.clubId!)
          .eq('is_active', true)
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
      final loadedClubs = List<Map<String, dynamic>>.from(clubs);
      final availableFilters = _buildFilters(loadedClubs);
      setState(() {
        _clubs = loadedClubs;
        _joinedClubIds
          ..clear()
          ..addAll(joined);
        if (!availableFilters.contains(_activeFilter)) {
          _activeFilter = 'ALL';
        }
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

    if (clubId == null || clubId.isEmpty || _pendingClubIds.contains(clubId)) {
      return;
    }

    if (userId == null) {
      context.go('/onboarding');
      return;
    }

    final isJoined = _joinedClubIds.contains(clubId);
    unawaited(HapticFeedback.lightImpact());
    setState(() => _pendingClubIds.add(clubId));

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
      AfriToast.error(
        context,
        isJoined
            ? 'Could not leave this fan club right now.'
            : 'Could not join this fan club right now.',
      );
    } finally {
      if (mounted) {
        setState(() => _pendingClubIds.remove(clubId));
      }
    }
  }

  List<String> _buildFilters(List<Map<String, dynamic>> clubs) {
    final filters = <String>['ALL'];
    final seen = <String>{'all'};

    for (final club in clubs) {
      final region = _trimmedRegion(club['region']);
      if (region == null) {
        continue;
      }
      final key = region.toLowerCase();
      if (seen.add(key)) {
        filters.add(region);
      }
    }

    return filters;
  }

  List<Map<String, dynamic>> get _visibleClubs {
    final query = _searchController.text.trim().toLowerCase();
    return _clubs
        .where((club) {
          final region = _trimmedRegion(club['region'])?.toLowerCase() ?? '';
          final name = club['name']?.toString().toLowerCase() ?? '';
          final normalizedFilter = _activeFilter.trim().toLowerCase();
          final matchesFilter =
              normalizedFilter == 'all' || region == normalizedFilter;
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
    final primary = ColorTokens.clubPrimary;
    final featuredClub = _clubs.isEmpty ? null : _clubs.first;
    final filters = _buildFilters(_clubs);

    return Scaffold(
      backgroundColor: ColorTokens.background,
      body: GradientBackground(
        child: SafeArea(
          child: AfriRefreshIndicator(
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
                        AfriIconButton(
                          icon: AfriIcons.back,
                          onTap: () => context.pop(),
                          tooltip: 'Back',
                        ),
                        const SizedBox(width: SpacingTokens.spacing2),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'THE COMMUNITY',
                                style:
                                    TypographyTokens.labelLarge(
                                      ColorTokens.onSurfaceVariant,
                                    ).copyWith(
                                      fontWeight: FontWeight.w700,
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
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(SpacingTokens.screenPadding),
                    child: AfriInputField(
                      controller: _searchController,
                      hint: 'Search clubs or locations',
                      prefixIcon: AfriIcons.search,
                      onChanged: (_) => setState(() {}),
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
                        onTap: () => unawaited(
                          context.push('/fan-clubs/${featuredClub['id']}'),
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
                        children: filters
                            .map((filter) {
                              final selected = filter == _activeFilter;
                              return Padding(
                                padding: const EdgeInsets.only(
                                  right: SpacingTokens.spacing2,
                                ),
                                child: AfriChoiceChip(
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
                FanClubsResultsSliver(
                  isLoading: _isLoading,
                  error: _error,
                  visibleClubs: _visibleClubs,
                  joinedClubIds: _joinedClubIds,
                  pendingClubIds: _pendingClubIds,
                  onRetry: () => unawaited(_loadClubs()),
                  onOpenClub: (clubId) =>
                      unawaited(context.push('/fan-clubs/$clubId')),
                  onJoinToggled: _toggleJoin,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FanClubsResultsSliver extends StatelessWidget {
  const FanClubsResultsSliver({
    super.key,
    required this.isLoading,
    required this.error,
    required this.visibleClubs,
    required this.joinedClubIds,
    required this.pendingClubIds,
    required this.onRetry,
    required this.onOpenClub,
    required this.onJoinToggled,
  });

  final bool isLoading;
  final String? error;
  final List<Map<String, dynamic>> visibleClubs;
  final Set<String> joinedClubIds;
  final Set<String> pendingClubIds;
  final VoidCallback onRetry;
  final ValueChanged<String> onOpenClub;
  final ValueChanged<Map<String, dynamic>> onJoinToggled;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: SpacingTokens.spacing6),
          child: AfriSkeletonList(),
        ),
      );
    }

    if (error != null) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(SpacingTokens.screenPadding),
          child: AfriErrorView(compact: true, message: error, onRetry: onRetry),
        ),
      );
    }

    if (visibleClubs.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final club = visibleClubs[index];
        final clubId = club['id']?.toString() ?? '';
        final joined = joinedClubIds.contains(clubId);
        final isPending = pendingClubIds.contains(clubId);

        return Padding(
          padding: EdgeInsets.fromLTRB(
            SpacingTokens.spacing6,
            0,
            SpacingTokens.spacing6,
            index == visibleClubs.length - 1
                ? SpacingTokens.spacing20
                : SpacingTokens.spacing3,
          ),
          child: FanClubListItem(
            club: club,
            isJoined: joined,
            isPending: isPending,
            isOfficial: false,
            onTap: () => onOpenClub(clubId),
            onJoinToggled: () => onJoinToggled(club),
          ),
        );
      }, childCount: visibleClubs.length),
    );
  }
}

String? _trimmedRegion(Object? value) {
  final trimmed = value?.toString().trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}
