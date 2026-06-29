import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import '../official_fanclub_register.dart';
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
      final clubs = await _loadPublicFanclubs(client: client);

      if (!mounted) return;
      final loadedClubs = clubs;
      final availableFilters = _buildFilters(loadedClubs);
      setState(() {
        _clubs = loadedClubs;
        _joinedClubIds.clear();
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

  Future<List<Map<String, dynamic>>> _loadPublicFanclubs({
    required SupabaseClient client,
  }) async {
    try {
      final rows = await client
          .from('fanclubs')
          .select()
          .eq('approval_status', 'approved')
          .eq('active', true)
          .eq('visibility', 'public')
          .order('sort_order', ascending: true);
      final clubs = List<Map<String, dynamic>>.from(
        rows,
      ).map(normalizeFanclubRow).toList(growable: false);
      if (clubs.isNotEmpty) {
        return clubs;
      }
    } catch (_) {
      // Use the verified Gikundiro register as the offline public fallback.
    }

    return officialFanclubRegister();
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

    unawaited(HapticFeedback.lightImpact());
    AfriToast.info(
      context,
      'Fanclub requests use the protected review path before joining is confirmed.',
    );
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
                      SpacingTokens.spacing0,
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
                                style: TypographyTokens.labelLarge(
                                  ColorTokens.onSurfaceVariant,
                                ).copyWith(fontWeight: FontWeight.w700),
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
            isOfficial: club['is_official'] as bool? ?? false,
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
